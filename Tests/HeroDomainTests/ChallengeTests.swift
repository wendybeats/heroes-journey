import XCTest
@testable import HeroDomain

/// Doc 33 challenges: banded odds that scale with level, a training bonus that moves them, a seeded roll on the
/// fact, grants priced by the ruleset (XP plus at most one point), and a cadence of 2–4 a week.
final class ChallengeTests: XCTestCase {
    let user = UserID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var ruleset: ProgressionRuleset {
        ProgressionRuleset(id: "ruleset.test", version: 1, status: .dev, xpPerMinuteByFamily: ["strength": 2.0], attributeWeightsByFamily: ["strength": ["strength": 1.0, "endurance": 0.2], "cardio": ["endurance": 1.0]],
                           attributePointsPerXP: 0.1, verificationMultiplier: [:], dailyTaper: .init(fullCreditMinutes: 30, taperRate: 0.2, hardCapMinutes: 90), minimumDurationSeconds: 60,
                           levelThresholdsTotalXP: [0, 97, 206, 327, 467, 648, 869, 1113, 1386, 1700, 2014], dailyActivityXPCap: 40,
                           challenges: .init(difficulty: ["easy": 0.6, "standard": 0.8, "hard": 1.1],
                                             grant: ["easy": .init(xp: 8, points: 0, loseXP: 2), "standard": .init(xp: 12, points: 1, loseXP: 3), "hard": .init(xp: 18, points: 1, loseXP: 4)],
                                             cadence: .init(fromLevel: 2, chancePerDay: 0.45, minGapDays: 1, maxGapDays: 3),
                                             trainingBonus: .init(targetSharePerMinute: 0.02, maxTargetShare: 0.8)))
    }

    func testTargetScalesWithLevelAndDifficulty() {
        let r = ruleset
        let s2 = ChallengeMath.share(level: 2, ruleset: r, attributeCount: 4), s8 = ChallengeMath.share(level: 8, ruleset: r, attributeCount: 4)
        XCTAssertGreaterThan(s8, s2 * 5, "the balanced share grows with the curve")
        XCTAssertEqual(s8, 0.1 * Double(1113 + 1386) / 2 / 4, accuracy: 0.001, "Level 8 sits between its own threshold (index 7) and the next")
        let easy = ChallengeMath.target(difficulty: "easy", share: s8, ruleset: r), hard = ChallengeMath.target(difficulty: "hard", share: s8, ruleset: r)
        XCTAssertEqual(easy, s8 * 0.6, accuracy: 0.001); XCTAssertEqual(hard, s8 * 1.1, accuracy: 0.001)
        XCTAssertEqual(ChallengeMath.target(difficulty: "unknown", share: s8, ruleset: r), s8 * 0.8, accuracy: 0.001, "unknown words read as standard")
    }

    func testBandsReadSpecialistAgainstBalanced() {
        let r = ruleset
        let target = ChallengeMath.target(difficulty: "standard", share: ChallengeMath.share(level: 8, ruleset: r, attributeCount: 4), ruleset: r)   // ≈ 31
        XCTAssertEqual(ChallengeMath.band(probability: ChallengeMath.winProbability(stat: 60, target: target), ruleset: r), .likely)
        XCTAssertEqual(ChallengeMath.band(probability: ChallengeMath.winProbability(stat: 31, target: target), ruleset: r), .even)
        XCTAssertEqual(ChallengeMath.band(probability: ChallengeMath.winProbability(stat: 12, target: target), ruleset: r), .longShot)
        XCTAssertEqual(ChallengeMath.winProbability(stat: target, target: target), 0.5, accuracy: 0.0001)
    }

    /// The owner's loop: Long shot → one 30-minute strength session → Even.
    func testTrainingBonusMovesTheBand() {
        let r = ruleset
        let target = ChallengeMath.target(difficulty: "standard", share: ChallengeMath.share(level: 8, ruleset: r, attributeCount: 4), ruleset: r)
        let before = ChallengeMath.winProbability(stat: 12, target: target)
        XCTAssertEqual(ChallengeMath.band(probability: before, ruleset: r), .longShot)
        let bonus = ChallengeMath.trainingBonus(minutesByFamily: ["strength": 30], attributeID: "strength", target: target, ruleset: r)
        XCTAssertEqual(bonus, 0.6 * target, accuracy: 0.001)
        XCTAssertEqual(ChallengeMath.band(probability: ChallengeMath.winProbability(stat: 12 + bonus, target: target), ruleset: r), .even)
        // Cardio feeds endurance, not strength: no help on a strength test. The cap holds at 80 % of the target.
        XCTAssertEqual(ChallengeMath.trainingBonus(minutesByFamily: ["cardio": 60], attributeID: "strength", target: target, ruleset: r), 0)
        XCTAssertEqual(ChallengeMath.trainingBonus(minutesByFamily: ["strength": 300], attributeID: "strength", target: target, ruleset: r), 0.8 * target, accuracy: 0.001)
    }

    func testRollIsSeededAndUniform() {
        XCTAssertEqual(ChallengeMath.roll(seed: "a|2026-10-12|u"), ChallengeMath.roll(seed: "a|2026-10-12|u"))
        XCTAssertNotEqual(ChallengeMath.roll(seed: "a|2026-10-12|u"), ChallengeMath.roll(seed: "a|2026-10-13|u"))
        var sum = 0.0
        for i in 0..<4000 { let v = ChallengeMath.roll(seed: "seed\(i)"); XCTAssertTrue(v >= 0 && v < 1); sum += v }
        XCTAssertEqual(sum / 4000, 0.5, accuracy: 0.03)
    }

    func testEngineGrantsByOutcomeAndDifficultyOnceAndIgnoresTheCap() async throws {
        let r = ruleset
        func ref(_ won: Bool, _ difficulty: String) -> ChallengeReference {
            ChallengeReference(challengeID: "challenge.test", characterID: "npc.x", attributeID: "strength", difficulty: difficulty, stat: 20, trainingBonus: 0, target: 25, probability: 0.4, roll: won ? 0.1 : 0.9, won: won, setIndex: 0)
        }
        let capped = EvaluationContext(priorEligibleMinutesToday: 90, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:], priorActivityXPToday: 40)
        let win = ProgressionEngine.evaluate(event: ChallengeReference.makeEvent(ref(true, "hard"), userID: user, familyFallback: "strength", at: now), ruleset: r, context: capped)
        XCTAssertEqual(win.xp, 18); XCTAssertEqual(win.attributes, ["strength": 1], "at most one point, and the daily activity cap does not apply")
        let easyWin = ProgressionEngine.evaluate(event: ChallengeReference.makeEvent(ref(true, "easy"), userID: user, familyFallback: "strength", at: now), ruleset: r, context: capped)
        XCTAssertEqual(easyWin.xp, 8); XCTAssertTrue(easyWin.attributes.isEmpty)
        let loss = ProgressionEngine.evaluate(event: ChallengeReference.makeEvent(ref(false, "standard"), userID: user, familyFallback: "strength", at: now), ruleset: r, context: capped)
        XCTAssertEqual(loss.xp, 3); XCTAssertTrue(loss.attributes.isEmpty, "a loss never costs anything and never grants a stat")
        // Through the service: the same fact submitted twice grants once.
        let service = LocalAuthorityProgressionService(authority: .init(ruleset: r, levelRewards: [:], calendar: .current), owner: user)
        let event = ChallengeReference.makeEvent(ref(true, "standard"), userID: user, familyFallback: "strength", at: now)
        let first = try await service.submit(ProgressionSubmission(event: event, contentVersion: "t", submittedAt: now))
        let second = try await service.submit(ProgressionSubmission(event: event, contentVersion: "t", submittedAt: now))
        XCTAssertEqual(first.xp, 12); XCTAssertTrue(second.wasAlreadyProcessed)
        let ledger = await service.ledger
        XCTAssertEqual(ledger.xp.filter { $0.activityEventID == event.id }.count, 1)
        XCTAssertEqual(ChallengeMath.record(challengeID: "challenge.test", events: [event, event]).won, 2)
    }

    func testCadenceAveragesTwoToFourAWeekWithNoBackToBackDays() {
        let r = ruleset
        var offers = 0, last: Int? = nil
        for day in 0..<365 {
            let gap = last.map { day - $0 }
            if ChallengeMath.offersToday(level: 5, daysSinceLastOffer: gap, seed: "u|\(day)", ruleset: r) {
                if let l = last { XCTAssertGreaterThan(day - l, 1, "never two days running"); XCTAssertLessThanOrEqual(day - l, 4, "guaranteed by the third quiet day") }
                offers += 1; last = day
            }
        }
        let perWeek = Double(offers) / 52
        XCTAssertGreaterThan(perWeek, 2.0, "\(perWeek)"); XCTAssertLessThan(perWeek, 4.0, "\(perWeek)")
        XCTAssertFalse(ChallengeMath.offersToday(level: 1, daysSinceLastOffer: nil, seed: "x", ruleset: r), "not before from_level")
    }

    func testChallengeReferenceRoundTrips() throws {
        let ref = ChallengeReference(challengeID: "challenge.cairon.strength", characterID: "guide.elder", attributeID: "strength", difficulty: "standard", stat: 14, trainingBonus: 6.5, target: 20, probability: 0.52, roll: 0.3, won: true, setIndex: 2)
        let event = ChallengeReference.makeEvent(ref, userID: user, familyFallback: "strength", at: now)
        let data = try JSONEncoder().encode(event)
        let back = try JSONDecoder().decode(ActivityEvent.self, from: data)
        XCTAssertEqual(back.challenge, ref); XCTAssertEqual(back.source, .challenge)
        // An archive written before challenges decodes with no reference.
        let old = try JSONDecoder().decode(ActivityEvent.self, from: try JSONEncoder().encode(ActivityEvent(userID: user, activityTypeID: "a", familyID: "strength", startedAt: now, durationSeconds: 600, source: .manual, verification: .selfReported)))
        XCTAssertNil(old.challenge)
    }
}

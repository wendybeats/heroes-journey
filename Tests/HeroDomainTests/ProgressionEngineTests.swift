import XCTest
@testable import HeroDomain

final class ProgressionEngineTests: XCTestCase {
    let user = UserID()
    let calendar: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    let day = Date(timeIntervalSince1970: 1_800_000_000)  // fixed, deterministic

    var ruleset: ProgressionRuleset {
        ProgressionRuleset(
            id: "ruleset.test", version: 1, status: .dev,
            xpPerMinuteByFamily: ["strength": 2.0, "learning": 1.0],
            attributeWeightsByFamily: ["strength": ["strength": 1.0, "endurance": 0.2], "learning": ["knowledge": 1.0]],
            attributePointsPerXP: 0.5,
            verificationMultiplier: ["verified": 1.0, "structured": 1.0, "self_reported": 1.0],
            dailyTaper: .init(fullCreditMinutes: 90, taperRate: 0.25, hardCapMinutes: 240),
            minimumDurationSeconds: 60,
            levelThresholdsTotalXP: [0, 60, 150, 280, 450]
        )
    }
    let levelRewards: [Int: [RewardID]] = [2: ["reward.l2"], 3: ["reward.l3"], 5: ["reward.l5"]]

    func event(minutes: Int, family: FamilyID = "strength", type: ActivityTypeID = "weightlifting", at: Date? = nil, id: ActivityEventID = ActivityEventID()) -> ActivityEvent {
        ActivityEvent(id: id, userID: user, activityTypeID: type, familyID: family, startedAt: at ?? day, durationSeconds: minutes * 60, source: .manual, verification: .selfReported, createdAt: day)
    }
    func context(prior: Double = 0, xp: Int = 0, granted: Set<RewardID> = []) -> EvaluationContext {
        EvaluationContext(priorEligibleMinutesToday: prior, priorTotalXP: xp, grantedRewardIDs: granted, levelRewards: levelRewards)
    }

    // MARK: pure calculation

    func testBasicXPAndAttributes() {
        let p = ProgressionEngine.evaluate(event: event(minutes: 30), ruleset: ruleset, context: context())
        XCTAssertEqual(p.xp, 60)                                  // 30 min × 2 xp/min
        XCTAssertEqual(p.attributes["strength"], 30)              // 60 × 0.5 × 1.0
        XCTAssertEqual(p.attributes["endurance"], 6)              // 60 × 0.5 × 0.2
        XCTAssertNil(p.attributes["knowledge"])
        XCTAssertEqual(p.eligibleMinutes, 30)
    }

    func testDeterministic() {
        let e = event(minutes: 45)
        let a = ProgressionEngine.evaluate(event: e, ruleset: ruleset, context: context(prior: 10, xp: 100))
        let b = ProgressionEngine.evaluate(event: e, ruleset: ruleset, context: context(prior: 10, xp: 100))
        XCTAssertEqual(a, b)
    }

    func testBelowMinimumDurationEarnsNothing() {
        let p = ProgressionEngine.evaluate(event: event(minutes: 0), ruleset: ruleset, context: context())
        XCTAssertTrue(p.isEmpty)
    }

    func testUnknownFamilyEarnsNothingButDoesNotCrash() {
        let p = ProgressionEngine.evaluate(event: event(minutes: 30, family: "cardio", type: "running"), ruleset: ruleset, context: context())
        XCTAssertTrue(p.isEmpty)
    }

    func testDailyTaperReducesButNeverBlocks() {
        // 0→90 full, 90→240 at 25 %, >240 nothing
        XCTAssertEqual(ProgressionEngine.creditedMinutes(60, prior: 0, taper: ruleset.dailyTaper), 60)
        XCTAssertEqual(ProgressionEngine.creditedMinutes(60, prior: 60, taper: ruleset.dailyTaper), 30 + 30 * 0.25)
        XCTAssertEqual(ProgressionEngine.creditedMinutes(60, prior: 200, taper: ruleset.dailyTaper), 40 * 0.25)
        XCTAssertEqual(ProgressionEngine.creditedMinutes(60, prior: 300, taper: ruleset.dailyTaper), 0)
        // the event itself is still a valid fact; only the game credit tapers
        let p = ProgressionEngine.evaluate(event: event(minutes: 60), ruleset: ruleset, context: context(prior: 300))
        XCTAssertEqual(p.xp, 0)
    }

    func testLevelThresholdsAndNextLevel() {
        XCTAssertEqual(ruleset.level(forTotalXP: 0), 1)
        XCTAssertEqual(ruleset.level(forTotalXP: 59), 1)
        XCTAssertEqual(ruleset.level(forTotalXP: 60), 2)
        XCTAssertEqual(ruleset.level(forTotalXP: 449), 4)
        XCTAssertEqual(ruleset.level(forTotalXP: 450), 5)
        XCTAssertEqual(ruleset.level(forTotalXP: 99_999), 5, "no technical max: stays at last content level")
        XCTAssertEqual(ruleset.xpToNextLevel(fromTotalXP: 10), 50)
        XCTAssertNil(ruleset.xpToNextLevel(fromTotalXP: 450))
    }

    func testLevelUpUnlocksEverySkippedLevelReward() {
        // 0 → 160 xp jumps L1 → L3 in one event; both L2 and L3 rewards are proposed
        let p = ProgressionEngine.evaluate(event: event(minutes: 80), ruleset: ruleset, context: context())
        XCTAssertEqual(p.levelBefore, 1); XCTAssertEqual(p.levelAfter, 3)
        XCTAssertEqual(p.rewardsUnlocked, ["reward.l2", "reward.l3"])
    }

    func testAlreadyGrantedRewardIsNotProposedAgain() {
        let p = ProgressionEngine.evaluate(event: event(minutes: 80), ruleset: ruleset, context: context(granted: ["reward.l2"]))
        XCTAssertEqual(p.rewardsUnlocked, ["reward.l3"])
    }

    // MARK: ledger invariants (doc 13)

    func testProcessingSameEventTwiceDoesNotDoubleGrant() {
        var ledger = ProgressionLedger()
        let e = event(minutes: 80)
        let p = ProgressionEngine.evaluate(event: e, ruleset: ruleset, context: context())
        XCTAssertTrue(ledger.commit(p, for: e, at: day))
        XCTAssertFalse(ledger.commit(p, for: e, at: day), "retry must be a no-op")
        let s = ledger.snapshot(ruleset: ruleset)
        XCTAssertEqual(s.totalXP, 160)
        XCTAssertEqual(ledger.rewards.count, 2)
        XCTAssertEqual(ledger.processing.count, 1)
    }

    func testEarnedRewardsRemainAfterRulesetChange() {
        var ledger = ProgressionLedger()
        let e1 = event(minutes: 80)
        ledger.commit(ProgressionEngine.evaluate(event: e1, ruleset: ruleset, context: context()), for: e1, at: day)
        XCTAssertEqual(ledger.snapshot(ruleset: ruleset).level, 3)

        // A harsher v2 curve: the same XP is now only Level 2. Facts and grants are untouched.
        let harsher = ProgressionRuleset(id: "ruleset.test", version: 2, status: .active,
            xpPerMinuteByFamily: ruleset.xpPerMinuteByFamily, attributeWeightsByFamily: ruleset.attributeWeightsByFamily,
            attributePointsPerXP: 0.5, verificationMultiplier: ruleset.verificationMultiplier, dailyTaper: ruleset.dailyTaper,
            minimumDurationSeconds: 60, levelThresholdsTotalXP: [0, 100, 300, 600, 1000])
        let s2 = ledger.snapshot(ruleset: harsher)
        XCTAssertEqual(s2.totalXP, 160, "ledger unchanged")
        XCTAssertEqual(s2.grantedRewards, ["reward.l2", "reward.l3"], "grants remain earned")
        XCTAssertEqual(ledger.xp.first?.rulesetID, "ruleset.test")
        XCTAssertEqual(e1.durationSeconds, 80 * 60, "activity fact unchanged")
    }

    func testContextDerivesSameDayMinutesPerFamilyOnly() {
        var ledger = ProgressionLedger()
        let a = event(minutes: 50, at: day)
        let b = event(minutes: 20, family: "learning", type: "reading", at: day)
        let c = event(minutes: 40, at: day.addingTimeInterval(-86_400))  // yesterday
        for e in [a, b, c] {
            ledger.commit(ProgressionEngine.evaluate(event: e, ruleset: ruleset, context: context()), for: e, at: day)
        }
        let next = event(minutes: 60, at: day.addingTimeInterval(3600))
        let ctx = ledger.context(for: next, ruleset: ruleset, events: [a, b, c, next], levelRewards: levelRewards, calendar: calendar)
        XCTAssertEqual(ctx.priorEligibleMinutesToday, 50, "only same family, same day, already processed")
        XCTAssertEqual(ctx.priorTotalXP, 100 + 20 + 80)
    }

    func testBackfillIsSeparateProcessingIdentity() {
        var ledger = ProgressionLedger()
        let e = event(minutes: 30)
        ledger.commit(ProgressionEngine.evaluate(event: e, ruleset: ruleset, context: context()), for: e, at: day)
        let backfill = ProgressionProposal(activityEventID: e.id, rulesetID: "ruleset.agility-backfill", xp: 0, attributes: ["agility": 5], levelBefore: 1, levelAfter: 1, rewardsUnlocked: [], eligibleMinutes: 0)
        XCTAssertTrue(ledger.commit(backfill, for: e, purpose: .backfill, at: day))
        XCTAssertFalse(ledger.commit(backfill, for: e, purpose: .backfill, at: day))
        XCTAssertEqual(ledger.attributes.last?.reason, .backfill)
        XCTAssertEqual(ledger.snapshot(ruleset: ruleset).attributes["agility"], 5)
    }

    func testEventIDIsStableAcrossRetries() throws {
        let e = event(minutes: 10)
        let data = try JSONEncoder().encode(e)
        let decoded = try JSONDecoder().decode(ActivityEvent.self, from: data)
        XCTAssertEqual(decoded.id, e.id)
        XCTAssertEqual(decoded, e)
    }

    // MARK: dev-5 cross-family daily cap

    func testDailyActivityCapAppliesAcrossFamiliesAndNotToGoals() {
        let capped = ProgressionRuleset(id: "ruleset.cap", version: 1, status: .dev, xpPerMinuteByFamily: ["strength": 2.0, "learning": 1.0],
                                        attributeWeightsByFamily: ["strength": ["strength": 1.0], "learning": ["knowledge": 1.0]], attributePointsPerXP: 0.5,
                                        verificationMultiplier: [:], dailyTaper: ruleset.dailyTaper, minimumDurationSeconds: 60, levelThresholdsTotalXP: [0, 1000],
                                        goalXP: ["primary": 30], dailyActivityXPCap: 40)
        // First session: 30 min strength = 60 xp, capped to 40; attributes follow the capped amount.
        let first = ProgressionEngine.evaluate(event: event(minutes: 30), ruleset: capped, context: context())
        XCTAssertEqual(first.xp, 40); XCTAssertEqual(first.attributes["strength"], 20)
        // Second session in another family on the same day: the cap is already spent.
        let spent = EvaluationContext(priorEligibleMinutesToday: 0, priorTotalXP: 40, grantedRewardIDs: [], levelRewards: [:], priorActivityXPToday: 40)
        let second = ProgressionEngine.evaluate(event: event(minutes: 30, family: "learning", type: "reading"), ruleset: capped, context: spent)
        XCTAssertEqual(second.xp, 0); XCTAssertTrue(second.attributes.isEmpty)
        XCTAssertEqual(second.eligibleMinutes, 30, "minutes are still recorded as credited for the taper; only XP is capped")
        // Goals sit outside the cap.
        let goal = ActivityEvent(userID: user, activityTypeID: "goal.x", familyID: "strength", startedAt: day, durationSeconds: 0, source: .goal, verification: .selfReported,
                                 goal: GoalReference(templateID: "goal.x", slot: .primary, attributeID: "strength"), createdAt: day)
        XCTAssertEqual(ProgressionEngine.evaluate(event: goal, ruleset: capped, context: spent).xp, 30)
    }

    func testLedgerContextCountsTodaysActivityXPAcrossFamilies() {
        let capped = ProgressionRuleset(id: "ruleset.cap", version: 1, status: .dev, xpPerMinuteByFamily: ["strength": 2.0, "learning": 1.0],
                                        attributeWeightsByFamily: [:], attributePointsPerXP: 0.5, verificationMultiplier: [:], dailyTaper: ruleset.dailyTaper,
                                        minimumDurationSeconds: 60, levelThresholdsTotalXP: [0], dailyActivityXPCap: 40)
        var ledger = ProgressionLedger()
        let a = event(minutes: 15)                                                       // 30 xp
        ledger.commit(ProgressionEngine.evaluate(event: a, ruleset: capped, context: context()), for: a, at: day)
        let b = event(minutes: 30, family: "learning", type: "reading", at: day.addingTimeInterval(3600))
        let ctx = ledger.context(for: b, ruleset: capped, events: [a, b], levelRewards: [:], calendar: calendar)
        XCTAssertEqual(ctx.priorActivityXPToday, 30)
        XCTAssertEqual(ctx.priorEligibleMinutesToday, 0, "per-family taper context is still per family")
        XCTAssertEqual(ProgressionEngine.evaluate(event: b, ruleset: capped, context: ctx).xp, 10)
        let tomorrow = event(minutes: 30, at: day.addingTimeInterval(86_400 * 2))
        XCTAssertEqual(ledger.context(for: tomorrow, ruleset: capped, events: [a, b, tomorrow], levelRewards: [:], calendar: calendar).priorActivityXPToday, 0)
    }
}

final class StrainTests: XCTestCase {
    let user = UserID()
    let day = Date(timeIntervalSince1970: 1_800_000_000)
    let calendar = Calendar(identifier: .gregorian)
    var strained: ProgressionRuleset {
        ProgressionRuleset(id: "ruleset.strain", version: 1, status: .dev, xpPerMinuteByFamily: ["strength": 2.0, "learning": 1.0, "cardio": 2.0],
                           attributeWeightsByFamily: ["strength": ["strength": 1.0]], attributePointsPerXP: 0.5, verificationMultiplier: [:],
                           dailyTaper: .init(fullCreditMinutes: 90, taperRate: 0.25, hardCapMinutes: 240), minimumDurationSeconds: 60, levelThresholdsTotalXP: [0, 100_000],
                           dailyActivityStrain: .init(fullCreditXP: 120, bands: [.init(upTo: 200, rate: 0.5), .init(upTo: 400, rate: 0.25)]))
    }
    func event(minutes: Int, family: FamilyID = "strength", at: Date? = nil) -> ActivityEvent {
        ActivityEvent(userID: user, activityTypeID: ActivityTypeID(family.rawValue), familyID: family, startedAt: at ?? day, durationSeconds: minutes * 60, source: .manual, verification: .selfReported, createdAt: day)
    }
    func ctx(priorRaw: Int) -> EvaluationContext { EvaluationContext(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:], priorActivityXPToday: priorRaw) }

    /// Owner 2026-10-17: full to 120, half to 200, a quarter to 400, nothing after; a day tops out at 210.
    func testBandsArePiecewiseOverTheDaysRawXP() {
        let s = strained.dailyActivityStrain!
        XCTAssertEqual(s.credited(upToRaw: 0), 0); XCTAssertEqual(s.credited(upToRaw: 120), 120); XCTAssertEqual(s.credited(upToRaw: 200), 160)
        XCTAssertEqual(s.credited(upToRaw: 400), 210); XCTAssertEqual(s.credited(upToRaw: 900), 210)
        XCTAssertEqual(s.credit(raw: 60, priorRaw: 0), 60, "inside the full band")
        XCTAssertEqual(s.credit(raw: 60, priorRaw: 90), 45, "30 full + 30 at half")
        XCTAssertEqual(s.credit(raw: 100, priorRaw: 150), 37, "50 at half + 50 at a quarter, floored")
        XCTAssertEqual(s.credit(raw: 80, priorRaw: 400), 0, "past the last band")
    }

    /// The engine strains real activity; the proposal keeps the raw XP; attributes follow the credited XP.
    func testEngineStrainsAndKeepsTheRawXP() {
        let first = ProgressionEngine.evaluate(event: event(minutes: 60), ruleset: strained, context: ctx(priorRaw: 0))    // 120 raw
        XCTAssertEqual(first.xp, 120); XCTAssertEqual(first.unstrainedXP, 120)
        let second = ProgressionEngine.evaluate(event: event(minutes: 60, family: "cardio"), ruleset: strained, context: ctx(priorRaw: 120))   // 120 raw: 80 at half + 40 at a quarter
        XCTAssertEqual(second.xp, 50); XCTAssertEqual(second.unstrainedXP, 120)
        XCTAssertEqual(second.eligibleMinutes, 60, "minutes still count for the taper")
        let third = ProgressionEngine.evaluate(event: event(minutes: 60, family: "learning"), ruleset: strained, context: ctx(priorRaw: 240))   // 60 raw, all at a quarter
        XCTAssertEqual(third.xp, 15)
        XCTAssertEqual(ProgressionEngine.evaluate(event: event(minutes: 30), ruleset: strained, context: ctx(priorRaw: 400)).xp, 0)
        let goal = ActivityEvent(userID: user, activityTypeID: "goal.x", familyID: "strength", startedAt: day, durationSeconds: 0, source: .goal, verification: .selfReported,
                                 goal: GoalReference(templateID: "goal.x", slot: .primary, attributeID: "strength"), createdAt: day)
        let withGoals = ProgressionRuleset(id: "r", version: 1, status: .dev, xpPerMinuteByFamily: [:], attributeWeightsByFamily: [:], attributePointsPerXP: 0.5, verificationMultiplier: [:],
                                           dailyTaper: strained.dailyTaper, minimumDurationSeconds: 60, levelThresholdsTotalXP: [0], goalXP: ["primary": 30], dailyActivityStrain: strained.dailyActivityStrain)
        XCTAssertEqual(ProgressionEngine.evaluate(event: goal, ruleset: withGoals, context: ctx(priorRaw: 500)).xp, 30, "goals sit outside strain")
    }

    /// The ledger places the next event by the day's raw XP, not the strained grant; records without it fall back to the grant.
    func testLedgerContextUsesRawXPForTheBands() {
        var ledger = ProgressionLedger()
        let a = event(minutes: 60), b = event(minutes: 60, family: "cardio", at: day.addingTimeInterval(3600)), c = event(minutes: 30, family: "learning", at: day.addingTimeInterval(7200))
        ledger.commit(ProgressionEngine.evaluate(event: a, ruleset: strained, context: ledger.context(for: a, ruleset: strained, events: [a], levelRewards: [:], calendar: calendar)), for: a, at: day)
        ledger.commit(ProgressionEngine.evaluate(event: b, ruleset: strained, context: ledger.context(for: b, ruleset: strained, events: [a, b], levelRewards: [:], calendar: calendar)), for: b, at: day)
        XCTAssertEqual(ledger.snapshot(ruleset: strained).totalXP, 170, "120 + 50")
        let ctx = ledger.context(for: c, ruleset: strained, events: [a, b, c], levelRewards: [:], calendar: calendar)
        XCTAssertEqual(ctx.priorActivityXPToday, 240, "raw, not the 170 granted")
        XCTAssertEqual(ProgressionEngine.evaluate(event: c, ruleset: strained, context: ctx).xp, 7, "30 raw at a quarter")
        let tomorrow = event(minutes: 30, at: day.addingTimeInterval(86_400 * 2))
        XCTAssertEqual(ledger.context(for: tomorrow, ruleset: strained, events: [a, b, c, tomorrow], levelRewards: [:], calendar: calendar).priorActivityXPToday, 0)
    }
}

final class StepsCreditTests: XCTestCase {
    let user = UserID()
    let day = Date(timeIntervalSince1970: 1_800_000_000)
    let calendar = Calendar(identifier: .gregorian)
    var ruleset: ProgressionRuleset {
        ProgressionRuleset(id: "ruleset.steps", version: 1, status: .dev, xpPerMinuteByFamily: ["cardio": 2.0], attributeWeightsByFamily: ["cardio": ["endurance": 1.0]],
                           attributePointsPerXP: 0.1, verificationMultiplier: [:], dailyTaper: .init(fullCreditMinutes: 30, taperRate: 0.2, hardCapMinutes: 90), minimumDurationSeconds: 60,
                           levelThresholdsTotalXP: [0, 100_000], dailyActivityStrain: .init(fullCreditXP: 120, bands: [.init(upTo: 200, rate: 0.5)]), steps: .init(xpPerThousand: 4, fullCreditSteps: 20_000, moments: [5000, 10_000, 20_000]))
    }
    func fact(_ steps: Int, at: Date? = nil) -> ActivityEvent {
        ActivityEvent(userID: user, activityTypeID: "steps", familyID: "cardio", startedAt: at ?? day, durationSeconds: 0, source: .healthImport, verification: .verified, sourceExternalID: "steps.\(steps)", steps: steps, createdAt: day)
    }

    /// Owner 2026-10-17: 4 XP per thousand up to 40 a day; a day's facts are deltas priced against the prior steps.
    func testStepsEarnUpToTheDailyCap() {
        let s = ruleset.steps!
        XCTAssertEqual(s.credit(steps: 2500, priorSteps: 0), 10); XCTAssertEqual(s.credit(steps: 2500, priorSteps: 2500), 10)
        XCTAssertEqual(s.credit(steps: 6000, priorSteps: 6000), 24); XCTAssertEqual(s.credit(steps: 3000, priorSteps: 12_000), 12)
        // HER-28 (owner 2026-10-23): full rate to 20,000, then the raw XP beyond goes to strain.
        XCTAssertEqual(s.credit(steps: 2000, priorSteps: 19_000), 4, "only the 1,000 inside full credit"); XCTAssertEqual(s.beyondRaw(steps: 2000, priorSteps: 19_000), 4)
        XCTAssertEqual(s.credit(steps: 5000, priorSteps: 25_000), 0); XCTAssertEqual(s.beyondRaw(steps: 5000, priorSteps: 25_000), 20)
        XCTAssertEqual(s.momentCrossed(from: 4800, to: 5300), 5000); XCTAssertNil(s.momentCrossed(from: 5000, to: 5400)); XCTAssertEqual(s.momentCrossed(from: 0, to: 12_000), 10_000)
        // Beyond full credit the engine strains the raw XP by the day's session XP: a quiet day keeps it, a heavy day halves it.
        let quiet = EvaluationContext(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:], priorActivityXPToday: 0, priorStepsToday: 25_000)
        XCTAssertEqual(ProgressionEngine.evaluate(event: fact(5000), ruleset: ruleset, context: quiet).xp, 20)
        let heavy = EvaluationContext(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:], priorActivityXPToday: 150, priorStepsToday: 25_000)
        XCTAssertEqual(ProgressionEngine.evaluate(event: fact(5000), ruleset: ruleset, context: heavy).xp, 10, "the 20 raw land in the 50 % band")
        let ctx = EvaluationContext(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:], priorStepsToday: 6000)
        let p = ProgressionEngine.evaluate(event: fact(6000), ruleset: ruleset, context: ctx)
        XCTAssertEqual(p.xp, 16); XCTAssertEqual(p.attributes["endurance"], 1, "cardio's weight carries the points"); XCTAssertEqual(p.eligibleMinutes, 0)
    }

    /// The ledger supplies the day's prior steps; steps sit outside strain's raw XP; tomorrow starts at zero.
    func testLedgerCountsPriorStepsAndKeepsThemOutOfStrain() {
        var ledger = ProgressionLedger()
        let a = fact(8000), b = fact(4000, at: day.addingTimeInterval(3600))
        ledger.commit(ProgressionEngine.evaluate(event: a, ruleset: ruleset, context: ledger.context(for: a, ruleset: ruleset, events: [a], levelRewards: [:], calendar: calendar)), for: a, at: day)
        let ctxB = ledger.context(for: b, ruleset: ruleset, events: [a, b], levelRewards: [:], calendar: calendar)
        XCTAssertEqual(ctxB.priorStepsToday, 8000); XCTAssertEqual(ctxB.priorActivityXPToday, 0, "steps are not session XP")
        XCTAssertEqual(ProgressionEngine.evaluate(event: b, ruleset: ruleset, context: ctxB).xp, 8, "40 − 32")
        let tomorrow = fact(3000, at: day.addingTimeInterval(86_400 * 2))
        XCTAssertEqual(ledger.context(for: tomorrow, ruleset: ruleset, events: [a, b, tomorrow], levelRewards: [:], calendar: calendar).priorStepsToday, 0)
        // Older archives have no steps field.
        let data = try! JSONEncoder().encode(a)
        var dict = try! JSONSerialization.jsonObject(with: data) as! [String: Any]; dict.removeValue(forKey: "steps")
        XCTAssertNil(try! JSONDecoder().decode(ActivityEvent.self, from: JSONSerialization.data(withJSONObject: dict)).steps)
    }
}

final class BalanceLeverTests: XCTestCase {
    let user = UserID()
    let day = Date(timeIntervalSince1970: 1_800_000_000)
    func ruleset(base: Int?) -> ProgressionRuleset {
        ProgressionRuleset(id: "r", version: 1, status: .dev, xpPerMinuteByFamily: ["strength": 2.0], attributeWeightsByFamily: [:], attributePointsPerXP: 0.5,
                           verificationMultiplier: [:], dailyTaper: .init(fullCreditMinutes: 90, taperRate: 0.25, hardCapMinutes: 240),
                           minimumDurationSeconds: 60, levelThresholdsTotalXP: [0, 60], sessionBaseXP: base, healthHistoryWindowDays: 7)
    }
    func event(minutes: Int) -> ActivityEvent {
        ActivityEvent(userID: user, activityTypeID: "weightlifting", familyID: "strength", startedAt: day, durationSeconds: minutes * 60, source: .manual, verification: .selfReported, createdAt: day)
    }
    func ctx(prior: Double = 0) -> EvaluationContext { EvaluationContext(priorEligibleMinutesToday: prior, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:]) }

    func testSessionBaseXPAddsOnceAndIsNotTapered() {
        XCTAssertEqual(ProgressionEngine.evaluate(event: event(minutes: 30), ruleset: ruleset(base: 5), context: ctx()).xp, 65)
        XCTAssertEqual(ProgressionEngine.evaluate(event: event(minutes: 30), ruleset: ruleset(base: nil), context: ctx()).xp, 60)
        // beyond the hard cap: no credited minutes, so no base either (nothing earned, nothing to reward)
        XCTAssertEqual(ProgressionEngine.evaluate(event: event(minutes: 30), ruleset: ruleset(base: 5), context: ctx(prior: 300)).xp, 0)
        // below the minimum duration: nothing
        XCTAssertEqual(ProgressionEngine.evaluate(event: event(minutes: 0), ruleset: ruleset(base: 5), context: ctx()).xp, 0)
    }

    func testFirstSyncHistoryWindow() {
        let imported = ImportedActivity(externalID: "old", sourceKind: "running", startedAt: day.addingTimeInterval(-10 * 86_400), endedAt: day.addingTimeInterval(-10 * 86_400 + 1800))
        let recent = ImportedActivity(externalID: "new", sourceKind: "running", startedAt: day.addingTimeInterval(-2 * 86_400), endedAt: day.addingTimeInterval(-2 * 86_400 + 1800))
        let from = day.addingTimeInterval(-7 * 86_400)
        func run(_ i: ImportedActivity, creditFrom: Date?) -> ImportOutcome {
            ImportReconciler.reconcile(i, userID: user, existing: [], mapping: ["running": "running"], familyOf: { _ in "cardio" }, fallbackTypeID: "walking", fallbackFamilyID: "cardio", now: day, creditFrom: creditFrom)
        }
        guard case .historyOnlyBeforeWindow = run(imported, creditFrom: from).disposition else { return XCTFail("10-day-old workout is history only on first sync") }
        XCTAssertNotNil(run(imported, creditFrom: from).event, "the fact is still recorded")
        guard case .imported = run(recent, creditFrom: from).disposition else { return XCTFail("2-day-old workout is credited") }
        guard case .imported = run(imported, creditFrom: nil).disposition else { return XCTFail("later syncs credit everything new") }
    }
}

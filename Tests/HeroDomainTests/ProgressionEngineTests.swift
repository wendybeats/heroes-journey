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

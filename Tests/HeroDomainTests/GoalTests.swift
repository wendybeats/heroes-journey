import XCTest
@testable import HeroDomain

final class GoalTests: XCTestCase {
    let user = UserID()
    let calendar: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    // 2026-10-05 is a Monday (weekday 2); 2026-10-04 a Sunday (weekday 1).
    let monday = DayKey(year: 2026, month: 10, day: 5)
    let sunday = DayKey(year: 2026, month: 10, day: 4)
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func t(_ id: String, _ slot: GoalSlot, rule: GoalCompletionRule = .manual, attr: AttributeID = "mindfulness", tags: [String] = []) -> GoalTemplate {
        GoalTemplate(id: GoalTemplateID(id), slot: slot, title: id, lines: ["a", "b"], attributeID: attr, rule: rule, tags: tags)
    }
    var templates: [GoalTemplate] {
        [
            t("p.strength", .primary, rule: .activityFamily(family: "strength", minMinutes: 30), attr: "strength", tags: ["training", "strength"]),
            t("p.cardio", .primary, rule: .activityFamily(family: "cardio", minMinutes: 30), attr: "endurance", tags: ["training", "cardio"]),
            t("p.rest", .primary, rule: .steps(base: 5000, perLevel: 400), attr: "endurance", tags: ["rest"]),
            t("s.learn1", .secondary, attr: "knowledge", tags: ["learning"]), t("s.learn2", .secondary, attr: "knowledge", tags: ["learning"]),
            t("s.mind1", .secondary, tags: ["mindfulness"]), t("s.mind2", .secondary, tags: ["mindfulness"]), t("s.mind3", .secondary, tags: ["mindfulness"]),
            t("w.1", .smallWin), t("w.2", .smallWin), t("w.3", .smallWin), t("w.4", .smallWin, tags: ["energy"]),
        ]
    }
    func inputs(day: DayKey, prefs: GoalPreferences = GoalPreferences(), level: Int = 1, history: [GoalPlan] = [], completions: [GoalCompletion] = [], seed: UInt64 = 42) -> GoalGenerator.Inputs {
        .init(day: day, templates: templates, preferences: prefs, level: level, history: history, completions: completions, seed: seed, calendar: calendar)
    }

    // MARK: generation

    func testPlanIsDeterministicAndHasOneGoalPerSlot() {
        let a = GoalGenerator.plan(inputs(day: monday), now: now)
        let b = GoalGenerator.plan(inputs(day: monday), now: now)
        XCTAssertEqual(a.goals.map(\.templateID), b.goals.map(\.templateID))
        XCTAssertEqual(a.goals.map(\.lineIndex), b.goals.map(\.lineIndex))
        XCTAssertEqual(a.goals.map(\.slot), [.primary, .secondary, .smallWin])
    }

    func testDifferentSeedsOrDaysCanDiffer() {
        var picks = Set<[GoalTemplateID]>()
        for seed in 1...20 { picks.insert(GoalGenerator.plan(inputs(day: monday, seed: UInt64(seed)), now: now).goals.map(\.templateID)) }
        XCTAssertGreaterThan(picks.count, 1)
    }

    func testTrainingDayFollowsPrimaryFamilyAndRestDayUsesRestPool() {
        let strength = GoalGenerator.plan(inputs(day: monday, prefs: GoalPreferences(primaryFamily: "strength", trainingDaysPerWeek: 4)), now: now)
        XCTAssertEqual(strength.goals[0].templateID, "p.strength")
        let cardio = GoalGenerator.plan(inputs(day: monday, prefs: GoalPreferences(primaryFamily: "cardio", trainingDaysPerWeek: 4)), now: now)
        XCTAssertEqual(cardio.goals[0].templateID, "p.cardio")
        // Four days a week = Mon Tue Thu Fri; Sunday is rest.
        let rest = GoalGenerator.plan(inputs(day: sunday, prefs: GoalPreferences(trainingDaysPerWeek: 4)), now: now)
        XCTAssertEqual(rest.goals[0].templateID, "p.rest")
        XCTAssertEqual(rest.goals[0].target, 5000)
        XCTAssertEqual(GoalGenerator.plan(inputs(day: sunday, prefs: GoalPreferences(trainingDaysPerWeek: 4), level: 4), now: now).goals[0].target, 6200)
    }

    func testSecondaryFollowsInterest() {
        for seed in 1...10 {
            let plan = GoalGenerator.plan(inputs(day: monday, prefs: GoalPreferences(secondaryInterest: "learning"), seed: UInt64(seed)), now: now)
            XCTAssertTrue(plan.goals[1].templateID.rawValue.hasPrefix("s.learn"))
        }
    }

    func testNoRepeatInsideWindowWhenPoolAllows() {
        var history: [GoalPlan] = []
        var day = DayKey(year: 2026, month: 10, day: 1)
        var seen: [GoalTemplateID] = []
        for _ in 0..<3 {
            let plan = GoalGenerator.plan(inputs(day: day, history: history, seed: 7), now: now)
            seen.append(plan.goals[2].templateID)      // small wins, 4 templates, window 7
            history.append(plan)
            day = DayKey(day.date(calendar: calendar)!.addingTimeInterval(86_400), calendar: calendar)
        }
        XCTAssertEqual(Set(seen).count, 3, "three consecutive days must not repeat a small win: \(seen)")
        // Secondary: 3 mindfulness templates, window 5 → day 4 must reuse one (pool exhausted, relaxed).
        history = []; day = DayKey(year: 2026, month: 10, day: 1)
        var secondaries: [GoalTemplateID] = []
        for _ in 0..<4 {
            let plan = GoalGenerator.plan(inputs(day: day, history: history, seed: 7), now: now)
            secondaries.append(plan.goals[1].templateID); history.append(plan)
            day = DayKey(day.date(calendar: calendar)!.addingTimeInterval(86_400), calendar: calendar)
        }
        XCTAssertEqual(Set(secondaries.prefix(3)).count, 3)
        XCTAssertEqual(secondaries.count, 4)
    }

    func testMotivationMatchIsFavoured() {
        var hits = 0
        for seed in 1...200 where GoalGenerator.plan(inputs(day: monday, prefs: GoalPreferences(motivation: "energy"), seed: UInt64(seed)), now: now).goals[2].templateID == "w.4" { hits += 1 }
        // weight 2 of 5 total → expect ~40 %; without the boost ~25 %.
        XCTAssertGreaterThan(hits, 60, "\(hits)")
    }

    // MARK: evaluation

    func testActivityCompletesMatchingGoalAndManualDoesNot() {
        let plan = GoalGenerator.plan(inputs(day: monday), now: now)
        let strength = ActivityEvent(userID: user, activityTypeID: "weightlifting", familyID: "strength", startedAt: now, durationSeconds: 35 * 60, source: .manual, verification: .selfReported)
        let short = ActivityEvent(userID: user, activityTypeID: "weightlifting", familyID: "strength", startedAt: now, durationSeconds: 10 * 60, source: .manual, verification: .selfReported)
        XCTAssertTrue(GoalEvaluator.satisfied(plan: plan, templates: templates, completed: [], events: [short], steps: nil).isEmpty)
        let hits = GoalEvaluator.satisfied(plan: plan, templates: templates, completed: [], events: [strength], steps: nil)
        XCTAssertEqual(hits.map { $0.goal.slot }, [.primary])
        XCTAssertEqual(hits.first?.source, .activity(strength.id))
        XCTAssertTrue(GoalEvaluator.satisfied(plan: plan, templates: templates, completed: [plan.goals[0].id], events: [strength], steps: nil).isEmpty, "already completed")
    }

    func testStepsCompleteRestGoalAtTarget() {
        let plan = GoalGenerator.plan(inputs(day: sunday, prefs: GoalPreferences(trainingDaysPerWeek: 4)), now: now)
        XCTAssertTrue(GoalEvaluator.satisfied(plan: plan, templates: templates, completed: [], events: [], steps: 4999).isEmpty)
        XCTAssertEqual(GoalEvaluator.satisfied(plan: plan, templates: templates, completed: [], events: [], steps: 5000).first?.source, .steps(5000))
    }

    func testGoalEventsNeverSatisfyActivityGoals() {
        let plan = GoalGenerator.plan(inputs(day: monday), now: now)
        let goalEvent = GoalEvaluator.makeEvent(for: plan.goals[0], template: templates[0], userID: user, familyFallback: "strength", at: now)
        XCTAssertEqual(goalEvent.durationSeconds, 0); XCTAssertEqual(goalEvent.source, .goal); XCTAssertNotNil(goalEvent.goal)
        XCTAssertTrue(GoalEvaluator.satisfied(plan: plan, templates: templates, completed: [], events: [goalEvent], steps: nil).isEmpty)
    }

    // MARK: progression

    var ruleset: ProgressionRuleset {
        ProgressionRuleset(id: "ruleset.test", version: 1, status: .dev, xpPerMinuteByFamily: ["strength": 2.0], attributeWeightsByFamily: ["strength": ["strength": 1.0]],
                           attributePointsPerXP: 0.5, verificationMultiplier: [:], dailyTaper: .init(fullCreditMinutes: 90, taperRate: 0.25, hardCapMinutes: 240),
                           minimumDurationSeconds: 60, levelThresholdsTotalXP: [0, 10, 150], goalXP: ["primary": 8, "secondary": 5, "small_win": 3])
    }

    func testGoalEventEarnsFlatXPAndAttributeThroughTheEngine() {
        let plan = GoalGenerator.plan(inputs(day: monday), now: now)
        let event = GoalEvaluator.makeEvent(for: plan.goals[0], template: templates[0], userID: user, familyFallback: "strength", at: now)
        let context = EvaluationContext(priorEligibleMinutesToday: 500, priorTotalXP: 4, grantedRewardIDs: [], levelRewards: [2: ["reward.l2"]])
        let p = ProgressionEngine.evaluate(event: event, ruleset: ruleset, context: context)
        XCTAssertEqual(p.xp, 8, "flat, untapered, despite a zero duration and an exhausted daily allowance")
        XCTAssertEqual(p.attributes, ["strength": 4])
        XCTAssertEqual(p.eligibleMinutes, 0)
        XCTAssertTrue(p.leveledUp); XCTAssertEqual(p.rewardsUnlocked, ["reward.l2"])
        let win = GoalEvaluator.makeEvent(for: plan.goals[2], template: templates[8], userID: user, familyFallback: "strength", at: now)
        XCTAssertEqual(ProgressionEngine.evaluate(event: win, ruleset: ruleset, context: context).xp, 3)
    }

    func testGoalXPAbsentMeansGoalsEarnNothing() {
        let plan = GoalGenerator.plan(inputs(day: monday), now: now)
        let event = GoalEvaluator.makeEvent(for: plan.goals[0], template: templates[0], userID: user, familyFallback: "strength", at: now)
        let base = ruleset
        let r = ProgressionRuleset(id: base.id, version: 1, status: .dev, xpPerMinuteByFamily: base.xpPerMinuteByFamily, attributeWeightsByFamily: base.attributeWeightsByFamily, attributePointsPerXP: 0.5, verificationMultiplier: [:], dailyTaper: base.dailyTaper, minimumDurationSeconds: 60, levelThresholdsTotalXP: base.levelThresholdsTotalXP)
        XCTAssertTrue(ProgressionEngine.evaluate(event: event, ruleset: r, context: .init(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:])).isEmpty)
    }

    func testGoalCompletionIsIdempotentAtTheServiceBoundary() async throws {
        let plan = GoalGenerator.plan(inputs(day: monday), now: now)
        let event = GoalEvaluator.makeEvent(for: plan.goals[0], template: templates[0], userID: user, familyFallback: "strength", at: now)
        let service = LocalAuthorityProgressionService(authority: .init(ruleset: ruleset, levelRewards: [:], calendar: calendar), owner: user)
        let sub = ProgressionSubmission(event: event, contentVersion: "t", submittedAt: now)
        let first = try await service.submit(sub), second = try await service.submit(sub)
        XCTAssertEqual(first.xp, 8); XCTAssertTrue(second.wasAlreadyProcessed); XCTAssertEqual(second.xp, 8)
        let snap = await service.ledger.snapshot(ruleset: ruleset)
        XCTAssertEqual(snap.totalXP, 8)
    }

    func testDayKeyRoundTripsAndCountsDays() throws {
        let data = try JSONEncoder().encode(monday)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"2026-10-05\"")
        XCTAssertEqual(try JSONDecoder().decode(DayKey.self, from: data), monday)
        XCTAssertEqual(monday.daysSince(sunday, calendar: calendar), 1)
        XCTAssertTrue(sunday < monday)
    }

    func testEventWithoutGoalFieldStillDecodes() throws {
        // Archives written before doc 24 have no `goal` key; nil must encode as absent and decode back as nil.
        let event = ActivityEvent(userID: user, activityTypeID: "running", familyID: "cardio", startedAt: now, durationSeconds: 600, source: .manual, verification: .selfReported, createdAt: now)
        let data = try JSONEncoder().encode(event)
        let keys = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys
        XCTAssertFalse(keys.contains("goal"))
        XCTAssertNil(try JSONDecoder().decode(ActivityEvent.self, from: data).goal)
    }

    func testManualLogWithSetsSatisfiesTheSetGoal() {
        let plan = GoalPlan(day: monday, goals: [DailyGoal(templateID: "p.sets", slot: .primary, day: monday, lineIndex: 0, target: nil)], generatedAt: now)
        let tpl = [t("p.sets", .primary, rule: .workoutSets(count: 12), attr: "strength", tags: ["training", "strength"])]
        let manual = ActivityEvent(userID: user, activityTypeID: "weightlifting", familyID: "strength", startedAt: now, durationSeconds: 60, source: .manual, verification: .selfReported, structuredSetCount: 12)
        XCTAssertEqual(GoalEvaluator.satisfied(plan: plan, templates: tpl, completed: [], events: [manual], steps: nil).first?.source, .activity(manual.id))
        let eleven = ActivityEvent(userID: user, activityTypeID: "weightlifting", familyID: "strength", startedAt: now, durationSeconds: 60, source: .manual, verification: .selfReported, structuredSetCount: 11)
        XCTAssertTrue(GoalEvaluator.satisfied(plan: plan, templates: tpl, completed: [], events: [eleven], steps: nil).isEmpty)
    }

    func testBondSealIsOnePermanentGrantFromTheRuleset() async throws {
        let r = ProgressionRuleset(id: "ruleset.bond", version: 1, status: .dev, xpPerMinuteByFamily: [:],
                                   attributeWeightsByFamily: ["cardio": ["endurance": 1.0], "creativity": ["knowledge": 0.5, "mindfulness": 0.5], "learning": ["knowledge": 1.0]],
                                   attributePointsPerXP: 0.5, verificationMultiplier: [:], dailyTaper: ruleset.dailyTaper, minimumDurationSeconds: 60,
                                   levelThresholdsTotalXP: [0, 10], bondGrant: .init(xp: 12, primaryPoints: 6, secondaryPoints: 4))
        let e = BondReference.makeEvent(primaryFamily: "cardio", secondaryInterest: "creativity", ruleset: r, userID: user, at: now)
        XCTAssertEqual(e.source, .bond); XCTAssertEqual(e.bond?.primaryAttributeID, "endurance")
        XCTAssertEqual(e.bond?.secondaryAttributeID, "knowledge", "a tie resolves alphabetically, so it is stable")
        let p = ProgressionEngine.evaluate(event: e, ruleset: r, context: .init(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:]))
        XCTAssertEqual(p.xp, 12); XCTAssertEqual(p.attributes, ["endurance": 6, "knowledge": 4]); XCTAssertTrue(p.leveledUp)
        // Same attribute on both sides adds up; no bond_grant means no grant.
        let same = BondReference.makeEvent(primaryFamily: "learning", secondaryInterest: "learning", ruleset: r, userID: user, at: now)
        XCTAssertEqual(ProgressionEngine.evaluate(event: same, ruleset: r, context: .init(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:])).attributes, ["knowledge": 10])
        XCTAssertTrue(ProgressionEngine.evaluate(event: e, ruleset: ruleset, context: .init(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:])).isEmpty)
        // Idempotent at the boundary like everything else.
        let service = LocalAuthorityProgressionService(authority: .init(ruleset: r, levelRewards: [:], calendar: calendar), owner: user)
        let sub = ProgressionSubmission(event: e, contentVersion: "t", submittedAt: now)
        _ = try await service.submit(sub); let again = try await service.submit(sub)
        XCTAssertTrue(again.wasAlreadyProcessed); XCTAssertEqual(await service.ledger.snapshot(ruleset: r).totalXP, 12)
    }
}

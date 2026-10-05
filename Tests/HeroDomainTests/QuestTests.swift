import XCTest
@testable import HeroDomain

final class QuestTests: XCTestCase {
    let user = UserID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let table: [ProgressionRuleset.DailyQuest.RewardEntry] = [
        .init(weight: 60, xp: 6, tier: "common"), .init(weight: 30, xp: 10, tier: "uncommon"), .init(weight: 10, xp: 16, tier: "rare", rewardID: "reward.quest.rare"),
    ]
    var ruleset: ProgressionRuleset {
        ProgressionRuleset(id: "ruleset.test", version: 1, status: .dev, xpPerMinuteByFamily: ["strength": 2.0], attributeWeightsByFamily: [:], attributePointsPerXP: 0.5,
                           verificationMultiplier: [:], dailyTaper: .init(fullCreditMinutes: 90, taperRate: 0.25, hardCapMinutes: 240), minimumDurationSeconds: 60,
                           levelThresholdsTotalXP: [0, 10], dailyQuest: .init(durationMinutes: 240, unlockRule: "all_goals", rewardTable: table))
    }
    func makeRun(id: UUID = UUID()) -> QuestRun { QuestRun(id: id, questID: "quest.test", day: DayKey(year: 2026, month: 10, day: 5), startedAt: now, returnsAt: now.addingTimeInterval(4 * 3600)) }

    func testRollIsDeterministicPerRunAndInsideTheTable() {
        let id = UUID()
        let a = QuestResolver.roll(table: table, runID: id), b = QuestResolver.roll(table: table, runID: id)
        XCTAssertEqual(a, b)
        XCTAssertNotNil(a); XCTAssertTrue((0..<3).contains(a!))
        XCTAssertNil(QuestResolver.roll(table: [], runID: id))
    }

    func testRollRespectsWeightsRoughly() {
        var counts = [0, 0, 0]
        for _ in 0..<2000 { counts[QuestResolver.roll(table: table, runID: UUID())!] += 1 }
        XCTAssertGreaterThan(counts[0], 1000, "\(counts)")      // 60 % expected
        XCTAssertLessThan(counts[2], 300, "\(counts)")          // 10 % expected
        XCTAssertGreaterThan(counts[2], 100, "\(counts)")
    }

    func testDueOnlyAtOrAfterReturn() {
        let r = makeRun()
        XCTAssertFalse(r.isDue(at: now)); XCTAssertFalse(r.isDue(at: now.addingTimeInterval(4 * 3600 - 1)))
        XCTAssertTrue(r.isDue(at: now.addingTimeInterval(4 * 3600)))
        XCTAssertEqual(r.remaining(at: now.addingTimeInterval(3600)), 3 * 3600)
        var done = r; done.resolvedAt = now.addingTimeInterval(5 * 3600)
        XCTAssertFalse(done.isDue(at: now.addingTimeInterval(6 * 3600)))
    }

    func testReturnEventIsPricedFromTheTableAndGrantsTheRewardOnce() {
        let r = makeRun()
        let rare = QuestResolver.makeEvent(for: r, rewardIndex: 2, userID: user, familyFallback: "strength", at: now)
        XCTAssertEqual(rare.source, .quest); XCTAssertEqual(rare.durationSeconds, 0)
        let fresh = EvaluationContext(priorEligibleMinutesToday: 999, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:])
        let p = ProgressionEngine.evaluate(event: rare, ruleset: ruleset, context: fresh)
        XCTAssertEqual(p.xp, 16); XCTAssertEqual(p.rewardsUnlocked, ["reward.quest.rare"]); XCTAssertTrue(p.leveledUp)
        let already = EvaluationContext(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: ["reward.quest.rare"], levelRewards: [:])
        XCTAssertEqual(ProgressionEngine.evaluate(event: rare, ruleset: ruleset, context: already).rewardsUnlocked, [])
        let common = QuestResolver.makeEvent(for: r, rewardIndex: 0, userID: user, familyFallback: "strength", at: now)
        XCTAssertEqual(ProgressionEngine.evaluate(event: common, ruleset: ruleset, context: fresh).xp, 6)
    }

    func testOutOfRangeIndexOrMissingTableEarnsNothing() {
        let r = makeRun()
        let bad = QuestResolver.makeEvent(for: r, rewardIndex: 9, userID: user, familyFallback: "strength", at: now)
        let ctx = EvaluationContext(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:])
        XCTAssertTrue(ProgressionEngine.evaluate(event: bad, ruleset: ruleset, context: ctx).isEmpty)
        let noQuest = ProgressionRuleset(id: "r", version: 1, status: .dev, xpPerMinuteByFamily: [:], attributeWeightsByFamily: [:], attributePointsPerXP: 0.5, verificationMultiplier: [:],
                                         dailyTaper: ruleset.dailyTaper, minimumDurationSeconds: 60, levelThresholdsTotalXP: [0])
        let ok = QuestResolver.makeEvent(for: r, rewardIndex: 0, userID: user, familyFallback: "strength", at: now)
        XCTAssertTrue(ProgressionEngine.evaluate(event: ok, ruleset: noQuest, context: ctx).isEmpty)
    }

    func testQuestRunRoundTripsThroughJSON() throws {
        var r = makeRun(); r.reward = QuestReference(questID: "quest.test", rewardIndex: 1); r.resolvedAt = now
        let data = try JSONEncoder().encode(r)
        XCTAssertEqual(try JSONDecoder().decode(QuestRun.self, from: data), r)
        let event = ActivityEvent(userID: user, activityTypeID: "running", familyID: "cardio", startedAt: now, durationSeconds: 600, source: .manual, verification: .selfReported, createdAt: now)
        let keys = try XCTUnwrap(JSONSerialization.jsonObject(with: try JSONEncoder().encode(event)) as? [String: Any]).keys
        XCTAssertFalse(keys.contains("quest"))
    }

    /// Doc 29: the quest's own pool decides the reward; owned ones are skipped, lower pools fill in, deterministic per run.
    func testPickPrefersUngrantedInTierThenAnyPool() {
        let pools = [LootPool(tier: "common", rewards: ["r.c1", "r.c2"]), LootPool(tier: "uncommon", rewards: ["r.u1"]), LootPool(tier: "rare", rewards: ["r.r1"])]
        let id = UUID()
        let a = QuestResolver.pick(tier: "common", pools: pools, granted: [], runID: id)
        XCTAssertEqual(a, QuestResolver.pick(tier: "common", pools: pools, granted: [], runID: id))
        XCTAssertTrue(["r.c1", "r.c2"].contains(a!))
        XCTAssertEqual(QuestResolver.pick(tier: "common", pools: pools, granted: ["r.c1"], runID: id), "r.c2")
        XCTAssertEqual(QuestResolver.pick(tier: "common", pools: pools, granted: ["r.c1", "r.c2"], runID: id), "r.u1", "commons owned: the next pool fills in")
        XCTAssertTrue(["r.c1", "r.c2"].contains(QuestResolver.pick(tier: "rare", pools: pools, granted: ["r.r1"], runID: id)!), "rare owned: falls back to the first pool with something unowned")
        XCTAssertNil(QuestResolver.pick(tier: "rare", pools: pools, granted: ["r.c1", "r.c2", "r.u1", "r.r1"], runID: id), "everything owned: XP only")
        XCTAssertNil(QuestResolver.pick(tier: "common", pools: [], granted: [], runID: id))
    }

    func testEngineGrantsTheRewardRecordedOnTheFactOverTheTableRow() {
        let r = makeRun()
        let fresh = EvaluationContext(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:])
        let chosen = QuestResolver.makeEvent(for: r, rewardIndex: 0, rewardID: "reward.quest.cap", userID: user, familyFallback: "strength", at: now)
        let p = ProgressionEngine.evaluate(event: chosen, ruleset: ruleset, context: fresh)
        XCTAssertEqual(p.xp, 6, "XP still comes from the rolled row"); XCTAssertEqual(p.rewardsUnlocked, ["reward.quest.cap"])
        let owned = EvaluationContext(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: ["reward.quest.cap"], levelRewards: [:])
        XCTAssertEqual(ProgressionEngine.evaluate(event: chosen, ruleset: ruleset, context: owned).rewardsUnlocked, [], "never twice")
        // Old facts without a chosen reward decode and still use the table row.
        let data = try! JSONEncoder().encode(QuestReference(questID: "quest.test", rewardIndex: 2))
        XCTAssertNil(try! JSONDecoder().decode(QuestReference.self, from: data).rewardID)
    }

    /// Doc 29: runs saved before the claim moment decode as unclaimed; claiming is state, not a grant.
    func testOlderRunsDecodeAsUnclaimed() throws {
        var r = makeRun(); r.resolvedAt = now
        let data = try JSONEncoder().encode(r)
        var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        dict.removeValue(forKey: "claimedAt")
        let old = try JSONDecoder().decode(QuestRun.self, from: JSONSerialization.data(withJSONObject: dict))
        XCTAssertTrue(old.isResolved); XCTAssertFalse(old.isClaimed)
        var claimed = old; claimed.claimedAt = now
        XCTAssertTrue(claimed.isClaimed)
    }
}

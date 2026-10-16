import XCTest
@testable import HeroDomain

final class StoryTests: XCTestCase {
    let user = UserID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func m(_ id: String, _ level: Int, trigger: Milestone.Trigger = .auto, quest: QuestID? = nil, feature: String? = nil, reward: RewardID? = nil, completes: Bool = false) -> Milestone {
        Milestone(id: MilestoneID(id), level: level, trigger: trigger, triggerLabel: trigger == .manual ? "Go" : nil, storyChapter: "chapter.\(id)", unlockQuest: quest, unlockFeature: feature, reward: reward, completesChapter: completes)
    }
    var campaign: Campaign {
        Campaign(chapters: [CampaignChapter(id: "chapter.one", areaID: "under_city", displayName: "One", levels: [1, 10], milestones: [
            m("one.1", 1), m("one.2", 2, feature: "home_room"), m("one.5", 5, quest: "quest.gym_1"), m("one.8", 8), m("one.10", 10, trigger: .manual, reward: "reward.x", completes: true),
        ])])
    }

    func testDueIsOrderedAndCatchesUpOneBeatAtATime() {
        var p = StoryProgress()
        XCTAssertEqual(StoryDirector.due(level: 1, campaign: campaign, progress: p).map(\.id), ["one.1"])
        // A fast leveller at Level 6 still gets every beat, in order, not just the latest.
        XCTAssertEqual(StoryDirector.due(level: 6, campaign: campaign, progress: p).map(\.id), ["one.1", "one.2", "one.5"])
        XCTAssertEqual(StoryDirector.nextAuto(level: 6, campaign: campaign, progress: p)?.id, "one.1")
        p = StoryDirector.complete(campaign.milestone("one.1")!, campaign: campaign, progress: p)
        XCTAssertEqual(StoryDirector.nextAuto(level: 6, campaign: campaign, progress: p)?.id, "one.2")
        p = StoryDirector.complete(campaign.milestone("one.2")!, campaign: campaign, progress: p)
        XCTAssertTrue(p.hasFeature("home_room"))
        p = StoryDirector.complete(campaign.milestone("one.5")!, campaign: campaign, progress: p)
        XCTAssertTrue(p.unlockedQuests.contains("quest.gym_1"))
        XCTAssertNil(StoryDirector.nextAuto(level: 6, campaign: campaign, progress: p), "nothing due until Level 8")
    }

    /// Doc 33 §A: a beat that requires a quest waits for its first completion, and everything after it waits too.
    func testBeatsWaitForTheirQuest() {
        let held = Milestone(id: "one.6", level: 6, storyChapter: "chapter.six", requiresQuest: "quest.gym_1", heldLine: "The floor is still waiting.")
        let gated = Campaign(chapters: [CampaignChapter(id: "chapter.one", areaID: "under_city", displayName: "One", levels: [1, 10], milestones: [m("one.5", 5, quest: "quest.gym_1"), held, m("one.7", 7)])])
        var p = StoryProgress()
        p = StoryDirector.complete(gated.milestone("one.5")!, campaign: gated, progress: p)
        XCTAssertNil(StoryDirector.nextAuto(level: 9, campaign: gated, progress: p, completedQuests: []), "held: the floor quest has not been completed")
        XCTAssertEqual(StoryDirector.held(level: 9, campaign: gated, progress: p, completedQuests: [])?.heldLine, "The floor is still waiting.")
        XCTAssertNil(StoryDirector.nextAuto(level: 9, campaign: gated, progress: p, completedQuests: ["quest.other"]))
        XCTAssertEqual(StoryDirector.nextAuto(level: 9, campaign: gated, progress: p, completedQuests: ["quest.gym_1"])?.id, "one.6")
        XCTAssertNil(StoryDirector.held(level: 9, campaign: gated, progress: p, completedQuests: ["quest.gym_1"]))
        XCTAssertNil(StoryDirector.nextAuto(level: 5, campaign: gated, progress: p, completedQuests: []), "not due at all below its level")
        // A held beat also keeps the later ones back, so Level 7 cannot retire the floor quest early.
        XCTAssertEqual(StoryDirector.due(level: 9, campaign: gated, progress: p).map(\.id), ["one.6", "one.7"])
        let data = try! JSONEncoder().encode(held)
        XCTAssertEqual(try! JSONDecoder().decode(Milestone.self, from: data), held)
    }

    /// Doc 34: the boss beat waits for Level 10 and three completed gym-area runs; repeats of one quest count.
    func testBeatsWaitForEnoughQuestRunsInAnArea() throws {
        let boss = Milestone(id: "one.10", level: 10, trigger: .manual, triggerLabel: "Face him", storyChapter: "chapter.boss", completesChapter: true,
                             requiresQuest: "quest.gym_3", requiresAreaQuests: AreaQuestGate(areaID: "colossus_gym", count: 3), heldLine: "Three floors first.")
        let c = Campaign(chapters: [CampaignChapter(id: "chapter.one", areaID: "under_city", displayName: "One", levels: [1, 10], milestones: [m("one.9", 9), boss])])
        var p = StoryProgress()
        p = StoryDirector.complete(c.milestone("one.9")!, campaign: c, progress: p)
        XCTAssertTrue(StoryDirector.offered(level: 10, campaign: c, progress: p, completedQuests: ["quest.gym_3"], areaQuestRuns: ["colossus_gym": 2]).isEmpty, "two runs: held")
        XCTAssertEqual(StoryDirector.held(level: 10, campaign: c, progress: p, completedQuests: ["quest.gym_3"], areaQuestRuns: ["colossus_gym": 2])?.heldLine, "Three floors first.")
        XCTAssertTrue(StoryDirector.offered(level: 10, campaign: c, progress: p, completedQuests: [], areaQuestRuns: ["colossus_gym": 5]).isEmpty, "runs enough, named quest never done: still held")
        XCTAssertEqual(StoryDirector.offered(level: 10, campaign: c, progress: p, completedQuests: ["quest.gym_3"], areaQuestRuns: ["colossus_gym": 3]).map(\.id), ["one.10"])
        XCTAssertTrue(StoryDirector.offered(level: 9, campaign: c, progress: p, completedQuests: ["quest.gym_3"], areaQuestRuns: ["colossus_gym": 3]).isEmpty, "not before its level")
        XCTAssertTrue(StoryDirector.offered(level: 10, campaign: c, progress: p, completedQuests: ["quest.gym_3"], areaQuestRuns: ["under_city": 9]).isEmpty, "another area's runs do not count")
        XCTAssertFalse(StoryDirector.isHeld(m("one.9", 9), completedQuests: [], areaQuestRuns: [:]), "no gate, never held")
        let back = try JSONDecoder().decode(Milestone.self, from: try JSONEncoder().encode(boss))
        XCTAssertEqual(back, boss); XCTAssertEqual(back.requiresAreaQuests?.count, 3)
    }

    func testManualMilestoneGatesTheStoryUntilThePlayerStartsIt() {
        var p = StoryProgress()
        for id in ["one.1", "one.2", "one.5", "one.8"] { p = StoryDirector.complete(campaign.milestone(MilestoneID(id))!, campaign: campaign, progress: p) }
        XCTAssertNil(StoryDirector.nextAuto(level: 12, campaign: campaign, progress: p), "a manual beat never auto-plays")
        XCTAssertEqual(StoryDirector.offered(level: 12, campaign: campaign, progress: p).map(\.id), ["one.10"])
        XCTAssertTrue(StoryDirector.offered(level: 9, campaign: campaign, progress: p).isEmpty, "not offered below its level")
        let done = StoryDirector.complete(campaign.milestone("one.10")!, campaign: campaign, progress: p)
        XCTAssertTrue(done.completedChapters.contains("chapter.one"))
        XCTAssertEqual(StoryDirector.complete(campaign.milestone("one.10")!, campaign: campaign, progress: done), done, "idempotent")
    }

    func testCurrentQuestIsTheLastUnlockedInContentOrder() {
        struct Q { let id: QuestID; let gate: MilestoneID? }
        let quests = [Q(id: "quest.street", gate: nil), Q(id: "quest.gym_1", gate: "one.5"), Q(id: "quest.gym_2", gate: "one.7")]
        var p = StoryProgress()
        XCTAssertEqual(StoryDirector.currentQuest(quests: quests, id: \.id, unlockedBy: \.gate, progress: p)?.id, "quest.street")
        p = StoryDirector.complete(campaign.milestone("one.5")!, campaign: campaign, progress: p)
        p.completedMilestones.insert("one.5")
        XCTAssertEqual(StoryDirector.currentQuest(quests: quests, id: \.id, unlockedBy: \.gate, progress: p)?.id, "quest.gym_1")
    }

    func testStoryGrantGoesThroughTheEngineOnce() async throws {
        let ruleset = ProgressionRuleset(id: "r", version: 1, status: .dev, xpPerMinuteByFamily: [:], attributeWeightsByFamily: [:], attributePointsPerXP: 0.5,
                                         verificationMultiplier: [:], dailyTaper: .init(fullCreditMinutes: 90, taperRate: 0.25, hardCapMinutes: 240), minimumDurationSeconds: 60, levelThresholdsTotalXP: [0])
        let e = StoryReference.makeEvent(for: campaign.milestone("one.10")!, userID: user, familyFallback: "strength", at: now)
        XCTAssertEqual(e.source, .story)
        let fresh = EvaluationContext(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:])
        let p = ProgressionEngine.evaluate(event: e, ruleset: ruleset, context: fresh)
        XCTAssertEqual(p.xp, 0); XCTAssertEqual(p.rewardsUnlocked, ["reward.x"])
        let service = LocalAuthorityProgressionService(authority: .init(ruleset: ruleset, levelRewards: [:], calendar: .current), owner: user)
        let sub = ProgressionSubmission(event: e, contentVersion: "t", submittedAt: now)
        _ = try await service.submit(sub); let again = try await service.submit(sub)
        let grants = await service.ledger.rewards.count
        XCTAssertTrue(again.wasAlreadyProcessed); XCTAssertEqual(grants, 1)
        // A milestone without a reward is a no-op fact.
        let none = StoryReference.makeEvent(for: campaign.milestone("one.8")!, userID: user, familyFallback: "strength", at: now)
        XCTAssertTrue(ProgressionEngine.evaluate(event: none, ruleset: ruleset, context: fresh).isEmpty)
    }

    func testProgressRoundTrips() throws {
        var p = StoryProgress(); p.completedMilestones = ["one.1"]; p.unlockedFeatures = ["home_room"]; p.unlockedBackdrops = ["backdrop.x"]
        XCTAssertEqual(try JSONDecoder().decode(StoryProgress.self, from: try JSONEncoder().encode(p)), p)
    }
}

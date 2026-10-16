import Foundation

// Campaign and story state (doc 28). Levels make milestones eligible; `StoryProgress` records what
// the player has actually experienced. The director is pure: same inputs → same next beat.

public enum MilestoneTag: Sendable {}
public typealias MilestoneID = StableID<MilestoneTag>

/// Doc 34 boss unlock: a beat that waits until the player has completed (claimed) at least `count` quest runs
/// in an area. Runs of the same quest count; it is effort in the area the story wants, not a checklist.
public struct AreaQuestGate: Hashable, Codable, Sendable {
    public let areaID: AreaID
    public let count: Int
    public init(areaID: AreaID, count: Int) { self.areaID = areaID; self.count = count }
    enum CodingKeys: String, CodingKey { case areaID = "area_id", count }
}

/// One beat of the campaign, bound to a level. Everything it does is declared as data; the app
/// plays the chapter, applies the unlocks, and records completion.
public struct Milestone: Hashable, Codable, Sendable {
    /// `auto`: plays as soon as it is due. `manual`: the player starts it (boss encounters).
    public enum Trigger: String, Codable, Sendable { case auto, manual }
    public let id: MilestoneID
    public let level: Int
    public let trigger: Trigger
    /// Shown on the manual trigger's button.
    public let triggerLabel: String?
    public let storyChapter: String?
    public let unlockBackdrop: BackdropID?
    public let unlockQuest: QuestID?
    /// App features gated by story: `home_room`, …
    public let unlockFeature: String?
    /// Granted once through the engine as a story fact.
    public let reward: RewardID?
    public let completesChapter: Bool
    public let teaseArea: AreaID?
    /// Doc 33 §A: the beat waits until this quest has been completed (claimed) once. Beats play in order, so
    /// everything after a held beat waits too; a level never outruns the visit the story assumes.
    public let requiresQuest: QuestID?
    /// Doc 34: the beat also waits for this many completed quest runs in an area (the boss: three gym quests).
    public let requiresAreaQuests: AreaQuestGate?
    /// Shown on the goals card while the beat is held, so the stall reads as intent.
    public let heldLine: String?
    public let notes: String?

    public init(id: MilestoneID, level: Int, trigger: Trigger = .auto, triggerLabel: String? = nil, storyChapter: String? = nil, unlockBackdrop: BackdropID? = nil, unlockQuest: QuestID? = nil, unlockFeature: String? = nil, reward: RewardID? = nil, completesChapter: Bool = false, teaseArea: AreaID? = nil, requiresQuest: QuestID? = nil, requiresAreaQuests: AreaQuestGate? = nil, heldLine: String? = nil, notes: String? = nil) {
        self.id = id; self.level = level; self.trigger = trigger; self.triggerLabel = triggerLabel; self.storyChapter = storyChapter
        self.unlockBackdrop = unlockBackdrop; self.unlockQuest = unlockQuest; self.unlockFeature = unlockFeature; self.reward = reward
        self.completesChapter = completesChapter; self.teaseArea = teaseArea; self.requiresQuest = requiresQuest; self.requiresAreaQuests = requiresAreaQuests; self.heldLine = heldLine; self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id, level, trigger, triggerLabel = "trigger_label", storyChapter = "story_chapter", unlockBackdrop = "unlock_backdrop"
        case unlockQuest = "unlock_quest", unlockFeature = "unlock_feature", reward, completesChapter = "completes_chapter", teaseArea = "tease_area"
        case requiresQuest = "requires_quest", requiresAreaQuests = "requires_area_quests", heldLine = "held_line", notes
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(MilestoneID.self, forKey: .id); level = try c.decode(Int.self, forKey: .level)
        trigger = try c.decodeIfPresent(Trigger.self, forKey: .trigger) ?? .auto
        triggerLabel = try c.decodeIfPresent(String.self, forKey: .triggerLabel)
        storyChapter = try c.decodeIfPresent(String.self, forKey: .storyChapter)
        unlockBackdrop = try c.decodeIfPresent(BackdropID.self, forKey: .unlockBackdrop)
        unlockQuest = try c.decodeIfPresent(QuestID.self, forKey: .unlockQuest)
        unlockFeature = try c.decodeIfPresent(String.self, forKey: .unlockFeature)
        reward = try c.decodeIfPresent(RewardID.self, forKey: .reward)
        completesChapter = try c.decodeIfPresent(Bool.self, forKey: .completesChapter) ?? false
        teaseArea = try c.decodeIfPresent(AreaID.self, forKey: .teaseArea)
        requiresQuest = try c.decodeIfPresent(QuestID.self, forKey: .requiresQuest)
        requiresAreaQuests = try c.decodeIfPresent(AreaQuestGate.self, forKey: .requiresAreaQuests)
        heldLine = try c.decodeIfPresent(String.self, forKey: .heldLine)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }
}

public struct CampaignChapter: Hashable, Codable, Sendable {
    public let id: String
    public let areaID: AreaID
    public let displayName: String
    public let levels: [Int]
    public let milestones: [Milestone]
    enum CodingKeys: String, CodingKey { case id, areaID = "area_id", displayName = "display_name", levels, milestones }
    public init(id: String, areaID: AreaID, displayName: String, levels: [Int], milestones: [Milestone]) {
        self.id = id; self.areaID = areaID; self.displayName = displayName; self.levels = levels; self.milestones = milestones
    }
    public var levelRange: ClosedRange<Int> { (levels.first ?? 1)...(levels.last ?? levels.first ?? 1) }
}

public struct Campaign: Hashable, Codable, Sendable {
    public let chapters: [CampaignChapter]
    public init(chapters: [CampaignChapter]) { self.chapters = chapters }
    /// Every milestone in campaign order (chapter order, then level, then declaration order).
    public var milestones: [Milestone] { chapters.flatMap { ch in ch.milestones.sorted { $0.level < $1.level } } }
    public func milestone(_ id: MilestoneID) -> Milestone? { milestones.first { $0.id == id } }
    public func chapter(containing id: MilestoneID) -> CampaignChapter? { chapters.first { $0.milestones.contains { $0.id == id } } }
}

/// What the player has experienced and unlocked. Persisted with the archive; recovered with it.
public struct StoryProgress: Hashable, Codable, Sendable {
    public var completedMilestones: Set<MilestoneID> = []
    public var unlockedBackdrops: Set<BackdropID> = []
    public var unlockedQuests: Set<QuestID> = []
    public var unlockedFeatures: Set<String> = []
    public var completedChapters: Set<String> = []
    public init() {}

    public func isComplete(_ id: MilestoneID) -> Bool { completedMilestones.contains(id) }
    public func hasFeature(_ feature: String) -> Bool { unlockedFeatures.contains(feature) }
}

public enum StoryDirector {
    /// Milestones whose level the player has reached and that have not been experienced, in
    /// campaign order. The app presents the first `auto` one; `manual` ones wait for the player.
    public static func due(level: Int, campaign: Campaign, progress: StoryProgress) -> [Milestone] {
        campaign.milestones.filter { $0.level <= level && !progress.isComplete($0.id) }
    }

    /// Doc 33 §A / doc 34: a milestone is held while the quest it requires has not been completed once, or
    /// while the area it names has fewer completed quest runs than it asks for. Both gates must clear.
    public static func isHeld(_ milestone: Milestone, completedQuests: Set<QuestID>, areaQuestRuns: [AreaID: Int] = [:]) -> Bool {
        if let q = milestone.requiresQuest, !completedQuests.contains(q) { return true }
        if let gate = milestone.requiresAreaQuests, (areaQuestRuns[gate.areaID] ?? 0) < gate.count { return true }
        return false
    }

    /// The first due beat that is waiting on its quest, if the story is stalled on one.
    public static func held(level: Int, campaign: Campaign, progress: StoryProgress, completedQuests: Set<QuestID>, areaQuestRuns: [AreaID: Int] = [:]) -> Milestone? {
        guard let first = due(level: level, campaign: campaign, progress: progress).first, isHeld(first, completedQuests: completedQuests, areaQuestRuns: areaQuestRuns) else { return nil }
        return first
    }

    /// The next beat to present automatically: the earliest due milestone, unless an earlier due
    /// milestone is manual (a boss gate) or held for its quest, in which case the story waits.
    public static func nextAuto(level: Int, campaign: Campaign, progress: StoryProgress, completedQuests: Set<QuestID> = [], areaQuestRuns: [AreaID: Int] = [:]) -> Milestone? {
        guard let first = due(level: level, campaign: campaign, progress: progress).first else { return nil }
        return first.trigger == .auto && !isHeld(first, completedQuests: completedQuests, areaQuestRuns: areaQuestRuns) ? first : nil
    }

    /// Manual milestones the player may start now (every earlier milestone is complete, its quests done).
    public static func offered(level: Int, campaign: Campaign, progress: StoryProgress, completedQuests: Set<QuestID> = [], areaQuestRuns: [AreaID: Int] = [:]) -> [Milestone] {
        let dueList = due(level: level, campaign: campaign, progress: progress)
        guard let first = dueList.first, first.trigger == .manual, !isHeld(first, completedQuests: completedQuests, areaQuestRuns: areaQuestRuns) else { return [] }
        return [first]
    }

    /// Record a milestone as experienced and apply its unlocks. Idempotent: applying twice changes nothing.
    public static func complete(_ milestone: Milestone, campaign: Campaign, progress: StoryProgress) -> StoryProgress {
        var p = progress
        p.completedMilestones.insert(milestone.id)
        if let b = milestone.unlockBackdrop { p.unlockedBackdrops.insert(b) }
        if let q = milestone.unlockQuest { p.unlockedQuests.insert(q) }
        if let f = milestone.unlockFeature { p.unlockedFeatures.insert(f) }
        if milestone.completesChapter, let ch = campaign.chapter(containing: milestone.id) { p.completedChapters.insert(ch.id) }
        return p
    }

    /// The quest the player should be sent on: the last unlocked one in campaign order, else the
    /// first quest that needs no unlock. Pure over content order.
    public static func currentQuest<Q>(quests: [Q], id: (Q) -> QuestID, unlockedBy: (Q) -> MilestoneID?, progress: StoryProgress) -> Q? {
        let unlocked = quests.filter { q in
            guard let gate = unlockedBy(q) else { return true }
            return progress.isComplete(gate)
        }
        return unlocked.last
    }
}

/// Carried on the `ActivityEvent` a milestone creates when it grants something, so the grant goes
/// through the engine and the ledger exactly once (rules 2 and 4).
public struct StoryReference: Hashable, Codable, Sendable {
    public let milestoneID: MilestoneID
    public let rewardID: RewardID?
    public init(milestoneID: MilestoneID, rewardID: RewardID?) { self.milestoneID = milestoneID; self.rewardID = rewardID }
    enum CodingKeys: String, CodingKey { case milestoneID = "milestone_id", rewardID = "reward_id" }

    public static func makeEvent(for milestone: Milestone, userID: UserID, familyFallback: FamilyID, at now: Date, id: ActivityEventID = ActivityEventID()) -> ActivityEvent {
        ActivityEvent(id: id, userID: userID, activityTypeID: ActivityTypeID(milestone.id.rawValue), familyID: familyFallback, startedAt: now, durationSeconds: 0,
                      source: .story, verification: .selfReported, story: StoryReference(milestoneID: milestone.id, rewardID: milestone.reward), createdAt: now)
    }
}

import Foundation

// Daily quest (doc 24, doc 22 §3 "simplified dungeon"). The character leaves for a fixed
// duration once today's goals are done and returns with a reward rolled from a ruleset table.
// No combat, no live interaction. The return is a fact priced by the engine like everything else.

public enum QuestTag: Sendable {}
public typealias QuestID = StableID<QuestTag>

/// Rolled reward, by index into `ProgressionRuleset.DailyQuest.rewardTable`. Stored on the
/// return fact so the ledger can be replayed under the same ruleset.
public struct QuestReference: Hashable, Codable, Sendable {
    public let questID: QuestID
    public let rewardIndex: Int
    /// The reward chosen from the quest's own loot pool at resolution (doc 29). nil = the ruleset
    /// table's reward for that row. Recorded on the fact so the engine never has to choose.
    public let rewardID: RewardID?
    public init(questID: QuestID, rewardIndex: Int, rewardID: RewardID? = nil) { self.questID = questID; self.rewardIndex = rewardIndex; self.rewardID = rewardID }
    enum CodingKeys: String, CodingKey { case questID = "quest_id", rewardIndex = "reward_index", rewardID = "reward_id" }
}

/// A quest's rewards for one tier (content). Pools are consulted in the order given.
public struct LootPool: Hashable, Sendable {
    public let tier: String
    public let rewards: [RewardID]
    public init(tier: String, rewards: [RewardID]) { self.tier = tier; self.rewards = rewards }
}

/// One departure. `resolvedAt`/`reward` are set when the character returns (first open after
/// `returnsAt`, or the notification). Never resolved early.
public struct QuestRun: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let questID: QuestID
    public let day: DayKey
    public let startedAt: Date
    public let returnsAt: Date
    public var resolvedAt: Date?
    public var reward: QuestReference?
    /// The progression fact created at return.
    public var activityEventID: ActivityEventID?
    /// When the player opened the cache (doc 29). The grant is already on the ledger at return;
    /// claiming is the moment it is shown. nil on older runs decodes as unclaimed-but-shown.
    public var claimedAt: Date?

    public init(id: UUID = UUID(), questID: QuestID, day: DayKey, startedAt: Date, returnsAt: Date) {
        self.id = id; self.questID = questID; self.day = day; self.startedAt = startedAt; self.returnsAt = returnsAt
    }

    public var isResolved: Bool { resolvedAt != nil }
    public var isClaimed: Bool { claimedAt != nil }
    public func isDue(at now: Date) -> Bool { !isResolved && now >= returnsAt }
    public func remaining(at now: Date) -> TimeInterval { max(0, returnsAt.timeIntervalSince(now)) }
    public var duration: TimeInterval { returnsAt.timeIntervalSince(startedAt) }
}

public enum QuestResolver {
    /// Weighted roll over the table, deterministic from the run id so a replay rolls the same
    /// reward. Nil when the table is empty.
    public static func roll(table: [ProgressionRuleset.DailyQuest.RewardEntry], runID: UUID) -> Int? {
        guard !table.isEmpty else { return nil }
        var rng = SeededGenerator(seed: runID.uuidString.hashValueStable)
        let total = table.reduce(0.0) { $0 + max(0, $1.weight) }
        guard total > 0 else { return 0 }
        var roll = Double(rng.next() % 1_000_000) / 1_000_000 * total
        for (i, entry) in table.enumerated() {
            roll -= max(0, entry.weight)
            if roll < 0 { return i }
        }
        return table.count - 1
    }

    /// Choose the reward for a rolled tier from the quest's pools: an ungranted reward of that tier
    /// first, else an ungranted one from any pool in order (so a common roll can still hand out
    /// something new once the commons are owned), else nil (XP only). Deterministic per run.
    public static func pick(tier: String, pools: [LootPool], granted: Set<RewardID>, runID: UUID) -> RewardID? {
        var rng = SeededGenerator(seed: runID.uuidString.hashValueStable &+ 0x9E37)
        func choose(_ list: [RewardID]) -> RewardID? { list.isEmpty ? nil : list[Int(rng.next() % UInt64(list.count))] }
        if let pool = pools.first(where: { $0.tier == tier }), let r = choose(pool.rewards.filter { !granted.contains($0) }) { return r }
        for pool in pools { if let r = choose(pool.rewards.filter { !granted.contains($0) }) { return r } }
        return nil
    }

    /// The return fact. Zero duration; the engine prices it from the ruleset table.
    public static func makeEvent(for run: QuestRun, rewardIndex: Int, rewardID: RewardID? = nil, userID: UserID, familyFallback: FamilyID, at now: Date, id: ActivityEventID = ActivityEventID()) -> ActivityEvent {
        ActivityEvent(id: id, userID: userID, activityTypeID: ActivityTypeID(run.questID.rawValue), familyID: familyFallback, startedAt: now, durationSeconds: 0,
                      source: .quest, verification: .selfReported, quest: QuestReference(questID: run.questID, rewardIndex: rewardIndex, rewardID: rewardID), createdAt: now)
    }
}

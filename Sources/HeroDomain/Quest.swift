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
    public init(questID: QuestID, rewardIndex: Int) { self.questID = questID; self.rewardIndex = rewardIndex }
    enum CodingKeys: String, CodingKey { case questID = "quest_id", rewardIndex = "reward_index" }
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

    public init(id: UUID = UUID(), questID: QuestID, day: DayKey, startedAt: Date, returnsAt: Date) {
        self.id = id; self.questID = questID; self.day = day; self.startedAt = startedAt; self.returnsAt = returnsAt
    }

    public var isResolved: Bool { resolvedAt != nil }
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

    /// The return fact. Zero duration; the engine prices it from the ruleset table.
    public static func makeEvent(for run: QuestRun, rewardIndex: Int, userID: UserID, familyFallback: FamilyID, at now: Date, id: ActivityEventID = ActivityEventID()) -> ActivityEvent {
        ActivityEvent(id: id, userID: userID, activityTypeID: ActivityTypeID(run.questID.rawValue), familyID: familyFallback, startedAt: now, durationSeconds: 0,
                      source: .quest, verification: .selfReported, quest: QuestReference(questID: run.questID, rewardIndex: rewardIndex), createdAt: now)
    }
}

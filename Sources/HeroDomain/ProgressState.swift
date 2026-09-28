import Foundation

/// Derived, rebuildable view of a user's progression (doc 03 `UserProgressSnapshot`).
/// Never persisted as truth; always a fold over the ledgers.
public struct ProgressSnapshot: Sendable, Equatable {
    public let totalXP: Int
    public let level: Int
    public let attributes: [AttributeID: Int]
    public let grantedRewards: Set<RewardID>

    public init(totalXP: Int, level: Int, attributes: [AttributeID: Int], grantedRewards: Set<RewardID>) {
        self.totalXP = totalXP; self.level = level; self.attributes = attributes; self.grantedRewards = grantedRewards
    }
}

/// In-memory ledger set with the invariants the server must also enforce. Used by tests and
/// by the local preview path; the authoritative copy lives in Postgres (doc 09).
public struct ProgressionLedger: Sendable, Equatable, Codable {
    public private(set) var xp: [XPTransaction] = []
    public private(set) var attributes: [AttributeTransaction] = []
    public private(set) var rewards: [RewardGrant] = []
    public private(set) var processing: [ProcessingRecord] = []

    public init() {}

    public func hasProcessed(_ eventID: ActivityEventID, purpose: ProcessingRecord.Purpose = .original) -> Bool {
        processing.contains { $0.activityEventID == eventID && $0.purpose == purpose }
    }

    public var grantedRewardIDs: Set<RewardID> { Set(rewards.map(\.rewardID)) }

    /// Commit a proposal exactly once. A second commit for the same event+purpose is a no-op
    /// and returns false (doc 13 invariant: processing twice never double-grants).
    @discardableResult
    public mutating func commit(_ proposal: ProgressionProposal, for event: ActivityEvent, purpose: ProcessingRecord.Purpose = .original, at now: Date) -> Bool {
        guard !hasProcessed(event.id, purpose: purpose) else { return false }
        let reason: LedgerReason = purpose == .original ? .activity : .backfill
        if proposal.xp != 0 {
            xp.append(XPTransaction(userID: event.userID, activityEventID: event.id, amount: proposal.xp, reason: reason, rulesetID: proposal.rulesetID, createdAt: now))
        }
        for (attribute, amount) in proposal.attributes.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            attributes.append(AttributeTransaction(userID: event.userID, attributeID: attribute, activityEventID: event.id, amount: amount, reason: reason, rulesetID: proposal.rulesetID, createdAt: now))
        }
        let already = grantedRewardIDs
        for reward in proposal.rewardsUnlocked where !already.contains(reward) {
            rewards.append(RewardGrant(userID: event.userID, rewardID: reward, triggeringEventID: event.id, rulesetID: proposal.rulesetID, grantedAt: now))
        }
        processing.append(ProcessingRecord(activityEventID: event.id, purpose: purpose, rulesetID: proposal.rulesetID, processedAt: now, eligibleMinutes: proposal.eligibleMinutes))
        return true
    }

    /// Reconstruct what an earlier commit granted, for an idempotent repeat receipt.
    public func recordedOutcome(for event: ActivityEvent, ruleset: ProgressionRuleset) -> ProgressionProposal {
        let record = processing.first { $0.activityEventID == event.id && $0.purpose == .original }
        let xpAmount = xp.filter { $0.activityEventID == event.id && $0.reason == .activity }.reduce(0) { $0 + $1.amount }
        var attrs: [AttributeID: Int] = [:]
        for tx in attributes where tx.activityEventID == event.id && tx.reason == .activity { attrs[tx.attributeID, default: 0] += tx.amount }
        let granted = rewards.filter { $0.triggeringEventID == event.id }.map(\.rewardID)
        // Level before/after: total XP from entries committed up to and including this event.
        var total = 0, before = 0, after = 0
        for tx in xp {
            if tx.activityEventID == event.id { before = total }
            total += tx.amount
            if tx.activityEventID == event.id { after = total }
        }
        if xpAmount == 0 { before = total; after = total }
        return ProgressionProposal(activityEventID: event.id, rulesetID: record?.rulesetID ?? ruleset.id, xp: xpAmount, attributes: attrs,
                                   levelBefore: ruleset.level(forTotalXP: before), levelAfter: ruleset.level(forTotalXP: after),
                                   rewardsUnlocked: granted, eligibleMinutes: record?.eligibleMinutes ?? 0)
    }

    /// Fold the ledgers into a snapshot under the given ruleset's level curve.
    public func snapshot(ruleset: ProgressionRuleset) -> ProgressSnapshot {
        let total = xp.reduce(0) { $0 + $1.amount }
        var attrs: [AttributeID: Int] = [:]
        for tx in attributes { attrs[tx.attributeID, default: 0] += tx.amount }
        return ProgressSnapshot(totalXP: total, level: ruleset.level(forTotalXP: total), attributes: attrs, grantedRewards: grantedRewardIDs)
    }

    /// Context for evaluating `event`, derived from what this ledger already holds.
    public func context(for event: ActivityEvent, ruleset: ProgressionRuleset, events: [ActivityEvent], levelRewards: [Int: [RewardID]], calendar: Calendar) -> EvaluationContext {
        let snapshot = snapshot(ruleset: ruleset)
        // Exact: sum the credit-weighted minutes recorded when each same-day, same-family event was processed.
        let sameDayIDs = Set(events.filter {
            $0.id != event.id && $0.familyID == event.familyID && calendar.isDate($0.startedAt, inSameDayAs: event.startedAt)
        }.map(\.id))
        let prior = processing.filter { $0.purpose == .original && sameDayIDs.contains($0.activityEventID) }.reduce(0.0) { $0 + $1.eligibleMinutes }
        return EvaluationContext(priorEligibleMinutesToday: prior, priorTotalXP: snapshot.totalXP, grantedRewardIDs: snapshot.grantedRewards, levelRewards: levelRewards)
    }
}

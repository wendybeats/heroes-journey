import Foundation

/// Why a ledger entry exists. Migrations and backfills get their own codes so they can be
/// audited and, if defective, isolated (doc 11).
public enum LedgerReason: String, Codable, Sendable {
    case activity
    case backfill
    case adjustment
    case admin
}

/// Append-only overall XP entry (doc 03).
public struct XPTransaction: Hashable, Codable, Sendable {
    public let id: UUID
    public let userID: UserID
    public let activityEventID: ActivityEventID?
    public let amount: Int
    public let reason: LedgerReason
    public let rulesetID: RulesetID
    public let createdAt: Date

    public init(id: UUID = UUID(), userID: UserID, activityEventID: ActivityEventID?, amount: Int, reason: LedgerReason, rulesetID: RulesetID, createdAt: Date) {
        self.id = id; self.userID = userID; self.activityEventID = activityEventID
        self.amount = amount; self.reason = reason; self.rulesetID = rulesetID; self.createdAt = createdAt
    }
}

/// Append-only attribute progress entry (doc 03).
public struct AttributeTransaction: Hashable, Codable, Sendable {
    public let id: UUID
    public let userID: UserID
    public let attributeID: AttributeID
    public let activityEventID: ActivityEventID?
    public let amount: Int
    public let reason: LedgerReason
    public let rulesetID: RulesetID
    public let createdAt: Date

    public init(id: UUID = UUID(), userID: UserID, attributeID: AttributeID, activityEventID: ActivityEventID?, amount: Int, reason: LedgerReason, rulesetID: RulesetID, createdAt: Date) {
        self.id = id; self.userID = userID; self.attributeID = attributeID; self.activityEventID = activityEventID
        self.amount = amount; self.reason = reason; self.rulesetID = rulesetID; self.createdAt = createdAt
    }
}

/// Permanent record that a reward was earned (doc 03). Once granted it is never revoked by
/// rebalancing (AGENTS rule 4).
public struct RewardGrant: Hashable, Codable, Sendable {
    public let id: UUID
    public let userID: UserID
    public let rewardID: RewardID
    public let triggeringEventID: ActivityEventID?
    public let rulesetID: RulesetID?
    public let grantedAt: Date

    public init(id: UUID = UUID(), userID: UserID, rewardID: RewardID, triggeringEventID: ActivityEventID?, rulesetID: RulesetID?, grantedAt: Date) {
        self.id = id; self.userID = userID; self.rewardID = rewardID
        self.triggeringEventID = triggeringEventID; self.rulesetID = rulesetID; self.grantedAt = grantedAt
    }
}

/// Records that an event was processed under a ruleset, which is what makes reprocessing
/// idempotent (doc 15 §4). Uniqueness key: (activityEventID, purpose).
public struct ProcessingRecord: Hashable, Codable, Sendable {
    public enum Purpose: String, Codable, Sendable { case original, backfill }
    public let activityEventID: ActivityEventID
    public let purpose: Purpose
    public let rulesetID: RulesetID
    public let processedAt: Date
    /// Credit-weighted minutes this event consumed of its family's daily allowance, so later
    /// events on the same day taper exactly (doc 15 §2: retain enough context to explain a grant).
    public let eligibleMinutes: Double

    public init(activityEventID: ActivityEventID, purpose: Purpose, rulesetID: RulesetID, processedAt: Date, eligibleMinutes: Double = 0) {
        self.activityEventID = activityEventID; self.purpose = purpose; self.rulesetID = rulesetID; self.processedAt = processedAt
        self.eligibleMinutes = eligibleMinutes
    }
}

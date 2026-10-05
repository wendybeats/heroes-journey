import Foundation

/// Where an activity fact came from. Adapters (HealthKit, manual UI) produce these; the
/// domain never sees platform types.
public enum ActivitySource: String, Codable, Sendable, CaseIterable {
    case manual
    case structuredWorkout = "structured_workout"
    case healthImport = "health_import"
    /// A completed daily goal (doc 24). Flat XP from the ruleset, no minutes.
    case goal
    /// A daily quest return (doc 24). XP from the rolled reward entry.
    case quest
    /// Sealing the bond at the end of onboarding (owner, 2026-10-02): one permanent starting grant.
    case bond
    /// A campaign milestone that grants something (doc 28): the grant goes through the engine once.
    case story
}

/// Doc 05. All levels earn progression in MVP; kept distinct so later systems can weight them.
public enum VerificationLevel: String, Codable, Sendable, CaseIterable {
    case verified
    case structured
    case selfReported = "self_reported"
}

/// Immutable statement of what happened in real life (doc 03). Never mutated after creation;
/// corrections are appended as separate records (doc 15 §1).
public struct ActivityEvent: Hashable, Codable, Sendable {
    public static let schemaVersion = 1

    public let id: ActivityEventID
    public let userID: UserID
    public let activityTypeID: ActivityTypeID
    /// Family at the time of logging. Snapshotted so a later taxonomy change does not
    /// rewrite history (doc 04 `family_id_snapshot`).
    public let familyID: FamilyID
    public let startedAt: Date
    public let durationSeconds: Int
    public let source: ActivitySource
    public let verification: VerificationLevel
    /// Stable identifier from the external source, for import deduplication.
    public let sourceExternalID: String?
    /// Number of valid sets: from the workout record, or self-reported on a manual log (owner QA 2026-10-02).
    public let structuredSetCount: Int?
    /// Optional self-reported distance (cardio) and rounds (combat). Facts, not credit.
    public let distanceMeters: Int?
    public let rounds: Int?
    /// Set when this fact is a goal completion. Absent on every archive written before doc 24.
    public let goal: GoalReference?
    /// Set when this fact is a quest return.
    public let quest: QuestReference?
    /// Set when this fact is the bond seal.
    public let bond: BondReference?
    /// Set when this fact is a story milestone grant.
    public let story: StoryReference?
    public let schemaVersion: Int
    public let createdAt: Date

    public init(
        id: ActivityEventID = ActivityEventID(),
        userID: UserID,
        activityTypeID: ActivityTypeID,
        familyID: FamilyID,
        startedAt: Date,
        durationSeconds: Int,
        source: ActivitySource,
        verification: VerificationLevel,
        sourceExternalID: String? = nil,
        structuredSetCount: Int? = nil,
        distanceMeters: Int? = nil,
        rounds: Int? = nil,
        goal: GoalReference? = nil,
        quest: QuestReference? = nil,
        bond: BondReference? = nil,
        story: StoryReference? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.activityTypeID = activityTypeID
        self.familyID = familyID
        self.startedAt = startedAt
        self.durationSeconds = max(0, durationSeconds)
        self.source = source
        self.verification = verification
        self.sourceExternalID = sourceExternalID
        self.structuredSetCount = structuredSetCount
        self.distanceMeters = distanceMeters
        self.rounds = rounds
        self.goal = goal
        self.quest = quest
        self.bond = bond
        self.story = story
        self.schemaVersion = Self.schemaVersion
        self.createdAt = createdAt
    }

    public var endedAt: Date { startedAt.addingTimeInterval(TimeInterval(durationSeconds)) }
    public var durationMinutes: Double { Double(durationSeconds) / 60 }
}

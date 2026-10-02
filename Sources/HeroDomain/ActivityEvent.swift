import Foundation

/// Where an activity fact came from. Adapters (HealthKit, manual UI) produce these; the
/// domain never sees platform types.
public enum ActivitySource: String, Codable, Sendable, CaseIterable {
    case manual
    case structuredWorkout = "structured_workout"
    case healthImport = "health_import"
    /// A completed daily goal (doc 24). Flat XP from the ruleset, no minutes.
    case goal
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
    /// For structured workouts: number of valid sets recorded. A fact from the workout record.
    public let structuredSetCount: Int?
    /// Set when this fact is a goal completion. Absent on every archive written before doc 24.
    public let goal: GoalReference?
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
        goal: GoalReference? = nil,
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
        self.goal = goal
        self.schemaVersion = Self.schemaVersion
        self.createdAt = createdAt
    }

    public var endedAt: Date { startedAt.addingTimeInterval(TimeInterval(durationSeconds)) }
    public var durationMinutes: Double { Double(durationSeconds) / 60 }
}

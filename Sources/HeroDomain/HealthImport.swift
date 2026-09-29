import Foundation

/// Platform-neutral description of an activity read from a health store (doc 08). HealthKit and
/// later Health Connect adapters produce these; nothing in the domain knows which one did.
public struct ImportedActivity: Hashable, Codable, Sendable {
    /// Stable identifier from the source (HealthKit UUID), used for deduplication.
    public let externalID: String
    /// Source-specific activity kind, e.g. HealthKit's raw workout activity type as a string.
    public let sourceKind: String
    public let startedAt: Date
    public let endedAt: Date
    public let sourceName: String?

    public init(externalID: String, sourceKind: String, startedAt: Date, endedAt: Date, sourceName: String? = nil) {
        self.externalID = externalID; self.sourceKind = sourceKind; self.startedAt = startedAt; self.endedAt = endedAt; self.sourceName = sourceName
    }
    public var durationSeconds: Int { max(0, Int(endedAt.timeIntervalSince(startedAt))) }
}

/// What the reconciler decided for one imported record, so the UI and audit trail can explain it.
public enum ImportDisposition: Hashable, Codable, Sendable {
    /// New fact; submit for progression.
    case imported(ActivityEventID)
    /// New fact, shown in history only: it overlaps an in-app structured workout, which is authoritative (doc 15 §3).
    case historyOnlyOverlap(ActivityEventID, overlapsEventID: ActivityEventID)
    /// New fact, shown in history only: the source kind has no activity mapping.
    case historyOnlyUnmapped(ActivityEventID)
    /// Already imported (same external ID).
    case duplicate(ActivityEventID)
}

public struct ImportOutcome: Hashable, Sendable {
    public let event: ActivityEvent?
    public let disposition: ImportDisposition
}

/// Pure reconciliation of imported records against existing facts (doc 15 §3: request retry,
/// repeated source import, overlapping real activity are three different problems).
public enum ImportReconciler {
    /// Fraction of the imported interval that must overlap an in-app structured workout for the
    /// in-app record to be treated as authoritative.
    public static let overlapThreshold = 0.5

    public static func reconcile(
        _ imported: ImportedActivity,
        userID: UserID,
        existing: [ActivityEvent],
        mapping: [String: ActivityTypeID],
        familyOf: (ActivityTypeID) -> FamilyID?,
        fallbackTypeID: ActivityTypeID,
        fallbackFamilyID: FamilyID,
        now: Date
    ) -> ImportOutcome {
        if let dup = existing.first(where: { $0.sourceExternalID == imported.externalID && $0.source == .healthImport }) {
            return ImportOutcome(event: nil, disposition: .duplicate(dup.id))
        }
        let mapped = mapping[imported.sourceKind]
        let typeID = mapped ?? fallbackTypeID
        let familyID = mapped.flatMap(familyOf) ?? fallbackFamilyID
        let event = ActivityEvent(userID: userID, activityTypeID: typeID, familyID: familyID, startedAt: imported.startedAt,
                                  durationSeconds: imported.durationSeconds, source: .healthImport, verification: .verified,
                                  sourceExternalID: imported.externalID, createdAt: now)
        guard mapped != nil else { return ImportOutcome(event: event, disposition: .historyOnlyUnmapped(event.id)) }
        if let authoritative = existing.first(where: { $0.source == .structuredWorkout && overlapFraction(imported, $0) >= overlapThreshold }) {
            return ImportOutcome(event: event, disposition: .historyOnlyOverlap(event.id, overlapsEventID: authoritative.id))
        }
        return ImportOutcome(event: event, disposition: .imported(event.id))
    }

    /// Share of the imported interval covered by `other`.
    public static func overlapFraction(_ imported: ImportedActivity, _ other: ActivityEvent) -> Double {
        let start = max(imported.startedAt, other.startedAt), end = min(imported.endedAt, other.endedAt)
        let overlap = max(0, end.timeIntervalSince(start))
        let total = imported.endedAt.timeIntervalSince(imported.startedAt)
        return total > 0 ? overlap / total : 0
    }
}

/// Sync bookkeeping the adapter persists. The anchor is opaque bytes from the source and is only
/// advanced after the events it covers are durably stored (doc 15 HealthKit correction).
public struct HealthSyncState: Codable, Sendable, Equatable {
    public enum Authorization: String, Codable, Sendable {
        case notRequested
        /// The system prompt completed. Read access is NOT knowable from this alone.
        case requested
        case unavailable
    }
    public var authorization: Authorization = .notRequested
    public var anchor: Data? = nil
    public var lastSyncAt: Date? = nil
    public var lastImportedCount: Int = 0
    public var lastError: String? = nil
    public init() {}
}

/// Append-only correction to an immutable fact (doc 15 §1). The original event is never edited;
/// the timeline is a projection that hides invalidated events. Progression already granted stays.
public struct ActivityCorrection: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case sourceDeleted }
    public let id: UUID
    public let activityEventID: ActivityEventID
    public let kind: Kind
    public let createdAt: Date
    public init(id: UUID = UUID(), activityEventID: ActivityEventID, kind: Kind, createdAt: Date) {
        self.id = id; self.activityEventID = activityEventID; self.kind = kind; self.createdAt = createdAt
    }
}

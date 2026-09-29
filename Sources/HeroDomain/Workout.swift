import Foundation

public enum ExerciseTag: Sendable {}
public typealias ExerciseID = StableID<ExerciseTag>

public struct WorkoutID: Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

/// Doc 15: set types cannot share an undifferentiated weight record. Each type declares what
/// it measures, and PR comparison only happens within a type.
public enum SetType: String, Codable, Sendable, CaseIterable {
    case weighted      // external load × reps
    case bodyweight    // reps only
    case assisted      // reps with assistance; logged, never a PR
    case timed         // seconds (plank, hang)
}

public enum WeightUnit: String, Codable, Sendable, CaseIterable {
    case kg, lb
    public static let kgPerLb = 0.45359237
    /// Normalise display input to kilograms (doc 15: normalise for calculation, keep display units).
    public func toKilograms(_ value: Double) -> Double { self == .kg ? value : value * Self.kgPerLb }
    public func fromKilograms(_ kg: Double) -> Double { self == .kg ? kg : kg / Self.kgPerLb }
}

/// One set. Weight is always stored in kilograms; `enteredUnit` preserves what the user typed.
public struct WorkoutSet: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public var type: SetType
    public var reps: Int?
    public var weightKg: Double?
    public var enteredUnit: WeightUnit
    public var durationSeconds: Int?
    public var completed: Bool

    public init(id: UUID = UUID(), type: SetType, reps: Int? = nil, weightKg: Double? = nil, enteredUnit: WeightUnit = .kg, durationSeconds: Int? = nil, completed: Bool = false) {
        self.id = id; self.type = type; self.reps = reps; self.weightKg = weightKg
        self.enteredUnit = enteredUnit; self.durationSeconds = durationSeconds; self.completed = completed
    }

    /// A set counts only when it is complete and carries the measurement its type needs.
    public var isValid: Bool {
        guard completed else { return false }
        switch type {
        case .weighted: return (reps ?? 0) > 0 && (weightKg ?? 0) > 0
        case .bodyweight, .assisted: return (reps ?? 0) > 0
        case .timed: return (durationSeconds ?? 0) > 0
        }
    }

    /// Epley estimate; only meaningful for weighted sets with 1…12 reps.
    public var estimatedOneRepMaxKg: Double? {
        guard type == .weighted, let w = weightKg, let r = reps, r >= 1, r <= 12 else { return nil }
        return r == 1 ? w : w * (1 + Double(r) / 30)
    }
}

public struct WorkoutExercise: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let exerciseID: ExerciseID
    public var sets: [WorkoutSet]
    public init(id: UUID = UUID(), exerciseID: ExerciseID, sets: [WorkoutSet] = []) {
        self.id = id; self.exerciseID = exerciseID; self.sets = sets
    }
    public var validSets: [WorkoutSet] { sets.filter(\.isValid) }
}

/// A structured strength session (doc 03 Workout). Mutable while active; once finished it is
/// linked to the immutable ActivityEvent that carries it into progression.
public struct Workout: Hashable, Codable, Sendable, Identifiable {
    public let id: WorkoutID
    public let userID: UserID
    public let startedAt: Date
    public var endedAt: Date?
    public var exercises: [WorkoutExercise]
    public var notes: String?
    public var activityEventID: ActivityEventID?
    public var personalRecords: [PersonalRecord]

    public init(id: WorkoutID = WorkoutID(), userID: UserID, startedAt: Date, exercises: [WorkoutExercise] = []) {
        self.id = id; self.userID = userID; self.startedAt = startedAt; self.exercises = exercises
        self.endedAt = nil; self.notes = nil; self.activityEventID = nil; self.personalRecords = []
    }

    public var isFinished: Bool { endedAt != nil }
    public var validSetCount: Int { exercises.reduce(0) { $0 + $1.validSets.count } }
    public var totalVolumeKg: Double {
        exercises.flatMap(\.validSets).reduce(0) { $0 + (($1.weightKg ?? 0) * Double($1.reps ?? 0)) }
    }

    /// Doc 02 step 6-8: persist, then convert to an activity fact. A workout with no valid sets
    /// is not an activity. `calisthenics` when every set is bodyweight, else `weightlifting`.
    public func makeActivityEvent(now: Date, weightliftingID: ActivityTypeID, calisthenicsID: ActivityTypeID, familyID: FamilyID) -> ActivityEvent? {
        guard validSetCount > 0 else { return nil }
        let end = endedAt ?? now
        let allBodyweight = exercises.flatMap(\.validSets).allSatisfy { $0.type == .bodyweight || $0.type == .timed }
        return ActivityEvent(userID: userID, activityTypeID: allBodyweight ? calisthenicsID : weightliftingID, familyID: familyID,
                             startedAt: startedAt, durationSeconds: max(60, Int(end.timeIntervalSince(startedAt))),
                             source: .structuredWorkout, verification: .structured, createdAt: now)
    }
}

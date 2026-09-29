import Foundation

/// A personal record, detected at workout finish and stored on the workout (doc 01 "PR detection").
public struct PersonalRecord: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case maxWeight        // weighted: heaviest set
        case estimatedOneRepMax  // weighted: best Epley estimate
        case maxReps          // bodyweight: most reps in a set
        case maxDuration      // timed: longest set
    }
    public let exerciseID: ExerciseID
    public let kind: Kind
    public let value: Double          // kg, reps or seconds by kind
    public let previous: Double?      // nil when this is the first comparable set ever
    public let setID: UUID

    public var isBaseline: Bool { previous == nil }
}

public enum PRDetector {
    /// Compare each valid set in `workout` against the best comparable set in `history`
    /// (finished workouts only, same exercise, same set type). Assisted sets never qualify.
    /// Within the workout, only the best set per kind is reported.
    public static func detect(workout: Workout, history: [Workout]) -> [PersonalRecord] {
        let priorSets: [ExerciseID: [WorkoutSet]] = history.filter { $0.isFinished && $0.id != workout.id }
            .reduce(into: [:]) { acc, w in for ex in w.exercises { acc[ex.exerciseID, default: []] += ex.validSets } }
        var out: [PersonalRecord] = []
        for exercise in workout.exercises {
            let prior = priorSets[exercise.exerciseID] ?? []
            for kind in [PersonalRecord.Kind.maxWeight, .estimatedOneRepMax, .maxReps, .maxDuration] {
                guard let best = exercise.validSets.compactMap({ s in metric(kind, s).map { (s, $0) } }).max(by: { $0.1 < $1.1 }) else { continue }
                let previous = prior.compactMap { metric(kind, $0) }.max()
                if previous == nil || best.1 > previous! {
                    out.append(PersonalRecord(exerciseID: exercise.exerciseID, kind: kind, value: best.1, previous: previous, setID: best.0.id))
                }
            }
        }
        return out
    }

    static func metric(_ kind: PersonalRecord.Kind, _ set: WorkoutSet) -> Double? {
        guard set.isValid else { return nil }
        switch (kind, set.type) {
        case (.maxWeight, .weighted): return set.weightKg
        case (.estimatedOneRepMax, .weighted): return set.estimatedOneRepMaxKg
        case (.maxReps, .bodyweight): return set.reps.map(Double.init)
        case (.maxDuration, .timed): return set.durationSeconds.map(Double.init)
        default: return nil   // assisted and cross-type comparisons never qualify
        }
    }
}

import Foundation
import HealthKit
import HeroDomain

/// HealthKit adapter (doc 08). Reads workout sessions incrementally and hands back platform-neutral
/// `ImportedActivity` values plus deleted external IDs. Nothing here decides rewards.
/// `HKHealthStore` is documented thread-safe but not marked Sendable; the only state here is that store.
final class HealthKitImporter: @unchecked Sendable {
    struct Page: Sendable {
        let imported: [ImportedActivity]
        let deletedExternalIDs: [String]
        let anchor: Data?
    }

    private let store = HKHealthStore()
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Presents the system prompt. Completion says only that the prompt finished; read access is
    /// not knowable (doc 15), so callers record `.requested`, never "granted".
    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType(), HKQuantityType(.stepCount)])
    }

    /// Step total for the local calendar day containing `date`. HealthKit merges overlapping
    /// sources (phone + watch) in a cumulative-sum statistics query, so this is not double counted.
    /// Steps are information and a goal source, never an activity (doc 24).
    func fetchSteps(on date: Date, calendar: Calendar = .current) async throws -> Int {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: HKQuantityType(.stepCount), quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0))
            }
            store.execute(query)
        }
    }

    /// Incremental read from `anchor`. The caller persists the returned anchor only after it has
    /// durably stored the page (doc 15 HealthKit correction).
    func fetchWorkouts(after anchor: Data?) async throws -> Page {
        let queryAnchor = anchor.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(type: .workoutType(), predicate: nil, anchor: queryAnchor, limit: HKObjectQueryNoLimit) { _, samples, deleted, newAnchor, error in
                if let error { continuation.resume(throwing: error); return }
                let workouts = (samples ?? []).compactMap { $0 as? HKWorkout }
                let imported = workouts.map { w in
                    ImportedActivity(externalID: w.uuid.uuidString, sourceKind: Self.kindName(w.workoutActivityType),
                                     startedAt: w.startDate, endedAt: w.endDate, sourceName: w.sourceRevision.source.name)
                }
                let anchorData = newAnchor.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
                continuation.resume(returning: Page(imported: imported, deletedExternalIDs: (deleted ?? []).map { $0.uuid.uuidString }, anchor: anchorData))
            }
            store.execute(query)
        }
    }

    /// Stable names for the bundle's mapping table. Unknown types get `other_<raw>` and import as history only.
    static func kindName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "running"
        case .walking: return "walking"
        case .hiking: return "hiking"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .tennis: return "tennis"
        case .boxing: return "boxing"
        case .kickboxing: return "kickboxing"
        case .martialArts: return "martialArts"
        case .wrestling: return "wrestling"
        case .traditionalStrengthTraining: return "traditionalStrengthTraining"
        case .functionalStrengthTraining: return "functionalStrengthTraining"
        case .coreTraining: return "coreTraining"
        case .crossTraining: return "crossTraining"
        case .yoga: return "yoga"
        case .flexibility: return "flexibility"
        case .cooldown: return "cooldown"
        case .pilates: return "pilates"
        case .mindAndBody: return "mindAndBody"
        default: return "other_\(type.rawValue)"
        }
    }
}

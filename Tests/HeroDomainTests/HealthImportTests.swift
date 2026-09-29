import XCTest
@testable import HeroDomain

final class HealthImportTests: XCTestCase {
    let user = UserID()
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    let mapping: [String: ActivityTypeID] = ["running": "running", "traditionalStrengthTraining": "weightlifting", "boxing": "boxing"]
    func family(_ id: ActivityTypeID) -> FamilyID? { ["running": "cardio", "weightlifting": "strength", "boxing": "combat"][id.rawValue].map { FamilyID($0) } }
    func run(_ imported: ImportedActivity, existing: [ActivityEvent] = []) -> ImportOutcome {
        ImportReconciler.reconcile(imported, userID: user, existing: existing, mapping: mapping, familyOf: family, fallbackTypeID: "walking", fallbackFamilyID: "cardio", now: t0)
    }
    func imported(_ kind: String, id: String = UUID().uuidString, start: TimeInterval = 0, minutes: Int = 30) -> ImportedActivity {
        ImportedActivity(externalID: id, sourceKind: kind, startedAt: t0.addingTimeInterval(start), endedAt: t0.addingTimeInterval(start + Double(minutes) * 60), sourceName: "Watch")
    }

    func testMappedWorkoutBecomesVerifiedEventWithExternalID() {
        let out = run(imported("running", id: "hk-1"))
        guard case .imported(let id) = out.disposition, let e = out.event else { return XCTFail("expected import") }
        XCTAssertEqual(e.id, id); XCTAssertEqual(e.activityTypeID, "running"); XCTAssertEqual(e.familyID, "cardio")
        XCTAssertEqual(e.source, .healthImport); XCTAssertEqual(e.verification, .verified); XCTAssertEqual(e.sourceExternalID, "hk-1")
        XCTAssertEqual(e.durationSeconds, 1800)
    }

    func testSameExternalIDIsADuplicate() {
        let first = run(imported("running", id: "hk-2"))
        let again = run(imported("running", id: "hk-2"), existing: [first.event!])
        XCTAssertNil(again.event)
        guard case .duplicate(let id) = again.disposition else { return XCTFail() }
        XCTAssertEqual(id, first.event!.id)
    }

    func testUnmappedKindIsHistoryOnly() {
        let out = run(imported("curling"))
        guard case .historyOnlyUnmapped = out.disposition else { return XCTFail() }
        XCTAssertEqual(out.event?.activityTypeID, "walking", "falls back to the generic type so the fact is kept")
    }

    func testOverlapWithInAppStrengthWorkoutIsHistoryOnly() {
        // in-app session 10:00–10:50; watch recorded 10:05–10:45 (100% inside) → history only
        let inApp = ActivityEvent(userID: user, activityTypeID: "weightlifting", familyID: "strength", startedAt: t0, durationSeconds: 3000, source: .structuredWorkout, verification: .structured, createdAt: t0)
        let out = run(imported("traditionalStrengthTraining", start: 300, minutes: 40), existing: [inApp])
        guard case .historyOnlyOverlap(_, let overlaps) = out.disposition else { return XCTFail("expected overlap disposition") }
        XCTAssertEqual(overlaps, inApp.id)
        XCTAssertNotNil(out.event, "the fact is still recorded")
        // a run that only brushes the session (20% overlap) is rewarded normally
        let brush = run(imported("running", start: 2400, minutes: 50), existing: [inApp])
        guard case .imported = brush.disposition else { return XCTFail("20% overlap should import") }
        // overlap with a manual log is not authoritative: only structured workouts are
        let manual = ActivityEvent(userID: user, activityTypeID: "boxing", familyID: "combat", startedAt: t0, durationSeconds: 3600, source: .manual, verification: .selfReported, createdAt: t0)
        guard case .imported = run(imported("boxing", start: 0, minutes: 60), existing: [manual]).disposition else { return XCTFail("manual logs do not suppress imports") }
    }

    func testOverlapFraction() {
        let other = ActivityEvent(userID: user, activityTypeID: "x", familyID: "y", startedAt: t0, durationSeconds: 3600, source: .manual, verification: .selfReported, createdAt: t0)
        XCTAssertEqual(ImportReconciler.overlapFraction(imported("running", start: 1800, minutes: 60), other), 0.5, accuracy: 1e-9)
        XCTAssertEqual(ImportReconciler.overlapFraction(imported("running", start: 7200, minutes: 10), other), 0)
    }

    func testSyncStateRoundTrips() throws {
        var s = HealthSyncState(); s.authorization = .requested; s.anchor = Data([1, 2, 3]); s.lastImportedCount = 4
        let back = try JSONDecoder().decode(HealthSyncState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }
}

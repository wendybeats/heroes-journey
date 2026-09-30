import XCTest
@testable import HeroDomain

final class WorkoutTests: XCTestCase {
    let user = UserID()
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func set(_ type: SetType, reps: Int? = nil, kg: Double? = nil, seconds: Int? = nil, done: Bool = true) -> WorkoutSet {
        WorkoutSet(type: type, reps: reps, weightKg: kg, durationSeconds: seconds, completed: done)
    }
    func workout(_ exercises: [WorkoutExercise], daysAgo: Int = 0, finished: Bool = true) -> Workout {
        var w = Workout(userID: user, startedAt: t0.addingTimeInterval(Double(-daysAgo) * 86_400), exercises: exercises)
        if finished { w.endedAt = w.startedAt.addingTimeInterval(3000) }
        return w
    }

    func testUnitNormalisationRoundTrips() {
        let kg = WeightUnit.lb.toKilograms(225)
        XCTAssertEqual(kg, 102.058, accuracy: 0.001)
        XCTAssertEqual(WeightUnit.lb.fromKilograms(kg), 225, accuracy: 1e-9)
        XCTAssertEqual(WeightUnit.kg.toKilograms(100), 100)
    }

    func testSetValidityPerType() {
        XCTAssertTrue(set(.weighted, reps: 5, kg: 100).isValid)
        XCTAssertFalse(set(.weighted, reps: 5, kg: nil).isValid)
        XCTAssertFalse(set(.weighted, reps: 5, kg: 100, done: false).isValid)
        XCTAssertTrue(set(.bodyweight, reps: 8).isValid)
        XCTAssertTrue(set(.timed, seconds: 60).isValid)
        XCTAssertFalse(set(.timed, reps: 10).isValid)
        XCTAssertEqual(set(.weighted, reps: 1, kg: 100).estimatedOneRepMaxKg, 100)
        XCTAssertEqual(set(.weighted, reps: 5, kg: 100).estimatedOneRepMaxKg!, 116.667, accuracy: 0.001)
        XCTAssertNil(set(.weighted, reps: 20, kg: 50).estimatedOneRepMaxKg, "Epley is not applied beyond 12 reps")
    }

    func testFirstEverPerformanceIsBaselinePR() {
        let w = workout([WorkoutExercise(exerciseID: "bench_press", sets: [set(.weighted, reps: 5, kg: 80), set(.weighted, reps: 5, kg: 85)])])
        let prs = PRDetector.detect(workout: w, history: [])
        XCTAssertEqual(Set(prs.map(\.kind)), [.maxWeight, .estimatedOneRepMax])
        XCTAssertTrue(prs.allSatisfy(\.isBaseline))
        XCTAssertEqual(prs.first { $0.kind == .maxWeight }?.value, 85)
    }

    func testPRBeatsHistoryOnlyWithinSameExerciseAndType() {
        let history = [
            workout([WorkoutExercise(exerciseID: "bench_press", sets: [set(.weighted, reps: 3, kg: 90)])], daysAgo: 7),  // est 1RM 99
            workout([WorkoutExercise(exerciseID: "back_squat", sets: [set(.weighted, reps: 5, kg: 140)])], daysAgo: 3),
        ]
        let today = workout([
            WorkoutExercise(exerciseID: "bench_press", sets: [set(.weighted, reps: 3, kg: 92.5), set(.weighted, reps: 8, kg: 70)]),
            WorkoutExercise(exerciseID: "back_squat", sets: [set(.weighted, reps: 5, kg: 130)]),
        ])
        let prs = PRDetector.detect(workout: today, history: history)
        let bench = prs.filter { $0.exerciseID == "bench_press" }
        XCTAssertEqual(bench.map(\.kind).sorted { $0.rawValue < $1.rawValue }, [.estimatedOneRepMax, .maxWeight])
        XCTAssertEqual(bench.first { $0.kind == .maxWeight }?.previous, 90)
        XCTAssertEqual(bench.first { $0.kind == .maxWeight }?.value, 92.5)
        XCTAssertTrue(prs.filter { $0.exerciseID == "back_squat" }.isEmpty, "130 < 140 is not a PR")
    }

    func testAssistedAndIncompleteSetsNeverQualify() {
        let history = [workout([WorkoutExercise(exerciseID: "pull_up", sets: [set(.bodyweight, reps: 8)])], daysAgo: 1)]
        let today = workout([WorkoutExercise(exerciseID: "pull_up", sets: [set(.assisted, reps: 15), set(.bodyweight, reps: 12, done: false), set(.bodyweight, reps: 9)])])
        let prs = PRDetector.detect(workout: today, history: history)
        XCTAssertEqual(prs.count, 1)
        XCTAssertEqual(prs[0].kind, .maxReps); XCTAssertEqual(prs[0].value, 9); XCTAssertEqual(prs[0].previous, 8)
    }

    func testTimedPRAndUnfinishedHistoryIgnored() {
        let unfinished = workout([WorkoutExercise(exerciseID: "plank", sets: [set(.timed, seconds: 300)])], daysAgo: 1, finished: false)
        let today = workout([WorkoutExercise(exerciseID: "plank", sets: [set(.timed, seconds: 90)])])
        let prs = PRDetector.detect(workout: today, history: [unfinished])
        XCTAssertEqual(prs.count, 1); XCTAssertEqual(prs[0].kind, .maxDuration); XCTAssertTrue(prs[0].isBaseline)
    }

    func testWorkoutBecomesOneStructuredActivityEvent() {
        var w = workout([WorkoutExercise(exerciseID: "bench_press", sets: [set(.weighted, reps: 5, kg: 80)])])
        let e = w.makeActivityEvent(now: t0, weightliftingID: "weightlifting", calisthenicsID: "calisthenics", familyID: "strength")!
        XCTAssertEqual(e.activityTypeID, "weightlifting"); XCTAssertEqual(e.source, .structuredWorkout); XCTAssertEqual(e.verification, .structured)
        XCTAssertEqual(e.durationSeconds, 3000); XCTAssertEqual(e.startedAt, w.startedAt)
        w.exercises = [WorkoutExercise(exerciseID: "push_up", sets: [set(.bodyweight, reps: 20)]), WorkoutExercise(exerciseID: "plank", sets: [set(.timed, seconds: 60)])]
        XCTAssertEqual(w.makeActivityEvent(now: t0, weightliftingID: "weightlifting", calisthenicsID: "calisthenics", familyID: "strength")?.activityTypeID, "calisthenics")
        w.exercises = [WorkoutExercise(exerciseID: "bench_press", sets: [set(.weighted, reps: 5, kg: 80, done: false)])]
        XCTAssertNil(w.makeActivityEvent(now: t0, weightliftingID: "weightlifting", calisthenicsID: "calisthenics", familyID: "strength"), "no valid sets, no activity")
        XCTAssertEqual(workout([WorkoutExercise(exerciseID: "x", sets: [set(.weighted, reps: 5, kg: 100), set(.weighted, reps: 3, kg: 110)])]).totalVolumeKg, 830)
    }
}

final class StructuredCreditTests: XCTestCase {
    let user = UserID()
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    var ruleset: ProgressionRuleset {
        ProgressionRuleset(id: "ruleset.test", version: 1, status: .dev,
            xpPerMinuteByFamily: ["strength": 2.0], attributeWeightsByFamily: ["strength": ["strength": 1.0]],
            attributePointsPerXP: 0.5, verificationMultiplier: [:],
            dailyTaper: .init(fullCreditMinutes: 90, taperRate: 0.25, hardCapMinutes: 240),
            minimumDurationSeconds: 60, levelThresholdsTotalXP: [0, 60, 150],
            structuredWorkout: .init(defaultMinutes: 45, liveThresholdMinutes: 5, minutesPerValidSet: 2.5, maxCreditedMinutes: 120))
    }
    func workout(sets: Int) -> Workout {
        var w = Workout(userID: user, startedAt: t0, exercises: [WorkoutExercise(exerciseID: "bench_press", sets: (0..<sets).map { _ in WorkoutSet(type: .weighted, reps: 5, weightKg: 80, completed: true) })])
        w.endedAt = t0.addingTimeInterval(50)   // logged after the fact in under a minute
        return w
    }
    func evaluate(_ e: ActivityEvent) -> ProgressionProposal {
        ProgressionEngine.evaluate(event: e, ruleset: ruleset, context: EvaluationContext(priorEligibleMinutesToday: 0, priorTotalXP: 0, grantedRewardIDs: [], levelRewards: [:]))
    }

    func testQuickLogIsCreditedBySetsNotWallClock() {
        // 8 sets logged in 50 s with no confirmed length: duration is the 60 s minimum, credit is 8 x 2.5 = 20 min
        let e = workout(sets: 8).makeActivityEvent(now: t0.addingTimeInterval(50), weightliftingID: "weightlifting", calisthenicsID: "calisthenics", familyID: "strength")!
        XCTAssertEqual(e.durationSeconds, 60); XCTAssertEqual(e.structuredSetCount, 8)
        XCTAssertEqual(ruleset.creditedMinutes(for: e), 20)
        XCTAssertEqual(evaluate(e).xp, 40)
    }

    func testConfirmedSessionLengthBecomesTheFactAndWinsWhenLonger() {
        let e = workout(sets: 8).makeActivityEvent(now: t0.addingTimeInterval(50), durationMinutes: 45, weightliftingID: "weightlifting", calisthenicsID: "calisthenics", familyID: "strength")!
        XCTAssertEqual(e.durationSeconds, 45 * 60)
        XCTAssertEqual(ruleset.creditedMinutes(for: e), 45, "45 min > 8 sets x 2.5")
        XCTAssertEqual(evaluate(e).xp, 90)
    }

    func testSetFloorStillAppliesToAShortConfirmedLength() {
        let e = workout(sets: 20).makeActivityEvent(now: t0, durationMinutes: 10, weightliftingID: "weightlifting", calisthenicsID: "calisthenics", familyID: "strength")!
        XCTAssertEqual(ruleset.creditedMinutes(for: e), 50, "20 sets x 2.5 beats a 10-minute claim")
    }

    func testCapAndNonStructuredUnchanged() {
        let e = workout(sets: 80).makeActivityEvent(now: t0, durationMinutes: 300, weightliftingID: "weightlifting", calisthenicsID: "calisthenics", familyID: "strength")!
        XCTAssertEqual(ruleset.creditedMinutes(for: e), 120)
        let manual = ActivityEvent(userID: user, activityTypeID: "boxing", familyID: "combat", startedAt: t0, durationSeconds: 1800, source: .manual, verification: .selfReported, createdAt: t0)
        XCTAssertEqual(ruleset.creditedMinutes(for: manual), 30)
        XCTAssertNil(manual.structuredSetCount)
    }

    func testRulesetWithoutBlockFallsBackToDuration() throws {
        let plain = ProgressionRuleset(id: "r", version: 1, status: .dev, xpPerMinuteByFamily: ["strength": 2], attributeWeightsByFamily: [:], attributePointsPerXP: 0.5, verificationMultiplier: [:], dailyTaper: .init(fullCreditMinutes: 90, taperRate: 0.25, hardCapMinutes: 240), minimumDurationSeconds: 60, levelThresholdsTotalXP: [0])
        let e = workout(sets: 8).makeActivityEvent(now: t0, weightliftingID: "weightlifting", calisthenicsID: "calisthenics", familyID: "strength")!
        XCTAssertEqual(plain.creditedMinutes(for: e), 1)
        // events saved before the field existed still decode
        let json = try JSONEncoder().encode(e)
        var dict = try JSONSerialization.jsonObject(with: json) as! [String: Any]; dict.removeValue(forKey: "structuredSetCount")
        let old = try JSONDecoder().decode(ActivityEvent.self, from: JSONSerialization.data(withJSONObject: dict))
        XCTAssertNil(old.structuredSetCount)
    }
}

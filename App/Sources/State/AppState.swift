import Foundation
import Observation
import HeroDomain
import HeroContent

/// Local, single-device state for the first loop (doc 15 milestone). Persisted as one
/// atomic JSON archive. Progression is never computed by the UI: every log goes through the
/// `ProgressionService` boundary as a submission, is queued in a durable outbox, and is shown
/// only from the receipt that comes back. Today the service is the in-process authority; a
/// Supabase-backed one replaces it without touching this file's callers.
@MainActor @Observable
final class AppState {
    struct Archive: Codable {
        static let schemaVersion = 3
        var schemaVersion = Archive.schemaVersion
        var userID: UserID
        var recipe: AvatarRecipe?
        var events: [ActivityEvent]
        var ledger: ProgressionLedger
        var outbox: Outbox
        var workouts: [Workout] = []
        var activeWorkout: Workout? = nil
        var preferredUnit: WeightUnit = .kg
        var healthSync: HealthSyncState = HealthSyncState()
        var corrections: [ActivityCorrection] = []
        var importLog: [String: ImportDisposition] = [:]

        init(userID: UserID, recipe: AvatarRecipe?, events: [ActivityEvent], ledger: ProgressionLedger, outbox: Outbox, workouts: [Workout], activeWorkout: Workout?, preferredUnit: WeightUnit, healthSync: HealthSyncState, corrections: [ActivityCorrection], importLog: [String: ImportDisposition]) {
            self.userID = userID; self.recipe = recipe; self.events = events; self.ledger = ledger; self.outbox = outbox
            self.workouts = workouts; self.activeWorkout = activeWorkout; self.preferredUnit = preferredUnit
            self.healthSync = healthSync; self.corrections = corrections; self.importLog = importLog
        }
        // v2 archives lack the workout fields; read them as empty rather than discarding the user's data.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
            userID = try c.decode(UserID.self, forKey: .userID)
            recipe = try c.decodeIfPresent(AvatarRecipe.self, forKey: .recipe)
            events = try c.decode([ActivityEvent].self, forKey: .events)
            ledger = try c.decode(ProgressionLedger.self, forKey: .ledger)
            outbox = try c.decode(Outbox.self, forKey: .outbox)
            workouts = try c.decodeIfPresent([Workout].self, forKey: .workouts) ?? []
            activeWorkout = try c.decodeIfPresent(Workout.self, forKey: .activeWorkout)
            preferredUnit = try c.decodeIfPresent(WeightUnit.self, forKey: .preferredUnit) ?? .kg
            healthSync = try c.decodeIfPresent(HealthSyncState.self, forKey: .healthSync) ?? HealthSyncState()
            corrections = try c.decodeIfPresent([ActivityCorrection].self, forKey: .corrections) ?? []
            importLog = try c.decodeIfPresent([String: ImportDisposition].self, forKey: .importLog) ?? [:]
        }
    }

    let bundle: ContentBundle
    let ruleset: ProgressionRuleset
    let tokens: DesignTokens
    private let service: LocalAuthorityProgressionService
    private(set) var userID: UserID
    var recipe: AvatarRecipe? { didSet { save() } }
    private(set) var events: [ActivityEvent]
    /// Mirror of the authority's ledger, refreshed after every receipt.
    private(set) var ledger: ProgressionLedger
    private(set) var outbox: Outbox
    private(set) var workouts: [Workout]
    var activeWorkout: Workout? { didSet { save() } }
    var preferredUnit: WeightUnit { didSet { save() } }
    private(set) var healthSync: HealthSyncState
    private(set) var corrections: [ActivityCorrection]
    private(set) var importLog: [String: ImportDisposition]
    private let importer = HealthKitImporter()
    var healthAvailable: Bool { HealthKitImporter.isAvailable }
    /// The most recent confirmed receipt, for the reward moment (doc 02).
    private(set) var lastReceipt: ProgressionReceipt?
    /// PRs from the workout whose receipt is showing, if any.
    private(set) var lastPersonalRecords: [PersonalRecord] = []
    /// Increments when a reward modal is dismissed, so Home animates the numbers *after* it.
    private(set) var rewardToken = 0

    var snapshot: ProgressSnapshot { ledger.snapshot(ruleset: ruleset) }
    var evolution: ContentBundle.Evolution? { bundle.evolution(forLevel: snapshot.level) }
    var pendingCount: Int { outbox.pending.count }
    /// Facts minus invalidated ones (doc 15 §1: the timeline is a projection over corrections).
    var visibleEvents: [ActivityEvent] {
        let hidden = Set(corrections.map(\.activityEventID))
        return events.filter { !hidden.contains($0.id) }
    }
    var todayEvents: [ActivityEvent] { visibleEvents.filter { Calendar.current.isDateInToday($0.startedAt) }.sorted { $0.startedAt > $1.startedAt } }
    /// How an imported event was treated, for badges in the timeline.
    func importDisposition(for event: ActivityEvent) -> ImportDisposition? {
        guard let ext = event.sourceExternalID, event.source == .healthImport else { return nil }
        return importLog[ext]
    }

    /// Events in the current calendar week (locale-aware week start). Facts only, no game math.
    var weekEvents: [ActivityEvent] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return visibleEvents.filter { interval.contains($0.startedAt) }
    }
    var weekMinutes: Int { weekEvents.reduce(0) { $0 + $1.durationSeconds / 60 } }
    var weekSessions: Int { weekEvents.count }
    struct FamilyMinutes { let family: ContentBundle.Family; let minutes: Int }
    var weekMinutesByFamily: [FamilyMinutes] {
        var totals: [FamilyID: Int] = [:]
        for e in weekEvents { totals[e.familyID, default: 0] += e.durationSeconds / 60 }
        return bundle.families.compactMap { f in
            guard let m = totals[f.id], m > 0 else { return nil }
            return FamilyMinutes(family: f, minutes: m)
        }
        .sorted { $0.minutes > $1.minutes }
    }

    init(bundle: ContentBundle, ruleset: ProgressionRuleset, tokens: DesignTokens, archive: Archive?) {
        self.bundle = bundle; self.ruleset = ruleset; self.tokens = tokens
        let user = archive?.userID ?? UserID()
        let events = archive?.events ?? []
        let ledger = archive?.ledger ?? ProgressionLedger()
        self.userID = user
        self.recipe = archive?.recipe
        self.events = events
        self.ledger = ledger
        self.outbox = archive?.outbox ?? Outbox()
        self.workouts = archive?.workouts ?? []
        self.activeWorkout = archive?.activeWorkout
        self.preferredUnit = archive?.preferredUnit ?? .kg
        self.healthSync = archive?.healthSync ?? HealthSyncState()
        self.corrections = archive?.corrections ?? []
        self.importLog = archive?.importLog ?? [:]
        let authority = ProgressionAuthority(ruleset: ruleset, levelRewards: bundle.levelRewards, calendar: .current)
        self.service = LocalAuthorityProgressionService(authority: authority, owner: user, ledger: ledger, events: events)
    }

    // MARK: logging → submission → receipt (the core loop)

    /// Records an immutable fact, queues it, and submits. The UI shows only the receipt.
    func log(activityTypeID: ActivityTypeID, minutes: Int, startedAt: Date = Date()) {
        guard let type = bundle.activityType(activityTypeID) else { return }
        let event = ActivityEvent(userID: userID, activityTypeID: type.id, familyID: type.familyID, startedAt: startedAt, durationSeconds: minutes * 60, source: .manual, verification: .selfReported)
        events.append(event)
        let submission = ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: Date())
        outbox.enqueue(submission)
        save()
        Task { await drain(showReward: true) }
    }

    /// Submit every pending entry in order. Safe to call on launch and after any failure.
    func drain(showReward: Bool = false) async {
        for entry in outbox.pending {
            do {
                let receipt = try await service.submit(entry.submission)
                outbox.confirm(receipt)
                ledger = await service.ledger
                if showReward && !receipt.wasAlreadyProcessed { lastReceipt = receipt }
                if receipt.leveledUp, var r = recipe, let ev = bundle.evolution(forLevel: receipt.levelAfter), ev.id != r.evolutionID {
                    r.evolutionID = ev.id
                    recipe = r
                }
            } catch {
                outbox.markAttempt(entry.submission.id, error: String(describing: error))
            }
            save()
        }
    }

    func dismissReward() {
        guard lastReceipt != nil else { return }
        lastReceipt = nil; lastPersonalRecords = []
        rewardToken += 1
    }

    // MARK: strength workouts (doc 02 "Strength workout")

    func startWorkout() {
        guard activeWorkout == nil else { return }
        activeWorkout = Workout(userID: userID, startedAt: Date())
    }

    func discardWorkout() { activeWorkout = nil }

    func addExercise(_ exerciseID: ExerciseID) {
        guard var w = activeWorkout, let def = bundle.exercise(exerciseID) else { return }
        // Prefill from the last performance of this exercise (doc 02 step 2).
        let previous = previousSets(for: exerciseID)
        let sets = previous.isEmpty
            ? [WorkoutSet(type: def.defaultSetType, enteredUnit: preferredUnit)]
            : previous.map { WorkoutSet(type: $0.type, reps: $0.reps, weightKg: $0.weightKg, enteredUnit: preferredUnit, durationSeconds: $0.durationSeconds, completed: false) }
        w.exercises.append(WorkoutExercise(exerciseID: exerciseID, sets: sets))
        activeWorkout = w
    }

    func removeExercise(_ id: UUID) {
        activeWorkout?.exercises.removeAll { $0.id == id }
    }

    func addSet(to exerciseID: UUID) {
        guard var w = activeWorkout, let i = w.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let last = w.exercises[i].sets.last
        let def = bundle.exercise(w.exercises[i].exerciseID)
        w.exercises[i].sets.append(WorkoutSet(type: last?.type ?? def?.defaultSetType ?? .weighted, reps: last?.reps, weightKg: last?.weightKg, enteredUnit: preferredUnit, durationSeconds: last?.durationSeconds, completed: false))
        activeWorkout = w
    }

    func updateSet(_ set: WorkoutSet, in exerciseID: UUID) {
        guard var w = activeWorkout, let i = w.exercises.firstIndex(where: { $0.id == exerciseID }),
              let j = w.exercises[i].sets.firstIndex(where: { $0.id == set.id }) else { return }
        w.exercises[i].sets[j] = set
        activeWorkout = w
    }

    func removeSet(_ setID: UUID, in exerciseID: UUID) {
        guard var w = activeWorkout, let i = w.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        w.exercises[i].sets.removeAll { $0.id == setID }
        activeWorkout = w
    }

    /// Valid sets from the most recent finished workout containing this exercise.
    func previousSets(for exerciseID: ExerciseID) -> [WorkoutSet] {
        workouts.filter(\.isFinished).sorted { $0.startedAt > $1.startedAt }
            .lazy.compactMap { $0.exercises.first { $0.exerciseID == exerciseID }?.validSets }
            .first { !$0.isEmpty } ?? []
    }

    /// Doc 02 steps 5-9: finish, persist, detect PRs, convert to an activity, submit, reward.
    /// Returns false when the workout had no valid sets (nothing is recorded).
    /// Suggested session length for the finish prompt: elapsed time when logged live, else the ruleset default.
    func suggestedWorkoutMinutes() -> Int {
        guard let w = activeWorkout else { return 45 }
        let sw = ruleset.structuredWorkout
        let elapsed = w.elapsedMinutes(now: Date())
        if elapsed >= (sw?.liveThresholdMinutes ?? 5) { return Int(elapsed.rounded()) }
        return Int((sw?.defaultMinutes ?? 45).rounded())
    }

    @discardableResult
    func finishWorkout(sessionMinutes: Int? = nil) -> Bool {
        guard var w = activeWorkout else { return false }
        let now = Date()
        w.endedAt = now
        let minutes = sessionMinutes.map { Double(max(1, $0)) }
        guard let event = w.makeActivityEvent(now: now, durationMinutes: minutes, weightliftingID: "weightlifting", calisthenicsID: "calisthenics", familyID: "strength") else { return false }
        w.personalRecords = PRDetector.detect(workout: w, history: workouts)
        w.activityEventID = event.id
        workouts.append(w)
        activeWorkout = nil
        events.append(event)
        outbox.enqueue(ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: now))
        lastPersonalRecords = w.personalRecords
        save()
        Task { await drain(showReward: true) }
        return true
    }

    func workout(for eventID: ActivityEventID) -> Workout? { workouts.first { $0.activityEventID == eventID } }

    // MARK: Apple Health (doc 08)

    func connectHealth() async {
        guard healthAvailable else { healthSync.authorization = .unavailable; save(); return }
        do {
            try await importer.requestAuthorization()
            healthSync.authorization = .requested   // the prompt finished; read access is not knowable
            healthSync.lastError = nil
        } catch {
            healthSync.lastError = String(describing: error)
        }
        save()
        await syncHealth()
    }

    /// Incremental import. Order matters: store facts, save, then advance the anchor, then submit.
    func syncHealth() async {
        guard healthSync.authorization == .requested else { return }
        do {
            let page = try await importer.fetchWorkouts(after: healthSync.anchor)
            let now = Date()
            var importedCount = 0
            for item in page.imported {
                let outcome = ImportReconciler.reconcile(
                    item, userID: userID, existing: events,
                    mapping: bundle.healthWorkoutMapping.map,
                    familyOf: { self.bundle.activityType($0)?.familyID },
                    fallbackTypeID: bundle.healthWorkoutMapping.fallbackActivityType,
                    fallbackFamilyID: bundle.activityType(bundle.healthWorkoutMapping.fallbackActivityType)?.familyID ?? "cardio",
                    now: now)
                importLog[item.externalID] = outcome.disposition
                guard let event = outcome.event else { continue }
                events.append(event); importedCount += 1
                if case .imported = outcome.disposition {
                    outbox.enqueue(ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: now))
                }
            }
            for ext in page.deletedExternalIDs {
                for e in events where e.sourceExternalID == ext && e.source == .healthImport && !corrections.contains(where: { $0.activityEventID == e.id }) {
                    corrections.append(ActivityCorrection(activityEventID: e.id, kind: .sourceDeleted, createdAt: now))
                }
            }
            save()                                  // facts are durable before the anchor moves
            healthSync.anchor = page.anchor
            healthSync.lastSyncAt = now
            healthSync.lastImportedCount = importedCount
            healthSync.lastError = nil
            save()
            await drain(showReward: importedCount > 0)
        } catch {
            healthSync.lastError = String(describing: error)
            save()
        }
    }

    // MARK: persistence

    private static var archiveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HeroesJourney", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("archive.v2.json")  // v3 is backward-compatible with v2 files
    }

    private func save() {
        let archive = Archive(userID: userID, recipe: recipe, events: events, ledger: ledger, outbox: outbox, workouts: workouts, activeWorkout: activeWorkout, preferredUnit: preferredUnit, healthSync: healthSync, corrections: corrections, importLog: importLog)
        do {
            let data = try JSONEncoder().encode(archive)
            try data.write(to: Self.archiveURL, options: .atomic)
        } catch {
            assertionFailure("archive save failed: \(error)")
        }
    }

    static func load() -> AppState {
        do {
            let bundle = try ContentBundle.decode(Data(contentsOf: contentURL("bundle.json")))
            let ruleset = try ProgressionRuleset.decode(Data(contentsOf: contentURL("ruleset.dev-1.json")))
            let tokens = try DesignTokens.decode(Data(contentsOf: contentURL("design-tokens.json")))
            precondition(bundle.integrityProblems(against: ruleset).isEmpty, "content bundle failed integrity: \(bundle.integrityProblems(against: ruleset))")
            let archive = (try? Data(contentsOf: archiveURL)).flatMap { try? JSONDecoder().decode(Archive.self, from: $0) }
            let state = AppState(bundle: bundle, ruleset: ruleset, tokens: tokens, archive: archive)
            Task { await state.syncHealth(); await state.drain() }  // catch up, then submit anything pending
            return state
        } catch {
            fatalError("content bundle missing or invalid: \(error)")
        }
    }

    /// Content is shipped as a folder reference (project.yml) so paths match the repo.
    static func contentURL(_ file: String) -> URL {
        guard let url = Bundle.main.url(forResource: "Content/v1/\(file)", withExtension: nil)
            ?? Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "Content/v1") else {
            fatalError("missing resource Content/v1/\(file)")
        }
        return url
    }
}

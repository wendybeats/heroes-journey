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
        static let schemaVersion = 4
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
        // v4 (doc 24): daily goals.
        var goalPreferences: GoalPreferences = GoalPreferences()
        var goalPlans: [GoalPlan] = []
        var goalCompletions: [GoalCompletion] = []
        var goalSeed: UInt64 = 0
        var questRuns: [QuestRun] = []
        var startedOn: DayKey? = nil
        var lastStageDay: DayKey? = nil

        init(userID: UserID, recipe: AvatarRecipe?, events: [ActivityEvent], ledger: ProgressionLedger, outbox: Outbox, workouts: [Workout], activeWorkout: Workout?, preferredUnit: WeightUnit, healthSync: HealthSyncState, corrections: [ActivityCorrection], importLog: [String: ImportDisposition], goalPreferences: GoalPreferences, goalPlans: [GoalPlan], goalCompletions: [GoalCompletion], goalSeed: UInt64, questRuns: [QuestRun], startedOn: DayKey?, lastStageDay: DayKey?) {
            self.userID = userID; self.recipe = recipe; self.events = events; self.ledger = ledger; self.outbox = outbox
            self.workouts = workouts; self.activeWorkout = activeWorkout; self.preferredUnit = preferredUnit
            self.healthSync = healthSync; self.corrections = corrections; self.importLog = importLog
            self.goalPreferences = goalPreferences; self.goalPlans = goalPlans; self.goalCompletions = goalCompletions; self.goalSeed = goalSeed; self.questRuns = questRuns; self.startedOn = startedOn; self.lastStageDay = lastStageDay
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
            goalPreferences = try c.decodeIfPresent(GoalPreferences.self, forKey: .goalPreferences) ?? GoalPreferences()
            goalPlans = try c.decodeIfPresent([GoalPlan].self, forKey: .goalPlans) ?? []
            goalCompletions = try c.decodeIfPresent([GoalCompletion].self, forKey: .goalCompletions) ?? []
            goalSeed = try c.decodeIfPresent(UInt64.self, forKey: .goalSeed) ?? 0
            questRuns = try c.decodeIfPresent([QuestRun].self, forKey: .questRuns) ?? []
            startedOn = try c.decodeIfPresent(DayKey.self, forKey: .startedOn)
            lastStageDay = try c.decodeIfPresent(DayKey.self, forKey: .lastStageDay)
        }
    }

    let bundle: ContentBundle
    let ruleset: ProgressionRuleset
    let tokens: DesignTokens
    private let service: LocalAuthorityProgressionService
    private(set) var userID: UserID
    var recipe: AvatarRecipe? { didSet { save(); if oldValue == nil { ensureTodayPlan() } } }
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
    /// Doc 24. Preferences come from onboarding (defaults until onboarding v2 asks); plans are
    /// derived per day and kept for the no-repeat window; completions are facts.
    var goalPreferences: GoalPreferences { didSet { save(); regenerateTodayIfUntouched() } }
    private(set) var goalPlans: [GoalPlan]
    private(set) var goalCompletions: [GoalCompletion]
    private let goalSeed: UInt64
    private(set) var questRuns: [QuestRun]
    /// Day 1 is the day the character woke (first plan). Stage screen shows once per day.
    private(set) var startedOn: DayKey?
    private(set) var lastStageDay: DayKey?
    /// Set when a departure was just confirmed, for the departure screen.
    var showDeparture = false
    /// Today's step total from Health, when known (increment 2 fills this in).
    private(set) var todaySteps: Int?
    private let importer = HealthKitImporter()
    var healthAvailable: Bool { HealthKitImporter.isAvailable }
    /// The most recent confirmed receipt, for the reward moment (doc 02).
    private(set) var lastReceipt: ProgressionReceipt?
    /// Goal receipts confirmed in the same drain as `lastReceipt` (auto-completed by that activity).
    private(set) var lastGoalReceipts: [ProgressionReceipt] = []
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
    /// Real activity only: goal completions and quest returns are facts too, but not sessions.
    var activityEvents: [ActivityEvent] { visibleEvents.filter { $0.source != .goal && $0.source != .quest && $0.source != .bond } }
    var todayEvents: [ActivityEvent] { activityEvents.filter { Calendar.current.isDateInToday($0.startedAt) }.sorted { $0.startedAt > $1.startedAt } }
    /// XP granted today to real activity (what the dev-5 daily cap counts).
    var todayActivityXP: Int {
        let ids = Set(todayEvents.map(\.id))
        return ledger.xp.filter { $0.reason == .activity && $0.activityEventID.map(ids.contains) == true }.reduce(0) { $0 + $1.amount }
    }
    /// Row label for any fact, goal completions included.
    func displayName(for event: ActivityEvent) -> String {
        if let goal = event.goal { return bundle.goalTemplate(goal.templateID)?.title.replacingOccurrences(of: "{target}", with: "") ?? goal.templateID.rawValue }
        if let quest = event.quest { return bundle.quest(quest.questID)?.displayName ?? quest.questID.rawValue }
        if event.bond != nil { return "The bond" }
        return bundle.activityType(event.activityTypeID)?.displayName ?? event.activityTypeID.rawValue
    }
    /// How an imported event was treated, for badges in the timeline.
    func importDisposition(for event: ActivityEvent) -> ImportDisposition? {
        guard let ext = event.sourceExternalID, event.source == .healthImport else { return nil }
        return importLog[ext]
    }

    /// Events in the current calendar week (locale-aware week start). Facts only, no game math.
    var weekEvents: [ActivityEvent] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return activityEvents.filter { interval.contains($0.startedAt) }
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
        self.goalPreferences = archive?.goalPreferences ?? GoalPreferences()
        self.goalPlans = archive?.goalPlans ?? []
        self.goalCompletions = archive?.goalCompletions ?? []
        self.questRuns = archive?.questRuns ?? []
        self.startedOn = archive?.startedOn
        self.lastStageDay = archive?.lastStageDay
        self.goalSeed = (archive?.goalSeed).flatMap { $0 == 0 ? nil : $0 } ?? UInt64.random(in: 1...UInt64.max)
        let authority = ProgressionAuthority(ruleset: ruleset, levelRewards: bundle.levelRewards, calendar: .current)
        self.service = LocalAuthorityProgressionService(authority: authority, owner: user, ledger: ledger, events: events)
    }

    // MARK: logging → submission → receipt (the core loop)

    /// Records an immutable fact, queues it, and submits. The UI shows only the receipt.
    func log(activityTypeID: ActivityTypeID, minutes: Int, sets: Int? = nil, distanceMeters: Int? = nil, rounds: Int? = nil, startedAt: Date = Date()) {
        guard let type = bundle.activityType(activityTypeID) else { return }
        let event = ActivityEvent(userID: userID, activityTypeID: type.id, familyID: type.familyID, startedAt: startedAt, durationSeconds: minutes * 60, source: .manual, verification: .selfReported,
                                  structuredSetCount: sets.flatMap { $0 > 0 ? $0 : nil }, distanceMeters: distanceMeters.flatMap { $0 > 0 ? $0 : nil }, rounds: rounds.flatMap { $0 > 0 ? $0 : nil })
        events.append(event)
        let submission = ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: Date())
        outbox.enqueue(submission)
        evaluateGoals(now: Date())
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
                if showReward && !receipt.wasAlreadyProcessed {
                    if entry.submission.event.goal != nil, lastReceipt != nil { lastGoalReceipts.append(receipt) } else { lastReceipt = receipt }
                }
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
        lastReceipt = nil; lastPersonalRecords = []; lastGoalReceipts = []
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
        evaluateGoals(now: now)
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
            healthSync.stepsRequested = true
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
        if !healthSync.stepsRequested {
            // Workouts were authorised before steps existed: ask once for the new type.
            try? await importer.requestAuthorization()
            healthSync.stepsRequested = true
            save()
        }
        await refreshSteps()
        do {
            let firstSync = healthSync.anchor == nil
            let page = try await importer.fetchWorkouts(after: healthSync.anchor)
            let now = Date()
            // First sync: credit only the recent window; older workouts are kept as history (doc 15).
            let creditFrom: Date? = firstSync ? ruleset.healthHistoryWindowDays.map { now.addingTimeInterval(-Double($0) * 86_400) } : nil
            var importedCount = 0
            for item in page.imported {
                let outcome = ImportReconciler.reconcile(
                    item, userID: userID, existing: events,
                    mapping: bundle.healthWorkoutMapping.map,
                    familyOf: { self.bundle.activityType($0)?.familyID },
                    fallbackTypeID: bundle.healthWorkoutMapping.fallbackActivityType,
                    fallbackFamilyID: bundle.activityType(bundle.healthWorkoutMapping.fallbackActivityType)?.familyID ?? "cardio",
                    now: now, creditFrom: creditFrom)
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
            evaluateGoals(now: now)
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

    /// Today's step total → `todaySteps`, then goal evaluation. A read failure leaves the last value.
    func refreshSteps() async {
        guard healthSync.authorization == .requested else { return }
        guard let steps = try? await importer.fetchSteps(on: Date()) else { return }
        let before = outbox.pending.count
        todaySteps = steps
        evaluateGoals(now: Date())
        if outbox.pending.count > before { save(); await drain(showReward: true) }
    }

    // MARK: daily goals (doc 24)

    var today: DayKey { DayKey(Date(), calendar: .current) }
    var todayPlan: GoalPlan? { goalPlans.first { $0.day == today } }
    var todayCompletions: [GoalCompletion] { goalCompletions.filter { $0.day == today } }
    func isCompleted(_ goal: DailyGoal) -> Bool { goalCompletions.contains { $0.goalID == goal.id } }
    var todayGoalsDone: Int { todayPlan?.goals.filter(isCompleted).count ?? 0 }
    var todayGoalsTotal: Int { todayPlan?.goals.count ?? 0 }
    /// The quest unlocks when every goal of the day is done (doc 24: no separate energy currency).
    var questReady: Bool { todayGoalsTotal > 0 && todayGoalsDone == todayGoalsTotal }
    func template(for goal: DailyGoal) -> GoalTemplate? { bundle.goalTemplate(goal.templateID) }
    func title(for goal: DailyGoal) -> String {
        let raw = template(for: goal)?.title ?? goal.templateID.rawValue
        return raw.replacingOccurrences(of: "{target}", with: goal.target.map { $0.formatted() } ?? "")
    }
    func line(for goal: DailyGoal) -> String {
        guard let t = template(for: goal), !t.lines.isEmpty else { return "" }
        return t.lines[min(goal.lineIndex, t.lines.count - 1)].replacingOccurrences(of: "{target}", with: goal.target.map { $0.formatted() } ?? "")
    }
    func isTrainingDay() -> Bool { GoalGenerator.isTrainingDay(today, preferences: goalPreferences, calendar: .current) }

    /// Make sure today has a plan. Call on launch and whenever the app comes to the foreground.
    func ensureTodayPlan() {
        guard recipe != nil, todayPlan == nil else { return }
        let plan = GoalGenerator.plan(generatorInputs(for: today), now: Date())
        if startedOn == nil { startedOn = today }
        goalPlans.append(plan)
        goalPlans = goalPlans.filter { today.daysSince($0.day, calendar: .current) <= 30 }   // keep the repeat window, not forever
        evaluateGoals(now: Date())
        save()
        Task { await drain(showReward: false) }
    }

    private func generatorInputs(for day: DayKey) -> GoalGenerator.Inputs {
        .init(day: day, templates: bundle.goalTemplates, preferences: goalPreferences, level: snapshot.level,
              history: goalPlans.filter { $0.day != day }, completions: goalCompletions, seed: goalSeed, calendar: .current)
    }

    /// Preferences changed (onboarding, settings): rebuild today only if nothing was completed yet.
    private func regenerateTodayIfUntouched() {
        guard todayPlan != nil, todayCompletions.isEmpty else { return }
        goalPlans.removeAll { $0.day == today }
        ensureTodayPlan()
    }

    /// Tap on a goal row. Any goal can be self-reported (doc 22: no shame, no gatekeeping).
    func completeGoal(_ goal: DailyGoal) {
        // Only manual goals can be self-reported; the rest complete from facts (dev-4, docs/21).
        guard !isCompleted(goal), template(for: goal)?.rule.isManual == true else { return }
        record(goal, source: .manual, now: Date())
        save()
        Task { await drain(showReward: true) }
    }

    /// Auto-completion from the day's facts. Submissions are queued; the caller drains.
    private func evaluateGoals(now: Date) {
        guard let plan = todayPlan else { return }
        let completed = Set(goalCompletions.map(\.goalID))
        let todays = activityEvents.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: now) }
        for hit in GoalEvaluator.satisfied(plan: plan, templates: bundle.goalTemplates, completed: completed, events: todays, steps: todaySteps) {
            record(hit.goal, source: hit.source, now: now)
        }
    }

    private func record(_ goal: DailyGoal, source: GoalCompletion.Source, now: Date) {
        guard let template = template(for: goal) else { return }
        let event = GoalEvaluator.makeEvent(for: goal, template: template, userID: userID, familyFallback: goalPreferences.primaryFamily, at: now)
        goalCompletions.append(GoalCompletion(goalID: goal.id, templateID: goal.templateID, day: goal.day, source: source, activityEventID: event.id, completedAt: now))
        events.append(event)
        outbox.enqueue(ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: now))
    }

    /// Onboarding v2: preferences first (no plan exists yet, so nothing regenerates), then the
    /// recipe, which creates day one's plan and queues the stage screen.
    func completeOnboarding(recipe newRecipe: AvatarRecipe, preferences: GoalPreferences) {
        goalPreferences = preferences
        recipe = newRecipe
        // Seal the bond: one permanent starting grant through the same engine (owner, 2026-10-02).
        guard ruleset.bondGrant != nil, !events.contains(where: { $0.source == .bond }) else { return }
        let now = Date()
        let event = BondReference.makeEvent(primaryFamily: preferences.primaryFamily, secondaryInterest: preferences.secondaryInterest, ruleset: ruleset, userID: userID, at: now)
        events.append(event)
        outbox.enqueue(ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: now))
        save()
        Task { await drain(showReward: false) }
    }

    // MARK: setting the stage (doc 24)

    var dayNumber: Int { (startedOn.map { today.daysSince($0, calendar: .current) } ?? 0) + 1 }
    /// True until the day's stage screen has been dismissed once.
    var needsStage: Bool { recipe != nil && todayPlan != nil && lastStageDay != today }
    func dismissStage() { lastStageDay = today; save() }

    // MARK: daily quest (doc 24)

    var quest: ContentBundle.Quest? { bundle.defaultQuest }
    var questDuration: TimeInterval { TimeInterval((ruleset.dailyQuest?.durationMinutes ?? 240) * 60) }
    /// The run that is out, if any (unresolved).
    var activeQuest: QuestRun? { questRuns.first { !$0.isResolved } }
    var todayQuest: QuestRun? { questRuns.first { $0.day == today } }
    var characterAway: Bool { activeQuest != nil }
    enum QuestState { case locked, ready, away(QuestRun), returned(QuestRun) }
    var questState: QuestState {
        if let run = activeQuest { return .away(run) }
        if let run = todayQuest, run.isResolved { return .returned(run) }
        return questReady ? .ready : .locked
    }
    func questRun(for eventID: ActivityEventID) -> QuestRun? { questRuns.first { $0.activityEventID == eventID } }

    /// Depart. One quest per day, only when today's goals are done; a quest already out blocks a second.
    func beginQuest(requestNotifications: Bool = true) async {
        guard let quest, questReady, activeQuest == nil, todayQuest == nil, ruleset.dailyQuest != nil else { return }
        let now = Date()
        let run = QuestRun(questID: quest.id, day: today, startedAt: now, returnsAt: now.addingTimeInterval(questDuration))
        questRuns.append(run)
        questRuns = questRuns.filter { today.daysSince($0.day, calendar: .current) <= 30 || !$0.isResolved }
        showDeparture = true
        save()
        if requestNotifications, await QuestNotifications.requestPermission() {
            await QuestNotifications.schedule(returnAt: run.returnsAt, characterName: recipe?.name ?? "Your character", line: quest.awayLines.first ?? "")
        }
    }

    /// Resolve a due run: roll, record the return fact, submit, show the reveal. Never early.
    func resolveQuestIfDue() {
        let now = Date()
        guard let i = questRuns.firstIndex(where: { $0.isDue(at: now) }), let table = ruleset.dailyQuest?.rewardTable,
              let index = QuestResolver.roll(table: table, runID: questRuns[i].id) else { return }
        let event = QuestResolver.makeEvent(for: questRuns[i], rewardIndex: index, userID: userID, familyFallback: goalPreferences.primaryFamily, at: now)
        questRuns[i].resolvedAt = now
        questRuns[i].reward = QuestReference(questID: questRuns[i].questID, rewardIndex: index)
        questRuns[i].activityEventID = event.id
        events.append(event)
        outbox.enqueue(ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: now))
        QuestNotifications.cancel()
        save()
        Task { await drain(showReward: true) }
    }

    func rewardTier(for run: QuestRun) -> String? { run.reward.flatMap { ruleset.dailyQuest?.rewardTable[safe: $0.rewardIndex]?.tier } }
    func returnLine(for run: QuestRun) -> String {
        guard let q = quest, let tier = rewardTier(for: run), let lines = q.returnLines[tier], !lines.isEmpty else { return "Back." }
        return lines[Int(run.id.uuidString.hashValueStableApp % UInt64(lines.count))]
    }
    func awayLine(for run: QuestRun) -> String {
        guard let q = quest, !q.awayLines.isEmpty else { return "" }
        return q.awayLines[Int(run.id.uuidString.hashValueStableApp % UInt64(q.awayLines.count))]
    }
    func departLine(for run: QuestRun) -> String {
        guard let q = quest, !q.departLines.isEmpty else { return "" }
        return q.departLines[Int(run.id.uuidString.hashValueStableApp % UInt64(q.departLines.count))]
    }

    // MARK: persistence

    private static var archiveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HeroesJourney", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("archive.v2.json")  // v3/v4 are backward-compatible with v2 files
    }

    private func save() {
        let archive = Archive(userID: userID, recipe: recipe, events: events, ledger: ledger, outbox: outbox, workouts: workouts, activeWorkout: activeWorkout, preferredUnit: preferredUnit, healthSync: healthSync, corrections: corrections, importLog: importLog, goalPreferences: goalPreferences, goalPlans: goalPlans, goalCompletions: goalCompletions, goalSeed: goalSeed, questRuns: questRuns, startedOn: startedOn, lastStageDay: lastStageDay)
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
            let ruleset = try ProgressionRuleset.decode(Data(contentsOf: contentURL("ruleset.dev-5.json")))
            let tokens = try DesignTokens.decode(Data(contentsOf: contentURL("design-tokens.json")))
            precondition(bundle.integrityProblems(against: ruleset).isEmpty, "content bundle failed integrity: \(bundle.integrityProblems(against: ruleset))")
            let archive = (try? Data(contentsOf: archiveURL)).flatMap { try? JSONDecoder().decode(Archive.self, from: $0) }
            let state = AppState(bundle: bundle, ruleset: ruleset, tokens: tokens, archive: archive)
            state.ensureTodayPlan()
            state.resolveQuestIfDue()
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

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

extension String {
    /// FNV-1a, stable across launches (the domain has the same function, internal to its module).
    var hashValueStableApp: UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01B3 }
        return h
    }
}

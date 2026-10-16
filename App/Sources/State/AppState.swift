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
        var storyProgress: StoryProgress = StoryProgress()
        /// Doc 33: one offer per day at most; declined or accepted offers stay so the cadence and sets can read them.
        var challengeOffers: [ChallengeOffer] = []

        init(userID: UserID, recipe: AvatarRecipe?, events: [ActivityEvent], ledger: ProgressionLedger, outbox: Outbox, workouts: [Workout], activeWorkout: Workout?, preferredUnit: WeightUnit, healthSync: HealthSyncState, corrections: [ActivityCorrection], importLog: [String: ImportDisposition], goalPreferences: GoalPreferences, goalPlans: [GoalPlan], goalCompletions: [GoalCompletion], goalSeed: UInt64, questRuns: [QuestRun], startedOn: DayKey?, lastStageDay: DayKey?, storyProgress: StoryProgress, challengeOffers: [ChallengeOffer] = []) {
            self.userID = userID; self.recipe = recipe; self.events = events; self.ledger = ledger; self.outbox = outbox
            self.workouts = workouts; self.activeWorkout = activeWorkout; self.preferredUnit = preferredUnit
            self.healthSync = healthSync; self.corrections = corrections; self.importLog = importLog
            self.goalPreferences = goalPreferences; self.goalPlans = goalPlans; self.goalCompletions = goalCompletions; self.goalSeed = goalSeed; self.questRuns = questRuns; self.startedOn = startedOn; self.lastStageDay = lastStageDay; self.storyProgress = storyProgress; self.challengeOffers = challengeOffers
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
            storyProgress = try c.decodeIfPresent(StoryProgress.self, forKey: .storyProgress) ?? StoryProgress()
            challengeOffers = try c.decodeIfPresent([ChallengeOffer].self, forKey: .challengeOffers) ?? []
        }
    }

    /// Doc 33: a challenge offered on a day. Open until declined or accepted (then its fact's id is here) or the day ends.
    struct ChallengeOffer: Codable, Equatable {
        let day: DayKey
        let challengeID: ChallengeID
        /// Which line set this meeting uses (meeting count, cycling).
        let setIndex: Int
        var declined = false
        var eventID: ActivityEventID? = nil
        var isOpen: Bool { !declined && eventID == nil }
    }
    /// The odds as the card shows them: stat, today's training bonus, the target, and the band word.
    struct ChallengeOdds: Equatable {
        let stat: Int, bonus: Double, target: Double, probability: Double, band: ChallengeBand
        /// Families whose minutes today moved (or would move) the odds, for the hint under the band.
        let helpingFamilies: [FamilyID]
    }
    /// What the clash plays: the challenge, the line set, the outcome and the fact that records it.
    struct ChallengeOutcome: Identifiable, Equatable {
        let challenge: ContentBundle.Challenge
        let set: ContentBundle.Challenge.LineSet
        let reference: ChallengeReference
        let eventID: ActivityEventID
        var id: ActivityEventID { eventID }
        var won: Bool { reference.won }
    }

    let bundle: ContentBundle
    private(set) var ruleset: ProgressionRuleset
    /// The content ruleset as loaded; `ruleset` may be a debug variant of it (daily cap off).
    private let baseRuleset: ProgressionRuleset
    let tokens: DesignTokens
    private var service: LocalAuthorityProgressionService
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
    private var goalSeed: UInt64   // var only for the debug goal reset
    private(set) var questRuns: [QuestRun]
    /// Day 1 is the day the character woke (first plan). Stage screen shows once per day.
    private(set) var startedOn: DayKey?
    private(set) var lastStageDay: DayKey?
    /// Doc 28: what the player has experienced and unlocked. Levels make beats eligible; this records them.
    private(set) var storyProgress: StoryProgress
    private(set) var challengeOffers: [ChallengeOffer]
    /// A quest's end scene (first completion) or repeat exchange (later ones) waiting to play after its return reveal.
    private(set) var pendingReturnScene: ContentBundle.StoryChapter?
    /// A world reaction just granted (doc 33: the rain stops on Protein Row), for Home to toast once.
    var lastWorldReaction: String?
    /// Owner 2026-10-06: an Ascension is a cutscene, never a stat that just appears. Recorded when the ledger
    /// crosses an evolution boundary (wherever that happens: a sheet, the quest screen, a relaunch) and played
    /// by Home as the highest-priority beat once the screen is quiet. Persisted so a kill mid-cover keeps it.
    struct PendingAscension: Codable, Equatable {
        let fromTier: Int, toTier: Int, evolutionName: String, chapterID: String?
    }
    private(set) var pendingAscension: PendingAscension? {
        didSet { UserDefaults.standard.set(pendingAscension.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.pendingAscensionKey) }
    }
    private static let pendingAscensionKey = "ascension.pending"
    func clearPendingAscension() { pendingAscension = nil }
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
    /// Doc 32: ascension is a tier of effects around the canonical body, from the level's evolution.
    /// The tier the character shows. While an Ascension waits to be played, every screen keeps the old tier so the takeover is the reveal.
    var ascensionTier: Int { pendingAscension?.fromTier ?? evolution?.ascensionTier ?? 0 }
    var pendingCount: Int { outbox.pending.count }
    /// Facts minus invalidated ones (doc 15 §1: the timeline is a projection over corrections).
    var visibleEvents: [ActivityEvent] {
        let hidden = Set(corrections.map(\.activityEventID))
        return events.filter { !hidden.contains($0.id) }
    }
    /// Real activity only: goal completions and quest returns are facts too, but not sessions.
    var activityEvents: [ActivityEvent] { visibleEvents.filter { $0.source != .goal && $0.source != .quest && $0.source != .bond && $0.source != .story && $0.source != .challenge } }
    var todayEvents: [ActivityEvent] { activityEvents.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: now) }.sorted { $0.startedAt > $1.startedAt } }
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
        if let c = event.challenge { return "\(bundle.character(CharacterID(c.characterID))?.displayName ?? "Someone")'s challenge" }
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
        guard let interval = cal.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return activityEvents.filter { interval.contains($0.startedAt) }
    }
    var weekMinutes: Int { weekEvents.reduce(0) { $0 + $1.durationSeconds / 60 } }
    /// Owner 2026-10-12: the week as a chart. For each day of the current week, the attributes that saw meaningful
    /// effort (an activity of at least ten minutes in a family that feeds them). Facts only.
    struct DayEffort { let day: Date; let isToday: Bool; let attributes: Set<AttributeID> }
    var weekEffort: [DayEffort] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return (0..<7).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            var attrs: Set<AttributeID> = []
            for e in activityEvents where cal.isDate(e.startedAt, inSameDayAs: day) && e.durationSeconds >= 10 * 60 {
                attrs.insert(BondReference.attribute(forFamily: e.familyID.rawValue, ruleset: ruleset, fallback: "endurance"))
            }
            return DayEffort(day: day, isToday: cal.isDate(day, inSameDayAs: now), attributes: attrs)
        }
    }
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
        pendingAscension = UserDefaults.standard.data(forKey: Self.pendingAscensionKey).flatMap { try? JSONDecoder().decode(PendingAscension.self, from: $0) }
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
        self.storyProgress = archive?.storyProgress ?? StoryProgress()
        challengeOffers = archive?.challengeOffers ?? []
        self.goalSeed = (archive?.goalSeed).flatMap { $0 == 0 ? nil : $0 } ?? UInt64.random(in: 1...UInt64.max)
        self.baseRuleset = ruleset
        let authority = ProgressionAuthority(ruleset: ruleset, levelRewards: bundle.levelRewards, calendar: .current)
        self.service = LocalAuthorityProgressionService(authority: authority, owner: user, ledger: ledger, events: events)
        // Saves from before doc 32 wore nothing on the canonical body: dress them in the starter outfit once.
        if var r = recipe, r.equipped.isEmpty { r.equipped = bundle.starterEquipment; recipe = r }
        // Saves from before increment 30: the story opened a world backdrop but the Home scene never switched. Catch up once.
        if var r = recipe, r.backdropID == bundle.defaultBackdrop?.id {
            let unlocked = storyProgress.unlockedBackdrops
            let opened = bundle.campaign.milestones.compactMap { $0.unlockBackdrop }.filter { unlocked.contains($0) }
            if let last = opened.last(where: { bundle.backdrop($0)?.role != "home_room" }) { r.backdropID = last; recipe = r }
        }
    }

    // MARK: logging → submission → receipt (the core loop)

    /// Records an immutable fact, queues it, and submits. The UI shows only the receipt.
    func log(activityTypeID: ActivityTypeID, minutes: Int, sets: Int? = nil, distanceMeters: Int? = nil, rounds: Int? = nil, startedAt: Date? = nil) {
        guard let type = bundle.activityType(activityTypeID) else { return }
        let event = ActivityEvent(userID: userID, activityTypeID: type.id, familyID: type.familyID, startedAt: startedAt ?? now, durationSeconds: minutes * 60, source: .manual, verification: .selfReported,
                                  structuredSetCount: sets.flatMap { $0 > 0 ? $0 : nil }, distanceMeters: distanceMeters.flatMap { $0 > 0 ? $0 : nil }, rounds: rounds.flatMap { $0 > 0 ? $0 : nil })
        events.append(event)
        let submission = ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: now)
        outbox.enqueue(submission)
        evaluateGoals(now: now)
        save()
        Task { await drain(showReward: true) }
    }

    /// Submit every pending entry in order. Safe to call on launch and after any failure.
    func drain(showReward: Bool = false) async {
        for entry in outbox.pending {
            do {
                let receipt = try await service.submit(entry.submission)
                outbox.confirm(receipt)
                let levelBefore = snapshot.level
                ledger = await service.ledger
                noteAscension(from: levelBefore, to: snapshot.level)
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

    /// Queue the Ascension takeover when a level change crosses into a higher tier. Idempotent per boundary.
    private func noteAscension(from levelBefore: Int, to levelAfter: Int) {
        guard levelAfter > levelBefore else { return }
        let old = bundle.evolution(forLevel: levelBefore), new = bundle.evolution(forLevel: levelAfter)
        guard let new, old?.id != new.id, (new.ascensionTier ?? 0) > (old?.ascensionTier ?? 0) else { return }
        pendingAscension = PendingAscension(fromTier: pendingAscension?.fromTier ?? old?.ascensionTier ?? 0, toTier: new.ascensionTier ?? 0,
                                            evolutionName: new.displayName, chapterID: new.ascensionChapter)
    }

    func dismissReward() {
        guard lastReceipt != nil else { return }
        lastReceipt = nil; lastPersonalRecords = []; lastGoalReceipts = []
        rewardToken += 1
    }

    // MARK: strength workouts (doc 02 "Strength workout")

    func startWorkout() {
        guard activeWorkout == nil else { return }
        activeWorkout = Workout(userID: userID, startedAt: now)
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
        let elapsed = w.elapsedMinutes(now: now)
        if elapsed >= (sw?.liveThresholdMinutes ?? 5) { return Int(elapsed.rounded()) }
        return Int((sw?.defaultMinutes ?? 45).rounded())
    }

    @discardableResult
    func finishWorkout(sessionMinutes: Int? = nil) -> Bool {
        guard var w = activeWorkout else { return false }
        let now = self.now
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
            let now = self.now
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
        guard let steps = try? await importer.fetchSteps(on: Date()) else { return }   // Health reads the real calendar
        let before = outbox.pending.count
        todaySteps = steps
        evaluateGoals(now: now)
        if outbox.pending.count > before { save(); await drain(showReward: true) }
    }

    // MARK: daily goals (doc 24)

    /// The app's clock. `devDayOffset` (debug controls) shifts it so daily progression can be seen without waiting;
    /// everything day-sensitive (today's facts, goals, quests, offers, the week) reads this, never the wall clock
    /// (owner QA 2026-10-12: an advanced day has to feel like a real one).
    var now: Date { Date().addingTimeInterval(TimeInterval(devDayOffset) * 86_400) }
    var today: DayKey { DayKey(now, calendar: .current) }

    // MARK: challenges (doc 33)

    var todayOffer: ChallengeOffer? { challengeOffers.first { $0.day == today && $0.isOpen } }
    /// Challenges the player's progress has reached, in content order.
    var availableChallenges: [ContentBundle.Challenge] {
        bundle.challenges.filter { ch in
            if let l = ch.availableFromLevel, snapshot.level < l { return false }
            if let q = ch.availableAfterQuest, !completedQuestIDs.contains(q) { return false }
            if let m = ch.availableAfterMilestone, !storyProgress.isComplete(m) { return false }
            return true
        }
    }
    /// One roll a day (doc 33 cadence), skipped while the story owns the day (unclaimed cache, held beat).
    private func rollChallengeOffer() {
        guard !challengeOffers.contains(where: { $0.day == today }), unclaimedQuest == nil else { return }
        let lastDay = challengeOffers.map(\.day).max()
        let gap = lastDay.map { today.daysSince($0, calendar: .current) }
        guard ChallengeMath.offersToday(level: snapshot.level, daysSinceLastOffer: gap, seed: "\(userID.rawValue.uuidString)|\(today.rawValue)|offer", ruleset: ruleset) else { return }
        offerChallenge(seed: "\(userID.rawValue.uuidString)|\(today.rawValue)|who")
    }
    private func offerChallenge(seed: String) {
        let pool = availableChallenges
        guard !pool.isEmpty else { return }
        // Pick the person first, evenly, then one of their challenges, so Cairon's four do not outweigh a lifter's one.
        // Not the same person twice running when there is a choice.
        var people = Array(Set(pool.map(\.characterID))).sorted { $0.rawValue < $1.rawValue }
        if let last = challengeOffers.sorted(by: { $0.day < $1.day }).last, let lastCharacter = bundle.challenge(last.challengeID)?.characterID, people.count > 1 {
            people.removeAll { $0 == lastCharacter }
        }
        let who = people[Int(ChallengeMath.roll(seed: seed + "|who") * Double(people.count)) % people.count]
        let theirs = pool.filter { $0.characterID == who }
        let pick = theirs[Int(ChallengeMath.roll(seed: seed) * Double(theirs.count)) % theirs.count]
        let meetings = challengeOffers.filter { $0.challengeID == pick.id && $0.eventID != nil }.count
        challengeOffers.append(ChallengeOffer(day: today, challengeID: pick.id, setIndex: meetings))
        challengeOffers = challengeOffers.filter { today.daysSince($0.day, calendar: .current) <= 60 }
        save()
    }
    /// Today's credited minutes per family, from the ledger's processing records (the engine's own taper).
    var todayCreditedMinutesByFamily: [String: Double] {
        var out: [String: Double] = [:]
        let byEvent = Dictionary(ledger.processing.map { ($0.activityEventID, $0.eligibleMinutes) }, uniquingKeysWith: { a, _ in a })
        for e in todayEvents { out[e.familyID.rawValue, default: 0] += byEvent[e.id] ?? 0 }
        return out
    }
    func odds(for challenge: ContentBundle.Challenge) -> ChallengeOdds {
        let share = ChallengeMath.share(level: snapshot.level, ruleset: ruleset, attributeCount: max(1, bundle.attributes.count))
        let target = ChallengeMath.target(difficulty: challenge.difficulty, share: share, ruleset: ruleset)
        let stat = snapshot.attributes[challenge.attributeID] ?? 0
        let bonus = ChallengeMath.trainingBonus(minutesByFamily: todayCreditedMinutesByFamily, attributeID: challenge.attributeID, target: target, ruleset: ruleset)
        let p = ChallengeMath.winProbability(stat: Double(stat) + bonus, target: target)
        let helping = bundle.families.filter { (ruleset.attributeWeightsByFamily[$0.id.rawValue]?[challenge.attributeID.rawValue] ?? 0) >= 0.5 }.map(\.id)
        return ChallengeOdds(stat: stat, bonus: bonus, target: target, probability: p, band: ChallengeMath.band(probability: p, ruleset: ruleset), helpingFamilies: helping)
    }
    func challengeRecord(_ id: ChallengeID) -> (won: Int, lost: Int) { ChallengeMath.record(challengeID: id, events: visibleEvents) }
    func declineChallenge() {
        guard let i = challengeOffers.firstIndex(where: { $0.day == today && $0.isOpen }) else { return }
        challengeOffers[i].declined = true; save()
    }
    /// nil = roll; true/false forces the outcome (dev controls only set it).
    var devForcedOutcome: Bool?
    /// Accept today's offer: roll once (seeded), write the fact, queue it, return what the clash should play. Idempotent per offer.
    func acceptChallenge() -> ChallengeOutcome? {
        guard let i = challengeOffers.firstIndex(where: { $0.day == today && $0.isOpen }), let challenge = bundle.challenge(challengeOffers[i].challengeID),
              let set = challenge.set(forMeeting: challengeOffers[i].setIndex) else { return nil }
        let o = odds(for: challenge)
        var roll = ChallengeMath.roll(seed: "\(userID.rawValue.uuidString)|\(challenge.id.rawValue)|\(today.rawValue)|roll")
        if let forced = devForcedOutcome { roll = forced ? 0 : 0.999_999 }
        let ref = ChallengeReference(challengeID: challenge.id, characterID: challenge.characterID.rawValue, attributeID: challenge.attributeID, difficulty: challenge.difficulty,
                                     stat: o.stat, trainingBonus: o.bonus, target: o.target, probability: o.probability, roll: roll, won: roll < o.probability, setIndex: challengeOffers[i].setIndex)
        let family = o.helpingFamilies.first ?? goalPreferences.primaryFamily
        let now = self.now
        let event = ChallengeReference.makeEvent(ref, userID: userID, familyFallback: family, at: now)
        events.append(event)
        outbox.enqueue(ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: now))
        challengeOffers[i].eventID = event.id
        save()
        Task { await drain(showReward: false) }   // the clash shows the result itself
        return ChallengeOutcome(challenge: challenge, set: set, reference: ref, eventID: event.id)
    }
    /// The grant the ruleset will give for an outcome, for the result card before the receipt lands.
    func challengeGrant(for outcome: ChallengeOutcome) -> (xp: Int, points: Int) {
        guard let g = ruleset.challenges?.grant[outcome.challenge.difficulty] else { return (0, 0) }
        return outcome.won ? (g.xp, g.points) : (g.loseXP, 0)
    }
    /// Offer one now (dev controls), whatever the cadence says; replaces an open offer.
    func devOfferChallenge() {
        challengeOffers.removeAll { $0.day == today && $0.isOpen }
        offerChallenge(seed: "\(userID.rawValue.uuidString)|\(today.rawValue)|dev\(challengeOffers.count)")
        devToken += 1
    }

    // MARK: debug controls (DEBUG builds only; owner QA 2026-10-05). None of these create facts the engine
    // would not have created; they move time, swap the ruleset variant, or regenerate a plan.

    var devDayOffset: Int {
        get { UserDefaults.standard.integer(forKey: "dev.dayOffset") }
        set { UserDefaults.standard.set(newValue, forKey: "dev.dayOffset"); devToken += 1 }
    }
    private(set) var devToken = 0
    var devDailyCapOff: Bool { ruleset.dailyActivityXPCap == nil && baseRuleset.dailyActivityXPCap != nil }

    /// Pull the active quest's return to now and resolve it.
    func devFinishQuest() {
        guard let i = questRuns.firstIndex(where: { !$0.isResolved }) else { return }
        questRuns[i].returnsAt = now
        resolveQuestIfDue()
    }
    /// Replay the Ascension takeover for the current tier (0 → current), with its scene.
    func devReplayAscension() {
        guard let ev = evolution, let tier = ev.ascensionTier, tier > 0 else { return }
        pendingAscension = PendingAscension(fromTier: 0, toTier: tier, evolutionName: ev.displayName, chapterID: ev.ascensionChapter)
    }
    /// Swap the ruleset for a copy without the daily activity cap (or back). The service is rebuilt on the same ledger.
    func devSetDailyCap(off: Bool) {
        var variant = baseRuleset
        if off, var json = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(baseRuleset)) as? [String: Any] {
            json.removeValue(forKey: "daily_activity_xp_cap")
            if let data = try? JSONSerialization.data(withJSONObject: json), let r = try? ProgressionRuleset.decode(data) { variant = r }
        }
        ruleset = variant
        let authority = ProgressionAuthority(ruleset: ruleset, levelRewards: bundle.levelRewards, calendar: .current)
        service = LocalAuthorityProgressionService(authority: authority, owner: userID, ledger: ledger, events: events)
        devToken += 1
    }
    /// Throw away today's plan and completions and draw a new one with a fresh seed.
    func devResetDailyGoals() {
        goalPlans.removeAll { $0.day == today }
        goalCompletions.removeAll { $0.day == today }
        goalSeed = UInt64.random(in: 1...UInt64.max)
        save()
        ensureTodayPlan()
    }
    /// Tomorrow, now: new goals, the stage screen again, a new daily quest.
    func devAdvanceDay() { devDayOffset += 1; resolveQuestIfDue(); ensureTodayPlan() }
    func devResetDay() { devDayOffset = 0; resolveQuestIfDue(); ensureTodayPlan() }
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
        let target = goal.target.map { $0.formatted() } ?? ""
        if let story = goal.storyLine { return story.replacingOccurrences(of: "{target}", with: target) }
        guard let t = template(for: goal), !t.lines.isEmpty else { return "" }
        return t.lines[min(goal.lineIndex, t.lines.count - 1)].replacingOccurrences(of: "{target}", with: target)
    }
    func isTrainingDay() -> Bool { GoalGenerator.isTrainingDay(today, preferences: goalPreferences, calendar: .current) }

    /// Make sure today has a plan. Call on launch and whenever the app comes to the foreground.
    func ensureTodayPlan() {
        guard recipe != nil else { return }
        rollChallengeOffer()
        guard todayPlan == nil else { return }
        let plan = GoalGenerator.plan(generatorInputs(for: today), now: now)
        if startedOn == nil { startedOn = today }
        goalPlans.append(plan)
        goalPlans = goalPlans.filter { today.daysSince($0.day, calendar: .current) <= 30 }   // keep the repeat window, not forever
        evaluateGoals(now: now)
        save()
        Task { await drain(showReward: false) }
    }

    private func generatorInputs(for day: DayKey) -> GoalGenerator.Inputs {
        .init(day: day, templates: bundle.goalTemplates, preferences: goalPreferences, level: snapshot.level,
              history: goalPlans.filter { $0.day != day }, completions: goalCompletions, seed: goalSeed, calendar: .current,
              storyFlags: storyFlags, storyLineChance: ruleset.goalStoryLineChance ?? 0)
    }

    /// Doc 33: what the story has reached, as flags the content can name: completed milestone ids, plus
    /// `quest.<id>.rare` once a quest has come back with a rare roll.
    var storyFlags: Set<String> {
        var flags = Set(storyProgress.completedMilestones.map(\.rawValue))
        for run in questRuns where run.isClaimed && rewardTier(for: run) == "rare" { flags.insert("quest.\(run.questID.rawValue).rare") }
        return flags
    }
    /// Doc 33 Row rumours: one a day from the pool the story has unlocked, on rest days.
    var todayRumour: String? {
        let pool = bundle.rumours.filter { storyProgress.isComplete($0.after) }
        guard !pool.isEmpty else { return nil }
        let roll = ChallengeMath.roll(seed: "\(userID.rawValue.uuidString)|\(today.rawValue)|rumour")
        return pool[Int(roll * Double(pool.count)) % pool.count].text
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
        record(goal, source: .manual, now: now)
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
        var completedBy: ActivityEvent? = nil
        if case let .activity(id) = source { completedBy = events.first { $0.id == id } }
        let event = GoalEvaluator.makeEvent(for: goal, template: template, userID: userID, familyFallback: goalPreferences.primaryFamily, at: now, completedBy: completedBy, ruleset: ruleset)
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
        let now = self.now
        let event = BondReference.makeEvent(primaryFamily: preferences.primaryFamily, secondaryInterest: preferences.secondaryInterest, ruleset: ruleset, userID: userID, at: now)
        events.append(event)
        outbox.enqueue(ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: now))
        // The awakening was played inside onboarding: record its milestone so the director never replays it.
        for m in bundle.campaign.milestones where m.level <= 1 && m.storyChapter == "chapter.awakening" {
            storyProgress = StoryDirector.complete(m, campaign: bundle.campaign, progress: storyProgress)
        }
        save()
        Task { await drain(showReward: false) }
    }

    // MARK: story director (doc 28)

    var campaign: Campaign { bundle.campaign }
    /// The next beat to play automatically, if the player's level has reached it.
    var nextStoryBeat: Milestone? { StoryDirector.nextAuto(level: snapshot.level, campaign: campaign, progress: storyProgress, completedQuests: completedQuestIDs, areaQuestRuns: completedRunsByArea) }
    /// Manual beats the player can start now (boss encounters).
    var offeredMilestones: [Milestone] { StoryDirector.offered(level: snapshot.level, campaign: campaign, progress: storyProgress, completedQuests: completedQuestIDs, areaQuestRuns: completedRunsByArea) }
    /// Doc 33 §A: quests completed (claimed) at least once; beats that require one wait for it.
    var completedQuestIDs: Set<QuestID> { Set(questRuns.filter(\.isClaimed).map(\.questID)) }
    /// Doc 34: completed (claimed) quest runs per area, for beats that wait on effort in an area (the boss gate).
    var completedRunsByArea: [AreaID: Int] {
        var counts: [AreaID: Int] = [:]
        for run in questRuns where run.isClaimed { if let area = bundle.quest(run.questID)?.areaID { counts[area, default: 0] += 1 } }
        return counts
    }
    /// The beat the story is waiting on, if any (its `heldLine` shows on the goals card).
    var heldBeat: Milestone? { StoryDirector.held(level: snapshot.level, campaign: campaign, progress: storyProgress, completedQuests: completedQuestIDs, areaQuestRuns: completedRunsByArea) }
    func hasFeature(_ feature: String) -> Bool { storyProgress.hasFeature(feature) }
    var currentChapter: CampaignChapter? { campaign.chapters.first { !storyProgress.completedChapters.contains($0.id) && $0.levelRange.contains(snapshot.level) } ?? campaign.chapters.last }

    /// Record a beat as experienced, apply its unlocks, and route its reward through the engine (once).
    func completeMilestone(_ milestone: Milestone) {
        guard !storyProgress.isComplete(milestone.id) else { return }
        storyProgress = StoryDirector.complete(milestone, campaign: campaign, progress: storyProgress)
        // Owner QA 2026-10-05: a world backdrop the story opens becomes the Home scene; the room's own backdrop does not (the room is a hub, not the world).
        if let b = milestone.unlockBackdrop, let backdrop = bundle.backdrop(b), backdrop.role != "home_room", var r = recipe {
            r.backdropID = backdrop.id; recipe = r
        }
        if milestone.reward != nil, !events.contains(where: { $0.story?.milestoneID == milestone.id }) {
            let now = self.now
            let event = StoryReference.makeEvent(for: milestone, userID: userID, familyFallback: goalPreferences.primaryFamily, at: now)
            events.append(event)
            outbox.enqueue(ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: now))
            save()
            Task { await drain(showReward: true) }
            return
        }
        save()
    }

    func clearPendingReturnChapter() { pendingReturnScene = nil }

    // MARK: setting the stage (doc 24)

    var dayNumber: Int { (startedOn.map { today.daysSince($0, calendar: .current) } ?? 0) + 1 }
    /// True until the day's stage screen has been dismissed once.
    var needsStage: Bool { recipe != nil && todayPlan != nil && lastStageDay != today }
    func dismissStage() { lastStageDay = today; save() }

    // MARK: daily quest (doc 24)

    /// The quest the story has reached: the last one unlocked by a completed milestone, else the first ungated one (doc 28).
    var quest: ContentBundle.Quest? { StoryDirector.currentQuest(quests: bundle.quests, id: \.id, unlockedBy: \.unlockedByMilestone, progress: storyProgress) ?? bundle.defaultQuest }
    func questDefinition(_ id: QuestID) -> ContentBundle.Quest? { bundle.quest(id) }
    /// Content may override the ruleset's duration (gym quests run 8 h; owner 2026-10-05).
    var questDuration: TimeInterval { TimeInterval((quest?.durationMinutes ?? ruleset.dailyQuest?.durationMinutes ?? 240) * 60) }
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
        let now = self.now
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
        let now = self.now
        guard let i = questRuns.firstIndex(where: { $0.isDue(at: now) }), let table = ruleset.dailyQuest?.rewardTable,
              let index = QuestResolver.roll(table: table, runID: questRuns[i].id, runsSinceRare: runsSinceRare, pityAfter: ruleset.dailyQuest?.pityRareAfter,
                                             availableTiers: (bundle.quest(questRuns[i].questID)?.lootPools).flatMap { $0.isEmpty ? nil : Set($0.map(\.tier)) }) else { return }
        // The quest's own loot pool decides what the rolled tier hands out, preferring something not yet owned (doc 29).
        let pools = bundle.quest(questRuns[i].questID)?.lootPools ?? []
        let chosen = QuestResolver.pick(tier: table[index].tier, pools: pools, granted: ledger.grantedRewardIDs, runID: questRuns[i].id)
        let event = QuestResolver.makeEvent(for: questRuns[i], rewardIndex: index, rewardID: chosen, userID: userID, familyFallback: goalPreferences.primaryFamily, at: now)
        questRuns[i].resolvedAt = now
        questRuns[i].reward = QuestReference(questID: questRuns[i].questID, rewardIndex: index, rewardID: chosen)
        questRuns[i].activityEventID = event.id
        events.append(event)
        outbox.enqueue(ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: now))
        QuestNotifications.cancel()
        save()
        // The grant lands now; the reveal waits until the player opens the cache (doc 29).
        Task { await drain(showReward: false) }
    }

    /// Resolved runs since the last rare roll, newest first (pity counter, doc 29). Rolls are tiers, so a
    /// pity rare that fell back to a lower item still resets the counter.
    var runsSinceRare: Int {
        let resolved = questRuns.filter(\.isResolved).sorted { ($0.resolvedAt ?? .distantPast) > ($1.resolvedAt ?? .distantPast) }
        var n = 0
        for run in resolved { if rewardTier(for: run) == "rare" { break }; n += 1 }
        return n
    }
    /// A resolved run whose cache has not been opened. Home points at it; the story waits for it.
    var unclaimedQuest: QuestRun? { questRuns.first { $0.isResolved && !$0.isClaimed } }
    /// The item this run brought back (the fact's chosen reward, else the table row's), if any.
    func questReward(for run: QuestRun) -> ContentBundle.Item? {
        guard let ref = run.reward else { return nil }
        guard let id = ref.rewardID ?? ruleset.dailyQuest?.rewardTable[safe: ref.rewardIndex]?.rewardID,
              let reward = bundle.reward(id), let itemID = reward.grants.first?.itemID else { return nil }
        return bundle.item(itemID)
    }
    /// True when the return fact granted something new (false = XP only, everything in the pool was owned).
    func questGrantedSomethingNew(_ run: QuestRun) -> Bool {
        guard let eventID = run.activityEventID, let receipt = outbox.receipt(for: eventID) else { return questReward(for: run) != nil }
        return !receipt.rewardsGranted.isEmpty
    }
    /// Open the cache: show the receipt (XP, level-up) and queue the quest's end scene. Idempotent.
    func claimQuest(_ run: QuestRun) {
        guard let i = questRuns.firstIndex(where: { $0.id == run.id }), questRuns[i].isResolved, !questRuns[i].isClaimed else { return }
        questRuns[i].claimedAt = now
        if let eventID = questRuns[i].activityEventID, let receipt = outbox.receipt(for: eventID) { lastReceipt = receipt }
        // Owner QA 2026-10-06 / doc 33: the end scene plays on the first completion; later completions play the
        // quest's repeat exchanges in order (content), cycling, so a seventh walk still says something.
        let questID = questRuns[i].questID
        let completion = questRuns.filter { $0.questID == questID && $0.isClaimed }.count   // this one included
        let quest = bundle.quest(questID)
        if completion == 1 {
            pendingReturnScene = quest?.onReturnChapter.flatMap { bundle.chapter($0) }
            // Doc 33: rewards tied to a quest's first completion (the rain stops on Protein Row) go through the engine once.
            for reward in bundle.rewards(onCompleting: questID) where !ledger.grantedRewardIDs.contains(reward.id) && !events.contains(where: { $0.story?.rewardID == reward.id }) {
                let now = self.now
                let event = ActivityEvent(userID: userID, activityTypeID: ActivityTypeID("quest.\(questID.rawValue).completed"), familyID: goalPreferences.primaryFamily, startedAt: now, durationSeconds: 0,
                                          source: .story, verification: .selfReported, story: StoryReference(milestoneID: MilestoneID("quest.\(questID.rawValue).completed"), rewardID: reward.id), createdAt: now)
                events.append(event)
                outbox.enqueue(ProgressionSubmission(event: event, contentVersion: bundle.contentVersion, submittedAt: now))
                lastWorldReaction = reward.displayName ?? rewardDisplayName(reward.id)
                Task { await drain(showReward: false) }
            }
        } else if let quest, let beats = quest.repeatExchange(forCompletion: completion) {
            let backdrop = quest.onReturnChapter.flatMap { bundle.chapter($0) }?.backdropID ?? recipe?.backdropID ?? "backdrop.alley_awakening"
            pendingReturnScene = ContentBundle.StoryChapter(id: "repeat.\(questID.rawValue).\(completion)", title: quest.displayName, backdropID: backdrop, then: "return", beats: beats)
        } else {
            pendingReturnScene = nil
        }
        save()
    }

    /// What a reward is called when it lands: the item, backdrop or evolution it grants, else its id.
    func rewardDisplayName(_ id: RewardID) -> String {
        guard let reward = bundle.reward(id), let grant = reward.grants.first else { return id.rawValue }
        if let name = reward.displayName { return name }
        if let i = grant.itemID, let item = bundle.item(i) { return item.displayName }
        if let b = grant.backdropID, let backdrop = bundle.backdrop(b) { return backdrop.displayName }
        if let e = grant.evolutionID, let ev = bundle.evolutions.first(where: { $0.id == e }) { return ev.displayName }
        return id.rawValue
    }
    func rewardTier(for run: QuestRun) -> String? { run.reward.flatMap { ruleset.dailyQuest?.rewardTable[safe: $0.rewardIndex]?.tier } }
    func returnLine(for run: QuestRun) -> String {
        guard let q = bundle.quest(run.questID) ?? quest, let tier = rewardTier(for: run), let lines = q.returnLines[tier], !lines.isEmpty else { return "Back." }
        return lines[Int(run.id.uuidString.hashValueStableApp % UInt64(lines.count))]
    }
    func awayLine(for run: QuestRun) -> String {
        guard let q = bundle.quest(run.questID) ?? quest, !q.awayLines.isEmpty else { return "" }
        return q.awayLines[Int(run.id.uuidString.hashValueStableApp % UInt64(q.awayLines.count))]
    }
    func departLine(for run: QuestRun) -> String {
        guard let q = bundle.quest(run.questID) ?? quest, !q.departLines.isEmpty else { return "" }
        return q.departLines[Int(run.id.uuidString.hashValueStableApp % UInt64(q.departLines.count))]
    }

    // MARK: the room (doc 28: the player's home, a persistent hub that accumulates)

    /// Items the ledger has granted, resolved through the bundle's rewards (never from UI state).
    var ownedItems: [ContentBundle.Item] {
        let granted = ledger.grantedRewardIDs
        var ids: [ItemID] = bundle.items.filter(\.isStarter).map(\.id)   // the starter outfit is everyone's (doc 32)
        for reward in bundle.rewards where granted.contains(reward.id) {
            for g in reward.grants { if let i = g.itemID, !ids.contains(i) { ids.append(i) } }
        }
        return ids.compactMap { bundle.item($0) }
    }
    /// Home scenes the player may stand in: the default plus any granted by a reward.
    var ownedHomeBackdrops: [ContentBundle.Backdrop] {
        let granted = ledger.grantedRewardIDs
        let grantedIDs = Set(bundle.rewards.filter { granted.contains($0.id) }.flatMap { $0.grants.compactMap(\.backdropID) })
        // Default, granted, or opened by the story (world scenes only; the room's backdrop stays in the room).
        return bundle.backdrops.filter { ($0.isHomeScene && ($0.isDefault == true || grantedIDs.contains($0.id))) || (storyProgress.unlockedBackdrops.contains($0.id) && $0.role != "home_room") }
    }
    func setEquipped(_ item: ContentBundle.Item?, slot: AvatarRecipe.Slot) {
        guard var r = recipe, slot.isWearable else { return }
        if let item { r.equipped[slot] = item.id } else { r.equipped.removeValue(forKey: slot) }
        recipe = r
    }
    func setHomeBackdrop(_ backdrop: ContentBundle.Backdrop) {
        guard var r = recipe, ownedHomeBackdrops.contains(where: { $0.id == backdrop.id }) else { return }
        r.backdropID = backdrop.id; recipe = r
    }
    func updateAppearance(_ change: (inout AvatarRecipe) -> Void) {
        guard var r = recipe else { return }
        change(&r); recipe = r
    }

    // MARK: persistence

    private static var archiveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HeroesJourney", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("archive.v2.json")  // v3/v4 are backward-compatible with v2 files
    }

    private func save() {
        let archive = Archive(userID: userID, recipe: recipe, events: events, ledger: ledger, outbox: outbox, workouts: workouts, activeWorkout: activeWorkout, preferredUnit: preferredUnit, healthSync: healthSync, corrections: corrections, importLog: importLog, goalPreferences: goalPreferences, goalPlans: goalPlans, goalCompletions: goalCompletions, goalSeed: goalSeed, questRuns: questRuns, startedOn: startedOn, lastStageDay: lastStageDay, storyProgress: storyProgress, challengeOffers: challengeOffers)
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

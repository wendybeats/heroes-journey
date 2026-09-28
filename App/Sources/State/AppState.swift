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
        static let schemaVersion = 2
        var schemaVersion = Archive.schemaVersion
        var userID: UserID
        var recipe: AvatarRecipe?
        var events: [ActivityEvent]
        var ledger: ProgressionLedger
        var outbox: Outbox
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
    /// The most recent confirmed receipt, for the reward moment (doc 02).
    private(set) var lastReceipt: ProgressionReceipt?

    var snapshot: ProgressSnapshot { ledger.snapshot(ruleset: ruleset) }
    var evolution: ContentBundle.Evolution? { bundle.evolution(forLevel: snapshot.level) }
    var pendingCount: Int { outbox.pending.count }
    var todayEvents: [ActivityEvent] { events.filter { Calendar.current.isDateInToday($0.startedAt) }.sorted { $0.startedAt > $1.startedAt } }

    /// Events in the current calendar week (locale-aware week start). Facts only, no game math.
    var weekEvents: [ActivityEvent] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return events.filter { interval.contains($0.startedAt) }
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

    func dismissReward() { lastReceipt = nil }

    // MARK: persistence

    private static var archiveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HeroesJourney", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("archive.v2.json")
    }

    private func save() {
        let archive = Archive(userID: userID, recipe: recipe, events: events, ledger: ledger, outbox: outbox)
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
            Task { await state.drain() }  // anything left pending from a previous run
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

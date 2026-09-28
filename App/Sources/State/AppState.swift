import Foundation
import Observation
import HeroDomain
import HeroContent

/// Local, single-device state for the first loop (doc 15 milestone). Persisted as one
/// atomic JSON archive; replaced by a synced store before HealthKit import volume.
/// No client-side XP is authoritative: `ledger` is a local *preview* until a server exists.
@MainActor @Observable
final class AppState {
    struct Archive: Codable {
        static let schemaVersion = 1
        var schemaVersion = Archive.schemaVersion
        var userID: UserID
        var recipe: AvatarRecipe?
        var events: [ActivityEvent]
        var ledger: ProgressionLedger
    }

    let bundle: ContentBundle
    let ruleset: ProgressionRuleset
    let tokens: DesignTokens
    private(set) var userID: UserID
    var recipe: AvatarRecipe? { didSet { save() } }
    private(set) var events: [ActivityEvent]
    private(set) var ledger: ProgressionLedger
    /// The most recent proposal, for the reward moment (doc 02).
    private(set) var lastProposal: ProgressionProposal?

    var snapshot: ProgressSnapshot { ledger.snapshot(ruleset: ruleset) }
    var evolution: ContentBundle.Evolution? { bundle.evolution(forLevel: snapshot.level) }
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
        self.userID = archive?.userID ?? UserID()
        self.recipe = archive?.recipe
        self.events = archive?.events ?? []
        self.ledger = archive?.ledger ?? ProgressionLedger()
    }

    // MARK: logging → progression (the core loop)

    /// Records an immutable fact, then evaluates and commits its preview progression once.
    func log(activityTypeID: ActivityTypeID, minutes: Int, startedAt: Date = Date()) {
        guard let type = bundle.activityType(activityTypeID) else { return }
        let event = ActivityEvent(userID: userID, activityTypeID: type.id, familyID: type.familyID, startedAt: startedAt, durationSeconds: minutes * 60, source: .manual, verification: .selfReported)
        events.append(event)
        let context = ledger.context(for: event, ruleset: ruleset, events: events, levelRewards: bundle.levelRewards, calendar: .current)
        let proposal = ProgressionEngine.evaluate(event: event, ruleset: ruleset, context: context)
        ledger.commit(proposal, for: event, at: Date())
        lastProposal = proposal
        if proposal.leveledUp, var r = recipe, let ev = bundle.evolution(forLevel: proposal.levelAfter), ev.id != r.evolutionID {
            r.evolutionID = ev.id
            recipe = r
        }
        save()
    }

    func dismissReward() { lastProposal = nil }

    // MARK: persistence

    private static var archiveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HeroesJourney", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("archive.v1.json")
    }

    private func save() {
        let archive = Archive(userID: userID, recipe: recipe, events: events, ledger: ledger)
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
            return AppState(bundle: bundle, ruleset: ruleset, tokens: tokens, archive: archive)
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

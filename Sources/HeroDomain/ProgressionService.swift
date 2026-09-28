import Foundation

/// The client → authority request. Carries the immutable fact and a client-generated
/// submission ID so a retry after a lost response is recognised (doc 15 §3 "request retry").
public struct ProgressionSubmission: Hashable, Codable, Sendable {
    public let id: UUID
    public let event: ActivityEvent
    public let contentVersion: String
    public let submittedAt: Date

    public init(id: UUID = UUID(), event: ActivityEvent, contentVersion: String, submittedAt: Date) {
        self.id = id; self.event = event; self.contentVersion = contentVersion; self.submittedAt = submittedAt
    }
}

/// The authority → client response. Exactly one per event, however many times it is submitted.
/// `wasAlreadyProcessed` tells the UI to show nothing new (doc 15 §5: preview vs confirmed).
public struct ProgressionReceipt: Hashable, Codable, Sendable {
    public let submissionID: UUID
    public let activityEventID: ActivityEventID
    public let rulesetID: RulesetID
    public let xp: Int
    public let attributes: [AttributeID: Int]
    public let levelBefore: Int
    public let levelAfter: Int
    public let rewardsGranted: [RewardID]
    public let eligibleMinutes: Double
    public let wasAlreadyProcessed: Bool
    public let confirmedAt: Date

    public init(submissionID: UUID, proposal: ProgressionProposal, wasAlreadyProcessed: Bool, confirmedAt: Date) {
        self.submissionID = submissionID
        self.activityEventID = proposal.activityEventID
        self.rulesetID = proposal.rulesetID
        self.xp = proposal.xp
        self.attributes = proposal.attributes
        self.levelBefore = proposal.levelBefore
        self.levelAfter = proposal.levelAfter
        self.rewardsGranted = proposal.rewardsUnlocked
        self.eligibleMinutes = proposal.eligibleMinutes
        self.wasAlreadyProcessed = wasAlreadyProcessed
        self.confirmedAt = confirmedAt
    }

    public var leveledUp: Bool { levelAfter > levelBefore }
}

public enum ProgressionServiceError: Error, Equatable, Sendable {
    case unknownActivityType(ActivityTypeID)
    case wrongOwner
    case unavailable
}

/// The grant boundary (doc 09 "server authority", doc 15 §4). The only way progression is
/// committed. A Supabase-backed implementation replaces `LocalAuthorityProgressionService`
/// without the app changing.
public protocol ProgressionService: Sendable {
    func submit(_ submission: ProgressionSubmission) async throws -> ProgressionReceipt
}

/// Rules the authority must enforce regardless of transport. Pure over a `ProgressionLedger`.
public struct ProgressionAuthority: Sendable {
    public let ruleset: ProgressionRuleset
    public let levelRewards: [Int: [RewardID]]
    public let calendar: Calendar

    public init(ruleset: ProgressionRuleset, levelRewards: [Int: [RewardID]], calendar: Calendar) {
        self.ruleset = ruleset; self.levelRewards = levelRewards; self.calendar = calendar
    }

    /// Evaluate and commit exactly once. A repeat submission for an already processed event returns
    /// the original outcome, reconstructed from the ledger, with `wasAlreadyProcessed == true`.
    public func process(_ submission: ProgressionSubmission, ledger: inout ProgressionLedger, events: [ActivityEvent], now: Date) -> ProgressionReceipt {
        let event = submission.event
        if ledger.hasProcessed(event.id) {
            return ProgressionReceipt(submissionID: submission.id, proposal: ledger.recordedOutcome(for: event, ruleset: ruleset), wasAlreadyProcessed: true, confirmedAt: now)
        }
        let context = ledger.context(for: event, ruleset: ruleset, events: events, levelRewards: levelRewards, calendar: calendar)
        let proposal = ProgressionEngine.evaluate(event: event, ruleset: ruleset, context: context)
        ledger.commit(proposal, for: event, at: now)
        return ProgressionReceipt(submissionID: submission.id, proposal: proposal, wasAlreadyProcessed: false, confirmedAt: now)
    }
}

/// In-process authority for the single-device build. It is the *same code path* a server would
/// run, so the app never fabricates XP client-side; it only ever shows receipts.
public actor LocalAuthorityProgressionService: ProgressionService {
    public private(set) var ledger: ProgressionLedger
    public private(set) var events: [ActivityEvent]
    private let authority: ProgressionAuthority
    private let owner: UserID
    private let clock: @Sendable () -> Date

    public init(authority: ProgressionAuthority, owner: UserID, ledger: ProgressionLedger = ProgressionLedger(), events: [ActivityEvent] = [], clock: @escaping @Sendable () -> Date = { Date() }) {
        self.authority = authority; self.owner = owner; self.ledger = ledger; self.events = events; self.clock = clock
    }

    public func submit(_ submission: ProgressionSubmission) async throws -> ProgressionReceipt {
        guard submission.event.userID == owner else { throw ProgressionServiceError.wrongOwner }
        if !events.contains(where: { $0.id == submission.event.id }) { events.append(submission.event) }
        return authority.process(submission, ledger: &ledger, events: events, now: clock())
    }
}

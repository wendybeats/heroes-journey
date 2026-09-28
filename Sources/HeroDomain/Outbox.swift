import Foundation

/// Durable local queue of submissions with their confirmation state (doc 15 §5). Persisted by the
/// app with the archive; a submission survives restart until a receipt is stored for it.
public struct Outbox: Codable, Sendable, Equatable {
    public enum State: Codable, Sendable, Equatable {
        case pending
        case confirmed(ProgressionReceipt)
    }
    public struct Entry: Codable, Sendable, Equatable {
        public let submission: ProgressionSubmission
        public var state: State
        public var attempts: Int
        public var lastError: String?
    }

    public private(set) var entries: [Entry] = []
    public init() {}

    public var pending: [Entry] { entries.filter { if case .pending = $0.state { return true }; return false } }
    public func receipt(for eventID: ActivityEventID) -> ProgressionReceipt? {
        for e in entries { if case .confirmed(let r) = e.state, r.activityEventID == eventID { return r } }
        return nil
    }

    /// Enqueue once per event; a second enqueue for the same event is ignored so a retry reuses
    /// the original submission ID.
    @discardableResult
    public mutating func enqueue(_ submission: ProgressionSubmission) -> Bool {
        guard !entries.contains(where: { $0.submission.event.id == submission.event.id }) else { return false }
        entries.append(Entry(submission: submission, state: .pending, attempts: 0, lastError: nil))
        return true
    }

    public mutating func markAttempt(_ submissionID: UUID, error: String?) {
        guard let i = entries.firstIndex(where: { $0.submission.id == submissionID }) else { return }
        entries[i].attempts += 1; entries[i].lastError = error
    }

    public mutating func confirm(_ receipt: ProgressionReceipt) {
        guard let i = entries.firstIndex(where: { $0.submission.id == receipt.submissionID }) else { return }
        entries[i].state = .confirmed(receipt); entries[i].lastError = nil
    }
}

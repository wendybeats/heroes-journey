import Foundation
import HeroDomain
import Supabase

// HER-17 increment 1 (owner 2026-10-19): an account is its fact log. Every ActivityEvent and its receipt go to Supabase
// as append-only rows; the archive follows as a profile snapshot for fast restore. Identity is an anonymous Supabase
// user created on first launch and kept in the keychain; Sign in with Apple links to it in increment 2. The app's
// local authority is unchanged: this uploads what it decided, it does not decide anything.

/// Rows as the tables want them. Dates and nested facts encode through the client's own JSON encoder.
struct ActivityEventRow: Encodable, Sendable {
    let id: UUID
    let profileID: UUID
    let startedAt: Date
    let source: String
    let activityTypeID: String
    let familyID: String
    let schemaVersion: Int
    let payload: ActivityEvent
    enum CodingKeys: String, CodingKey { case id, profileID = "profile_id", startedAt = "started_at", source, activityTypeID = "activity_type_id", familyID = "family_id", schemaVersion = "schema_version", payload }
}

struct ReceiptRow: Encodable, Sendable {
    let submissionID: UUID
    let eventID: UUID
    let rulesetID: String
    let xp: Int
    let levelBefore: Int
    let levelAfter: Int
    let payload: ProgressionReceipt
    let confirmedAt: Date
    enum CodingKeys: String, CodingKey { case submissionID = "submission_id", eventID = "event_id", rulesetID = "ruleset_id", xp, levelBefore = "level_before", levelAfter = "level_after", payload, confirmedAt = "confirmed_at" }
}

struct ProfileRow: Encodable, Sendable {
    let id: UUID
    let profileID: UUID
    enum CodingKeys: String, CodingKey { case id, profileID = "profile_id" }
}

struct ProfileStateRow<State: Encodable & Sendable>: Encodable, Sendable {
    let state: State
    let stateVersion: Int
    let stateUpdatedAt: Date
    enum CodingKeys: String, CodingKey { case state, stateVersion = "state_version", stateUpdatedAt = "state_updated_at" }
}

struct ProfileFetchRow<State: Decodable & Sendable>: Decodable, Sendable {
    let state: State?
    let stateVersion: Int
    let rebuildRequired: Bool
    enum CodingKeys: String, CodingKey { case state, stateVersion = "state_version", rebuildRequired = "rebuild_required" }
}

/// A plain Sendable class, not an actor: the Supabase client's responses are not Sendable, so every call stays in a
/// nonisolated context and only Sendable values (ids, facts, the archive) cross into the main actor.
final class AccountSync: @unchecked Sendable {
    /// The project URL and publishable key are public by design (row-level security is the guard); the service and
    /// secret keys never go in the repo.
    static let projectURL = URL(string: "https://fuwscpmwyaksklwvrohm.supabase.co")!
    static let publishableKey = "sb_publishable_CfwLnXtgYVDJoDWABEtrqg_dk25sWQK"

    private let client: SupabaseClient
    private let lock = NSLock()
    private var _authUserID: UUID?
    var authUserID: UUID? {
        lock.lock(); defer { lock.unlock() }
        return _authUserID
    }
    private func setAuthUserID(_ id: UUID) { lock.lock(); _authUserID = id; lock.unlock() }

    init() {
        client = SupabaseClient(supabaseURL: Self.projectURL, supabaseKey: Self.publishableKey)
    }

    /// The keychain session if there is one, else a new anonymous user. Returns the auth user id.
    func signIn() async throws -> UUID {
        if let session = try? await client.auth.session {
            setAuthUserID(session.user.id)
            return session.user.id
        }
        let session = try await client.auth.signInAnonymously()
        setAuthUserID(session.user.id)
        return session.user.id
    }

    /// Bind the local character id to the auth user. Idempotent.
    func bindProfile(_ profileID: UUID) async throws {
        guard let authUserID else { return }
        try await client.from("profiles").upsert(ProfileRow(id: authUserID, profileID: profileID), onConflict: "id", ignoreDuplicates: true).execute()
    }

    /// Append facts and receipts. Duplicates are ignored server-side (the tables are append-only; a retry never updates).
    func upload(events: [ActivityEvent], receipts: [ProgressionReceipt], profileID: UUID) async throws {
        guard !events.isEmpty else { return }
        let rows = events.map { e in
            ActivityEventRow(id: e.id.rawValue, profileID: profileID, startedAt: e.startedAt, source: e.steps != nil ? "steps" : e.source.rawValue,
                             activityTypeID: e.activityTypeID.rawValue, familyID: e.familyID.rawValue, schemaVersion: e.schemaVersion, payload: e)
        }
        try await client.from("activity_events").upsert(rows, onConflict: "id", ignoreDuplicates: true).execute()
        let receiptRows = receipts.map { r in
            ReceiptRow(submissionID: r.submissionID, eventID: r.activityEventID.rawValue, rulesetID: r.rulesetID.rawValue, xp: r.xp,
                       levelBefore: r.levelBefore, levelAfter: r.levelAfter, payload: r, confirmedAt: r.confirmedAt)
        }
        if !receiptRows.isEmpty {
            try await client.from("receipts").upsert(receiptRows, onConflict: "submission_id", ignoreDuplicates: true).execute()
        }
    }

    /// The archive as a profile snapshot, for restore on a fresh install. Never the truth for progression.
    func uploadState<State: Encodable & Sendable>(_ state: State, version: Int) async throws {
        guard let authUserID else { return }
        try await client.from("profiles").update(ProfileStateRow(state: state, stateVersion: version, stateUpdatedAt: Date())).eq("id", value: authUserID.uuidString).execute()
    }

    /// The saved snapshot, if the server has one for this user.
    func fetchState<State: Decodable & Sendable>(_ type: State.Type) async throws -> (state: State, version: Int)? {
        guard let authUserID else { return nil }
        let row: ProfileFetchRow<State> = try await client.from("profiles").select("state, state_version, rebuild_required").eq("id", value: authUserID.uuidString).single().execute().value
        guard let state = row.state else { return nil }
        return (state, row.stateVersion)
    }
}

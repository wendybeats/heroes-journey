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
    private var _isAnonymous = true
    /// Whether the current user is still a guest (no Apple identity linked).
    var isAnonymous: Bool { lock.lock(); defer { lock.unlock() }; return _isAnonymous }
    private func note(_ session: Session) { lock.lock(); _authUserID = session.user.id; _isAnonymous = session.user.isAnonymous; lock.unlock() }

    enum AppleOutcome: Sendable {
        /// The Apple identity now belongs to the user this device already had; nothing moves.
        case linked
        /// The Apple ID already had an account (or linking is off): the device is now signed into that account.
        case switched(from: UUID?, to: UUID)
    }

    init() {
        client = SupabaseClient(supabaseURL: Self.projectURL, supabaseKey: Self.publishableKey)
    }

    /// The keychain session if there is one, else a new anonymous user. Returns the auth user id.
    func signIn() async throws -> UUID {
        if let session = try? await client.auth.session {
            note(session)
            return session.user.id
        }
        let session = try await client.auth.signInAnonymously()
        note(session)
        return session.user.id
    }

    /// Sign in with Apple. First try to link the identity to the current (guest) user, which keeps the user id and
    /// every row; GoTrue links when the id-token grant carries the current session and manual linking is on. If that
    /// is refused (the Apple ID already has an account, or linking is off), sign into the Apple account instead.
    func signInWithApple(idToken: String, nonce: String) async throws -> AppleOutcome {
        let before = authUserID
        if let current = try? await client.auth.session, current.user.isAnonymous, let linked = try? await linkIdentity(session: current, idToken: idToken, nonce: nonce) {
            note(linked)
            if linked.user.id == before { return .linked }
            return .switched(from: before, to: linked.user.id)
        }
        let session = try await client.auth.signInWithIdToken(credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce))
        note(session)
        return session.user.id == before ? .linked : .switched(from: before, to: session.user.id)
    }

    private struct TokenResponse: Decodable { let accessToken: String; let refreshToken: String
        enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token" } }

    /// The id-token grant with the guest session attached: GoTrue treats that as "link to this user".
    private func linkIdentity(session current: Session, idToken: String, nonce: String) async throws -> Session {
        var request = URLRequest(url: Self.projectURL.appendingPathComponent("auth/v1/token").appending(queryItems: [URLQueryItem(name: "grant_type", value: "id_token")]))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(current.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["provider": "apple", "id_token": idToken, "nonce": nonce])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.userAuthenticationRequired) }
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        return try await client.auth.setSession(accessToken: token.accessToken, refreshToken: token.refreshToken)
    }

    /// Drop the keychain session. The anonymous user it held is unreachable afterwards unless an Apple identity was linked.
    func signOut() async {
        try? await client.auth.signOut()
        forgetIdentity()
    }
    private func forgetIdentity() { lock.lock(); _authUserID = nil; _isAnonymous = true; lock.unlock() }

    /// HER-14: erase every row and the auth user through `delete_my_account()` (security definer; the append-only
    /// triggers allow deletes only inside it). The session dies with the user; the local sign-out just forgets it.
    func deleteAccount() async throws {
        try await client.rpc("delete_my_account").execute()
        await signOut()
    }

    /// Bind the local character id to the auth user. Idempotent: the row keeps the character it was first bound to;
    /// `state.userID` is the character the account currently plays.
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
        // Facts are keyed (user_id, id) since increment 2; user_id defaults to auth.uid() server-side.
        try await client.from("activity_events").upsert(rows, onConflict: "user_id,id", ignoreDuplicates: true).execute()
        let receiptRows = receipts.map { r in
            ReceiptRow(submissionID: r.submissionID, eventID: r.activityEventID.rawValue, rulesetID: r.rulesetID.rawValue, xp: r.xp,
                       levelBefore: r.levelBefore, levelAfter: r.levelAfter, payload: r, confirmedAt: r.confirmedAt)
        }
        if !receiptRows.isEmpty {
            try await client.from("receipts").upsert(receiptRows, onConflict: "user_id,submission_id", ignoreDuplicates: true).execute()
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

import SwiftUI
import AuthenticationServices
import CryptoKit

// HER-17 increment 2: native Sign in with Apple. The button is Apple's; the nonce is ours (raw to Supabase, hashed to
// Apple); the identity token goes to Supabase, which links it to the guest user or signs the player into the
// account the Apple ID already has. The app never sees an email or a name it keeps.

struct AppleSignInButton: View {
    @Environment(AppState.self) private var state
    @State private var rawNonce = AppleSignInButton.randomNonce()
    @State private var error: String?
    /// HER-14: both this phone and the account have progress; the player picks which character this phone plays.
    @State private var conflict: AppState.SignInConflict?
    var label: SignInWithAppleButton.Label = .signIn

    var body: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.xs) {
            SignInWithAppleButton(label) { request in
                rawNonce = Self.randomNonce()
                request.requestedScopes = []
                request.nonce = Self.sha256(rawNonce)
            } onCompletion: { result in
                switch result {
                case let .success(authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
                        error = "Apple returned no identity token."; return
                    }
                    let nonce = rawNonce
                    Task {
                        switch await state.signInWithApple(idToken: token, nonce: nonce) {
                        case .done: error = nil
                        case let .conflict(c): conflict = c
                        case let .failed(message): error = message
                        }
                    }
                case let .failure(err):
                    // The player cancelled, or the capability is missing on this build; both are silent except in debug.
                    error = (err as? ASAuthorizationError)?.code == .canceled ? nil : err.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
            if let error { Text(error).font(HeroFont.caption).foregroundStyle(NeoTokyo.Hierarchy.destructive) }
        }
        .confirmationDialog("This Apple ID already has a character", isPresented: Binding(get: { conflict != nil }, set: { if !$0 { conflict = nil } }),
                            titleVisibility: .visible, presenting: conflict) { c in
            Button("Use \(c.server.name) from the account") { Task { await state.resolveSignInConflict(useServer: true) } }
            Button("Keep \(c.local.name) on this phone") { Task { await state.resolveSignInConflict(useServer: false) } }
            Button("Cancel", role: .cancel) { Task { await state.resolveSignInConflict(useServer: false) } }
        } message: { c in
            Text("\(Self.describe(c.server)) is on the account. \(Self.describe(c.local)) is on this phone. Both stay saved on the server; choose which one this phone plays. Cancel keeps this phone's.")
        }
    }

    private static func describe(_ s: AppState.CharacterSummary) -> String {
        let when = s.lastActive.map { ", last active " + $0.formatted(date: .abbreviated, time: .omitted) } ?? ""
        return "\(s.name), level \(s.level), \(s.facts) activities\(when)"
    }

    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

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
                    Task { error = await state.signInWithApple(idToken: token, nonce: nonce) }
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

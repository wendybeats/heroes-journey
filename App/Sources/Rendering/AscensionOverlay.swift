import SwiftUI
import CoreGraphics
import HeroDomain

/// Still image of the character in its resting pose for a given outfit (no animation), used
/// where two copies must match exactly (a gold mask over the sprite).
@MainActor
enum StillCharacter {
    static func image(recipe: AvatarRecipe, outfit: String?, ascension: Int = 0) -> CGImage? {
        // Doc 32: one canonical body; `outfit` is ignored (legacy call sites).
        CharacterKitStore.shared.image(recipe: recipe, pose: .rest, ascension: ascension)
    }
}

/// Evolution celebration (owner, 2026-09-30): full-screen takeover. The character rises to centre
/// and floods flat gold (0–0.9 s), an oversized flash bursts (0.9–1.6 s), the gold drains to reveal
/// the new outfit (1.3–2.0 s), "Ascension is here" holds (1.8–3.2 s), then the character settles
/// back into its place in the scene (3.2–3.9 s).
struct AscensionOverlay: View {
    let start: Date
    let recipe: AvatarRecipe
    /// Doc 32: tiers, not outfits. The body stays; at the reveal the eyes change and the field appears.
    let fromTier: Int
    let toTier: Int
    let evolutionName: String
    /// Where the scene draws the character, so the settle lands exactly there.
    let sceneFrame: CGRect
    static let revealAt: TimeInterval = 1.3
    static let settleAt: TimeInterval = 3.2
    static let duration: TimeInterval = 3.9
    @State private var settled = false

    private static func easeOut(_ u: Double) -> Double { 1 - pow(1 - u, 3) }
    private static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42)
            let big: CGFloat = 3, small: CGFloat = sceneFrame.width / 64
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                let t = timeline.date.timeIntervalSince(start)
                let scrim = t < 0.4 ? Self.clamp(t / 0.4) * 0.88 : (t >= Self.settleAt ? 0.88 * (1 - Self.clamp((t - Self.settleAt) / 0.7)) : 0.88)
                let gold = t < 0.9 ? Self.clamp((t - 0.2) / 0.7) : (t < Self.revealAt ? 1 : 1 - Self.clamp((t - Self.revealAt) / 0.7))
                let tier = t < Self.revealAt ? fromTier : toTier
                let textOpacity = t < 1.8 ? 0 : (t < Self.settleAt ? Self.clamp((t - 1.8) / 0.4) : 1 - Self.clamp((t - Self.settleAt) / 0.4))
                ZStack {
                    NeoTokyo.Surface.scrim.opacity(scrim).ignoresSafeArea()
                    // over-exaggerated flash: pulse, tuck, snap to well past the edges, with a white core
                    Canvas { context, size in
                        guard t >= 0.9 && t < 1.7 else { return }
                        let u = (t - 0.9) / 0.8
                        let edge = hypot(size.width, size.height) * 1.2
                        let radius: Double, alpha: Double
                        if u < 0.25 { radius = 60 + Self.easeOut(u / 0.25) * 140; alpha = 0.9 }
                        else if u < 0.4 { let v = (u - 0.25) / 0.15; radius = 200 - v * v * 40; alpha = 0.9 + 0.1 * v }
                        else { let v = (u - 0.4) / 0.6; let e = 1 - pow(2, -10 * v); radius = 160 + e * (edge - 160); alpha = 1 - v }
                        let gradient = Gradient(stops: [
                            .init(color: NeoTokyo.Text.primary.opacity(alpha), location: 0),
                            .init(color: NeoTokyo.Hierarchy.primary.opacity(alpha * 0.85), location: 0.25),
                            .init(color: NeoTokyo.Hierarchy.primary.opacity(alpha * 0.35), location: 0.7),
                            .init(color: NeoTokyo.Hierarchy.primary.opacity(0), location: 1),
                        ])
                        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))
                    }
                    .ignoresSafeArea()
                    VStack(spacing: NeoTokyo.Spacing.sm) {
                        Eyebrow(text: "Ascension is here")
                        Text(evolutionName).font(HeroFont.statLG).foregroundStyle(NeoTokyo.Hierarchy.primary)
                    }
                    .opacity(textOpacity)
                    .position(x: geo.size.width / 2, y: center.y + 64 * big / 2 + 56)
                    if let cg = StillCharacter.image(recipe: recipe, outfit: nil, ascension: tier) {
                        let sprite = Image(decorative: cg, scale: 1).interpolation(.none).resizable()
                        ZStack {
                            sprite
                            NeoTokyo.Hierarchy.primary.mask { sprite }.opacity(gold)
                        }
                        .frame(width: 64 * (settled ? small : big), height: 128 * (settled ? small : big))
                        .shadow(color: NeoTokyo.Hierarchy.primary.opacity(gold * 0.9), radius: 24)
                        .position(settled ? CGPoint(x: sceneFrame.midX, y: sceneFrame.midY) : center)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .task {
            try? await Task.sleep(for: .milliseconds(Int(Self.settleAt * 1000)))
            withAnimation(.easeInOut(duration: 0.6)) { settled = true }
        }
    }
}

/// Level progress bar with an explicit wrap: fill to the end, snap to zero, fill to the new value.
struct LevelBar: View {
    let fill: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(NeoTokyo.Surface.overlay)
                Capsule().fill(NeoTokyo.Hierarchy.primary).frame(width: max(6, geo.size.width * CGFloat(min(1, max(0, fill)))))
            }
        }
        .frame(height: 6)
    }
}

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

/// Evolution celebration, long form (owner play-through 2026-10-17, doc 40 #12). The character rises slowly to centre while the
/// glow builds (0–2.0 s); gold lightning strikes around them and the eyes light (2.0–3.4 s); the figure is lost in light
/// (3.4–4.6 s); one final flash and the reveal (4.6–5.2 s); then the ascended character holds with its name, flares
/// playing, until the player taps Continue; the settle back into the scene follows the tap (0.6 s). Reduce Motion goes
/// straight to the hold. Doc 32/38 own the look; this is the timing and the hold.
struct AscensionOverlay: View {
    let start: Date
    let recipe: AvatarRecipe
    /// Doc 32: tiers, not outfits. The body stays; at the reveal the eyes change and the field appears.
    let fromTier: Int
    let toTier: Int
    let evolutionName: String
    /// Where the scene draws the character, so the settle lands exactly there.
    let sceneFrame: CGRect
    /// The player's tap at the hold; the caller clears the overlay after the settle.
    var onContinue: () -> Void = {}
    static let riseEnd: TimeInterval = 2.0
    static let lightningEnd: TimeInterval = 3.4
    static let whiteAt: TimeInterval = 3.4
    static let revealAt: TimeInterval = 4.6
    static let holdAt: TimeInterval = 5.2
    static let settleDuration: TimeInterval = 0.6
    static let strikes: [TimeInterval] = [2.05, 2.45, 2.8, 3.1]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    @State private var continued = false

    private static func easeOut(_ u: Double) -> Double { 1 - pow(1 - u, 3) }
    private static func easeInOut(_ u: Double) -> Double { u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2 }
    private static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42)
            let big: CGFloat = 3, small: CGFloat = sceneFrame.width / 64
            let origin = CGPoint(x: sceneFrame.midX, y: sceneFrame.midY)
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: continued)) { timeline in
                let raw = timeline.date.timeIntervalSince(start)
                let t = reduceMotion ? Self.holdAt : raw
                let rise = Self.easeInOut(Self.clamp(t / Self.riseEnd))
                let scrim = 0.9 * Self.clamp(t / 0.6)
                // glow: builds through the rise, stays through the lightning, floods to white, drains after the reveal
                let glow = t < Self.whiteAt ? Self.clamp(t / Self.riseEnd) * 0.8 : (t < Self.revealAt ? 1 : 1 - Self.clamp((t - Self.revealAt) / 0.6))
                let white = t < Self.whiteAt ? 0 : (t < Self.revealAt ? Self.clamp((t - Self.whiteAt) / 0.9) : 1 - Self.clamp((t - Self.revealAt) / 0.5))
                let tier = t < Self.revealAt ? fromTier : toTier
                let eyes = t >= 2.3 && t < Self.whiteAt + 0.3 ? Self.clamp((t - 2.3) / 0.4) : 0
                let textOpacity = Self.clamp((t - Self.holdAt + 0.2) / 0.5)
                let strike = Self.strikes.first { t >= $0 && t < $0 + 0.16 }
                let strikeFlash = strike.map { 0.35 * (1 - (t - $0) / 0.16) } ?? 0
                let figureCenter = CGPoint(x: origin.x + (center.x - origin.x) * rise, y: origin.y + (center.y - origin.y) * rise)
                let scale = small + (big - small) * rise
                ZStack {
                    NeoTokyo.Surface.scrim.opacity(scrim).ignoresSafeArea()
                    // the final flash, oversized, at the reveal
                    Canvas { context, size in
                        guard t >= Self.revealAt - 0.1 && t < Self.revealAt + 0.8 else { return }
                        let u = (t - Self.revealAt + 0.1) / 0.9
                        let edge = hypot(size.width, size.height) * 1.2
                        let radius: Double, alpha: Double
                        if u < 0.2 { radius = 80 + Self.easeOut(u / 0.2) * 160; alpha = 1 }
                        else { let v = (u - 0.2) / 0.8; let e = 1 - pow(2, -10 * v); radius = 240 + e * (edge - 240); alpha = 1 - v }
                        let gradient = Gradient(stops: [
                            .init(color: NeoTokyo.Text.primary.opacity(alpha), location: 0),
                            .init(color: NeoTokyo.Hierarchy.primary.opacity(alpha * 0.85), location: 0.25),
                            .init(color: NeoTokyo.Hierarchy.primary.opacity(alpha * 0.35), location: 0.7),
                            .init(color: NeoTokyo.Hierarchy.primary.opacity(0), location: 1),
                        ])
                        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))
                    }
                    .ignoresSafeArea()
                    // lightning: gold bolts from above, each alive for a few frames, a white core, a flash on the room
                    if let strike, !reduceMotion {
                        Canvas { context, size in
                            let n = Int((strike * 10).rounded()) % 4
                            let fromX = center.x + CGFloat([-140, 120, -60, 90][n]), toX = center.x + CGFloat([-18, 22, -8, 12][n])
                            let toY = center.y - 60 + CGFloat(n * 25)
                            var path = Path(); path.move(to: CGPoint(x: fromX, y: -10))
                            let segments = 9
                            for i in 1...segments {
                                let u = Double(i) / Double(segments)
                                let jag = sin(Double(i) * 2.7 + strike * 13) * 28 * (1 - u)
                                path.addLine(to: CGPoint(x: fromX + (toX - fromX) * u + jag, y: -10 + (toY + 10) * u))
                            }
                            let fade = 1 - (t - strike) / 0.16
                            // Owner QA 2026-10-18: the strikes take the tier's colour (II is purple) so each Ascension reads as its own.
                            context.stroke(path, with: .color(NeoTokyo.Ascension.color(forTier: toTier).opacity(0.9 * fade)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                            context.stroke(path, with: .color(NeoTokyo.Text.primary.opacity(fade)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    }
                    // the figure: the still on the way up, the live ascended character at the hold (its flares play)
                    if t >= Self.holdAt {
                        CharacterView(recipe: recipe, scale: big, ascension: toTier)
                            .frame(width: 64 * big, height: 128 * big)
                            .scaleEffect(settled ? small / big : 1)
                            .shadow(color: NeoTokyo.Hierarchy.primary.opacity(settled ? 0 : 0.5), radius: 28)
                            .position(settled ? origin : center)
                    } else if let cg = StillCharacter.image(recipe: recipe, outfit: nil, ascension: tier) {
                        let sprite = Image(decorative: cg, scale: 1).interpolation(.none).resizable()
                        ZStack {
                            sprite
                            NeoTokyo.Hierarchy.primary.mask { sprite }.opacity(glow * 0.9)
                            NeoTokyo.Text.primary.mask { sprite }.opacity(white)
                            // the eyes light before the room does
                            Capsule().fill(NeoTokyo.Ascension.color(forTier: toTier)).frame(width: 4 * scale, height: 1.5 * scale)
                                .shadow(color: NeoTokyo.Ascension.color(forTier: toTier), radius: 6).shadow(color: NeoTokyo.Text.primary, radius: 3)
                                .offset(x: 2.5 * scale, y: -39 * scale)
                                .opacity(eyes)
                        }
                        .frame(width: 64 * scale, height: 128 * scale)
                        .shadow(color: NeoTokyo.Hierarchy.primary.opacity(glow), radius: 12 + 36 * glow)
                        .position(figureCenter)
                    }
                    // the room flashes with each strike, then floods to white
                    NeoTokyo.Text.primary.opacity(max(strikeFlash, white * 0.95)).ignoresSafeArea().allowsHitTesting(false)
                    if t >= Self.holdAt, !settled {
                        VStack(spacing: NeoTokyo.Spacing.md) {
                            VStack(spacing: NeoTokyo.Spacing.sm) {
                                Eyebrow(text: "Ascension is here")
                                Text(evolutionName).font(HeroFont.statLG).foregroundStyle(NeoTokyo.Hierarchy.primary)
                            }
                            Button("Continue") {
                                continued = true
                                withAnimation(.easeInOut(duration: Self.settleDuration)) { settled = true }
                                Task { @MainActor in try? await Task.sleep(for: .milliseconds(Int(Self.settleDuration * 1000) + 50)); onContinue() }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: 220)
                        }
                        .opacity(textOpacity)
                        .position(x: geo.size.width / 2, y: center.y + 128 * big / 2 + 70)   // under the feet, not across the body (owner QA 2026-10-12)
                    }
                }
            }
        }
        .ignoresSafeArea()
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

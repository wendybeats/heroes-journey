import SwiftUI
import CoreGraphics
import HeroDomain
import HeroContent

// Doc 38: Ascension is rendered around the composite character, never into it. One renderer, every tier by a
// content profile (`ascension_profiles`). Layers behind the body: the echo (the shadow that stops obeying) and the
// broken arc. Layers in front: edge flares (light catching a disconnected run of the edge, one pixel outside it),
// artifacts (a pixel of the body detaching and vanishing) and sparse fragments. Effects are asymmetric and
// intermittent by construction: each has its own timer. The composite's own pixels are untouched.

/// Per-character effect state, stepped by the timeline; a reference so the Canvas closure can advance it. Not
/// actor-isolated on purpose: the Canvas renderer closure is not, and the view only ever uses it from one place.
final class AscensionDriver {
    struct Flare { let cx: Int, cy: Int, t0: Double, life: Double, radius: Double }
    struct Artifact { let x: Int, y: Int, ox: Int, oy: Int, color: Color, t0: Double, life: Double, dist: Double }
    struct Fragment { let x: Double, y: Double, vx: Double, vy: Double, w: Int, h: Int, white: Bool, t0: Double, life: Double }
    var flares: [Flare] = [], artifacts: [Artifact] = [], fragments: [Fragment] = []
    var nextFlare = 0.0, nextArtifact = 0.0, nextFragment = 0.0, nextEchoShift = 0.0, echoShiftUntil = 0.0
    var echoShift = (0, 0)
    private var rng = SystemRandomNumberGenerator()
    private func rnd(_ a: Double, _ b: Double) -> Double { Double.random(in: a...b, using: &rng) }

    func step(now: Double, profile: ContentBundle.AscensionProfile, edges: [CharacterKitStore.EdgePixel], reduceMotion: Bool) {
        guard !edges.isEmpty else { return }
        if reduceMotion {
            // Static: two fixed flares, nothing that moves (doc 38 §24 keeps eyes, static edge light and the shadow state).
            if flares.isEmpty { for i in 0..<min(2, profile.flares) { let e = edges[(i * 37) % edges.count]; flares.append(Flare(cx: e.x, cy: e.y, t0: now, life: .infinity, radius: profile.flareRadius)) } }
            artifacts.removeAll(); fragments.removeAll(); echoShift = (0, 0)
            return
        }
        if now >= nextFlare, flares.count < profile.flares, let c = edges.randomElement(using: &rng) {
            flares.append(Flare(cx: c.x, cy: c.y, t0: now, life: rnd(0.5, 1.1), radius: profile.flareRadius + rnd(-1, 3)))
            nextFlare = now + rnd(profile.flareEveryMs.lowerBound, profile.flareEveryMs.upperBound) / 1000
        }
        flares.removeAll { now - $0.t0 >= $0.life }
        if now >= nextArtifact, let e = edges.randomElement(using: &rng) {
            artifacts.append(Artifact(x: e.x, y: e.y, ox: e.ox == 0 ? 1 : e.ox, oy: e.oy, color: e.color, t0: now, life: rnd(0.26, 0.42), dist: rnd(2, 4)))
            nextArtifact = now + rnd(profile.artifactEveryMs.lowerBound, profile.artifactEveryMs.upperBound) / 1000
        }
        artifacts.removeAll { now - $0.t0 >= $0.life }
        if profile.fragmentMax > 0, now >= nextFragment, fragments.count < profile.fragmentMax {
            // shoulders, hair and hands: the top of the body and the outer edges of the arms
            let pool = edges.filter { $0.y < 60 || (abs($0.ox) == 1 && $0.y > 40 && $0.y < 80) }
            if let e = (pool.isEmpty ? edges : pool).randomElement(using: &rng) {
                fragments.append(Fragment(x: Double(e.x) + Double(e.ox) * rnd(2, 6), y: Double(e.y) + Double(e.oy) * rnd(1, 4) - rnd(0, 3), vx: Double(e.ox) * rnd(0.5, 2), vy: -rnd(1, 4),
                                          w: rnd(0, 1) < 0.7 ? 1 : 2, h: rnd(0, 1) < 0.85 ? 1 : 3, white: rnd(0, 1) < 0.35, t0: now, life: rnd(0.6, 1.3)))
            }
            nextFragment = now + rnd(0.25, 0.7)
        }
        fragments.removeAll { now - $0.t0 >= $0.life }
        if profile.echoAlpha > 0, now >= nextEchoShift {
            echoShift = (Int(rnd(-2, 2).rounded()), Int(rnd(-1, 1).rounded())); echoShiftUntil = now + rnd(0.2, 0.42); nextEchoShift = now + rnd(2.5, 6)
        }
        if echoShiftUntil > 0, now > echoShiftUntil { echoShift = (0, 0); echoShiftUntil = 0 }
    }
}

/// The composite character with its Ascension layers, in the character's own 64×128 frame at `scale`. Drop-in for
/// `LayeredCharacterView` wherever a tier applies. `lag` is the host's lagged position (the echo follows late when
/// the body moves); zero when the character stands still.
struct AscendedCharacterView: View {
    let recipe: AvatarRecipe
    var scale: CGFloat = 2
    let tier: Int
    let profile: ContentBundle.AscensionProfile
    var lag: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var driver = AscensionDriver()

    private var store: CharacterKitStore { CharacterKitStore.shared }
    private var color: Color { NeoTokyo.Ascension.color(forTier: tier) }
    private var size: CGSize { CGSize(width: CGFloat(CharacterKit.width) * scale, height: CGFloat(CharacterKit.height) * scale) }

    var body: some View {
        ZStack {
            layer(behind: true)
            LayeredCharacterView(recipe: recipe, scale: scale, ascension: tier)
            layer(behind: false)
        }
        .frame(width: size.width, height: size.height)
    }

    /// The kit's ground pivot row (assets/sprites/README canvas contract: feet on row 122 of 128).
    private static let pivotY: CGFloat = 122

    private func layer(behind: Bool) -> some View {
        // Everything the main actor owns is read here, once per layout, and captured by value into the renderer.
        let edges = store.edges(recipe: recipe), pupils = store.pupils(recipe: recipe)
        let echoImage = profile.echoAlpha > 0 ? store.image(recipe: recipe, pose: .rest, ascension: 0) : nil
        let driver = self.driver, profile = self.profile, color = self.color, size = self.size, scale = self.scale, tier = self.tier, lag = self.lag, reduceMotion = self.reduceMotion
        return TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { timeline in
            Canvas(rendersAsynchronously: false) { ctx, _ in
                let now = timeline.date.timeIntervalSinceReferenceDate
                if behind { driver.step(now: now, profile: profile, edges: edges, reduceMotion: reduceMotion) }
                let s = scale
                if behind {
                    // one broken arc under the feet (II), a dashed partial ellipse, slowly turning
                    if profile.arcAlpha > 0 {
                        let cx = size.width / 2, cy = Self.pivotY * s - 1
                        let base = reduceMotion ? 0.3 : now * 0.2 * 2 * .pi + 0.3
                        var p = Path(); p.addArc(center: .zero, radius: 17 * s, startAngle: .radians(base), endAngle: .radians(base + 1.7), clockwise: false)
                        p = p.applying(CGAffineTransform(translationX: cx, y: cy).scaledBy(x: 1, y: 0.3))
                        ctx.stroke(p, with: .color(color.opacity(profile.arcAlpha)), style: StrokeStyle(lineWidth: max(1, s / 2), dash: [3 * s, 2 * s]))
                    }
                    // the echo: the composite tinted dark, offset, lagging and sometimes shifting on its own
                    if profile.echoAlpha > 0, let cg = echoImage {
                        let dx = CGFloat(profile.echoOffset.x + driver.echoShift.0) * s + lag.width, dy = CGFloat(profile.echoOffset.y + driver.echoShift.1) * s + lag.height
                        let rect = CGRect(x: dx, y: dy, width: size.width, height: size.height)
                        let shifting = driver.echoShift.0 != 0 || driver.echoShift.1 != 0
                        ctx.opacity = profile.echoAlpha + (shifting ? 0.15 : 0)
                        ctx.drawLayer { l in
                            l.draw(Image(decorative: cg, scale: 1).interpolation(.none), in: rect)
                            l.blendMode = .sourceAtop
                            l.fill(Path(rect), with: .color(NeoTokyo.Surface.scrim))
                            l.fill(Path(rect), with: .color(color.opacity(0.45)))
                        }
                        ctx.opacity = 1
                    }
                } else {
                    // flares: the tier colour on edge pixels within a small radius of a point, fading in and out
                    for f in driver.flares {
                        let t = f.life.isFinite ? (now - f.t0) / f.life : 0.3
                        let a = (t < 0.3 ? t / 0.3 : 1 - (t - 0.3) / 0.7) * profile.flareAlpha
                        for e in edges {
                            let d = hypot(Double(e.x - f.cx), Double(e.y - f.cy)); if d > f.radius { continue }
                            let rect = CGRect(x: CGFloat(e.x + e.ox) * s, y: CGFloat(e.y + e.oy) * s, width: s, height: s)
                            ctx.fill(Path(rect), with: .color(color.opacity(a * (1 - d / f.radius * 0.6))))
                            if tier >= 2, d < f.radius * 0.5 { ctx.fill(Path(rect), with: .color(Color.white.opacity(a * 0.4))) }
                        }
                    }
                    for art in driver.artifacts {
                        let t = (now - art.t0) / art.life
                        let rect = CGRect(x: (CGFloat(art.x) + CGFloat(art.ox) * art.dist * t).rounded() * s, y: (CGFloat(art.y) + CGFloat(art.oy) * art.dist * t).rounded() * s, width: s, height: s)
                        ctx.fill(Path(rect), with: .color(art.color.opacity(1 - t)))
                    }
                    for fr in driver.fragments {
                        let t = (now - fr.t0) / fr.life
                        let a = t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75
                        let rect = CGRect(x: (fr.x + fr.vx * t).rounded() * s, y: (fr.y + fr.vy * t).rounded() * s, width: CGFloat(fr.w) * s, height: CGFloat(fr.h) * s)
                        ctx.fill(Path(rect), with: .color((fr.white ? Color.white : color).opacity(a)))
                    }
                    // eye bloom: a soft square of the tier colour behind the pupils (the pupils themselves are painted by the kit)
                    if profile.eyeBloom > 0 {
                        for (x, y) in pupils {
                            let rect = CGRect(x: CGFloat(x - 2) * s, y: CGFloat(y - 1) * s, width: 5 * s, height: 3 * s)
                            ctx.fill(Path(rect), with: .color(color.opacity(profile.eyeBloom * 0.35)))
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

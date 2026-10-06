import SwiftUI

/// Pixel-art star effects. Stars are 4-point pluses drawn on a 3 pt grid so they sit
/// naturally next to the sprite. Prototype: the "Level Badge Motion" artifact (2026-09-29).
enum PixelStar {
    /// Draw one star at `center` with `size` arms (in cells).
    static func draw(in context: inout GraphicsContext, center: CGPoint, size: Int, cell: CGFloat, color: Color, opacity: Double) {
        let shading = GraphicsContext.Shading.color(color.opacity(opacity))
        let cx = (center.x / cell).rounded() * cell, cy = (center.y / cell).rounded() * cell
        for i in -size...size {
            context.fill(Path(CGRect(x: cx + CGFloat(i) * cell, y: cy, width: cell, height: cell)), with: shading)
            context.fill(Path(CGRect(x: cx, y: cy + CGFloat(i) * cell, width: cell, height: cell)), with: shading)
        }
        if size >= 2 {
            for (dx, dy) in [(1, 1), (-1, 1), (1, -1), (-1, -1)] {
                context.fill(Path(CGRect(x: cx + CGFloat(dx) * cell, y: cy + CGFloat(dy) * cell, width: cell, height: cell)), with: shading)
            }
        }
    }
}

/// Calm twinkle around the level numeral: three stars on a fixed orbit centred on the numeral, each on its own phase.
struct PixelStars: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// (dx, dy, phase) relative to the numeral's centre.
    private static let orbit: [(CGFloat, CGFloat, Double)] = [(-26, -22, 0), (28, -26, 2.1), (24, 16, 4.2)]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let origin = CGPoint(x: size.width / 2, y: size.height / 2)
                for (i, (dx, dy, phase)) in Self.orbit.enumerated() {
                    let tw = max(0, sin(t * 1.4 + phase))
                    let opacity = reduceMotion ? 0.5 : 0.2 + 0.8 * tw * tw
                    let starSize = reduceMotion ? 1 : 1 + Int((tw * 1.3).rounded())
                    PixelStar.draw(in: &context, center: CGPoint(x: origin.x + dx, y: origin.y + dy), size: starSize, cell: 3,
                                   color: i == 1 ? NeoTokyo.Text.primary : NeoTokyo.Hierarchy.primary, opacity: opacity)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Level readout: white numeral, pixel stars around it. `flash` tints the numeral gold and
/// the level rolls with a numeric transition when it changes.
struct LevelBadge: View {
    let level: Int
    let subtitle: String
    var flash: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Eyebrow(text: "Level")
            Text(level, format: .number)
                .font(HeroFont.statXL)
                .foregroundStyle(flash ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.primary)
                .contentTransition(.numericText(value: Double(level)))
                .shadow(color: NeoTokyo.Hierarchy.primary.opacity(flash ? 0.8 : 0), radius: 14)
                .overlay { PixelStars().frame(width: 120, height: 110) }  // centred on the numeral
            Text(subtitle).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
        }
    }
}

/// Anchors reported by Home so the level-up overlay can originate from the right places.
struct SceneAnchorsKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Fullscreen level-up, Fire Emblem style: the aura pulses out from the character (0–0.25 s),
/// tucks in for a beat (0.25–0.4 s), then snaps to the screen edges and fades (0.4–0.85 s);
/// 0.7–1.6 s pixel-star burst from the level numeral. Home animates the counter at 1.1 s.
struct LevelUpOverlay: View {
    let start: Date
    let characterCenter: CGPoint
    let badgeCenter: CGPoint
    static let counterDelay: TimeInterval = 1.1

    struct Particle { let angle: Double; let speed: Double; let size: Int; let gold: Bool }
    private static let burst: [Particle] = {
        var out: [Particle] = []
        for i in 0..<22 {
            let base: Double = Double(i) / 22.0 * Double.pi * 2.0
            let jitter: Double = Double(i % 2) * 0.15
            let speed: Double = Double(60 + (i * 37) % 50)
            out.append(Particle(angle: base + jitter, speed: speed, size: 1 + i % 3, gold: i % 4 != 0))
        }
        return out
    }()
    private static func easeOut(_ u: Double) -> Double { 1 - pow(1 - u, 3) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                if t < 0.85 {
                    let edge: Double = hypot(size.width, size.height) * 0.6
                    var radius: Double = 40
                    var alpha: Double = 0.35
                    if t < 0.25 {
                        let u: Double = t / 0.25
                        radius = 40 + Self.easeOut(u) * 70
                    } else if t < 0.4 {
                        let u: Double = (t - 0.25) / 0.15
                        radius = 110 - u * u * 20
                        alpha = 0.35 + 0.15 * u
                    } else {
                        let u: Double = (t - 0.4) / 0.45
                        let e: Double = 1 - pow(2, -10 * u)
                        radius = 90 + e * (edge - 90)
                        alpha = 0.5 * (1 - u)
                    }
                    let gradient = Gradient(stops: [
                        .init(color: NeoTokyo.Hierarchy.primary.opacity(alpha), location: 0),
                        .init(color: NeoTokyo.Hierarchy.primary.opacity(alpha * 0.5), location: 0.7),
                        .init(color: NeoTokyo.Hierarchy.primary.opacity(0), location: 1),
                    ])
                    context.fill(Path(CGRect(origin: .zero, size: size)),
                                 with: .radialGradient(gradient, center: characterCenter, startRadius: 0, endRadius: radius))
                }
                if t >= 0.7 && t < 1.6 {
                    let u: Double = (t - 0.7) / 0.9
                    let e: Double = Self.easeOut(u)
                    for p in Self.burst {
                        let d: Double = p.speed * e
                        let px: Double = badgeCenter.x + cos(p.angle) * d
                        let py: Double = badgeCenter.y + sin(p.angle) * d * 0.85
                        let point = CGPoint(x: px, y: py)
                        PixelStar.draw(in: &context, center: point, size: p.size, cell: 3,
                                       color: p.gold ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.primary, opacity: 1 - u)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Doc 32 Ascension Field: the digital world struggling to render space around this character.
/// Tier 1: two broken arcs turning slowly behind the body, gold at low opacity. Tier 2 adds sparse
/// pixels drifting upward. Tier 3+ adds a fragmented ground glyph under the feet. Never a solid aura,
/// never proportions. Static under Reduce Motion.
struct AscensionField: View {
    let tier: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height * 0.55)
                let r = min(size.width, size.height) * 0.46
                let gold = NeoTokyo.Hierarchy.primary
                // Two incomplete arcs, counter-rotating, drawn as 2 px dashes so they read as pixels.
                for (k, speed) in [(0, 0.11), (1, -0.07)] {
                    let radius = r * (k == 0 ? 1.0 : 0.82)
                    let base = t * speed * .pi * 2 + Double(k) * 1.9
                    for seg in 0..<3 {
                        let a0 = base + Double(seg) * (2 * .pi / 3), a1 = a0 + 0.9 - Double(k) * 0.25
                        var p = Path(); p.addArc(center: center, radius: radius, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
                        context.stroke(p, with: .color(gold.opacity(0.22)), style: StrokeStyle(lineWidth: 2, dash: [2, 3]))
                    }
                }
                if tier >= 2 {
                    // Sparse drift: eight pixels on fixed lanes, rising and fading over 3 s each.
                    for i in 0..<8 {
                        let phase = (t / 3.0 + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
                        let x = center.x + cos(Double(i) * 2.3) * r * 0.9
                        let y = center.y + r * 0.9 - phase * r * 1.8
                        let alpha = phase < 0.15 ? phase / 0.15 : 1 - (phase - 0.15) / 0.85
                        context.fill(Path(CGRect(x: x, y: y, width: 2, height: 2)), with: .color(gold.opacity(0.6 * alpha)))
                    }
                }
                if tier >= 3 {
                    // Fragmented ground glyph: a flattened ring of dashes under the feet.
                    var g = Path(); g.addEllipse(in: CGRect(x: center.x - r * 0.7, y: size.height * 0.92, width: r * 1.4, height: r * 0.18))
                    context.stroke(g, with: .color(gold.opacity(0.28)), style: StrokeStyle(lineWidth: 2, dash: [3, 4], dashPhase: CGFloat(t * 6)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

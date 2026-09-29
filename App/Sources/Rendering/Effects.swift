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

/// Calm twinkle around the level numeral: eight stars on fixed orbits, each on its own phase.
struct PixelStars: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// (dx, dy, phase) relative to the numeral's centre.
    private static let orbit: [(CGFloat, CGFloat, Double)] = [
        (-24, -30, 0), (36, -38, 1.1), (52, -6, 2.3), (46, 22, 3.1), (-30, 18, 4.2), (-14, -52, 5.0), (62, -26, 0.7), (-38, -6, 2.9),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let origin = CGPoint(x: size.width / 2, y: size.height / 2)
                for (i, (dx, dy, phase)) in Self.orbit.enumerated() {
                    let tw = max(0, sin(t * 1.6 + phase))
                    let opacity = reduceMotion ? 0.5 : 0.25 + 0.75 * tw * tw
                    let starSize = reduceMotion ? 1 : 1 + Int((tw * 1.3).rounded())
                    PixelStar.draw(in: &context, center: CGPoint(x: origin.x + dx, y: origin.y + dy), size: starSize, cell: 3,
                                   color: i % 3 == 0 ? NeoTokyo.Text.primary : NeoTokyo.Hierarchy.primary, opacity: opacity)
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
                .overlay { PixelStars().frame(width: 160, height: 140) }
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

/// Fullscreen level-up: 0–1.3 s aura from the character to the screen edges, fading as it grows;
/// 0.9–1.9 s pixel-star burst from the level numeral. The counter itself is animated by Home at 1.5 s.
struct LevelUpOverlay: View {
    let start: Date
    let characterCenter: CGPoint
    let badgeCenter: CGPoint
    static let duration: TimeInterval = 2.0

    private static let burst: [(angle: Double, speed: CGFloat, size: Int, gold: Bool)] = (0..<22).map { i in
        (Double(i) / 22 * .pi * 2 + Double(i % 2) * 0.15, CGFloat(60 + (i * 37) % 50), 1 + i % 3, i % 4 != 0)
    }
    private static func easeOut(_ u: Double) -> Double { 1 - pow(1 - u, 3) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                if t < 1.3 {
                    let u = t / 1.3
                    let radius = 40 + Self.easeOut(u) * hypot(size.width, size.height) * 0.6
                    let gradient = Gradient(stops: [
                        .init(color: NeoTokyo.Hierarchy.primary.opacity(0.35 * (1 - u)), location: 0),
                        .init(color: NeoTokyo.Hierarchy.primary.opacity(0.18 * (1 - u)), location: 0.6),
                        .init(color: NeoTokyo.Hierarchy.primary.opacity(0), location: 1),
                    ])
                    context.fill(Path(CGRect(origin: .zero, size: size)),
                                 with: .radialGradient(gradient, center: characterCenter, startRadius: 0, endRadius: radius))
                }
                if t >= 0.9 && t < 1.9 {
                    let u = (t - 0.9) / 1.0, e = Self.easeOut(u)
                    for p in Self.burst {
                        let d = p.speed * e
                        let point = CGPoint(x: badgeCenter.x + cos(p.angle) * d, y: badgeCenter.y + sin(p.angle) * d * 0.85)
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

import SwiftUI
import HeroDomain
import HeroContent

/// Doc 24 "Departure": the character walks in place while the district scrolls right→left, a
/// dotted path runs to a hidden reward, and a countdown says when they return. Walk clip is
/// pending authoring (owner, 2026-10-02): the idle sprite is used until then.
struct DepartureView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let run: QuestRun

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                ScrollingBackdrop(assetSetID: state.recipe?.backdropID ?? "backdrop.rain_district", pointsPerSecond: reduceMotion ? 0 : 28)
                if let recipe = state.recipe {
                    CharacterView(recipe: recipe, outfit: state.evolution?.outfit, scale: HomeView.characterScale)
                        .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.35), radius: 16)
                        .padding(.bottom, NeoTokyo.Spacing.xl)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .clipped()

            VStack(spacing: NeoTokyo.Spacing.lg) {
                Eyebrow(text: "Daily quest")
                Text(state.quest?.displayName ?? "Quest")
                    .font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
                Text(state.departLine(for: run))
                    .font(HeroFont.body).foregroundStyle(NeoTokyo.Text.secondary)
                    .multilineTextAlignment(.center)
                QuestPath(progress: 0)
                    .padding(.horizontal, NeoTokyo.Spacing.md)
                Countdown(until: run.returnsAt)
            }
            .padding(NeoTokyo.Spacing.xl)
            Spacer()
            Button("Got it") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, NeoTokyo.Spacing.lg)
                .padding(.bottom, NeoTokyo.Spacing.lg)
        }
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
    }
}

/// Backdrop image tiled horizontally and moved right→left on a timeline. Two copies, so the
/// seam wraps; the far copy is the same image dimmed at half speed for depth.
struct ScrollingBackdrop: View {
    let assetSetID: BackdropID
    var pointsPerSecond: Double = 28
    @State private var image: Image?
    @State private var start = Date()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: pointsPerSecond == 0)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(start)
                let w = geo.size.width
                ZStack {
                    layer(width: w, height: geo.size.height, offset: offset(elapsed, speed: pointsPerSecond * 0.5, width: w)).opacity(0.45)
                    layer(width: w, height: geo.size.height, offset: offset(elapsed, speed: pointsPerSecond, width: w))
                        .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .bottom))
                }
            }
        }
        .task(id: assetSetID) { image = BackdropImage.load(assetSetID.rawValue) }
    }

    private func offset(_ t: TimeInterval, speed: Double, width: CGFloat) -> CGFloat {
        guard width > 0, speed > 0 else { return 0 }
        return CGFloat(-(t * speed).truncatingRemainder(dividingBy: Double(width)))
    }

    @ViewBuilder
    private func layer(width: CGFloat, height: CGFloat, offset: CGFloat) -> some View {
        HStack(spacing: 0) {
            tile(width: width, height: height)
            tile(width: width, height: height)
        }
        .offset(x: offset)
        .frame(width: width, height: height, alignment: .leading)
    }

    @ViewBuilder
    private func tile(width: CGFloat, height: CGFloat) -> some View {
        if let image {
            image.resizable().interpolation(.none).scaledToFill()
                .frame(width: width, height: height, alignment: .bottom).clipped()
        } else {
            SceneBackdrop(shades: NeoTokyo.Backdrop.rainDistrict).frame(width: width, height: height)
        }
    }
}

/// Dotted path from the character's mark to a "?" reward slot (Finch reference 08, doc 23).
struct QuestPath: View {
    /// 0…1 along the path.
    let progress: Double
    var body: some View {
        HStack(spacing: NeoTokyo.Spacing.sm) {
            Image(systemName: "figure.walk").font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                .frame(width: 36, height: 36).background(NeoTokyo.Surface.overlay, in: Circle())
            GeometryReader { geo in
                let dots = max(6, Int(geo.size.width / 14))
                HStack(spacing: 0) {
                    ForEach(0..<dots, id: \.self) { i in
                        Circle()
                            .fill(Double(i) / Double(max(1, dots - 1)) <= progress ? NeoTokyo.Hierarchy.primary : NeoTokyo.Surface.line)
                            .frame(width: 5, height: 5)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: geo.size.height)
            }
            .frame(height: 36)
            Text("?").font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.onAccent)
                .frame(width: 36, height: 36).background(NeoTokyo.Hierarchy.primary, in: Circle())
        }
    }
}

/// H:MM:SS until `until`, tabular digits, updates every second. Reads "Back" once due.
struct Countdown: View {
    let until: Date
    var font: Font = HeroFont.statMD
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, until.timeIntervalSince(timeline.date))
            Text(remaining == 0 ? "Back" : Self.format(remaining))
                .font(font).foregroundStyle(NeoTokyo.Text.primary)
        }
    }
    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

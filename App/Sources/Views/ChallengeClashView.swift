import SwiftUI
import HeroDomain
import HeroContent

/// Doc 33: the clash, precursor to the Gym fight (owner build notes 2026-10-12). The area's backdrop fills the
/// upper stage, bottom-aligned so its floor is the stage floor; hero left and challenger right stand on it. A
/// bottom sheet carries the title, the offer line and "Begin". On Begin: 3 · 2 · 1, then an old-school tackle:
/// both wind up, snap forward and collide at the centre with a hit-shake; a gold bloom then a white-out engulfs
/// the whole screen and holds until the result card arrives; then the aftermath exchange as a story scene.
/// The fact is already written; nothing here can fail or double-grant. Reduce Motion: straight to the result.
struct ChallengeClashView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let outcome: AppState.ChallengeOutcome
    let onFinish: () -> Void

    enum Phase: Equatable { case ready, count(Int), windup, lunge, hit(Int), bloom, whiteout, result, aftermath }
    @State private var phase: Phase = .ready

    private var challenger: ContentBundle.Character? { state.bundle.character(outcome.challenge.characterID) }
    private var backdrop: BackdropID {
        let id: BackdropID = outcome.challenge.areaID == "colossus_gym" ? "backdrop.colossus_gym.interior_01" : (state.recipe?.backdropID ?? "backdrop.rain_district")
        return BackdropID(state.bundle.backdrop(id)?.assetSetID.rawValue ?? id.rawValue)
    }
    private var aftermath: ContentBundle.StoryChapter {
        ContentBundle.StoryChapter(id: "aftermath.\(outcome.challenge.id.rawValue)", title: outcome.challenge.name, backdropID: backdrop, then: "return",
                                   beats: outcome.won ? outcome.set.aftermathWin : outcome.set.aftermathLose)
    }
    private var title: String { "\(challenger?.displayName ?? "Someone")'s challenge: \(outcome.challenge.name)" }

    var body: some View {
        Group {
            if phase == .aftermath {
                if aftermath.beats.isEmpty { Color.clear.onAppear { onFinish() } }
                else { StoryView(chapter: aftermath, heroRecipe: state.recipe) { onFinish() } }
            } else {
                stage
            }
        }
    }

    // MARK: stage

    private static let spriteWidth: CGFloat = 64 * HomeView.characterScale
    private var inMotion: Bool { if case .hit = phase { return true }; return phase == .lunge || phase == .bloom || phase == .whiteout }
    private var windingUp: Bool { phase == .windup }
    private var glow: Color { inMotion ? .white : NeoTokyo.Hierarchy.primary }
    private var whiteOpacity: Double {
        switch phase { case .whiteout: return 1; case .bloom: return 0.35; case .result: return 0; default: return 0 }
    }
    private func shake(_ phase: Phase) -> CGFloat { if case let .hit(n) = phase { return n % 2 == 0 ? 6 : -6 }; return 0 }

    private var stage: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                // To collide at the centre: each sprite travels from its edge to touch the other at the midline.
                let travel = max(0, geo.size.width / 2 - Self.spriteWidth - NeoTokyo.Spacing.xl)
                let heroX: CGFloat = windingUp ? -16 : (inMotion ? travel + shake(phase) : 0)
                let foeX: CGFloat = windingUp ? 16 : (inMotion ? -travel - shake(phase) : 0)
                ZStack(alignment: .bottom) {
                    BackdropImage(assetSetID: backdrop)
                    HStack(alignment: .bottom) {
                        if let recipe = state.recipe {
                            CharacterView(recipe: recipe, scale: HomeView.characterScale, ascension: state.ascensionTier)
                                .rotationEffect(.degrees(inMotion ? 12 : (windingUp ? -6 : 0)), anchor: .bottom)
                                .shadow(color: glow.opacity(inMotion || windingUp ? 0.95 : 0.35), radius: inMotion ? 30 : 16)
                                .offset(x: heroX)
                        }
                        Spacer()
                        if let sprite = challenger?.spriteAssetSetID {
                            SpritePlayer(assetSetID: sprite, animation: "still", scale: HomeView.characterScale)
                                .rotationEffect(.degrees(inMotion ? -12 : (windingUp ? 6 : 0)), anchor: .bottom)
                                .shadow(color: glow.opacity(inMotion || windingUp ? 0.95 : 0.35), radius: inMotion ? 30 : 16)
                                .offset(x: foeX)
                        }
                    }
                    .padding(.horizontal, NeoTokyo.Spacing.xl)
                    .padding(.bottom, geo.size.height * 0.07)   // on the backdrop's floor, not floating
                    .animation(motion(for: phase), value: phase)
                    if case let .count(n) = phase {
                        Text("\(n)")
                            .font(HeroFont.statXL).foregroundStyle(NeoTokyo.Text.primary)
                            .shadow(color: NeoTokyo.Surface.base.opacity(0.9), radius: 8)
                            .id(n)
                            .transition(.scale(scale: 1.6).combined(with: .opacity))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            bottomSheet
        }
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
        .overlay { flashLayers }
        .overlay { if phase == .result { resultCard.transition(.scale(scale: 0.92).combined(with: .opacity)) } }
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    /// Snappy, not smooth: a short linear lunge, instant hit-shake frames.
    private func motion(for phase: Phase) -> Animation? {
        switch phase {
        case .windup: return .linear(duration: 0.12)
        case .lunge: return .linear(duration: 0.14)
        case .hit: return nil
        default: return .easeOut(duration: 0.3)
        }
    }

    /// Gold bloom from the point of impact, then a white-out over the whole screen that holds until the card.
    private var flashLayers: some View {
        ZStack {
            if phase == .bloom || phase == .whiteout {
                Circle()
                    .fill(RadialGradient(colors: [.white, NeoTokyo.Hierarchy.primary, NeoTokyo.Hierarchy.primary.opacity(0)], center: .center, startRadius: 0, endRadius: 700))
                    .frame(width: 1400, height: 1400)
                    .transition(.scale(scale: 0.05).combined(with: .opacity))
            }
            Color.white.opacity(whiteOpacity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(phase == .result ? .easeOut(duration: 0.7) : .easeIn(duration: 0.18), value: phase)
    }

    private var bottomSheet: some View {
        VStack(spacing: NeoTokyo.Spacing.sm) {
            Text(title).font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if phase == .ready {
                Text(outcome.set.offer).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Button("Begin") { Task { await run() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, NeoTokyo.Spacing.xs)
            } else {
                Color.clear.frame(height: 44)
            }
        }
        .padding(.horizontal, NeoTokyo.Spacing.lg)
        .padding(.top, NeoTokyo.Spacing.md)
        .padding(.bottom, NeoTokyo.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(NeoTokyo.Surface.raised.opacity(0.96))
    }

    private var resultCard: some View {
        let grant = state.challengeGrant(for: outcome)
        let attribute = state.bundle.attributes.first { $0.id == outcome.challenge.attributeID }
        return ZStack {
            NeoTokyo.Surface.scrim.opacity(0.7).ignoresSafeArea()
            VStack(spacing: NeoTokyo.Spacing.md) {
                Eyebrow(text: outcome.won ? "Challenge won" : "Challenge lost")
                Text("+\(grant.xp) XP").font(HeroFont.statXL).foregroundStyle(NeoTokyo.Hierarchy.primary)
                if grant.points > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: AttributeGlyph.symbol(for: outcome.challenge.attributeID))
                        Text("+\(grant.points) \(attribute?.displayName ?? outcome.challenge.attributeID.rawValue)")
                    }
                    .font(HeroFont.statSM).foregroundStyle(NeoTokyo.Attribute.color(for: outcome.challenge.attributeID.rawValue))
                }
                Text(outcome.won ? outcome.set.win : outcome.set.lose)
                    .font(HeroFont.body).foregroundStyle(NeoTokyo.Text.secondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Continue") { phase = .aftermath }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, NeoTokyo.Spacing.sm)
            }
            .padding(NeoTokyo.Spacing.xl)
            .frame(maxWidth: 340)
            .glass(tint: NeoTokyo.Surface.overlay)
            .padding(NeoTokyo.Spacing.xl)
        }
    }

    // MARK: sequence

    private func run() async {
        if reduceMotion { phase = .result; return }
        for n in [3, 2, 1] {
            phase = .count(n)
            try? await Task.sleep(for: .milliseconds(600))
        }
        phase = .windup
        try? await Task.sleep(for: .milliseconds(220))
        phase = .lunge
        try? await Task.sleep(for: .milliseconds(150))
        for n in 0..<4 {
            phase = .hit(n)
            try? await Task.sleep(for: .milliseconds(55))
        }
        phase = .bloom
        try? await Task.sleep(for: .milliseconds(260))
        phase = .whiteout
        try? await Task.sleep(for: .milliseconds(650))
        phase = .result
    }
}

import SwiftUI
import HeroDomain
import HeroContent

/// Doc 33: the clash, precursor to the Gym fight. The area's scroller backdrop, still; hero left, challenger
/// right, both idle. "3 · 2 · 1", both lean in, glow gold then white, dash to the centre; a flash blooms where
/// they meet and whites out the screen. Reset, then the result card (won / lost, the grant, Continue), then the
/// aftermath exchange as a story scene. The fact is already written; nothing here can fail or double-grant.
/// Reduce Motion: no countdown, dash or flash; straight to the result.
struct ChallengeClashView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let outcome: AppState.ChallengeOutcome
    let onFinish: () -> Void

    enum Phase: Equatable { case ready, armed, count(Int), lean, dash, flash, reset, result, aftermath }
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

    private var leaning: Bool { phase == .lean || phase == .dash || phase == .flash }
    private var dashing: Bool { phase == .dash || phase == .flash }
    private var glow: Color { phase == .dash || phase == .flash ? .white : NeoTokyo.Hierarchy.primary }

    private var stage: some View {
        ZStack {
            BackdropImage(assetSetID: backdrop).ignoresSafeArea()
            GeometryReader { geo in
                let travel = geo.size.width * 0.26
                // Owner build notes 2026-10-12: the characters stand on the backdrop's floor, in the bottom third of the
                // scene, and the Challenge button sits beneath them in a bottom panel; the sequence starts on the tap.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom) {
                        if let recipe = state.recipe {
                            CharacterView(recipe: recipe, scale: HomeView.characterScale, ascension: state.ascensionTier)
                                .rotationEffect(.degrees(leaning ? 10 : 0), anchor: .bottom)
                                .shadow(color: glow.opacity(leaning ? 0.9 : 0.35), radius: leaning ? 26 : 16)
                                .offset(x: dashing ? travel : 0)
                        }
                        Spacer()
                        if let sprite = challenger?.spriteAssetSetID {
                            SpritePlayer(assetSetID: sprite, animation: "still", scale: HomeView.characterScale)
                                .rotationEffect(.degrees(leaning ? -10 : 0), anchor: .bottom)
                                .shadow(color: glow.opacity(leaning ? 0.9 : 0.35), radius: leaning ? 26 : 16)
                                .offset(x: dashing ? -travel : 0)
                        }
                    }
                    .padding(.horizontal, NeoTokyo.Spacing.xl)
                    .animation(phase == .reset ? nil : .easeIn(duration: phase == .dash ? 0.28 : 0.45), value: phase)
                    .padding(.bottom, geo.size.height * 0.08)
                    bottomPanel
                        .frame(height: geo.size.height * 0.22)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            if case let .count(n) = phase {
                Text("\(n)")
                    .font(HeroFont.statXL).foregroundStyle(NeoTokyo.Text.primary)
                    .shadow(color: NeoTokyo.Surface.base.opacity(0.9), radius: 8)
                    .id(n)
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
            }
            if phase == .flash {
                Circle().fill(RadialGradient(colors: [.white, NeoTokyo.Hierarchy.primary.opacity(0.9), .clear], center: .center, startRadius: 0, endRadius: 320))
                    .frame(width: 640, height: 640)
                    .transition(.scale(scale: 0.1).combined(with: .opacity))
                Color.white.ignoresSafeArea().transition(.opacity)
            }
            if phase == .result || phase == .reset {
                resultCard.transition(.scale(scale: 0.92).combined(with: .opacity))
            }
            VStack {
                Eyebrow(text: "\(challenger?.displayName ?? "") · \(outcome.challenge.name)")
                    .padding(.top, NeoTokyo.Spacing.xl)
                Spacer()
            }
            .opacity(phase == .ready || phase == .reset ? 1 : 0)
        }
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    /// The pause before the clash: one big button. Reduce Motion goes straight to the result.
    private var bottomPanel: some View {
        VStack(spacing: NeoTokyo.Spacing.sm) {
            if phase == .ready {
                Text(outcome.set.offer).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                    .multilineTextAlignment(.center).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Button("Challenge") {
                    phase = .armed
                    Task { await run() }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, NeoTokyo.Spacing.lg)
        .padding(.bottom, NeoTokyo.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(
            LinearGradient(colors: [NeoTokyo.Surface.base.opacity(0), NeoTokyo.Surface.base.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
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
                    Text("+\(grant.points) \(attribute?.displayName ?? outcome.challenge.attributeID.rawValue)")
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
        try? await Task.sleep(for: .milliseconds(300))
        for n in [3, 2, 1] {
            phase = .count(n)
            try? await Task.sleep(for: .milliseconds(650))
        }
        phase = .lean
        try? await Task.sleep(for: .milliseconds(500))
        phase = .dash
        try? await Task.sleep(for: .milliseconds(300))
        phase = .flash
        try? await Task.sleep(for: .milliseconds(650))
        phase = .reset
        try? await Task.sleep(for: .milliseconds(350))
        phase = .result
    }
}

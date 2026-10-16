import SwiftUI
import HeroDomain
import HeroContent

/// Owner QA 2026-10-16: day-one Health credit, told once. Apple Health connected during the bond can land a day's
/// steps and the recent workouts at once; instead of a receipt per fact, Cairon says one thing, the counts are
/// shown, and dismissing it lets Home play the level-up once. Shaped like the reward modal. Never auto-dismisses:
/// it is the first thing a new player reads on Home.
struct HealthWelcomeMoment: View {
    @Environment(AppState.self) private var state
    let welcome: AppState.HealthWelcome

    var body: some View {
        let after = state.snapshot
        let xp = max(0, after.totalXP - welcome.totalXPBefore)
        ZStack {
            NeoTokyo.Surface.scrim.opacity(0.7).ignoresSafeArea()
            VStack(spacing: NeoTokyo.Spacing.md) {
                HStack(alignment: .top, spacing: NeoTokyo.Spacing.sm) {
                    // Owner line (2026-10-16), in Cairon's voice; the guide sits to the right of his bubble (hero always left).
                    Bubble(text: "Looks like your human is already active today. That's a good sign that you'll be successful.", trailing: true)
                    if let guide = state.bundle.character("guide.elder"), let set = guide.portraitAssetSetID {
                        PortraitView(assetSetID: set, size: 56)
                            .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
                    }
                }
                Eyebrow(text: "Apple Health · counted")
                HStack(spacing: NeoTokyo.Spacing.xl) {
                    if let steps = welcome.steps, steps > 0 {
                        VStack(spacing: 2) {
                            StatNumber(value: steps, font: HeroFont.statMD)
                            Text("steps today").font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                        }
                    }
                    if welcome.workouts > 0 {
                        VStack(spacing: 2) {
                            StatNumber(value: welcome.workouts, font: HeroFont.statMD)
                            Text(welcome.workouts == 1 ? "workout" : "workouts").font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                        }
                    }
                    VStack(spacing: 2) {
                        StatNumber(value: xp, unit: "xp", accent: NeoTokyo.Hierarchy.primary, font: HeroFont.statMD)
                        Text(after.level > welcome.levelBefore ? "Level \(after.level)" : "earned").font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                    }
                }
                .padding(.top, NeoTokyo.Spacing.xs)
                Text("Already on your ledger. Training moves it far more.")
                    .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted).multilineTextAlignment(.center)
                Button("Good") { state.dismissHealthWelcome() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, NeoTokyo.Spacing.sm)
            }
            .padding(NeoTokyo.Spacing.xl)
            .frame(maxWidth: 360)
            .glass(tint: NeoTokyo.Surface.overlay)
            .padding(NeoTokyo.Spacing.xl)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }
}

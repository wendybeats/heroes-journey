import SwiftUI
import HeroDomain

/// Doc 24 "Setting the stage" (Finch reference 05, doc 23): the first open of a day is a flat
/// navy flood with the day count, the date, the character in a framed scene, one line, and
/// today's goals. One tap. Motion reuses the Ascension flood timings (0.4 s scrim, content
/// rising 0.2–0.9 s) so the app has one transition language.
struct StageView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 1.0 : timeline.date.timeIntervalSince(start)
            let flood = min(1, max(0, t / 0.4))
            let rise = 1 - pow(1 - min(1, max(0, (t - 0.2) / 0.7)), 3)
            ZStack {
                NeoTokyo.Surface.base.opacity(flood).ignoresSafeArea()
                VStack(spacing: NeoTokyo.Spacing.xl) {
                    Spacer(minLength: NeoTokyo.Spacing.xl)
                    VStack(spacing: NeoTokyo.Spacing.xs) {
                        Eyebrow(text: "Day \(state.dayNumber)")
                        Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
                    }
                    framedScene
                        .rotationEffect(.degrees(-2))
                        .padding(.horizontal, NeoTokyo.Spacing.xl)
                    if let quote = state.bundle.quote(forDay: state.dayNumber) {
                        VStack(spacing: NeoTokyo.Spacing.xs) {
                            Text("“\(quote.text)”")
                                .font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                                .multilineTextAlignment(.center)
                            Text(quote.source).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                        }
                        .padding(.horizontal, NeoTokyo.Spacing.xl)
                    }
                    if let plan = state.todayPlan {
                        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
                            Eyebrow(text: state.isTrainingDay() ? "Training day · today's goals" : "Rest day · today's goals")
                            ForEach(plan.goals) { goal in
                                HStack(spacing: NeoTokyo.Spacing.sm) {
                                    Circle().fill(NeoTokyo.Attribute.color(for: state.template(for: goal)?.attributeID.rawValue ?? "")).frame(width: 6, height: 6)
                                    Text(state.title(for: goal)).font(HeroFont.bodyMedium).foregroundStyle(NeoTokyo.Text.primary)
                                    Spacer()
                                    if let xp = state.ruleset.goalXP?[goal.slot.rawValue] {
                                        Text("+\(xp)").font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Hierarchy.primary)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                        .padding(.horizontal, NeoTokyo.Spacing.lg)
                    }
                    Spacer()
                    Button("Begin the day") { state.dismissStage() }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, NeoTokyo.Spacing.lg)
                        .padding(.bottom, NeoTokyo.Spacing.lg)
                }
                .opacity(rise)
                .offset(y: (1 - rise) * 24)
            }
        }
    }

    /// The character on their backdrop inside an off-white frame: the "postcard" of the day.
    private var framedScene: some View {
        ZStack(alignment: .bottom) {
            BackdropImage(assetSetID: state.recipe?.backdropID ?? "backdrop.rain_district")
            if let recipe = state.recipe {
                CharacterView(recipe: recipe, scale: HomeView.characterScale, ascension: state.ascensionTier)
                    .padding(.bottom, NeoTokyo.Spacing.lg)
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.sm, style: .continuous))
        .padding(10)
        .background(NeoTokyo.Accent.button, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
        .shadow(color: NeoTokyo.Surface.scrim.opacity(0.6), radius: 24, y: 12)
    }

}

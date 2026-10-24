import SwiftUI
import HeroDomain
import HeroContent

/// Owner 2026-10-24: the echo asks for Apple Health the way it asks for notifications (`QuestDepartPrompt`): a medium
/// sheet, the character, one line in its own voice, what the permission is for, then the system prompt or "Not now".
/// Shown after the first session logged by hand, when a reinstall lost the grant, and once more a week later at most.
struct HealthConnectPrompt: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let reason: AppState.HealthPromptReason

    private var line: String {
        switch reason {
        case .firstLog: return "Nice one. Next time, let me pick that up myself. We can grow stronger together, automatically."
        case .reconnect: return "I lost touch with your Health data when the phone changed. Reconnect it and we grow stronger together, automatically."
        case .reoffer: return "Still logging by hand? Let me do it. We can grow stronger together, automatically."
        }
    }

    var body: some View {
        VStack(spacing: NeoTokyo.Spacing.lg) {
            if let recipe = state.recipe {
                SpritePortrait(recipe: recipe, outfit: state.evolution?.outfit, size: 120)
            }
            Bubble(text: line)
            HStack(spacing: NeoTokyo.Spacing.sm) {
                Image(systemName: "heart.fill").font(HeroFont.headline).foregroundStyle(NeoTokyo.Hierarchy.primary)
                Text("Workouts and steps reach me the moment they happen. Nothing is written back.").font(HeroFont.bodyMedium).foregroundStyle(NeoTokyo.Text.primary)
            }
            .padding(NeoTokyo.Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.raised)
            Button(reason == .reconnect ? "Reconnect Apple Health" : "Connect Apple Health") { dismiss(); Task { await state.answerHealthPrompt(connect: true) } }
                .buttonStyle(PrimaryButtonStyle())
            Button("Not now") { dismiss(); Task { await state.answerHealthPrompt(connect: false) } }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(NeoTokyo.Spacing.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
        .interactiveDismissDisabled()
    }
}

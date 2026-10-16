import SwiftUI
import HeroDomain
import HeroContent

/// Owner QA 2026-10-16: the boss offer looks like the challenge card (same shape, the same slot over the foot of the
/// scene, the portrait where the challenger's goes) and glows so the player knows it matters. Gold means
/// progression (doc 19) and this is the chapter's gate, so the glow is gold and slow. The line under the name is
/// Cairon's hint after a loss, else the invitation; attempts are never counted on screen (doc 37).
struct BossCard: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let milestone: Milestone
    let onFace: () -> Void
    @State private var lit = false

    var body: some View {
        if let boss = state.bundle.boss(forMilestone: milestone.id), let who = state.bundle.character(boss.characterID) {
            let label = milestone.triggerLabel ?? "Face \(who.displayName)"
            let line = state.bossAttempts(boss) > 0 ? (state.bossLossLine(boss) ?? "When you're ready. It waits for you.") : "When you're ready. It waits for you."
            let area = boss.areaID.flatMap { state.bundle.area($0)?.displayName }
            VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
                HStack(alignment: .top, spacing: NeoTokyo.Spacing.md) {
                    VStack(alignment: .leading, spacing: NeoTokyo.Spacing.xs) {
                        Eyebrow(text: area.map { "Boss · \($0)" } ?? "Boss")
                        Text(label).font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.shield.fill").font(HeroFont.captionMedium)
                            Text(who.displayName).font(HeroFont.captionMedium)
                        }
                        .foregroundStyle(NeoTokyo.Hierarchy.primary)
                        Text(line).font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if let portrait = who.cardPortrait {
                        PortraitView(assetSetID: portrait, size: 84)
                            .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
                            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.overlay)
                            .shadow(color: NeoTokyo.Hierarchy.primary.opacity(lit ? 0.55 : 0.2), radius: 14)
                    }
                }
                Button(label) { onFace() }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(NeoTokyo.Spacing.md)
            .glass(tint: NeoTokyo.Surface.raised)
            .overlay(
                RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous)
                    .stroke(NeoTokyo.Hierarchy.primary.opacity(lit ? 0.7 : 0.25), lineWidth: 1.5)
            )
            .shadow(color: NeoTokyo.Hierarchy.primary.opacity(lit ? 0.45 : 0.15), radius: lit ? 26 : 14)
            .onAppear {
                guard !reduceMotion else { lit = true; return }
                withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) { lit = true }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

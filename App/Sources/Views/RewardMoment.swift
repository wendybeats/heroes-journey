import SwiftUI
import HeroDomain

/// Doc 02 "reward moment": shown only from a confirmed receipt. XP, attributes, unlock if any, 2–4 s.
struct RewardMoment: View {
    @Environment(AppState.self) private var state
    let receipt: ProgressionReceipt

    var body: some View {
        VStack(spacing: NeoTokyo.Spacing.md) {
            Text(receipt.leveledUp ? "Level \(receipt.levelAfter)" : "+\(receipt.xp) XP")
                .font(HeroFont.statXL)
                .foregroundStyle(NeoTokyo.Hierarchy.primary)
            if receipt.leveledUp {
                Text("+\(receipt.xp) XP").font(HeroFont.statMD).foregroundStyle(NeoTokyo.Text.primary)
            }
            HStack(spacing: NeoTokyo.Spacing.lg) {
                ForEach(receipt.attributes.sorted { $0.key.rawValue < $1.key.rawValue }, id: \.key) { pair in
                    Text("+\(pair.value) \(state.bundle.attributes.first { $0.id == pair.key }?.displayName ?? pair.key.rawValue)")
                        .font(HeroFont.captionNumber)
                        .foregroundStyle(NeoTokyo.Attribute.color(for: pair.key.rawValue))
                }
            }
            if !receipt.rewardsGranted.isEmpty {
                Text("Unlocked: \(receipt.rewardsGranted.map(\.rawValue).joined(separator: ", "))")
                    .font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Hierarchy.primary)
            }
            if receipt.xp == 0 {
                Text("Logged. Daily credit for this family is used up; it still counts in your history.")
                    .font(HeroFont.caption).multilineTextAlignment(.center).foregroundStyle(NeoTokyo.Text.secondary)
            }
        }
        .padding(NeoTokyo.Spacing.xl)
        .background(NeoTokyo.Surface.overlay, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous).strokeBorder(NeoTokyo.Hierarchy.primaryDim, lineWidth: 1))
        .padding(NeoTokyo.Spacing.xl)
        .transition(.scale.combined(with: .opacity))
        .onTapGesture { state.dismissReward() }
        .task {
            try? await Task.sleep(for: .milliseconds(Int(NeoTokyo.Motion.rewardMs)))
            state.dismissReward()
        }
    }
}

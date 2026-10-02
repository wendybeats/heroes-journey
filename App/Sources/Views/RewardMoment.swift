import SwiftUI
import HeroDomain

/// Doc 02 "reward moment", as a modal: dimmed scrim, centred glass card, high contrast.
/// Shown only from a confirmed receipt. Tap anywhere or "Continue" to dismiss; auto-dismisses.
struct RewardMoment: View {
    @Environment(AppState.self) private var state
    let receipt: ProgressionReceipt

    var body: some View {
        ZStack {
            NeoTokyo.Surface.scrim.opacity(0.7).ignoresSafeArea()
                .onTapGesture { state.dismissReward() }
            VStack(spacing: NeoTokyo.Spacing.md) {
                Eyebrow(text: receipt.leveledUp ? "Level up" : (questRun != nil ? "Back from the quest" : (isGoal ? "Goal complete" : "Logged")))
                Text(receipt.leveledUp ? "Level \(receipt.levelAfter)" : "+\(receipt.xp) XP")
                    .font(HeroFont.statXL)
                    .foregroundStyle(NeoTokyo.Hierarchy.primary)
                if receipt.leveledUp {
                    Text("+\(receipt.xp) XP").font(HeroFont.statMD).foregroundStyle(NeoTokyo.Text.primary)
                }
                if let run = questRun {
                    if let tier = state.rewardTier(for: run), tier != "common" {
                        Eyebrow(text: tier)
                    }
                    Text(state.returnLine(for: run))
                        .font(HeroFont.body).foregroundStyle(NeoTokyo.Text.secondary)
                        .multilineTextAlignment(.center)
                }
                if !receipt.attributes.isEmpty {
                    HStack(spacing: NeoTokyo.Spacing.lg) {
                        ForEach(receipt.attributes.sorted { $0.key.rawValue < $1.key.rawValue }, id: \.key) { pair in
                            VStack(spacing: 2) {
                                Text("+\(pair.value)").font(HeroFont.statSM).foregroundStyle(NeoTokyo.Attribute.color(for: pair.key.rawValue))
                                Text(state.bundle.attributes.first { $0.id == pair.key }?.displayName ?? pair.key.rawValue)
                                    .font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                            }
                        }
                    }
                    .padding(.top, NeoTokyo.Spacing.xs)
                }
                ForEach(state.lastPersonalRecords.filter { !$0.isBaseline }, id: \.setID) { pr in
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill").font(HeroFont.caption)
                        Text("\(state.bundle.exercise(pr.exerciseID)?.displayName ?? pr.exerciseID.rawValue) · \(prLabel(pr))").font(HeroFont.captionMedium)
                    }
                    .foregroundStyle(NeoTokyo.Hierarchy.primary)
                }
                ForEach(state.lastGoalReceipts, id: \.activityEventID) { goal in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(HeroFont.caption)
                        Text("\(goalTitle(goal)) · +\(goal.xp) XP").font(HeroFont.captionMedium)
                    }
                    .foregroundStyle(NeoTokyo.Hierarchy.primary)
                }
                if !receipt.rewardsGranted.isEmpty {
                    Text("Unlocked: \(receipt.rewardsGranted.map(\.rawValue).joined(separator: ", "))")
                        .font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Hierarchy.primary)
                }
                if receipt.xp == 0 && !isGoal && questRun == nil {
                    Text("Daily credit for this family is used up. It still counts in your history.")
                        .font(HeroFont.caption).multilineTextAlignment(.center).foregroundStyle(NeoTokyo.Text.secondary)
                }
                Button("Continue") { state.dismissReward() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, NeoTokyo.Spacing.sm)
            }
            .padding(NeoTokyo.Spacing.xl)
            .frame(maxWidth: 340)
            .glass(tint: NeoTokyo.Surface.overlay)
            .padding(NeoTokyo.Spacing.xl)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .task {
            try? await Task.sleep(for: .milliseconds(4000 + (state.lastPersonalRecords.isEmpty ? 0 : 1500)))
            state.dismissReward()
        }
    }

    private var questRun: QuestRun? { state.questRun(for: receipt.activityEventID) }
    private var isGoal: Bool { state.goalCompletions.contains { $0.activityEventID == receipt.activityEventID } }

    private func goalTitle(_ r: ProgressionReceipt) -> String {
        guard let c = state.goalCompletions.first(where: { $0.activityEventID == r.activityEventID }),
              let goal = state.todayPlan?.goals.first(where: { $0.id == c.goalID }) else { return "Goal" }
        return state.title(for: goal)
    }

    private func prLabel(_ pr: PersonalRecord) -> String {
        let unit = state.preferredUnit
        switch pr.kind {
        case .maxWeight: return "\(Int(unit.fromKilograms(pr.value).rounded())) \(unit.rawValue)"
        case .estimatedOneRepMax: return "est. 1RM \(Int(unit.fromKilograms(pr.value).rounded())) \(unit.rawValue)"
        case .maxReps: return "\(Int(pr.value)) reps"
        case .maxDuration: return "\(Int(pr.value)) s"
        }
    }
}

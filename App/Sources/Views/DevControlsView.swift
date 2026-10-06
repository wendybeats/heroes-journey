#if DEBUG
import SwiftUI
import HeroDomain
import HeroContent

/// Debug-only controls (owner QA 2026-10-05): move time, drop the daily cap, redraw goals, finish the
/// quest. Nothing here fabricates XP; facts still go through the engine. Not compiled into release.
struct DevControlsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NeoTokyo.Spacing.lg) {
                    let _ = state.devToken
                    section("Time") {
                        row("Day offset", value: "\(state.devDayOffset) · \(state.today.year)-\(state.today.month)-\(state.today.day)")
                        Button("Advance one day") { state.devAdvanceDay() }.buttonStyle(SecondaryButtonStyle())
                        Button("Back to today") { state.devResetDay() }.buttonStyle(SecondaryButtonStyle())
                        Text("New goals, the stage screen and a new daily quest. Activity XP today still counts the real calendar.")
                            .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                    }
                    section("Quest") {
                        row("State", value: questLabel)
                        Button("Finish the quest now") { state.devFinishQuest() }
                            .buttonStyle(SecondaryButtonStyle()).disabled(state.activeQuest == nil)
                    }
                    section("XP") {
                        row("Daily activity cap", value: state.ruleset.dailyActivityXPCap.map { "\($0)" } ?? "off")
                        Toggle("Remove the daily cap", isOn: Binding(get: { state.devDailyCapOff }, set: { state.devSetDailyCap(off: $0) }))
                            .font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary).tint(NeoTokyo.Hierarchy.primary)
                        row("Activity XP today", value: "\(state.todayActivityXP)")
                    }
                    section("Goals") {
                        row("Today", value: "\(state.todayGoalsDone) / \(state.todayGoalsTotal)")
                        Button("Reset today's goals") { state.devResetDailyGoals() }.buttonStyle(SecondaryButtonStyle())
                    }
                    section("Story") {
                        row("Level", value: "\(state.snapshot.level)")
                        row("Next beat", value: state.nextStoryBeat?.id.rawValue ?? "none due")
                        row("Completed", value: "\(state.storyProgress.completedMilestones.count)")
                        row("Ascension", value: state.pendingAscension.map { "waiting · tier \($0.fromTier) → \($0.toTier)" } ?? "none waiting")
                        Button("Replay the Ascension") { state.devReplayAscension(); dismiss() }.buttonStyle(SecondaryButtonStyle())
                            .disabled(state.ascensionTier == 0 && state.pendingAscension == nil)
                    }
                    section("Sprites") {
                        NavigationLink("Sprite lab") { SpriteLabView() }.font(HeroFont.bodyMedium).foregroundStyle(NeoTokyo.Hierarchy.fallback)
                    }
                }
                .padding(NeoTokyo.Spacing.lg)
            }
            .background(NeoTokyo.Surface.base)
            .navigationTitle("Dev controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(NeoTokyo.Text.primary) } }
        }
    }

    private var questLabel: String {
        switch state.questState {
        case .locked: return "locked"
        case .ready: return "ready"
        case let .away(run): return "away · back \(Countdown.format(max(0, run.returnsAt.timeIntervalSinceNow)))"
        case let .returned(run): return run.isClaimed ? "claimed" : "back · unclaimed"
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
            Eyebrow(text: title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(HeroFont.body).foregroundStyle(NeoTokyo.Text.secondary)
            Spacer()
            Text(value).font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.primary)
        }
    }
}
#endif

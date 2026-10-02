import SwiftUI
import HeroDomain

/// Doc 24: today's 2–3 goals and the quest row that counts them. One large check per row,
/// a line from the character under each title. Completion goes through `AppState.completeGoal`
/// (a fact, then a receipt); nothing here computes XP.
struct GoalsCard: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            questRow
            if let plan = state.todayPlan {
                VStack(spacing: NeoTokyo.Spacing.sm) {
                    ForEach(plan.goals) { goal in
                        GoalRow(goal: goal)
                    }
                }
            } else {
                Text("No goals yet today.").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// The meter *is* the goal count (owner decision 2026-10-02).
    private var questRow: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            HStack(spacing: NeoTokyo.Spacing.md) {
                QuestRing(done: state.todayGoalsDone, total: state.todayGoalsTotal)
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow(text: state.isTrainingDay() ? "Training day" : "Rest day")
                    Text(questTitle).font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                    Text(questLine).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                }
                Spacer()
                if case let .away(run) = state.questState {
                    Countdown(until: run.returnsAt, font: HeroFont.bodyNumber)
                }
            }
            if case .ready = state.questState {
                Button("Begin quest") { Task { await state.beginQuest() } }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var questTitle: String {
        switch state.questState {
        case .locked: return "Daily quest"
        case .ready: return "Daily quest ready"
        case .away: return state.quest?.displayName ?? "Away"
        case .returned: return "Quest complete"
        }
    }

    private var questLine: String {
        switch state.questState {
        case .locked:
            let left = state.todayGoalsTotal - state.todayGoalsDone
            if state.todayGoalsTotal == 0 { return "Goals arrive with the day." }
            return left == 1 ? "One goal left to unlock it." : "\(left) goals left to unlock it."
        case .ready: return "All goals done. \(state.quest?.displayName ?? "The road") is open."
        case let .away(run): return state.awayLine(for: run)
        case let .returned(run): return state.returnLine(for: run)
        }
    }
}

/// Segmented ring: one gold arc per goal, count in the middle (numbers stay white, doc 19).
struct QuestRing: View {
    let done: Int
    let total: Int

    var body: some View {
        ZStack {
            ForEach(0..<max(1, total), id: \.self) { i in
                let gap = 0.06
                let span = 1.0 / Double(max(1, total))
                Circle()
                    .trim(from: span * Double(i) + gap / 2, to: span * Double(i + 1) - gap / 2)
                    .stroke(i < done ? NeoTokyo.Hierarchy.primary : NeoTokyo.Surface.overlay, style: StrokeStyle(lineWidth: 5, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            Text("\(done)/\(total)")
                .font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.primary)
        }
        .frame(width: 52, height: 52)
        .animation(.easeOut(duration: 0.5), value: done)
    }
}

struct GoalRow: View {
    @Environment(AppState.self) private var state
    let goal: DailyGoal

    var body: some View {
        let done = state.isCompleted(goal)
        HStack(spacing: NeoTokyo.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(state.title(for: goal))
                        .font(HeroFont.bodyMedium)
                        .foregroundStyle(done ? NeoTokyo.Text.secondary : NeoTokyo.Text.primary)
                        .strikethrough(done, color: NeoTokyo.Text.muted)
                    if goal.slot == .primary {
                        Circle().fill(NeoTokyo.Attribute.color(for: state.template(for: goal)?.attributeID.rawValue ?? "")).frame(width: 6, height: 6)
                    }
                }
                Text(state.line(for: goal))
                    .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: NeoTokyo.Spacing.sm)
            if let xp = state.ruleset.goalXP?[goal.slot.rawValue], !done {
                Text("+\(xp)").font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Hierarchy.primary)
            }
            Button {
                state.completeGoal(goal)
            } label: {
                Image(systemName: done ? "checkmark" : (state.template(for: goal)?.rule.isManual == false ? "bolt" : "circle"))
                    .font(HeroFont.headline)
                    .foregroundStyle(done ? NeoTokyo.Text.onAccent : NeoTokyo.Text.secondary)
                    .frame(width: 44, height: 44)
                    .background(done ? NeoTokyo.Hierarchy.primary : NeoTokyo.Surface.overlay, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(done)
            .accessibilityLabel(done ? "Completed" : "Mark complete")
        }
        .padding(.vertical, NeoTokyo.Spacing.xs)
        .animation(.easeOut(duration: 0.3), value: done)
    }
}

import SwiftUI
import HeroDomain

/// Doc 24: today's 2–3 goals and the quest row that counts them. One large check per row,
/// a line from the character under each title. Completion goes through `AppState.completeGoal`
/// (a fact, then a receipt); nothing here computes XP.
struct GoalsCard: View {
    @Environment(AppState.self) private var state
    @State private var showDepartPrompt = false

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
                // The notification explainer appears only until the system prompt has been answered; after that
                // "Begin quest" departs straight away (owner QA 2026-10-05).
                Button("Begin quest") {
                    Task {
                        if await QuestNotifications.isDecided() { await state.beginQuest(requestNotifications: await QuestNotifications.isAuthorized()) }
                        else { showDepartPrompt = true }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .sheet(isPresented: $showDepartPrompt) { QuestDepartPrompt().presentationDetents([.medium]) }
            }
            if state.unclaimedQuest != nil {
                Button("Open the cache") { state.showDeparture = true }
                    .buttonStyle(SecondaryButtonStyle())
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
            if state.todayGoalsTotal == 0 { return "See what the day asks of you." }
            return left == 1 ? "One goal left to unlock it." : "\(left) goals left to unlock it."
        case .ready: return "You did your part. \(state.quest?.displayName ?? "The road") is open."
        case let .away(run): return state.awayLine(for: run)
        case let .returned(run): return run.isClaimed ? state.returnLine(for: run) : "Back. Something came back too."
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
    @State private var showLog = false

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
            // dev-4 (docs/21): goal XP is now worth a short session, so goals backed by a fact are
            // completed only by that fact. Activity goals open the log; steps goals wait for Health.
            let rule = state.template(for: goal)?.rule ?? .manual
            switch rule {
            case .manual, _ where done:
                Button {
                    state.completeGoal(goal)
                } label: {
                    Image(systemName: done ? "checkmark" : "circle")
                        .font(HeroFont.headline)
                        .foregroundStyle(done ? NeoTokyo.Text.onAccent : NeoTokyo.Text.secondary)
                        .frame(width: 44, height: 44)
                        .background(done ? NeoTokyo.Hierarchy.primary : NeoTokyo.Surface.overlay, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(done)
                .accessibilityLabel(done ? "Completed" : "Mark complete")
            case .steps:
                VStack(spacing: 2) {
                    Text(state.todaySteps.map { $0.formatted() } ?? "—").font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.primary)
                    Text("steps").font(HeroFont.label).foregroundStyle(NeoTokyo.Text.muted)
                }
                .frame(width: 56)
            default:
                Button { showLog = true } label: {
                    Image(systemName: "plus")
                        .font(HeroFont.headline)
                        .foregroundStyle(NeoTokyo.Text.secondary)
                        .frame(width: 44, height: 44)
                        .background(NeoTokyo.Surface.overlay, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log activity")
                .sheet(isPresented: $showLog) { LogSheet() }
            }
        }
        .padding(.vertical, NeoTokyo.Spacing.xs)
        .animation(.easeOut(duration: 0.3), value: done)
    }
}

/// Owner QA 2026-10-02: explain before the system notification prompt. The character says why
/// they are leaving; "Enable notifications" asks the system, "Not now" departs silently.
struct QuestDepartPrompt: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: NeoTokyo.Spacing.lg) {
            if let recipe = state.recipe {
                SpritePortrait(recipe: recipe, outfit: state.evolution?.outfit, size: 120)
            }
            Bubble(text: state.quest?.notificationPrompt ?? "Time to see if I can find anything useful around here. I'll be back in a few hours.")
            Button("Enable notifications") { dismiss(); Task { await state.beginQuest(requestNotifications: true) } }
                .buttonStyle(PrimaryButtonStyle())
            Button("Not now") { dismiss(); Task { await state.beginQuest(requestNotifications: false) } }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(NeoTokyo.Spacing.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
    }
}

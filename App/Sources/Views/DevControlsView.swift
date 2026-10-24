#if DEBUG || DEVCONTROLS
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
                        Text("Moves the app's clock a whole day: new goals, the stage screen, a new daily quest and a new challenge roll. Facts logged after this land on the advanced day; Health still reads the real calendar.")
                            .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                    }
                    section("Last receipt") {
                        // HER-20: the engine's inputs for the last activity receipt, so a surprising number explains itself on the phone.
                        ForEach(state.explainLastReceipt(), id: \.0) { item in row(item.0, value: item.1) }
                    }
                    section("Quest") {
                        row("State", value: questLabel)
                        Button("Finish the quest now") { state.devFinishQuest() }
                            .buttonStyle(SecondaryButtonStyle()).disabled(state.activeQuest == nil)
                    }
                    section("XP") {
                        row("Strain", value: state.ruleset.dailyActivityStrain.map { s in "\(s.fullCreditXP) full · " + s.bands.map { "\(Int($0.rate * 100))% to \($0.upTo)" }.joined(separator: " · ") } ?? (state.ruleset.dailyActivityXPCap.map { "cap \($0)" } ?? "off"))
                        row("Activity XP today, raw", value: "\(state.todayUnstrainedXP)")
                        Toggle("Remove strain", isOn: Binding(get: { state.devDailyCapOff }, set: { state.devSetDailyCap(off: $0) }))
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
                        Picker("Tier", selection: Binding(get: { state.devAscensionTier ?? -1 }, set: { state.devAscensionTier = $0 < 0 ? nil : $0 })) {
                            Text("Live").tag(-1); Text("Base").tag(0); Text("I").tag(1); Text("II").tag(2)
                        }
                        .pickerStyle(.segmented)
                        Text("Doc 38: shows the chosen Ascension tier everywhere the character appears, without levelling. Live follows the ledger.")
                            .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                    }
                    section("Challenges") {
                        row("Today", value: state.todayOffer.map { "open · \($0.challengeID.rawValue)" } ?? "none open")
                        row("Available", value: "\(state.availableChallenges.count) of \(state.bundle.challenges.count)")
                        row("Held beat", value: state.heldBeat?.id.rawValue ?? "none")
                        Button("Offer a challenge now") { state.devOfferChallenge() }.buttonStyle(SecondaryButtonStyle())
                            .disabled(state.availableChallenges.isEmpty)
                        Picker("Outcome", selection: Binding(get: { state.devForcedOutcome.map { $0 ? 1 : 2 } ?? 0 }, set: { state.devForcedOutcome = $0 == 0 ? nil : $0 == 1 })) {
                            Text("Roll").tag(0); Text("Force win").tag(1); Text("Force loss").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                    section("Boss") {
                        let shares = state.combatShares
                        row("Shares S/E/K/M", value: String(format: "%.2f / %.2f / %.2f / %.2f", shares.strength, shares.endurance, shares.knowledge, shares.mindfulness))
                        if let boss = state.bundle.bosses.first { row("Attempts", value: "\(state.bossAttempts(boss))") }
                        Button("Fight Colossus now") { state.devBossRequest = state.bundle.bosses.first; dismiss() }.buttonStyle(SecondaryButtonStyle())
                            .disabled(state.bundle.bosses.isEmpty || state.ruleset.bossCombat == nil)
                        Button("Rehearse combat animations") { state.devBossRehearsal = true; state.devBossRequest = state.bundle.bosses.first; dismiss() }.buttonStyle(SecondaryButtonStyle())
                            .disabled(state.bundle.bosses.isEmpty || state.ruleset.bossCombat == nil)
                        Text("Opens the fight with your real stats and today's training, ignoring the Level 10 and three-gym-runs gate. Winning plays the resolution beat only if that gate is met.")
                            .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
                    }
                    section("Account") {
                        // HER-14: both restore paths without reinstalling. Fresh install keeps the keychain session (the
                        // snapshot should come straight back); Forget session starts a new guest ("Already have a character?").
                        row("Status", value: accountLabel)
                        Button("Simulate fresh install (keep session)") { Task { await state.devSimulateFreshInstall() }; dismiss() }.buttonStyle(SecondaryButtonStyle())
                        Button("Forget session and start over") { Task { await state.devForgetSession() }; dismiss() }.buttonStyle(SecondaryButtonStyle())
                        Text("Both wipe this phone's data. The server keeps everything; the first should restore your character within seconds, the second needs Apple sign-in on the name step.")
                            .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
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

    private var accountLabel: String {
        let status: String
        switch state.accountStatus { case .apple: status = "Apple"; case .guest: status = "guest"; case .offline: status = "offline" }
        return "\(status) · \(state.pendingUploadCount) pending" + (state.lastSyncError.map { " · \($0)" } ?? "")
    }

    private var questLabel: String {
        switch state.questState {
        case .locked: return "locked"
        case .ready: return "ready"
        case let .away(run): return "away · back \(Countdown.format(max(0, run.returnsAt.timeIntervalSince(state.now))))"
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

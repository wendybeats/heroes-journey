import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import HeroDomain
import HeroContent

/// Doc 19 "fitness first": the utility (today, this week, log) carries the screen. The
/// character is present and reacts, but sits in a compact scene rather than dominating.
struct HomeView: View {
    /// Idle sprite scale in points: the original 2 pt per sprite pixel (6 device px on 3x), 128×256 pt for the
    /// 64×128 cell. Owner 2026-10-06: the smaller size was meant for the walking quest only, not the idle.
    static let characterScale: CGFloat = 2
    /// Departure walk scale: 4 device px per sprite pixel (a third smaller), crisp on 3x displays.
    static var walkScale: CGFloat { 4 / displayScale }
    static var displayScale: CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.scale
        #else
        return 2
        #endif
    }
    @Environment(AppState.self) private var state
    @State private var showLog = false
    @State private var showHistory = false
    @State private var showWorkout = false
    @State private var departure: QuestRun?
    /// What the numbers currently show. Held at the pre-receipt values while the reward modal is
    /// up, then animated to the real snapshot when it closes (doc 02: reward, then visible change).
    @State private var shown: ProgressSnapshot?
    @State private var deltas: [AttributeID: Int] = [:]
    @State private var xpDelta = 0
    @State private var deltaToken = 0
    @State private var levelUpStart: Date?
    @State private var levelFlash = false
    @State private var ascension: (start: Date, from: Int, to: Int, name: String)?
    @State private var barFill: Double = 0
    /// The chapter being played from Home (doc 28): a due milestone's scene, or a quest's end scene.
    @State private var storyScene: StoryScene?
    @State private var chaining = false
    @State private var showRoom = false
    @State private var clash: AppState.ChallengeOutcome?
    @State private var bossFight: BossFight?
    @State private var toast: ToastItem?
    /// Toasts wait until Home is quiet again (owner 2026-10-12: they were firing under the next scene).
    @State private var pendingToasts: [ToastItem] = []
    #if DEBUG
    @State private var showDev = false
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// The screen's content. Its own view: the body with every presentation and hook inline is more than the type
    /// checker will take (CI 2026-10-16, twice), so content, presentations and director hooks are three pieces.
    private var scroll: some View {
        let snapshot = shown ?? state.snapshot
        return ScrollView {
            VStack(spacing: NeoTokyo.Spacing.lg) {
                // Home v2 (doc 24): the scene bleeds under the status bar and off the top edge; the
                // companion world comes first, then today's goals, then progression, then utility.
                sceneCard(snapshot)
                VStack(spacing: NeoTokyo.Spacing.lg) {
                    offerSlot
                    if let toast {
                        ToastBanner(item: toast)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    attributesRow(snapshot)
                    GoalsCard()
                    storyCard
                    todayCard
                    weekCard
                }
                .padding(.horizontal, NeoTokyo.Spacing.lg)
                .animation(.spring(duration: 0.55, bounce: 0.2), value: state.todayOffer?.challengeID)
                .animation(.spring(duration: 0.45, bounce: 0.25), value: toast?.id)
            }
            .padding(.bottom, 96)
        }
        .ignoresSafeArea(edges: .top)
        .background(NeoTokyo.Surface.base)
    }

    var body: some View {
        hooks(presented)
    }

    /// The navigation stack with every sheet, cover and overlay. Hooks are applied separately (`hooks`).
    private var presented: some View {
        NavigationStack {
            scroll
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
            // Owner 2026-10-12: a glass bottom nav (history · + · room) instead of a top bar over the XP row; one FAB logs anything.
            .safeAreaInset(edge: .bottom) { bottomNav }
            .sheet(isPresented: $showLog) {
                LogSheet(onTrackWorkout: {
                    showLog = false
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(450)); showWorkout = true }
                })
            }
            .fullScreenCover(isPresented: $showWorkout) { WorkoutView() }
            .sheet(isPresented: $showHistory) { HistoryView() }
            .fullScreenCover(item: $departure) { run in DepartureView(run: run) }
            .fullScreenCover(isPresented: Binding(get: { state.needsStage }, set: { if !$0 { state.dismissStage() } })) { StageView() }
            .fullScreenCover(item: $storyScene) { scene in
                StoryView(chapter: scene.chapter, heroRecipe: state.recipe) {
                    storyScene = nil
                    // A chained chapter plays next on its own backdrop; the milestone completes after the chain.
                    if let nextID = scene.chapter.nextChapter, let next = state.bundle.chapter(nextID) {
                        chaining = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(650))
                            storyScene = StoryScene(chapter: next, milestone: scene.milestone); chaining = false
                        }
                        return
                    }
                    // Recorded on finish, so an interrupted scene replays rather than being lost (idempotent).
                    if scene.completesAscension {
                        let name = state.evolution?.displayName ?? "Ascension"
                        state.clearPendingAscension()
                        showToast(ToastItem(text: "Ascended · \(name)", symbol: "arrow.up.circle.fill", style: .gold, holdSeconds: 2.2))
                    } else if let milestone = scene.milestone {
                        state.completeMilestone(milestone)
                        if milestone.unlockQuest != nil || milestone.unlockBackdrop != nil {
                            showToast(ToastItem(text: "New quest area unlocked", symbol: "checkmark.circle.fill"))
                        }
                    } else { state.clearPendingReturnChapter() }
                    // `then: room` (chapter.home): land in the room the chapter just gave you.
                    if scene.chapter.then == "room" { Task { try? await Task.sleep(for: .milliseconds(500)); showRoom = true } }
                }
            }
            .sheet(isPresented: $showRoom) { RoomView() }
            .fullScreenCover(item: $clash) { outcome in ChallengeClashView(outcome: outcome) { clash = nil } }
            .fullScreenCover(item: $bossFight) { fight in
                BossView(fight: fight) { result in
                    bossFight = nil
                    // Won: the beat plays (its chapter closes the area). Lost: nothing is lost; the hint was on the result card.
                    if result == .won, let milestone = fight.milestone {
                        Task { @MainActor in try? await Task.sleep(for: .milliseconds(500)); playMilestone(milestone) }
                    }
                }
            }
            .onChange(of: state.devBossRequest?.id) { _, id in
                guard id != nil, let boss = state.devBossRequest, let encounter = state.startBossEncounter(boss) else { return }
                state.devBossRequest = nil
                bossFight = BossFight(encounter: encounter, milestone: boss.milestoneID.flatMap { state.campaign.milestone($0) }, rehearsal: state.devBossRehearsal)
                state.devBossRehearsal = false
            }
            #if DEBUG
            .sheet(isPresented: $showDev) { DevControlsView() }
            #endif
            .overlayPreferenceValue(SceneAnchorsKey.self) { anchors in
                GeometryReader { geo in
                    if let start = levelUpStart, let c = anchors["character"], let b = anchors["badge"] {
                        let cr = geo[c], br = geo[b]
                        LevelUpOverlay(start: start, characterCenter: CGPoint(x: cr.midX, y: cr.midY), badgeCenter: CGPoint(x: br.midX, y: br.midY))
                    }
                    if let a = ascension, let recipe = state.recipe, let c = anchors["character"] {
                        AscensionOverlay(start: a.start, recipe: recipe, fromTier: a.from, toTier: a.to, evolutionName: a.name, sceneFrame: geo[c])
                    }
                }
            }
            .overlay { moments }
            .animation(.easeInOut(duration: 0.25), value: momentKey)
        }
    }

    /// Everything the director waits on, as one key: any change is a chance to play the next beat (doc 28). One
    /// `onChange` instead of eleven; the chain of them was more than the type checker takes (CI 2026-10-16).
    private var directorKey: String {
        "\(state.lastReceipt == nil)|\(state.healthWelcome == nil)|\(levelUpStart == nil)|\(ascension == nil)|\(state.needsStage)|"
            + "\(state.pendingReturnScene?.id ?? "")|\(state.pendingAscension?.toTier ?? -1)|\(storyScene == nil)|\(departure == nil)|\(clash == nil)|"
            + "\(state.unclaimedQuest?.id.uuidString ?? "")"
    }

    /// The director's and the ledger's hooks on the screen, split from `presented` so each type-checks on its own.
    private func hooks<V: View>(_ view: V) -> some View {
        view
        // Day-one Health credit (owner QA 2026-10-16): the numbers hold at the pre-credit values until the welcome card is dismissed.
        .onAppear { if shown == nil { let s = state.healthWelcome?.before ?? state.snapshot; shown = s; barFill = levelProgress(s) }; scheduleStory() }
        // The director waits for a quiet screen: no reward modal, no level-up or ascension, no stage,
        // nothing presented. Each of these settling is a chance to play the next beat.
        .onChange(of: directorKey) { _, _ in scheduleStory() }
        .onChange(of: state.lastWorldReaction) { _, name in if let name { state.lastWorldReaction = nil; showToast(ToastItem(text: name, symbol: "cloud.sun.fill")) } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { state.ensureTodayPlan(); state.resolveQuestIfDue(); Task { await state.syncHealth() } } }
        .onChange(of: state.showDeparture) { _, show in
            if show, let run = state.activeQuest ?? state.unclaimedQuest { departure = run; state.showDeparture = false }
        }
        .task(id: "\(state.activeQuest?.id.uuidString ?? "")|\(state.devDayOffset)") {   // re-armed when the dev clock moves
            // Resolve on time while the app stays in the foreground; the notification covers the rest.
            guard let run = state.activeQuest else { return }
            try? await Task.sleep(for: .seconds(max(0.5, run.remaining(at: state.now))))
            state.resolveQuestIfDue()
        }
        .onChange(of: state.snapshot) { _, new in
            // Sync silently unless a reward is showing (then wait for dismissal).
            // While an Ascension waits, the badge and bar hold the old level: the takeover is the reveal.
            if state.lastReceipt == nil && state.pendingAscension == nil && state.healthWelcome == nil { shown = new; barFill = levelProgress(new) }
        }
        .onChange(of: state.rewardToken) { _, _ in rewardDismissed() }
    }

    /// After a reward modal (or the day-one Health card) closes: the numbers animate to the real snapshot, with the
    /// level-up sequence when the level rose (doc 02).
    private func rewardDismissed() {
            let new = state.snapshot
            let old = shown ?? new
            xpDelta = new.totalXP - old.totalXP
            deltas = Dictionary(uniqueKeysWithValues: new.attributes.map { ($0.key, $0.value - (old.attributes[$0.key] ?? 0)) })
            deltaToken += 1
            if state.pendingAscension != nil {
                // The Ascension takeover plays when the screen is quiet (director, below); hold the old level until its reveal.
            } else if new.level > old.level && !reduceMotion {
                // Doc 02 reward moment, extended (owner, 2026-09-29): aura, star burst, then the counter.
                levelUpStart = Date()
                Task {
                    try? await Task.sleep(for: .milliseconds(Int(LevelUpOverlay.counterDelay * 1000)))
                    levelFlash = true
                    withAnimation(.easeOut(duration: 1.0)) { shown = new }
                    await wrapBar(to: levelProgress(new))
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation(.easeOut(duration: 0.6)) { levelFlash = false }
                    try? await Task.sleep(for: .milliseconds(600))
                    levelUpStart = nil
                    showToast(ToastItem(text: "Level \(new.level)", symbol: "arrow.up.circle.fill"))
                }
            } else {
                withAnimation(.easeOut(duration: 1.2)) { shown = new; barFill = levelProgress(new) }
            }
    }

    /// The reward modal, or the day-one Health card (owner QA 2026-10-16); never both.
    @ViewBuilder
    private var moments: some View {
        if let receipt = state.lastReceipt { RewardMoment(receipt: receipt) }
        else if let welcome = state.healthWelcome { HealthWelcomeMoment(welcome: welcome) }
    }
    private var momentKey: Int { (state.lastReceipt == nil ? 0 : 1) + (state.healthWelcome == nil ? 0 : 2) }

    // MARK: story director (doc 28)

    private var storyIdle: Bool {
        state.lastReceipt == nil && state.healthWelcome == nil && ascension == nil && levelUpStart == nil && !state.needsStage && state.unclaimedQuest == nil
            && departure == nil && storyScene == nil && clash == nil && !chaining && !showWorkout && !showLog && !showHistory && !showRoom
    }

    /// Present the next scene once the screen has settled. The delay lets a dismissal finish before
    /// the next cover is presented; presenting while one is animating away is dropped by UIKit.
    private func scheduleStory() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            presentStoryIfIdle()
        }
    }

    private func presentStoryIfIdle() {
        guard storyIdle else { return }
        // Owner 2026-10-06: an Ascension outranks every other beat. The takeover plays, then its scene, then the level's story.
        if let pending = state.pendingAscension { playAscension(pending); return }
        // A quest's end scene plays first (after its return reveal), then any beat the level has reached.
        if let chapter = state.pendingReturnScene {
            storyScene = StoryScene(chapter: chapter, milestone: nil)
            return
        }
        guard let milestone = state.nextStoryBeat else { flushToasts(); return }
        if let id = milestone.storyChapter, let chapter = state.bundle.chapter(id) {
            storyScene = StoryScene(chapter: chapter, milestone: milestone)
        } else {
            state.completeMilestone(milestone)   // a beat without a scene: apply its unlocks silently
        }
    }

    /// The Ascension takeover (doc 32): scrim, gold, the tier flips at the reveal, the counter and bar catch up,
    /// then the evolution's scene. Reduce Motion skips the overlay and goes straight to the scene.
    private func playAscension(_ pending: AppState.PendingAscension) {
        let new = state.snapshot
        guard state.recipe != nil, !reduceMotion else {
            shown = new; barFill = levelProgress(new); afterAscension(pending); return
        }
        ascension = (Date(), pending.fromTier, pending.toTier, pending.evolutionName)
        Task {
            try? await Task.sleep(for: .milliseconds(Int(AscensionOverlay.revealAt * 1000)))
            levelFlash = true
            shown = new
            await wrapBar(to: levelProgress(new))
            try? await Task.sleep(for: .milliseconds(Int((AscensionOverlay.duration - AscensionOverlay.revealAt) * 1000) - 1300))
            withAnimation(.easeOut(duration: 0.6)) { levelFlash = false }
            afterAscension(pending)   // the scene is presented before the overlay clears, so the director cannot replay it
            ascension = nil
        }
    }

    private func afterAscension(_ pending: AppState.PendingAscension) {
        if let id = pending.chapterID, let chapter = state.bundle.chapter(id) {
            storyScene = StoryScene(chapter: chapter, milestone: nil, completesAscension: true)
        } else {
            state.clearPendingAscension()
        }
    }

    /// Glass bottom nav (owner 2026-10-12): a short bar with even slots, the FAB poking out of the top. The room
    /// slot is always there (dimmed until the story opens it) so nothing sits off to one side.
    private var bottomNav: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                navButton("clock.arrow.circlepath", label: "History") { showHistory = true }
                #if DEBUG
                navButton("wrench.and.screwdriver", label: "Dev controls", muted: true) { showDev = true }
                #endif
                Color.clear.frame(maxWidth: .infinity).frame(height: 44)   // the FAB's slot
                navButton("house", label: "Room", muted: !state.hasFeature("home_room")) { if state.hasFeature("home_room") { showRoom = true } }
                    .disabled(!state.hasFeature("home_room"))
            }
            .padding(.horizontal, NeoTokyo.Spacing.sm)
            .padding(.top, NeoTokyo.Spacing.sm)
            .padding(.bottom, NeoTokyo.Spacing.xs)
            .glass(cornerRadius: NeoTokyo.Radius.lg, tint: NeoTokyo.Surface.overlay)
            .padding(.top, 22)
            Button { showLog = true } label: {
                ZStack {
                    Circle().fill(NeoTokyo.Accent.button)
                    Circle().strokeBorder(NeoTokyo.Text.primary.opacity(0.55), lineWidth: 1.5)
                    Circle().fill(LinearGradient(colors: [NeoTokyo.Text.primary.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                    Image(systemName: "plus").font(.system(size: 28, weight: .semibold)).foregroundStyle(NeoTokyo.Text.onAccent)
                }
                .frame(width: 64, height: 64)
                .shadow(color: NeoTokyo.Surface.scrim.opacity(0.7), radius: 14, y: 6)
                .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.18), radius: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log")
        }
        .padding(.horizontal, NeoTokyo.Spacing.lg)
        .padding(.bottom, NeoTokyo.Spacing.xs)
    }

    private func navButton(_ symbol: String, label: String, muted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(HeroFont.headline)
                .foregroundStyle(muted ? NeoTokyo.Text.muted : NeoTokyo.Text.secondary)
                .frame(maxWidth: .infinity).frame(height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: toasts (owner 2026-10-12): quick, above the stats, slide in and out

    /// Queue a toast; it shows once nothing else is on screen and no beat is about to play (the director calls back).
    private func showToast(_ item: ToastItem) {
        pendingToasts.append(item)
        flushToasts()
    }

    private func flushToasts() {
        guard toast == nil, storyIdle, state.pendingAscension == nil, state.pendingReturnScene == nil, state.nextStoryBeat == nil, !pendingToasts.isEmpty else { return }
        let item = pendingToasts.removeFirst()
        withAnimation(.spring(duration: 0.45, bounce: 0.25)) { toast = item }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(item.holdSeconds * 1000)))
            if toast?.id == item.id { withAnimation(.easeIn(duration: 0.3)) { toast = nil } }
            try? await Task.sleep(for: .milliseconds(400))
            flushToasts()
        }
    }

    /// Doc 33 (owner build notes 2026-10-12): today's challenge offer overlaps the foot of the scene and slides in.
    /// Owner QA 2026-10-16: a boss offer takes that slot in the same shape; the challenge then sits below it.
    /// Its own view: inline, the branch pushed the body past what the type checker will take.
    @ViewBuilder
    private var offerSlot: some View {
        let bossBeat = state.offeredMilestones.first { state.bundle.boss(forMilestone: $0.id) != nil }
        if let milestone = bossBeat {
            BossCard(milestone: milestone) { startMilestone(milestone) }
                .padding(.top, -96)
            ChallengeCard { if let outcome = state.acceptChallenge() { clash = outcome } }
        } else {
            ChallengeCard { if let outcome = state.acceptChallenge() { clash = outcome } }
                .padding(.top, -96)
        }
    }

    /// Manual beats without a boss wait on this card until the player starts them (a boss beat has `BossCard`, above).
    @ViewBuilder
    private var storyCard: some View {
        if let milestone = state.offeredMilestones.first, state.bundle.boss(forMilestone: milestone.id) == nil {
            VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
                Eyebrow(text: state.currentChapter?.displayName ?? "Story")
                Text(milestone.triggerLabel ?? "Continue").font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                Text("When you're ready. It waits for you.").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                Button(milestone.triggerLabel ?? "Continue") { startMilestone(milestone) }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    /// Start a manual beat. Doc 36/37: a boss stands behind the beat; the scene plays only once he is down.
    private func startMilestone(_ milestone: Milestone) {
        if let boss = state.bundle.boss(forMilestone: milestone.id), let encounter = state.startBossEncounter(boss) {
            bossFight = BossFight(encounter: encounter, milestone: milestone)
        } else {
            playMilestone(milestone)
        }
    }

    private func playMilestone(_ milestone: Milestone) {
        if let id = milestone.storyChapter, let chapter = state.bundle.chapter(id) {
            storyScene = StoryScene(chapter: chapter, milestone: milestone)
        } else {
            state.completeMilestone(milestone)
        }
    }

    /// Fill to the end, snap to zero without animation, fill to the new value (never slides backwards).
    private func wrapBar(to target: Double) async {
        withAnimation(.easeIn(duration: 0.45)) { barFill = 1 }
        try? await Task.sleep(for: .milliseconds(500))
        var noAnimation = Transaction(); noAnimation.disablesAnimations = true
        withTransaction(noAnimation) { barFill = 0 }
        try? await Task.sleep(for: .milliseconds(60))
        withAnimation(.easeOut(duration: 0.8)) { barFill = target }
    }

    // MARK: character scene (compact)

    private func sceneCard(_ snapshot: ProgressSnapshot) -> some View {
        ZStack(alignment: .bottom) {
            BackdropImage(assetSetID: state.recipe?.backdropID ?? "backdrop.rain_district")
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.86), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            // Character stands on the road: bottom-centre, 20% smaller than the 2x sprite scale.
            if let recipe = state.recipe {
                // Outfit follows the *displayed* level so the swap lands with the counter during the level-up sequence.
                CharacterView(recipe: recipe, scale: HomeView.characterScale, ascension: state.bundle.evolution(forLevel: snapshot.level)?.ascensionTier ?? 0)
                    .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.35), radius: 16)  // the character's own glow
                    .padding(.bottom, NeoTokyo.Spacing.xl)
                    .opacity(state.characterAway ? 0 : 1)   // out on the quest: the scene stays, the character is gone
                    .anchorPreference(key: SceneAnchorsKey.self, value: .bounds) { ["character": $0] }
            }
            if case let .away(run) = state.questState {
                Button { departure = run } label: {
                    VStack(spacing: NeoTokyo.Spacing.xs) {
                        Eyebrow(text: "Away · tap to look")
                        Countdown(until: run.returnsAt, font: HeroFont.statSM)
                    }
                    .padding(NeoTokyo.Spacing.md)
                    .glass(tint: NeoTokyo.Surface.overlay)
                }
                .buttonStyle(.plain)
                .padding(.bottom, NeoTokyo.Spacing.xl)
            } else if let run = state.unclaimedQuest {
                // Back with a cache (doc 29): the reveal waits on the quest screen until the player opens it.
                Button { departure = run } label: {
                    HStack(spacing: NeoTokyo.Spacing.sm) {
                        CacheIcon(tier: state.rewardTier(for: run), glowing: true).frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Eyebrow(text: "Back")
                            Text("Open the cache").font(HeroFont.bodyMedium).foregroundStyle(NeoTokyo.Text.primary)
                        }
                    }
                    .padding(NeoTokyo.Spacing.md)
                    .glass(tint: NeoTokyo.Surface.overlay)
                }
                .buttonStyle(.plain)
                .padding(.bottom, NeoTokyo.Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 440)
        // Owner 2026-10-06 / 2026-10-12: XP and level are part of the scene, not a card, and they sit at the top of it
        // (under the toolbar row) so the character keeps the road. No background.
        .overlay(alignment: .top) {
            // Under the status bar and the Dynamic Island, over the world (owner QA 2026-10-12).
            progressRow(snapshot)
                .padding(.horizontal, NeoTokyo.Spacing.lg)
                .padding(.top, DeviceInsets.top + 16)
        }
    }

    // MARK: progression row (owner 2026-10-12: XP and level overlay the top of the scene, no background)

    private func progressRow(_ snapshot: ProgressSnapshot) -> some View {
        // XP left, the bar running across to the level badge right, so the bar reads as XP travelling toward the next level.
        HStack(alignment: .center, spacing: NeoTokyo.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                StatNumber(value: snapshot.totalXP, unit: "xp", accent: NeoTokyo.Hierarchy.primary, font: HeroFont.statMD)
                    .overlay(alignment: .topTrailing) { DeltaBadge(delta: xpDelta, token: deltaToken).offset(x: 28, y: -10) }
                Text(state.recipe?.name ?? "").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.secondary)
            }
            VStack(spacing: 4) {
                LevelBar(fill: barFill)
                if let next = state.ruleset.xpToNextLevel(fromTotalXP: snapshot.totalXP) {
                    Text("\(next) to go").font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            LevelBadge(level: snapshot.level, subtitle: state.bundle.evolution(forLevel: snapshot.level)?.displayName ?? "", flash: levelFlash)
                .anchorPreference(key: SceneAnchorsKey.self, value: .bounds) { ["badge": $0] }
        }
        .shadow(color: NeoTokyo.Surface.base.opacity(0.9), radius: 6)   // legibility over the backdrop without a panel
    }

    // MARK: attributes (under the scene, above the quest)

    private func attributesRow(_ snapshot: ProgressSnapshot) -> some View {
        HStack {
            ForEach(state.bundle.attributes, id: \.id) { attribute in
                VStack(spacing: 2) {
                    // Owner 2026-10-12: the glyph sits inline with every stat so the icon alone comes to mean it.
                    HStack(spacing: 4) {
                        Image(systemName: AttributeGlyph.symbol(for: attribute.id)).font(HeroFont.caption)
                        CountingText(value: Double(snapshot.attributes[attribute.id] ?? 0), font: HeroFont.statSM, color: NeoTokyo.Attribute.color(for: attribute.id.rawValue))
                    }
                    .foregroundStyle(NeoTokyo.Attribute.color(for: attribute.id.rawValue))
                    Text(attribute.displayName).font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                }
                .overlay(alignment: .top) {
                    DeltaBadge(delta: deltas[attribute.id] ?? 0, token: deltaToken, color: NeoTokyo.Attribute.color(for: attribute.id.rawValue))
                        .offset(y: -16)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, NeoTokyo.Spacing.md)
        .padding(.horizontal, NeoTokyo.Spacing.sm)
        .glass(tint: NeoTokyo.Surface.raised)
    }

    // MARK: progression (gold) — kept for the level-up sequence's anchors; no longer in the layout

    private func progressCard(_ snapshot: ProgressSnapshot) -> some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                StatNumber(value: snapshot.totalXP, unit: "xp", accent: NeoTokyo.Hierarchy.primary, font: HeroFont.statLG)
                DeltaBadge(delta: xpDelta, token: deltaToken)
                Spacer()
                if let next = state.ruleset.xpToNextLevel(fromTotalXP: snapshot.totalXP) {
                    Text("\(next) to Level \(snapshot.level + 1)").font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.secondary)
                }
            }
            LevelBar(fill: barFill)
            Divider().overlay(NeoTokyo.Surface.line)
            HStack {
                ForEach(state.bundle.attributes, id: \.id) { attribute in
                    VStack(spacing: 2) {
                        CountingText(value: Double(snapshot.attributes[attribute.id] ?? 0), font: HeroFont.statSM, color: NeoTokyo.Attribute.color(for: attribute.id.rawValue))
                        Text(attribute.displayName).font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                    }
                    .overlay(alignment: .top) {
                        DeltaBadge(delta: deltas[attribute.id] ?? 0, token: deltaToken, color: NeoTokyo.Attribute.color(for: attribute.id.rawValue))
                            .offset(y: -16)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .card()
    }

    // MARK: utility (numbers in white; owner decision 2026-09-28)

    /// Owner 2026-10-12: the week as a chart. One column per day; a lit glyph for each attribute that saw
    /// meaningful effort (ten minutes or more in a family that feeds it). The totals stay, smaller, underneath.
    private var weekCard: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            Eyebrow(text: "This week")
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(state.weekEffort.enumerated()), id: \.offset) { pair in
                    let day = pair.element
                    VStack(spacing: NeoTokyo.Spacing.xs) {
                        Text(day.day.formatted(.dateTime.weekday(.narrow)))
                            .font(HeroFont.label).foregroundStyle(day.isToday ? NeoTokyo.Text.primary : NeoTokyo.Text.muted)
                        VStack(spacing: 3) {
                            ForEach(state.bundle.attributes, id: \.id) { attribute in
                                let lit = day.attributes.contains(attribute.id)
                                Image(systemName: AttributeGlyph.symbol(for: attribute.id))
                                    .font(HeroFont.label)
                                    .foregroundStyle(lit ? NeoTokyo.Attribute.color(for: attribute.id.rawValue) : NeoTokyo.Surface.line)
                                    .opacity(lit ? 1 : 0.6)
                            }
                        }
                        .padding(.vertical, NeoTokyo.Spacing.xs)
                        .frame(maxWidth: .infinity)
                        .background(day.isToday ? NeoTokyo.Surface.overlay : .clear, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.sm, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: NeoTokyo.Spacing.lg) {
                StatNumber(value: state.weekMinutes, unit: "min", font: HeroFont.statSM)
                StatNumber(value: state.weekSessions, unit: state.weekSessions == 1 ? "session" : "sessions", font: HeroFont.statSM)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
            HStack {
                Eyebrow(text: "Today")
                Spacer()
                healthStatus
            }
            if let cap = state.ruleset.dailyActivityXPCap {
                HStack(spacing: NeoTokyo.Spacing.xs) {
                    Text("Activity XP today").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                    Spacer()
                    Text("\(min(cap, state.todayActivityXP)) / \(cap)").font(HeroFont.captionNumber).foregroundStyle(state.todayActivityXP >= cap ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.primary)
                }
            }
            if let steps = state.todaySteps {
                HStack(alignment: .firstTextBaseline, spacing: NeoTokyo.Spacing.xs) {
                    StatNumber(value: steps, unit: "steps")
                    Spacer()
                }
            }
            if state.todayEvents.isEmpty {
                Text("Nothing logged yet.").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.muted)
            } else {
                if state.pendingCount > 0 {
                    Text("\(state.pendingCount) waiting to sync").font(HeroFont.caption).foregroundStyle(NeoTokyo.Hierarchy.fallback)
                }
                ForEach(state.todayEvents, id: \.id) { event in
                    HStack {
                        Text(state.bundle.activityType(event.activityTypeID)?.displayName ?? event.activityTypeID.rawValue)
                            .font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                        ImportBadge(disposition: state.importDisposition(for: event))
                        Spacer()
                        Text("\(event.durationSeconds / 60) min").font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Text.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder
    private var healthStatus: some View {
        switch state.healthSync.authorization {
        case .notRequested where state.healthAvailable:
            Button("Connect Apple Health") { Task { await state.connectHealth() } }
                .font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Hierarchy.fallback)
        case .requested:
            if let at = state.healthSync.lastSyncAt {
                Text("Health · \(at.formatted(.relative(presentation: .named)))").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
            } else if let err = state.healthSync.lastError {
                Text("Health · \(err.prefix(40))").font(HeroFont.caption).foregroundStyle(NeoTokyo.Hierarchy.destructive)
            }
        default:
            EmptyView()
        }
    }

    private func levelProgress(_ snapshot: ProgressSnapshot) -> Double {
        let thresholds = state.ruleset.levelThresholdsTotalXP
        let index = snapshot.level - 1
        guard index + 1 < thresholds.count else { return 1 }
        let lo = thresholds[index], hi = thresholds[index + 1]
        return hi > lo ? Double(snapshot.totalXP - lo) / Double(hi - lo) : 1
    }
}

/// Two-or-three shade backdrop that dithers into the app background at the edges (doc 18/19).
struct SceneBackdrop: View {
    let shades: [Color]
    var body: some View {
        Canvas { context, size in
            Self.draw(in: &context, size: size, shades: shades)
        }
    }

    /// Kept out of the ViewBuilder closure so the type checker sees plain, explicitly typed statements.
    private static func draw(in context: inout GraphicsContext, size: CGSize, shades: [Color]) {
        let bands: Int = max(2, shades.count)
        let bandHeight: CGFloat = size.height / CGFloat(bands)
        for (i, shade) in shades.prefix(bands).enumerated() {
            let rect = CGRect(x: 0, y: CGFloat(i) * bandHeight, width: size.width, height: bandHeight + 1)
            context.fill(Path(rect), with: .color(shade))
        }
        // Ordered-dither fade into surface.base on all four edges, 4 px cells.
        let cell: CGFloat = 4
        let fade: CGFloat = 40
        let fill: GraphicsContext.Shading = .color(NeoTokyo.Surface.sceneFade)
        var y: CGFloat = 0
        while y < size.height {
            var x: CGFloat = 0
            while x < size.width {
                let distance: CGFloat = min(min(x, y), min(size.width - x, size.height - y))
                if distance < fade {
                    let cx: Int = Int(x / cell)
                    let cy: Int = Int(y / cell)
                    let threshold: CGFloat = CGFloat((cx * 7 + cy * 13) % 16) / 16
                    if distance / fade < threshold {
                        context.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)), with: fill)
                    }
                }
                x += cell
            }
            y += cell
        }
    }
}

/// A chapter being played from Home, with the milestone it completes (nil for a quest's end scene).
struct StoryScene: Identifiable {
    let chapter: ContentBundle.StoryChapter
    let milestone: Milestone?
    /// The scene that follows an Ascension takeover; dismissing it clears the pending Ascension.
    var completesAscension = false
    var id: String { chapter.id }
}

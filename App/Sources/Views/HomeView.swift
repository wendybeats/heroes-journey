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
    #if DEBUG
    @State private var showDev = false
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let snapshot = shown ?? state.snapshot
        NavigationStack {
            ScrollView {
                VStack(spacing: NeoTokyo.Spacing.lg) {
                    // Home v2 (doc 24): the scene bleeds under the status bar and off the top edge; the
                    // companion world comes first, then today's goals, then progression, then utility.
                    sceneCard(snapshot)
                    VStack(spacing: NeoTokyo.Spacing.lg) {
                        VStack(spacing: NeoTokyo.Spacing.sm) {
                            progressRow(snapshot)
                            attributesRow(snapshot)
                        }
                        GoalsCard()
                        storyCard
                        todayCard
                        weekCard
                    }
                    .padding(.horizontal, NeoTokyo.Spacing.lg)
                }
                .padding(.bottom, 96)
            }
            .ignoresSafeArea(edges: .top)
            .background(NeoTokyo.Surface.base)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }
                        .foregroundStyle(NeoTokyo.Text.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // The room arrives with the story (milestone `unlock_feature: home_room`), not at install.
                    if state.hasFeature("home_room") {
                        Button { showRoom = true } label: { Image(systemName: "house") }
                            .foregroundStyle(NeoTokyo.Text.secondary)
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Button { showDev = true } label: { Image(systemName: "wrench.and.screwdriver") }
                        .foregroundStyle(NeoTokyo.Text.muted)
                }
                #endif
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: NeoTokyo.Spacing.sm) {
                    Button(state.activeWorkout == nil ? "Start workout" : "Resume workout") { showWorkout = true }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Log activity") { showLog = true }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, NeoTokyo.Spacing.lg)
                .padding(.bottom, NeoTokyo.Spacing.sm)
                .background(NeoTokyo.Surface.base.opacity(0.92))
            }
            .sheet(isPresented: $showLog) { LogSheet() }
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
                    if let milestone = scene.milestone { state.completeMilestone(milestone) } else { state.clearPendingReturnChapter() }
                    // `then: room` (chapter.home): land in the room the chapter just gave you.
                    if scene.chapter.then == "room" { Task { try? await Task.sleep(for: .milliseconds(500)); showRoom = true } }
                }
            }
            .sheet(isPresented: $showRoom) { RoomView() }
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
            .overlay { if let receipt = state.lastReceipt { RewardMoment(receipt: receipt) } }
            .animation(.easeInOut(duration: 0.25), value: state.lastReceipt == nil)
        }
        .onAppear { if shown == nil { shown = state.snapshot; barFill = levelProgress(state.snapshot) }; scheduleStory() }
        // The director waits for a quiet screen: no reward modal, no level-up or ascension, no stage,
        // nothing presented. Each of these settling is a chance to play the next beat.
        .onChange(of: state.lastReceipt == nil) { _, _ in scheduleStory() }
        .onChange(of: levelUpStart == nil) { _, _ in scheduleStory() }
        .onChange(of: ascension == nil) { _, _ in scheduleStory() }
        .onChange(of: state.needsStage) { _, _ in scheduleStory() }
        .onChange(of: state.pendingReturnChapter) { _, _ in scheduleStory() }
        .onChange(of: storyScene == nil) { _, _ in scheduleStory() }
        .onChange(of: departure == nil) { _, _ in scheduleStory() }
        .onChange(of: state.unclaimedQuest?.id) { _, _ in scheduleStory() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { state.ensureTodayPlan(); state.resolveQuestIfDue(); Task { await state.syncHealth() } } }
        .onChange(of: state.showDeparture) { _, show in
            if show, let run = state.activeQuest ?? state.unclaimedQuest { departure = run; state.showDeparture = false }
        }
        .task(id: state.activeQuest?.id) {
            // Resolve on time while the app stays in the foreground; the notification covers the rest.
            guard let run = state.activeQuest else { return }
            try? await Task.sleep(for: .seconds(max(0.5, run.remaining(at: Date()))))
            state.resolveQuestIfDue()
        }
        .onChange(of: state.snapshot) { _, new in
            // Sync silently unless a reward is showing (then wait for dismissal).
            if state.lastReceipt == nil { shown = new; barFill = levelProgress(new) }
        }
        .onChange(of: state.rewardToken) { _, _ in
            let new = state.snapshot
            let old = shown ?? new
            xpDelta = new.totalXP - old.totalXP
            deltas = Dictionary(uniqueKeysWithValues: new.attributes.map { ($0.key, $0.value - (old.attributes[$0.key] ?? 0)) })
            deltaToken += 1
            let oldEv = state.bundle.evolution(forLevel: old.level), newEv = state.bundle.evolution(forLevel: new.level)
            if new.level > old.level && oldEv?.id != newEv?.id && !reduceMotion {
                // Ascension (doc 32): a tier, not an outfit. The eyes and the field change under the overlay at the reveal.
                ascension = (Date(), oldEv?.ascensionTier ?? 0, newEv?.ascensionTier ?? 0, newEv?.displayName ?? "")
                Task {
                    try? await Task.sleep(for: .milliseconds(Int(AscensionOverlay.revealAt * 1000)))
                    levelFlash = true
                    shown = new
                    await wrapBar(to: levelProgress(new))
                    try? await Task.sleep(for: .milliseconds(Int((AscensionOverlay.duration - AscensionOverlay.revealAt) * 1000) - 1300))
                    withAnimation(.easeOut(duration: 0.6)) { levelFlash = false }
                    ascension = nil
                }
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
                }
            } else {
                withAnimation(.easeOut(duration: 1.2)) { shown = new; barFill = levelProgress(new) }
            }
        }
    }

    // MARK: story director (doc 28)

    private var storyIdle: Bool {
        state.lastReceipt == nil && ascension == nil && levelUpStart == nil && !state.needsStage && state.unclaimedQuest == nil
            && departure == nil && storyScene == nil && !chaining && !showWorkout && !showLog && !showHistory && !showRoom
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
        // A quest's end scene plays first (after its return reveal), then any beat the level has reached.
        if let id = state.pendingReturnChapter {
            if let chapter = state.bundle.chapter(id) { storyScene = StoryScene(chapter: chapter, milestone: nil) } else { state.clearPendingReturnChapter() }
            return
        }
        guard let milestone = state.nextStoryBeat else { return }
        if let id = milestone.storyChapter, let chapter = state.bundle.chapter(id) {
            storyScene = StoryScene(chapter: chapter, milestone: milestone)
        } else {
            state.completeMilestone(milestone)   // a beat without a scene: apply its unlocks silently
        }
    }

    /// Manual beats (boss encounters) wait on the card until the player starts them.
    @ViewBuilder
    private var storyCard: some View {
        if let milestone = state.offeredMilestones.first {
            VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
                Eyebrow(text: state.currentChapter?.displayName ?? "Story")
                Text(milestone.triggerLabel ?? "Continue").font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                Text("When you're ready. It waits for you.").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                Button(milestone.triggerLabel ?? "Continue") {
                    if let id = milestone.storyChapter, let chapter = state.bundle.chapter(id) {
                        storyScene = StoryScene(chapter: chapter, milestone: milestone)
                    } else {
                        state.completeMilestone(milestone)
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
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
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.86), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: progression row (owner 2026-10-06: XP and level sit under the scene, above the attributes)

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
        .padding(.horizontal, NeoTokyo.Spacing.md)
        .padding(.vertical, NeoTokyo.Spacing.sm)
        .glass(tint: NeoTokyo.Surface.raised)
        .padding(.top, -NeoTokyo.Spacing.xl)   // tucks up under the character's feet
    }

    // MARK: attributes (under the progression row, above the quest)

    private func attributesRow(_ snapshot: ProgressSnapshot) -> some View {
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

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            Eyebrow(text: "This week")
            HStack(alignment: .firstTextBaseline, spacing: NeoTokyo.Spacing.xl) {
                StatNumber(value: state.weekMinutes, unit: "min")
                StatNumber(value: state.weekSessions, unit: state.weekSessions == 1 ? "session" : "sessions")
                Spacer()
            }
            let byFamily = state.weekMinutesByFamily
            if !byFamily.isEmpty {
                VStack(spacing: NeoTokyo.Spacing.xs) {
                    ForEach(byFamily, id: \.family.id) { entry in
                        HStack {
                            Text(entry.family.displayName).font(HeroFont.callout).foregroundStyle(NeoTokyo.Text.primary)
                            Spacer()
                            Text("\(entry.minutes) min").font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.secondary)
                        }
                    }
                }
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
    var id: String { chapter.id }
}

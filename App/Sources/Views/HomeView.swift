import SwiftUI
import HeroDomain
import HeroContent

/// Doc 19 "fitness first": the utility (today, this week, log) carries the screen. The
/// character is present and reacts, but sits in a compact scene rather than dominating.
struct HomeView: View {
    /// Sprite scale in the scene: whole numbers only (kit rule). 2x with a taller card keeps the backdrop readable.
    static let characterScale: CGFloat = 2
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
    @State private var ascension: (start: Date, from: String?, to: String?, name: String)?
    @State private var barFill: Double = 0
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
                        GoalsCard()
                        progressCard(snapshot)
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
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { SpriteLabView() } label: { Image(systemName: "square.grid.3x3") }
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
            .overlayPreferenceValue(SceneAnchorsKey.self) { anchors in
                GeometryReader { geo in
                    if let start = levelUpStart, let c = anchors["character"], let b = anchors["badge"] {
                        let cr = geo[c], br = geo[b]
                        LevelUpOverlay(start: start, characterCenter: CGPoint(x: cr.midX, y: cr.midY), badgeCenter: CGPoint(x: br.midX, y: br.midY))
                    }
                    if let a = ascension, let recipe = state.recipe, let c = anchors["character"] {
                        AscensionOverlay(start: a.start, recipe: recipe, fromOutfit: a.from, toOutfit: a.to, evolutionName: a.name, sceneFrame: geo[c])
                    }
                }
            }
            .overlay { if let receipt = state.lastReceipt { RewardMoment(receipt: receipt) } }
            .animation(.easeInOut(duration: 0.25), value: state.lastReceipt == nil)
        }
        .onAppear { if shown == nil { shown = state.snapshot; barFill = levelProgress(state.snapshot) } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { state.ensureTodayPlan(); state.resolveQuestIfDue(); Task { await state.syncHealth() } } }
        .onChange(of: state.showDeparture) { _, show in
            if show, let run = state.activeQuest { departure = run; state.showDeparture = false }
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
                // Evolution: full-screen ascension. The scene swaps outfit under the overlay at the reveal.
                ascension = (Date(), oldEv?.outfit, newEv?.outfit, newEv?.displayName ?? "")
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
                CharacterView(recipe: recipe, outfit: state.bundle.evolution(forLevel: snapshot.level)?.outfit, scale: HomeView.characterScale)
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
            }
            VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
                Text(state.recipe?.name ?? "").font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                LevelBadge(level: snapshot.level, subtitle: state.bundle.evolution(forLevel: snapshot.level)?.displayName ?? "", flash: levelFlash)
                    .anchorPreference(key: SceneAnchorsKey.self, value: .bounds) { ["badge": $0] }
            }
            .padding(.horizontal, NeoTokyo.Spacing.lg)
            .padding(.top, 64)   // below the status bar, since the scene ignores the top safe area
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 440)
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.86), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: progression (gold)

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

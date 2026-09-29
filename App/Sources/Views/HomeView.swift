import SwiftUI
import HeroDomain
import HeroContent

/// Doc 19 "fitness first": the utility (today, this week, log) carries the screen. The
/// character is present and reacts, but sits in a compact scene rather than dominating.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showLog = false
    @State private var showHistory = false
    @State private var showWorkout = false
    /// What the numbers currently show. Held at the pre-receipt values while the reward modal is
    /// up, then animated to the real snapshot when it closes (doc 02: reward, then visible change).
    @State private var shown: ProgressSnapshot?
    @State private var deltas: [AttributeID: Int] = [:]
    @State private var xpDelta = 0
    @State private var deltaToken = 0

    var body: some View {
        let snapshot = shown ?? state.snapshot
        NavigationStack {
            ScrollView {
                VStack(spacing: NeoTokyo.Spacing.lg) {
                    sceneCard(snapshot)
                    progressCard(snapshot)
                    weekCard
                    todayCard
                }
                .padding(.horizontal, NeoTokyo.Spacing.lg)
                .padding(.bottom, 96)
            }
            .background(NeoTokyo.Surface.base)
            .navigationTitle(state.recipe?.name ?? "")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHistory = true } label: { Image(systemName: "clock.arrow.circlepath") }
                        .foregroundStyle(NeoTokyo.Text.secondary)
                }
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
            .overlay { if let receipt = state.lastReceipt { RewardMoment(receipt: receipt) } }
            .animation(.easeInOut(duration: 0.25), value: state.lastReceipt == nil)
        }
        .onAppear { if shown == nil { shown = state.snapshot } }
        .onChange(of: state.snapshot) { _, new in
            // Sync silently unless a reward is showing (then wait for dismissal).
            if state.lastReceipt == nil { shown = new }
        }
        .onChange(of: state.rewardToken) { _, _ in
            let new = state.snapshot
            let old = shown ?? new
            xpDelta = new.totalXP - old.totalXP
            deltas = Dictionary(uniqueKeysWithValues: new.attributes.map { ($0.key, $0.value - (old.attributes[$0.key] ?? 0)) })
            deltaToken += 1
            withAnimation(.easeOut(duration: 1.2)) { shown = new }
        }
    }

    // MARK: character scene (compact)

    private func sceneCard(_ snapshot: ProgressSnapshot) -> some View {
        ZStack(alignment: .bottomLeading) {
            BackdropImage(assetSetID: state.recipe?.backdropID ?? "backdrop.rain_district")
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow(text: "Level")
                    CountingText(value: Double(snapshot.level), font: HeroFont.statXL, color: NeoTokyo.Hierarchy.primary)
                    Text(state.evolution?.displayName ?? "").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                }
                Spacer()
                if let recipe = state.recipe {
                    LayeredCharacterView(recipe: recipe, scale: 2)
                        .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.35), radius: 16)  // the character's own glow
                }
            }
            .padding(NeoTokyo.Spacing.lg)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous))
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
            ProgressView(value: levelProgress(snapshot)).tint(NeoTokyo.Hierarchy.primary)
                .animation(.easeOut(duration: 1.2), value: levelProgress(snapshot))
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
            Eyebrow(text: "Today")
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
                        Spacer()
                        Text("\(event.durationSeconds / 60) min").font(HeroFont.bodyNumber).foregroundStyle(NeoTokyo.Text.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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

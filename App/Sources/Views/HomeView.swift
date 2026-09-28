import SwiftUI
import HeroDomain
import HeroContent

/// Doc 19 "fitness first": the utility (today, this week, log) carries the screen. The
/// character is present and reacts, but sits in a compact scene rather than dominating.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showLog = false
    @State private var showHistory = false

    var body: some View {
        let snapshot = state.snapshot
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
                Button("Log activity") { showLog = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, NeoTokyo.Spacing.lg)
                    .padding(.bottom, NeoTokyo.Spacing.sm)
                    .background(NeoTokyo.Surface.base.opacity(0.92))
            }
            .sheet(isPresented: $showLog) { LogSheet() }
            .sheet(isPresented: $showHistory) { HistoryView() }
            .overlay { if let proposal = state.lastProposal { RewardMoment(proposal: proposal) } }
        }
    }

    // MARK: character scene (compact)

    private func sceneCard(_ snapshot: ProgressSnapshot) -> some View {
        ZStack(alignment: .bottomLeading) {
            SceneBackdrop(shades: NeoTokyo.Backdrop.rainDistrict)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow(text: "Level")
                    Text(snapshot.level, format: .number).font(HeroFont.statXL).foregroundStyle(NeoTokyo.Hierarchy.primary)
                    Text(state.evolution?.displayName ?? "").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                }
                Spacer()
                SpritePlayer(assetSetID: state.evolution?.assetSetID ?? "hero.body.ev1", scale: 2)
                    .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.35), radius: 16)  // the character's own glow
            }
            .padding(NeoTokyo.Spacing.lg)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous))
    }

    // MARK: progression (gold)

    private func progressCard(_ snapshot: ProgressSnapshot) -> some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                StatNumber(value: snapshot.totalXP, unit: "xp", accent: NeoTokyo.Hierarchy.primary, font: HeroFont.statLG)
                Spacer()
                if let next = state.ruleset.xpToNextLevel(fromTotalXP: snapshot.totalXP) {
                    Text("\(next) to Level \(snapshot.level + 1)").font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.secondary)
                }
            }
            ProgressView(value: levelProgress(snapshot)).tint(NeoTokyo.Hierarchy.primary)
            Divider().overlay(NeoTokyo.Surface.line)
            HStack {
                ForEach(state.bundle.attributes, id: \.id) { attribute in
                    VStack(spacing: 2) {
                        Text(snapshot.attributes[attribute.id] ?? 0, format: .number)
                            .font(HeroFont.statSM)
                            .foregroundStyle(NeoTokyo.Attribute.color(for: attribute.id.rawValue))
                        Text(attribute.displayName).font(HeroFont.label).foregroundStyle(NeoTokyo.Text.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .card()
    }

    // MARK: utility (informational numbers in the tertiary accent)

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            Eyebrow(text: "This week")
            HStack(alignment: .firstTextBaseline, spacing: NeoTokyo.Spacing.xl) {
                StatNumber(value: state.weekMinutes, unit: "min", accent: NeoTokyo.Hierarchy.tertiary)
                StatNumber(value: state.weekSessions, unit: state.weekSessions == 1 ? "session" : "sessions", accent: NeoTokyo.Hierarchy.tertiary)
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

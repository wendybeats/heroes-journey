import SwiftUI
import HeroDomain
import HeroContent

/// Doc 02 "daily return": character centred in a backdrop, level, quick log, today, one teaser.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showLog = false
    @State private var showHistory = false

    var body: some View {
        let snapshot = state.snapshot
        NavigationStack {
            ScrollView {
                VStack(spacing: NeoTokyo.Spacing.xl) {
                    sceneCard(snapshot)
                    progressCard(snapshot)
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

    private func sceneCard(_ snapshot: ProgressSnapshot) -> some View {
        ZStack {
            SceneBackdrop(shades: NeoTokyo.Backdrop.rainDistrict)
            VStack(spacing: NeoTokyo.Spacing.sm) {
                SpritePlayer(assetSetID: state.evolution?.assetSetID ?? "hero.body.ev1")
                    .shadow(color: NeoTokyo.Accent.pink.opacity(0.35), radius: 18)  // the character's own glow
                Text("Level \(snapshot.level) · \(state.evolution?.displayName ?? "")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NeoTokyo.Text.secondary)
            }
            .padding(.vertical, NeoTokyo.Spacing.xl)
        }
        .frame(maxWidth: .infinity, minHeight: 380)
        .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous))
    }

    private func progressCard(_ snapshot: ProgressSnapshot) -> some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("XP").font(.caption).foregroundStyle(NeoTokyo.Text.secondary)
                StatNumber(value: snapshot.totalXP, accent: NeoTokyo.Accent.pink)
                Spacer()
                if let next = state.ruleset.xpToNextLevel(fromTotalXP: snapshot.totalXP) {
                    Text("\(next) to Level \(snapshot.level + 1)").font(.caption).foregroundStyle(NeoTokyo.Text.secondary)
                }
            }
            ProgressView(value: levelProgress(snapshot)).tint(NeoTokyo.Accent.pink)
            Divider().overlay(NeoTokyo.Surface.line)
            HStack {
                ForEach(state.bundle.attributes, id: \.id) { attribute in
                    VStack(spacing: 2) {
                        Text(snapshot.attributes[attribute.id] ?? 0, format: .number)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(NeoTokyo.Attribute.color(for: attribute.id.rawValue))
                        Text(attribute.displayName).font(.caption2).foregroundStyle(NeoTokyo.Text.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .card()
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
            Text("Today").font(.caption).foregroundStyle(NeoTokyo.Text.secondary)
            if state.todayEvents.isEmpty {
                Text("Nothing logged yet.").foregroundStyle(NeoTokyo.Text.muted)
            } else {
                ForEach(state.todayEvents, id: \.id) { event in
                    HStack {
                        Text(state.bundle.activityType(event.activityTypeID)?.displayName ?? event.activityTypeID.rawValue)
                            .foregroundStyle(NeoTokyo.Text.primary)
                        Spacer()
                        Text("\(event.durationSeconds / 60) min").foregroundStyle(NeoTokyo.Text.secondary).monospacedDigit()
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

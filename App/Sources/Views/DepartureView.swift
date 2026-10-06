import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import HeroDomain
import HeroContent

/// Doc 24 "Departure": the character walks in place while the district scrolls right→left, a
/// dotted path runs to a hidden reward, and a countdown says when they return. Walk clip is
/// pending authoring (owner, 2026-10-02): the idle sprite is used until then.
struct DepartureView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let run: QuestRun
    @State private var showClaim = false

    /// The run's own quest (the story may have moved on since departure).
    private var quest: ContentBundle.Quest? { state.questDefinition(run.questID) ?? state.quest }
    /// Resolved and not yet opened: the character is home, the cache glows, the walk stops.
    private var isBack: Bool { run.isResolved }
    private var unclaimed: Bool { isBack && !run.isClaimed }

    /// The quest's panorama, else the home backdrop. Kept out of the view builder for the type checker.
    private var questBackdrop: BackdropID {
        if let id = quest?.backdropID, let set = state.bundle.backdrop(id)?.assetSetID { return BackdropID(set.rawValue) }
        return state.recipe?.backdropID ?? BackdropID("backdrop.rain_district")
    }
    private var walkAssetSetID: AssetSetID? { quest?.walkAssetSetID }
    /// (item name, tier) for the loot tooltip, from the quest's preview list and the ruleset table.
    private var lootPreview: [(String, String)] {
        let table = state.ruleset.dailyQuest?.rewardTable ?? []
        return (quest?.previewRewards ?? []).compactMap { rewardID in
            guard let reward = state.bundle.reward(rewardID), let itemID = reward.grants.first?.itemID, let item = state.bundle.item(itemID) else { return nil }
            let tier = table.first { $0.rewardID == rewardID }?.tier ?? item.rarity
            return (item.displayName, tier)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                // Owner handoff 2026-10-02: the first-walk panorama (one plane, 10 s per strip in the
                // owner's preview) and the hooded walk cycle. Scroll speed is tuned to the strip, not the
                // stride; the owner judges foot-slide on device (walk 110 ms x 8 frames).
                ScrollingBackdrop(assetSetID: questBackdrop, pointsPerSecond: (reduceMotion || isBack) ? 0 : 114, parallax: false)
                if let walk = walkAssetSetID, !isBack {
                    SpritePlayer(assetSetID: walk, animation: "walk", scale: HomeView.walkScale)
                        .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.35), radius: 16)
                        .padding(.bottom, NeoTokyo.Spacing.xl)
                } else if let recipe = state.recipe {
                    CharacterView(recipe: recipe, scale: HomeView.walkScale, ascension: state.ascensionTier)
                        .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.35), radius: 16)
                        .padding(.bottom, NeoTokyo.Spacing.xl)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .clipped()

            VStack(spacing: NeoTokyo.Spacing.lg) {
                Eyebrow(text: isBack ? "Back" : "Daily quest")
                Text(quest?.displayName ?? "Quest")
                    .font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
                Text(isBack ? state.returnLine(for: run) : state.departLine(for: run))
                    .font(HeroFont.body).foregroundStyle(NeoTokyo.Text.secondary)
                    .multilineTextAlignment(.center)
                QuestPath(progress: isBack ? 1 : 0, lootPreview: lootPreview, cacheTier: isBack ? state.rewardTier(for: run) : nil,
                          glowing: unclaimed, onOpen: unclaimed ? { showClaim = true } : nil)
                    .padding(.horizontal, NeoTokyo.Spacing.md)
                if unclaimed {
                    Text("Tap the cache.").font(HeroFont.callout).foregroundStyle(NeoTokyo.Hierarchy.primary)
                } else if let subtext = quest?.subtext {
                    Text(subtext).font(HeroFont.callout).foregroundStyle(NeoTokyo.Text.secondary).multilineTextAlignment(.center)
                }
                if !isBack { Countdown(until: run.returnsAt) }
            }
            .padding(NeoTokyo.Spacing.xl)
            Spacer()
            Button(unclaimed ? "Later" : "Got it") { dismiss() }
                .buttonStyle(unclaimed ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))
                .padding(.horizontal, NeoTokyo.Spacing.lg)
                .padding(.bottom, NeoTokyo.Spacing.lg)
        }
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
        .overlay { if showClaim { ClaimMoment(run: run) { state.claimQuest(run); showClaim = false; dismiss() } } }
        .animation(.easeInOut(duration: 0.25), value: showClaim)
    }
}

/// Type-erased button style so one button can switch between the filled and the quiet style.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// Doc 29 claim moment: the opened cache, the item's still, one sentence, and "Claim". Shaped like
/// the reward modal (dimmed scrim, centred glass card). The grant is already on the ledger; this
/// is the moment it is shown, so nothing here can fail or double-grant.
struct ClaimMoment: View {
    @Environment(AppState.self) private var state
    let run: QuestRun
    let onClaim: () -> Void

    var body: some View {
        let fresh = state.questGrantedSomethingNew(run)
        let item = state.questReward(for: run)
        let tier = state.rewardTier(for: run)
        let xp = run.activityEventID.flatMap { state.outbox.receipt(for: $0)?.xp }
        ZStack {
            NeoTokyo.Surface.scrim.opacity(0.75).ignoresSafeArea()
            VStack(spacing: NeoTokyo.Spacing.md) {
                Eyebrow(text: tier.map { "\($0) cache" } ?? "Cache")
                if let item, fresh {
                    if let icon = item.iconAssetSetID {
                        AssetIcon(assetSetID: icon.rawValue, size: 180)
                            .shadow(color: NeoTokyo.Hierarchy.primary.opacity(item.rarity == "rare" ? 0.6 : 0.25), radius: 18)
                    }
                    Text(item.displayName).font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
                    Text(item.rarity).font(HeroFont.label).textCase(.uppercase).foregroundStyle(item.rarity == "rare" ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.secondary)
                    if let d = item.description {
                        Text(d).font(HeroFont.body).foregroundStyle(NeoTokyo.Text.secondary).multilineTextAlignment(.center)
                    }
                } else if let item {
                    // Trade-in (doc 29): the pool is owned, so the would-be drop becomes XP. The ruleset priced it; we only show it.
                    if let icon = item.iconAssetSetID { AssetIcon(assetSetID: icon.rawValue, size: 150).opacity(0.7) }
                    Text(item.displayName).font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
                    Text("Already yours").font(HeroFont.label).textCase(.uppercase).foregroundStyle(NeoTokyo.Text.secondary)
                    Text(xp.map { "Traded in for +\($0) XP." } ?? "Traded in for XP.").font(HeroFont.body).foregroundStyle(NeoTokyo.Hierarchy.primary).multilineTextAlignment(.center)
                } else {
                    CacheIcon(tier: tier).frame(width: 140, height: 140)
                    Text("Nothing new in it").font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
                    Text("Everything down there you already own. The walk still counts.").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.secondary).multilineTextAlignment(.center)
                }
                Button("Claim") { onClaim() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, NeoTokyo.Spacing.sm)
            }
            .padding(NeoTokyo.Spacing.xl)
            .frame(maxWidth: 340)
            .glass(tint: NeoTokyo.Surface.overlay)
            .padding(NeoTokyo.Spacing.xl)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }
}

/// Backdrop image tiled horizontally and moved right→left on a timeline. Two copies, so the
/// seam wraps; the far copy is the same image dimmed at half speed for depth.
struct ScrollingBackdrop: View {
    let assetSetID: BackdropID
    var pointsPerSecond: Double = 28
    /// A dimmed half-speed copy behind the strip. Off for a panorama that already has depth drawn in.
    var parallax = true
    @State private var image: Image?
    /// width / height of the still, so a wide panorama tiles at its own width, not the viewport's.
    @State private var aspect: CGFloat = 4.0 / 3.0
    @State private var start = Date()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: pointsPerSecond == 0)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(start)
                let w = max(geo.size.width, (geo.size.height * aspect).rounded())
                ZStack {
                    if parallax {
                        layer(width: w, height: geo.size.height, offset: offset(elapsed, speed: pointsPerSecond * 0.5, width: w)).opacity(0.45)
                    }
                    layer(width: w, height: geo.size.height, offset: offset(elapsed, speed: pointsPerSecond, width: w))
                        .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .bottom))
                }
            }
        }
        .task(id: assetSetID) {
            #if canImport(UIKit)
            if let ui = BackdropImage.loadUIImage(assetSetID.rawValue) {
                image = Image(uiImage: ui)
                if ui.size.height > 0 { aspect = ui.size.width / ui.size.height }
            }
            #else
            image = BackdropImage.load(assetSetID.rawValue)
            #endif
        }
    }

    private func offset(_ t: TimeInterval, speed: Double, width: CGFloat) -> CGFloat {
        guard width > 0, speed > 0 else { return 0 }
        return CGFloat(-(t * speed).truncatingRemainder(dividingBy: Double(width)))
    }

    @ViewBuilder
    private func layer(width: CGFloat, height: CGFloat, offset: CGFloat) -> some View {
        HStack(spacing: 0) {
            tile(width: width, height: height)
            tile(width: width, height: height)
        }
        .offset(x: offset)
        .frame(width: width, height: height, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    @ViewBuilder
    private func tile(width: CGFloat, height: CGFloat) -> some View {
        if let image {
            image.resizable().interpolation(.none).scaledToFill()
                .frame(width: width, height: height, alignment: .bottom).clipped()
        } else {
            SceneBackdrop(shades: NeoTokyo.Backdrop.rainDistrict).frame(width: width, height: height)
        }
    }
}

/// Dotted path from the character's mark to a "?" reward slot (Finch reference 08, doc 23).
struct QuestPath: View {
    /// 0…1 along the path.
    let progress: Double
    /// (item name, tier) shown when the loot box is tapped. Empty = plain "?".
    var lootPreview: [(String, String)] = []
    /// The returned cache's tier (nil while away: the common cache stands for "unknown").
    var cacheTier: String?
    /// Something is inside: pulse, and tapping opens it instead of the preview.
    var glowing = false
    var onOpen: (() -> Void)?
    @State private var showLoot = false
    var body: some View {
        HStack(spacing: NeoTokyo.Spacing.sm) {
            Image(systemName: "figure.walk").font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
                .frame(width: 36, height: 36).background(NeoTokyo.Surface.overlay, in: Circle())
            GeometryReader { geo in
                let dots = max(6, Int(geo.size.width / 14))
                HStack(spacing: 0) {
                    ForEach(0..<dots, id: \.self) { i in
                        Circle()
                            .fill(Double(i) / Double(max(1, dots - 1)) <= progress ? NeoTokyo.Hierarchy.primary : NeoTokyo.Surface.line)
                            .frame(width: 5, height: 5)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: geo.size.height)
            }
            .frame(height: 36)
            Button { if let onOpen { onOpen() } else { showLoot.toggle() } } label: { CacheIcon(tier: cacheTier, glowing: glowing).frame(width: 44, height: 44) }
                .buttonStyle(.plain)
                .accessibilityLabel(glowing ? "Open the cache" : "What might be found")
                .popover(isPresented: $showLoot, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
                        Eyebrow(text: "Might be found down there")
                        ForEach(lootPreview, id: \.0) { pair in
                            HStack {
                                Text(pair.0).font(HeroFont.bodyMedium).foregroundStyle(NeoTokyo.Text.primary)
                                Spacer()
                                Text(pair.1).font(HeroFont.label).textCase(.uppercase).foregroundStyle(pair.1 == "rare" ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.secondary)
                            }
                        }
                        if lootPreview.isEmpty { Text("Nobody knows.").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.muted) }
                    }
                    .padding(NeoTokyo.Spacing.lg)
                    .frame(minWidth: 240)
                    .presentationCompactAdaptation(.popover)
                }
        }
    }
}

/// Placeholder pixel loot box (owner to replace with authored art): a navy crate with a gold
/// latch, drawn on a 3 pt grid so it sits with the sprites.
struct LootBoxIcon: View {
    var body: some View {
        Canvas { context, size in
            let cell = size.width / 12
            func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: Color) {
                context.fill(Path(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: CGFloat(w) * cell, height: CGFloat(h) * cell)), with: .color(color))
            }
            fill(1, 3, 10, 8, NeoTokyo.Surface.overlay)          // body
            fill(1, 3, 10, 1, NeoTokyo.Hierarchy.fallback)        // lid edge (blue)
            fill(0, 4, 1, 7, NeoTokyo.Surface.line); fill(11, 4, 1, 7, NeoTokyo.Surface.line)
            fill(1, 10, 10, 1, NeoTokyo.Surface.scrim)             // base shadow
            fill(5, 6, 2, 2, NeoTokyo.Hierarchy.primary)           // gold latch
            fill(2, 5, 1, 1, NeoTokyo.Hierarchy.fallback); fill(9, 5, 1, 1, NeoTokyo.Hierarchy.fallback)  // rivets
        }
    }
}

/// H:MM:SS until `until`, tabular digits, updates every second. Reads "Back" once due.
struct Countdown: View {
    let until: Date
    var font: Font = HeroFont.statMD
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, until.timeIntervalSince(timeline.date))
            Text(remaining == 0 ? "Back" : Self.format(remaining))
                .font(font).foregroundStyle(NeoTokyo.Text.primary)
        }
    }
    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

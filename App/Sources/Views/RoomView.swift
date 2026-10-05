import SwiftUI
import HeroDomain
import HeroContent

/// The player's room (doc 28 §2B): a persistent hub, not the default screen. MVP: appearance,
/// equipment, home scene, history and settings. Built as a list of sections so later fixtures
/// (trophies, artifacts, furniture) can be added as content without restructuring.
/// Principle from the brief: the world changes occasionally, the character often, the room accumulates.
struct RoomView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var showHistory = false

    private var roomBackdrop: ContentBundle.Backdrop? { state.bundle.backdrops.first { $0.role == "home_room" } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NeoTokyo.Spacing.lg) {
                    scene
                    VStack(spacing: NeoTokyo.Spacing.lg) {
                        appearance
                        equipment
                        homeScene
                        progress
                        settings
                    }
                    .padding(.horizontal, NeoTokyo.Spacing.lg)
                }
                .padding(.bottom, NeoTokyo.Spacing.xxl)
            }
            .ignoresSafeArea(edges: .top)
            .background(NeoTokyo.Surface.base)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(NeoTokyo.Text.primary) } }
            .sheet(isPresented: $showHistory) { HistoryView() }
        }
    }

    private var scene: some View {
        ZStack(alignment: .bottom) {
            BackdropImage(assetSetID: BackdropID(roomBackdrop?.assetSetID.rawValue ?? "backdrop.under_city.home_01"))
            if let recipe = state.recipe {
                CharacterView(recipe: recipe, outfit: state.evolution?.outfit, scale: HomeView.characterScale)
                    .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.35), radius: 16)
                    .padding(.bottom, NeoTokyo.Spacing.xl)
            }
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: "Your room")
                Text(roomBackdrop?.displayName ?? "Under City").font(HeroFont.headline).foregroundStyle(NeoTokyo.Text.primary)
            }
            .padding(.horizontal, NeoTokyo.Spacing.lg).padding(.top, 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 380)
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.86), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: sections

    private var appearance: some View {
        let options = state.bundle.avatarOptions
        let recipe = state.recipe
        return VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            Eyebrow(text: "Appearance")
            Picker("Body", selection: Binding(get: { recipe?.baseBody ?? .male }, set: { body in
                state.updateAppearance { r in
                    r.baseBody = body
                    let styles = options.hairStyles(for: body.rawValue)
                    if !styles.contains(r.hairStyleID) { r.hairStyleID = styles.dropFirst().first ?? styles.first ?? r.hairStyleID }
                }
            })) {
                ForEach(AvatarRecipe.BaseBody.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("Skin").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.secondary)
            ChoiceChips(options: options.skinPalettes.map { ($0, options.displayName($0)) }, selection: Binding(get: { recipe?.skinPaletteID ?? "" }, set: { id in state.updateAppearance { $0.skinPaletteID = id } }))
            Text("Hair").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.secondary)
            ChoiceChips(options: options.hairStyles(for: recipe?.baseBody.rawValue ?? "male").map { ($0, options.displayName($0)) }, selection: Binding(get: { recipe?.hairStyleID ?? "" }, set: { id in state.updateAppearance { $0.hairStyleID = id } }))
            ChoiceChips(options: options.hairPalettes.map { ($0, options.displayName($0)) }, selection: Binding(get: { recipe?.hairPaletteID ?? "" }, set: { id in state.updateAppearance { $0.hairPaletteID = id } }))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var equipment: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            Eyebrow(text: "Equipment")
            let owned = state.ownedItems
            if owned.isEmpty {
                Text("Nothing yet. The Under City gives things to people who come back for them.").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.muted)
            } else {
                ForEach(owned, id: \.id) { item in
                    let equipped = state.recipe?.equipped[item.slot] == item.id
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName).font(HeroFont.bodyMedium).foregroundStyle(NeoTokyo.Text.primary)
                            Text("\(item.slot.rawValue) · \(item.rarity)").font(HeroFont.label).foregroundStyle(item.rarity == "rare" ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.muted)
                        }
                        Spacer()
                        Button(equipped ? "Equipped" : "Equip") { state.setEquipped(equipped ? nil : item, slot: item.slot) }
                            .font(HeroFont.captionMedium)
                            .foregroundStyle(equipped ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.secondary)
                    }
                }
                Text("An item shows on your character once its layers are in the kit; until then it is listed here.").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var homeScene: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            Eyebrow(text: "Where you stand")
            ChoiceChips(options: state.ownedHomeBackdrops.map { ($0.id.rawValue, $0.displayName) },
                        selection: Binding(get: { state.recipe?.backdropID.rawValue ?? "" }, set: { id in
                            if let b = state.bundle.backdrop(BackdropID(id)) { state.setHomeBackdrop(b) }
                        }))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            Eyebrow(text: "Progress")
            HStack(alignment: .firstTextBaseline, spacing: NeoTokyo.Spacing.xl) {
                StatNumber(value: state.snapshot.level, unit: "level", accent: NeoTokyo.Hierarchy.primary)
                StatNumber(value: state.snapshot.totalXP, unit: "xp", accent: NeoTokyo.Hierarchy.primary)
                StatNumber(value: state.dayNumber, unit: "days")
                Spacer()
            }
            if let chapter = state.currentChapter {
                Text("\(chapter.displayName) · \(state.storyProgress.completedMilestones.filter { id in chapter.milestones.contains { $0.id == id } }.count) of \(chapter.milestones.count) beats")
                    .font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
            }
            Button("History") { showHistory = true }.buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            Eyebrow(text: "Settings")
            HStack {
                Text("Weight unit").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                Spacer()
                Picker("Unit", selection: Binding(get: { state.preferredUnit }, set: { state.preferredUnit = $0 })) {
                    ForEach(WeightUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 120)
            }
            HStack {
                Text("Apple Health").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                Spacer()
                switch state.healthSync.authorization {
                case .requested: Text("Connected").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.secondary)
                case .unavailable: Text("Unavailable").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.muted)
                case .notRequested:
                    Button("Connect") { Task { await state.connectHealth() } }.font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Hierarchy.fallback)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

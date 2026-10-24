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
                        logPages
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
                CharacterView(recipe: recipe, scale: HomeView.characterScale, ascension: state.ascensionTier)
                    .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.35), radius: 16)
                    .padding(.bottom, NeoTokyo.Spacing.xl)
                    .offset(x: -56)   // stands left of the desk so the room reads (owner QA 2026-10-05)
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
            // Owner QA 2026-10-05: at this point only the hair cut and colour change; body and skin are who you are.
            Eyebrow(text: "Hair")
            ChoiceChips(options: options.hairStyles(for: recipe?.baseBody.rawValue ?? "male").map { ($0, options.displayName($0)) }, selection: Binding(get: { recipe?.hairStyleID ?? "" }, set: { id in state.updateAppearance { $0.hairStyleID = id } }))
            ChoiceChips(options: options.hairPalettes.map { ($0, options.displayName($0)) }, selection: Binding(get: { recipe?.hairPaletteID ?? "" }, set: { id in state.updateAppearance { $0.hairPaletteID = id } }))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var equipment: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
            Eyebrow(text: "Equipment")
            let owned = state.ownedItems.filter { $0.slot.isWearable }
            if owned.isEmpty {
                Text("Nothing yet. The Under City gives things to people who come back for them.").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.muted)
            } else {
                ForEach(owned, id: \.id) { item in
                    let equipped = state.recipe?.equipped[item.slot] == item.id
                    HStack(spacing: NeoTokyo.Spacing.sm) {
                        if let icon = item.iconAssetSetID { AssetIcon(assetSetID: icon.rawValue, size: 40) }
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

    /// Doc 33 found pages: Colossus's log, shown in order with gaps for the pages not yet found.
    @ViewBuilder
    private var logPages: some View {
        let all = state.bundle.items.filter { $0.slot == .collectible }.sorted { $0.id.rawValue < $1.id.rawValue }
        let owned = Set(state.ownedItems.map(\.id))
        if !all.isEmpty, all.contains(where: { owned.contains($0.id) }) {
            VStack(alignment: .leading, spacing: NeoTokyo.Spacing.sm) {
                HStack {
                    Eyebrow(text: "Colossus's log")
                    Spacer()
                    Text("\(all.filter { owned.contains($0.id) }.count) of \(all.count)").font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.secondary)
                }
                ForEach(all, id: \.id) { page in
                    let have = owned.contains(page.id)
                    HStack(alignment: .top, spacing: NeoTokyo.Spacing.sm) {
                        if have, let icon = page.iconAssetSetID { AssetIcon(assetSetID: icon.rawValue, size: 32) }
                        else { RoundedRectangle(cornerRadius: 4).strokeBorder(NeoTokyo.Surface.line, style: StrokeStyle(lineWidth: 1, dash: [3])).frame(width: 32, height: 32) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(have ? page.displayName : "A page still down there").font(HeroFont.bodyMedium).foregroundStyle(have ? NeoTokyo.Text.primary : NeoTokyo.Text.muted)
                            if have, let line = page.description { Text(line).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary).fixedSize(horizontal: false, vertical: true) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
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
            // HER-17: the account row. Guests see the Apple button; signed-in players see the state. HER-14: sync state and deletion.
            AccountRow()
            // HER-6: the analytics opt-out. Off clears the queue; nothing from Health is ever in it either way.
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Usage analytics").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                    Text("Level-ups, quests, fights. Never Health data.").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                }
                Spacer()
                Toggle("Usage analytics", isOn: Binding(get: { state.analyticsEnabled }, set: { state.analyticsEnabled = $0 }))
                    .labelsHidden().tint(NeoTokyo.Hierarchy.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// HER-17 / HER-14: the Account row in Settings. Status, the Apple button for guests, the last sync (so "did it
/// upload" is answerable on the phone), and account deletion (App Store Review 5.1.1(v)), confirmed twice, online only.
struct AccountRow: View {
    @Environment(AppState.self) private var state
    @State private var confirmDelete = false
    @State private var confirmDeleteAgain = false
    @State private var deleting = false
    @State private var deleteError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.xs) {
            HStack {
                Text("Account").font(HeroFont.body).foregroundStyle(NeoTokyo.Text.primary)
                Spacer()
                switch state.accountStatus {
                case .apple: Text("Signed in with Apple").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.secondary)
                case .guest: Text("Guest").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.secondary)
                case .offline: Text("Offline").font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.muted)
                }
            }
            Text(syncLine).font(HeroFont.caption).foregroundStyle(state.lastSyncError == nil ? NeoTokyo.Text.secondary : NeoTokyo.Text.muted)
            if state.accountStatus != .apple {
                Text("Sign in to keep your character if you change phones.").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.secondary)
                AppleSignInButton(label: .signIn)
            }
            Button(deleting ? "Deleting…" : "Delete account and data") { confirmDelete = true }
                .font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Hierarchy.destructive)
                .disabled(deleting || state.accountStatus == .offline)
                .padding(.top, NeoTokyo.Spacing.xs)
            if let deleteError { Text(deleteError).font(HeroFont.caption).foregroundStyle(NeoTokyo.Hierarchy.destructive) }
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account and data", role: .destructive) { confirmDeleteAgain = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your character, every activity you logged, your receipts and your sign-in are erased from our server and from this phone. Apple Health is not touched.")
        }
        .alert("This cannot be undone", isPresented: $confirmDeleteAgain) {
            Button("Delete", role: .destructive) {
                deleting = true
                Task { deleteError = await state.deleteAccount(); deleting = false }
            }
            Button("Keep my account", role: .cancel) {}
        } message: {
            Text("There is no recovery after this. The app starts over as a new guest.")
        }
    }

    private var syncLine: String {
        let pending = state.pendingUploadCount
        if state.lastSyncError == AppState.offlineSyncError { return pending > 0 ? "Offline · \(pending) \(pending == 1 ? "activity" : "activities") waiting to sync" : "Offline · will sync when connected" }
        if let error = state.lastSyncError { return "Sync failed: \(error)" }
        if pending > 0 { return "\(pending) \(pending == 1 ? "activity" : "activities") waiting to sync" }
        if let at = state.lastSyncAt { return "Synced \(RelativeDateTimeFormatter().localizedString(for: at, relativeTo: Date()))" }
        return "Not synced yet"
    }
}

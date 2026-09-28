import SwiftUI
import HeroDomain

/// Doc 02 first session, minimal: name, body, hair, hair color, skin. The preview is the live
/// layered character, so every choice is visible before "Wake them up".
struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @State private var name = ""
    @State private var draft: AvatarRecipe

    init() {
        _draft = State(initialValue: AvatarRecipe(name: "", baseBody: .male, skinPaletteID: "skin.light", hairStyleID: "hair.wolf", hairPaletteID: "hair.black", evolutionID: "ev1_awakened", backdropID: "backdrop.rain_district"))
    }

    var body: some View {
        let options = state.bundle.avatarOptions
        ScrollView {
            VStack(spacing: NeoTokyo.Spacing.xl) {
                ZStack {
                    SceneBackdrop(shades: NeoTokyo.Backdrop.rainDistrict)
                    LayeredCharacterView(recipe: draft, scale: 2)
                        .shadow(color: NeoTokyo.Hierarchy.primary.opacity(0.35), radius: 18)
                        .padding(.vertical, NeoTokyo.Spacing.lg)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous))

                VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
                    Text("Someone woke up here. Who are they?")
                        .font(HeroFont.title).foregroundStyle(NeoTokyo.Text.primary)
                    TextField("Name", text: $name)
                        .font(HeroFont.body)
                        .textInputAutocapitalization(.words)
                        .padding(NeoTokyo.Spacing.md)
                        .background(NeoTokyo.Surface.overlay, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md))
                    Picker("Body", selection: $draft.baseBody) {
                        ForEach(AvatarRecipe.BaseBody.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: draft.baseBody) { _, body in
                        let styles = options.hairStyles(for: body.rawValue)
                        if !styles.contains(draft.hairStyleID) { draft.hairStyleID = styles.dropFirst().first ?? styles.first ?? draft.hairStyleID }
                    }
                    optionRow("Hair", options: options.hairStyles(for: draft.baseBody.rawValue), selection: $draft.hairStyleID)
                    optionRow("Hair color", options: options.hairPalettes, selection: $draft.hairPaletteID)
                    optionRow("Skin", options: options.skinPalettes, selection: $draft.skinPaletteID)
                }
                .card()

                Button("Wake them up") {
                    guard let ev = state.bundle.evolution(forLevel: 1), let backdrop = state.bundle.defaultBackdrop else { return }
                    var r = draft
                    r.name = name.trimmingCharacters(in: .whitespaces); r.evolutionID = ev.id; r.backdropID = backdrop.id
                    state.recipe = r
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(NeoTokyo.Spacing.lg)
        }
        .background(NeoTokyo.Surface.base)
    }

    private func optionRow(_ label: String, options ids: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.xs) {
            Eyebrow(text: label)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NeoTokyo.Spacing.sm) {
                    ForEach(ids, id: \.self) { id in
                        let on = selection.wrappedValue == id
                        Button(state.bundle.avatarOptions.displayName(id)) { selection.wrappedValue = id }
                            .font(HeroFont.callout)
                            .foregroundStyle(on ? NeoTokyo.Hierarchy.primary : NeoTokyo.Text.secondary)
                            .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.sm)
                            .background(NeoTokyo.Surface.overlay, in: Capsule())
                            .overlay(Capsule().strokeBorder(on ? NeoTokyo.Hierarchy.primary : NeoTokyo.Surface.line, lineWidth: 1))
                    }
                }
            }
        }
    }
}

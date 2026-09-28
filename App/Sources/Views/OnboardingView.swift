import SwiftUI
import HeroDomain

/// Doc 02 first session, minimal: name, body, skin, hair. Story framing comes later.
struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @State private var name = ""
    @State private var body_ = AvatarRecipe.BaseBody.male
    @State private var skin = "skin.3"
    @State private var hairStyle = "hair.short"
    @State private var hairPalette = "hair.black"

    var body: some View {
        ScrollView {
            VStack(spacing: NeoTokyo.Spacing.xl) {
                ZStack {
                    SceneBackdrop(shades: NeoTokyo.Backdrop.rainDistrict)
                    SpritePlayer(assetSetID: "hero.body.ev1")
                        .shadow(color: NeoTokyo.Accent.pink.opacity(0.35), radius: 18)
                        .padding(.vertical, NeoTokyo.Spacing.xl)
                }
                .frame(maxWidth: .infinity, minHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: NeoTokyo.Radius.lg, style: .continuous))

                VStack(alignment: .leading, spacing: NeoTokyo.Spacing.md) {
                    Text("Someone woke up here. Who are they?")
                        .font(.title3.weight(.semibold)).foregroundStyle(NeoTokyo.Text.primary)
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .padding(NeoTokyo.Spacing.md)
                        .background(NeoTokyo.Surface.overlay, in: RoundedRectangle(cornerRadius: NeoTokyo.Radius.md))
                    Picker("Body", selection: $body_) {
                        ForEach(AvatarRecipe.BaseBody.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    optionRow("Skin", options: state.bundle.avatarOptions.skinPalettes, selection: $skin)
                    optionRow("Hair", options: state.bundle.avatarOptions.hairStyles, selection: $hairStyle)
                    optionRow("Hair color", options: state.bundle.avatarOptions.hairPalettes, selection: $hairPalette)
                }
                .card()

                Button("Wake them up") {
                    guard let ev = state.bundle.evolution(forLevel: 1), let backdrop = state.bundle.defaultBackdrop else { return }
                    state.recipe = AvatarRecipe(name: name.trimmingCharacters(in: .whitespaces), baseBody: body_, skinPaletteID: skin, hairStyleID: hairStyle, hairPaletteID: hairPalette, evolutionID: ev.id, backdropID: backdrop.id)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(NeoTokyo.Spacing.lg)
        }
        .background(NeoTokyo.Surface.base)
    }

    private func optionRow(_ label: String, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: NeoTokyo.Spacing.xs) {
            Text(label).font(.caption).foregroundStyle(NeoTokyo.Text.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NeoTokyo.Spacing.sm) {
                    ForEach(options, id: \.self) { option in
                        let on = selection.wrappedValue == option
                        Button(option.split(separator: ".").last.map(String.init)?.capitalized ?? option) { selection.wrappedValue = option }
                            .font(.subheadline)
                            .foregroundStyle(on ? NeoTokyo.Accent.pink : NeoTokyo.Text.secondary)
                            .padding(.horizontal, NeoTokyo.Spacing.md).padding(.vertical, NeoTokyo.Spacing.sm)
                            .background(NeoTokyo.Surface.overlay, in: Capsule())
                            .overlay(Capsule().strokeBorder(on ? NeoTokyo.Accent.pink : NeoTokyo.Surface.line, lineWidth: 1))
                    }
                }
            }
        }
    }
}

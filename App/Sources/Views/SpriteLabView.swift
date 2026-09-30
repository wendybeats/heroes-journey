import SwiftUI
import HeroDomain

/// Debug-only: one sprite, a 15-sprite grid, and cache counters for profiling (kit test D).
struct SpriteLabView: View {
    @Environment(AppState.self) private var state
    @State private var grid = false
    @State private var speed = 1.0
    private let variants: [(AvatarRecipe.BaseBody, String, String, String)] = [
        (.male, "hair.wolf", "hair.black", "skin.light"), (.female, "hair.ponytail", "hair.auburn", "skin.tan"),
        (.male, "hair.buzz", "hair.silver", "skin.deep"), (.female, "hair.long", "hair.blonde", "skin.fair"), (.male, "hair.bald", "hair.brown", "skin.brown"),
    ]
    private func recipe(_ i: Int) -> AvatarRecipe {
        let v = variants[i % variants.count]
        return AvatarRecipe(name: "lab", baseBody: v.0, skinPaletteID: v.3, hairStyleID: v.1, hairPaletteID: v.2, evolutionID: "ev1_awakened", backdropID: "backdrop.rain_district")
    }
    var body: some View {
        ScrollView {
            VStack(spacing: NeoTokyo.Spacing.lg) {
                Picker("Mode", selection: $grid) { Text("1 sprite").tag(false); Text("15 sprites").tag(true) }.pickerStyle(.segmented)
                Picker("Speed", selection: $speed) { Text("0.5x").tag(0.5); Text("1x").tag(1.0); Text("2x").tag(2.0) }.pickerStyle(.segmented)
                if grid {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(64 * 2)), count: 3), spacing: 8) {
                        ForEach(0..<15, id: \.self) { i in HoodieCharacterView(recipe: recipe(i), scale: 2, speed: speed) }
                    }
                } else {
                    HoodieCharacterView(recipe: recipe(0), scale: 3, speed: speed)
                }
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let store = HoodieKitStore.shared
                    Text("poses cached \(store.cachedPoseCount) · images cached \(store.cachedImageCount)")
                        .font(HeroFont.captionNumber).foregroundStyle(NeoTokyo.Text.secondary)
                }
            }
            .padding(NeoTokyo.Spacing.lg)
        }
        .background(NeoTokyo.Surface.base)
        .navigationTitle("Sprite lab")
    }
}

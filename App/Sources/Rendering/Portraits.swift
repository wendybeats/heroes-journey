import SwiftUI
import HeroDomain
import HeroContent

/// A content portrait (`kind: portrait` asset set): a generated still rendered nearest-neighbour
/// into a square. Used for the guide and for the hero before the bond.
struct PortraitView: View {
    let assetSetID: AssetSetID
    var size: CGFloat = 150
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image.resizable().interpolation(.none).scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous)
                    .strokeBorder(NeoTokyo.Text.muted, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .overlay(Text(assetSetID.rawValue).font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted))
            }
        }
        .frame(width: size, height: size)
        .task(id: assetSetID) { image = BackdropImage.load(assetSetID.rawValue) }
    }
}

/// Owner decision 2026-10-02: once the player has chosen who they are, the portrait is a zoomed
/// crop of the live sprite's resting frame, so cosmetics and evolutions are always accurate and
/// no portrait images are stored or generated. Head and shoulders: the top 40 % of the cell.
struct SpritePortrait: View {
    let recipe: AvatarRecipe
    let outfit: String?
    var size: CGFloat = 150

    var body: some View {
        let cg = StillCharacter.image(recipe: recipe, outfit: outfit)
        ZStack(alignment: .top) {
            if let cg {
                let cellW = CGFloat(cg.width), cellH = CGFloat(cg.height)
                // Crop window in cell units: central 70 % of the width, top 40 % of the height, 6 % margin above.
                let window = cellW * 0.7
                let scale = size / window
                Image(decorative: cg, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: cellW * scale, height: cellH * scale)
                    .offset(y: -cellH * 0.06 * scale)
            } else {
                Circle().strokeBorder(NeoTokyo.Text.muted, style: StrokeStyle(lineWidth: 1, dash: [4]))
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

/// Which portrait a speaker gets right now: content still, or the live sprite once a recipe exists.
struct SpeakerPortrait: View {
    @Environment(AppState.self) private var state
    let character: ContentBundle.Character
    /// The draft recipe during onboarding, or the saved one afterwards; nil = no sprite yet.
    var recipe: AvatarRecipe?
    var size: CGFloat = 150

    var body: some View {
        if character.id == "hero", let recipe {
            SpritePortrait(recipe: recipe, outfit: state.bundle.evolution(forLevel: 1)?.outfit, size: size)
        } else if let set = character.portraitAssetSetID {
            PortraitView(assetSetID: set, size: size)
        } else {
            // Unauthored portrait: a named stand-in so the scene still reads (Chad Colossus until his art lands).
            VStack(spacing: NeoTokyo.Spacing.xs) {
                Image(systemName: "person.fill").font(HeroFont.statLG).foregroundStyle(NeoTokyo.Text.muted)
                Text(character.displayName).font(HeroFont.captionMedium).foregroundStyle(NeoTokyo.Text.secondary)
            }
            .frame(width: size, height: size)
            .glass(cornerRadius: NeoTokyo.Radius.md, tint: NeoTokyo.Surface.overlay)
        }
    }
}

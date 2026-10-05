import SwiftUI
import HeroDomain
import HeroContent

/// An inventory still (`kind: icon`): a quest item or reward cache, rendered nearest-neighbour into a
/// square. Falls back to a dashed frame while the art is pending, like portraits.
struct AssetIcon: View {
    let assetSetID: String
    var size: CGFloat = 64
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image.resizable().interpolation(.none).scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: NeoTokyo.Radius.md, style: .continuous)
                    .strokeBorder(NeoTokyo.Text.muted, style: StrokeStyle(lineWidth: 1, dash: [4]))
            }
        }
        .frame(width: size, height: size)
        .task(id: assetSetID) { image = BackdropImage.load(assetSetID) }
    }
}

/// The reward cache for a tier (owner handoff 2026-10-05: common, uncommon, rare, legendary). The
/// placeholder crate stands in while a tier's art is missing. `glowing`: a slow gold pulse, the cue
/// that something is inside and waiting to be opened (doc 29).
struct CacheIcon: View {
    var tier: String?
    var glowing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: Image?
    @State private var pulse = false

    private var assetSetID: String { "icon.cache.\(tier ?? "common")" }

    var body: some View {
        ZStack {
            if let image {
                image.resizable().interpolation(.none).scaledToFit()
            } else {
                LootBoxIcon()
            }
        }
        .shadow(color: NeoTokyo.Hierarchy.primary.opacity(glowing ? (pulse ? 0.85 : 0.35) : 0), radius: glowing ? (pulse ? 14 : 8) : 0)
        .scaleEffect(glowing && pulse ? 1.06 : 1)
        .task(id: assetSetID) { image = BackdropImage.load(assetSetID) }
        .onAppear {
            guard glowing, !reduceMotion else { pulse = glowing; return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

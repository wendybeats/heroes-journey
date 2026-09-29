import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import HeroDomain
import HeroContent

/// A scene backdrop from `sprites/<asset_set_id>/rev<N>/<first frame>`, scaled to fill the
/// width and bottom-aligned so the character stands on its ground. Falls back to the dithered
/// band backdrop when the asset is missing.
struct BackdropImage: View {
    let assetSetID: BackdropID
    var fallbackShades: [Color] = NeoTokyo.Backdrop.rainDistrict
    @State private var image: Image?

    var body: some View {
        GeometryReader { geo in
            if let image {
                image
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                    .clipped()
            } else {
                SceneBackdrop(shades: fallbackShades)
            }
        }
        .task(id: assetSetID) { image = Self.load(assetSetID.rawValue) }
    }

    static func load(_ id: String) -> Image? {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("sprites/\(id)") else { return nil }
        let revisions = ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [])
            .compactMap { name -> (Int, String)? in
                guard name.hasPrefix("rev"), let n = Int(name.dropFirst(3)) else { return nil }
                return (n, name)
            }
            .sorted { $0.0 > $1.0 }
        for (_, rev) in revisions {
            let folder = root.appendingPathComponent(rev)
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
                  let manifest = try? SpriteManifest.decode(data), manifest.status != .retired,
                  let first = manifest.animations.values.first?.frames.first else { continue }
            #if canImport(UIKit)
            if let ui = UIImage(contentsOfFile: folder.appendingPathComponent(first).path) { return Image(uiImage: ui) }
            #endif
        }
        return nil
    }
}

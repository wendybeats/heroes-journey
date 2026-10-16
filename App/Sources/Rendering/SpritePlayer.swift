import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import HeroDomain
import HeroContent

/// Plays the frames a `SpriteManifest` describes, at integer nearest-neighbour scale.
/// Resolves `asset_set_id` → the highest revision folder shipped in the app bundle.
/// project.yml ships the `assets/sprites` folder reference, which lands in the bundle as `sprites/`.
/// Respects Reduce Motion by showing the poster frame.
struct SpritePlayer: View {
    let assetSetID: AssetSetID
    var animation = "idle"
    var scale: CGFloat = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loaded: Loaded?

    struct Loaded {
        let manifest: SpriteManifest
        /// Frames per animation name. Every animation of the revision loads at once, so a view that switches
        /// `animation` (the fight's states, the action masters) shows the new one on the next frame.
        let frames: [String: [Image]]
    }

    var body: some View {
        Group {
            if let loaded, let anim = loaded.manifest.animations[animation], let frames = loaded.frames[animation], !frames.isEmpty {
                if reduceMotion {
                    frame(frames[min(anim.posterFrame ?? 0, frames.count - 1)], loaded)
                } else {
                    TimelineView(.periodic(from: .now, by: Double(anim.frameDurationMs) / 1000)) { context in
                        let index = Int(context.date.timeIntervalSinceReferenceDate / (Double(anim.frameDurationMs) / 1000)) % frames.count
                        frame(frames[index], loaded)
                    }
                }
            } else {
                // Missing art must be visible, not silent: a muted outline at canvas size.
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(NeoTokyo.Text.muted, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(width: 64 * scale, height: 128 * scale)
                    .overlay(Text("\(assetSetID.rawValue) · \(animation)").font(.caption2).foregroundStyle(NeoTokyo.Text.muted))
            }
        }
        .task(id: assetSetID) { loaded = Self.load(assetSetID: assetSetID) }
    }

    private func frame(_ image: Image, _ loaded: Loaded) -> some View {
        image
            .interpolation(.none)
            .resizable()
            .frame(width: CGFloat(loaded.manifest.canvas.width) * scale, height: CGFloat(loaded.manifest.canvas.height) * scale)
    }

    /// The highest loadable revision of the set, with every animation it declares. An animation whose frame file is
    /// missing is left out (and shows as the outline above), the rest still play.
    static func load(assetSetID: AssetSetID) -> Loaded? {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("sprites/\(assetSetID.rawValue)") else { return nil }
        let revisions = ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [])
            .compactMap { name -> (Int, String)? in
                guard name.hasPrefix("rev"), let n = Int(name.dropFirst(3)) else { return nil }
                return (n, name)
            }
            .sorted { $0.0 > $1.0 }
        for (_, rev) in revisions {
            let folder = root.appendingPathComponent(rev)
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
                  let manifest = try? SpriteManifest.decode(data),
                  manifest.status.isLoadable else { continue }
            var frames: [String: [Image]] = [:]
            for (name, anim) in manifest.animations {
                var images: [Image] = []
                for path in anim.frames {
                    #if canImport(UIKit)
                    guard let ui = UIImage(contentsOfFile: folder.appendingPathComponent(path).path) else { images.removeAll(); break }
                    images.append(Image(uiImage: ui))
                    #endif
                }
                if !images.isEmpty { frames[name] = images }
            }
            if frames.isEmpty { continue }
            return Loaded(manifest: manifest, frames: frames)
        }
        return nil
    }
}

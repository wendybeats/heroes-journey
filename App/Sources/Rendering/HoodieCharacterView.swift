import SwiftUI
import CoreGraphics
import HeroDomain
import HeroContent

/// Loads the hoodie kit once and turns composed RGBA buffers into cached CGImages (sRGB).
@MainActor
final class HoodieKitStore {
    static let shared = HoodieKitStore()
    let composer: HoodieComposer?
    let clips: HoodieClipConfig?
    private var images: [String: CGImage] = [:]
    private var order: [String] = []
    private let cap = 400
    var cachedImageCount: Int { images.count }
    var cachedPoseCount: Int { composer?.cachedPoseCount ?? 0 }

    private init() {
        let root = Bundle.main.resourceURL?.appendingPathComponent("sprites/hero.kit.v3/hoodie")
        if let root,
           let mdata = try? Data(contentsOf: root.appendingPathComponent("hoodie_manifest.json")),
           let m = try? HoodieManifest.decode(mdata),
           let cdata = try? Data(contentsOf: root.appendingPathComponent("hoodie_clips.json")),
           let c = try? HoodieClipConfig.decode(cdata) {
            composer = HoodieComposer(manifest: m, loader: CGHoodieLayerLoader(root: root, manifest: m))
            clips = c
        } else { composer = nil; clips = nil }
    }

    func image(pose: HoodiePose, gender: String, style: String, hairColor: String, skin: String, items: [String] = []) -> CGImage? {
        guard let composer else { return nil }
        let key = "\(gender)|\(style)|\(hairColor)|\(skin)|\(pose.cacheKey)|\(items.joined(separator: ","))"
        if let hit = images[key] { return hit }
        var px = composer.pixels(for: pose, gender: gender, style: style, hairColor: hairColor, skin: skin, items: items)
        let W = composer.width, H = composer.height
        let img: CGImage? = px.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        if let img { images[key] = img; order.append(key); if order.count > cap { images.removeValue(forKey: order.removeFirst()) } }
        return img
    }
}

/// Recipe option IDs → kit keys ("hair.wolf" → "wolf", "skin.deep" → "Deep", "hair.black" → "Black").
enum HoodieVariant {
    static func style(_ id: String) -> String { id.hasPrefix("hair.") ? String(id.dropFirst(5)) : id }
    /// Equipped item ids in slot order; the composer drops any without layers in the kit.
    static func items(_ recipe: AvatarRecipe) -> [String] {
        recipe.equipped.sorted { $0.key.rawValue < $1.key.rawValue }.map { $0.value.rawValue }
    }
    static func ramp(_ id: String) -> String {
        let raw = id.split(separator: ".").last.map(String.init) ?? id
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }
}

/// Hoodie character (kit v3.1). Ticks at exactly the kit's rate from a time accumulator inside the
/// display-linked timeline (never a Timer); pauses when hidden or backgrounded; static pocketed
/// pose under Reduce Motion; integer scale, nearest-neighbour.
struct HoodieCharacterView: View {
    let recipe: AvatarRecipe
    var scale: CGFloat = 2
    var speed: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var driver = Driver()
    @State private var visible = false

    @MainActor
    final class Driver {
        var scheduler: HoodieIdleScheduler<SystemRandomNumberGenerator>?
        var pose = HoodiePose.pocketed
        var accumulator: TimeInterval = 0
        var last: Date?
        func advance(to now: Date, tickRate: Int, speed: Double) {
            guard let scheduler else { return }
            if let last { accumulator += now.timeIntervalSince(last) * speed }
            last = now
            let dt = 1.0 / Double(tickRate)
            var steps = 0
            while accumulator >= dt && steps < 12 { accumulator -= dt; pose = scheduler.tick(); steps += 1 }
            if steps == 12 { accumulator = 0 }   // huge gap (backgrounded): don't fast-forward
        }
        func pause() { last = nil }
    }

    private var store: HoodieKitStore { HoodieKitStore.shared }
    private var paused: Bool { reduceMotion || !visible || scenePhase != .active }

    var body: some View {
        let tickRate = store.clips?.tickRate ?? 12
        TimelineView(.animation(minimumInterval: 1.0 / Double(tickRate), paused: paused)) { timeline in
            let pose: HoodiePose = {
                if reduceMotion { return .pocketed }
                driver.advance(to: timeline.date, tickRate: tickRate, speed: max(0.1, speed))
                return driver.pose
            }()
            frame(store.image(pose: pose, gender: recipe.baseBody.rawValue, style: HoodieVariant.style(recipe.hairStyleID),
                              hairColor: HoodieVariant.ramp(recipe.hairPaletteID), skin: HoodieVariant.ramp(recipe.skinPaletteID), items: HoodieVariant.items(recipe)))
        }
        .onAppear {
            visible = true
            if driver.scheduler == nil, let clips = store.clips { driver.scheduler = HoodieIdleScheduler(config: clips, rng: SystemRandomNumberGenerator()) }
        }
        .onDisappear { visible = false; driver.pause() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { driver.pause() } }
    }

    @ViewBuilder
    private func frame(_ image: CGImage?) -> some View {
        let w = CGFloat(store.composer?.width ?? 64) * scale.rounded(), h = CGFloat(store.composer?.height ?? 128) * scale.rounded()
        if let image {
            Image(decorative: image, scale: 1).interpolation(.none).resizable().frame(width: w, height: h)
        } else {
            RoundedRectangle(cornerRadius: 4).strokeBorder(NeoTokyo.Text.muted, style: StrokeStyle(lineWidth: 1, dash: [4])).frame(width: w, height: h)
                .overlay(Text("hero.kit.v3").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted))
        }
    }
}

/// Picks the renderer by the evolution's outfit (content-driven). "hoodie" → kit v3; anything else → the suit (kit v2).
struct CharacterView: View {
    let recipe: AvatarRecipe
    let outfit: String?
    var scale: CGFloat = 2
    var body: some View {
        if outfit == "hoodie" {
            HoodieCharacterView(recipe: recipe, scale: scale)
        } else {
            LayeredCharacterView(recipe: recipe, scale: scale)
        }
    }
}

import SwiftUI
import CoreGraphics
import HeroDomain
import HeroContent

/// Runtime renderer for the layered kit: composes an index grid per pose (HeroContent's pure
/// `PoseComposer`), colors it with the recipe's skin and hair ramps, and plays the kit's locked
/// idle (breath, blink, hair drift) with the male flex every ~10 s. Ported from the approved
/// preview in assets/sprites/hero.kit.v2/source/previews/animated_variants.html.
@MainActor
final class CharacterKitStore {
    static let shared = CharacterKitStore()
    let kit: CharacterKit?
    let manifest: CharacterKitManifest?
    private var poseCache: [String: [UInt8]] = [:]
    private var imageCache: [String: CGImage] = [:]
    private var imageOrder: [String] = []
    private let imageCap = 400

    private let layerLoader: CGHoodieLayerLoader?
    private var itemLayers: [String: [UInt32]] = [:]

    private init() {
        let root = Bundle.main.resourceURL?.appendingPathComponent("sprites/hero.kit.v2")
        kit = root.flatMap { try? Data(contentsOf: $0.appendingPathComponent("kit.json")) }.flatMap { try? CharacterKit.decode($0) }
        manifest = root.flatMap { try? Data(contentsOf: $0.appendingPathComponent("kit-manifest.json")) }.flatMap { try? CharacterKitManifest.decode($0) }
        layerLoader = root.map { CGHoodieLayerLoader(root: $0, cellWidth: CharacterKit.width, cellHeight: CharacterKit.height, scale: 8) }
    }

    /// An item's 1x RGBA layer for a body (memory-order RGBA as UInt32), recoloured per the manifest, cached per item.
    private func itemLayer(_ id: String, body: String) -> [UInt32]? {
        guard let item = manifest?.items?[id], let rel = item.frames[body] else { return nil }
        let key = "\(id)|\(body)"
        if let hit = itemLayers[key] { return hit }
        guard var px = layerLoader?.load(rel) else { return nil }
        if let map = item.recolor, !map.isEmpty {
            var swap: [UInt32: UInt32] = [:]
            for (from, to) in map { swap[HoodieComposer.pack(from)] = HoodieComposer.pack(to) }
            for i in 0..<px.count where px[i] != 0 { if let v = swap[px[i]] { px[i] = v } }
        }
        itemLayers[key] = px; return px
    }

    /// Doc 32 Ascension I: the eyes change. Pupil and eye-white pixels (from the kit's blink patches) take the
    /// progression colour while the eyes are open. Palette indices: 5 = pupil, 9 = eye white.
    private func paintAscendedEyes(_ bytes: inout [UInt8], grid: [UInt8], kit: CharacterKit, body: String, pose: CharacterPose) {
        guard pose.blink == 0 else { return }
        let W = CharacterKit.width
        let eyes = body == "male" ? kit.male.eye : kit.female.eye
        for p in eyes.closed {
            let i = p.y * W + p.x
            switch grid[i] {
            case 5: bytes[i * 4] = 0xF3; bytes[i * 4 + 1] = 0xC0; bytes[i * 4 + 2] = 0x4A   // pupil: gold
            case 9: bytes[i * 4] = 0xFF; bytes[i * 4 + 1] = 0xEC; bytes[i * 4 + 2] = 0xB0   // white: pale gold
            default: continue
            }
        }
    }

    func image(recipe: AvatarRecipe, pose: CharacterPose, ascension: Int = 0) -> CGImage? {
        guard let kit, let manifest else { return nil }
        let body = recipe.baseBody.rawValue
        // Equipped items with layers, in draw order (doc 29). A head item is fitted to the bald head, so hair is hidden under it.
        let items = manifest.drawableItems(recipe.equipped.values.map(\.rawValue))
        let wearsHeadItem = items.contains { manifest.items?[$0]?.slot == "head" }
        let styleKey = wearsHeadItem ? nil : manifest.styleKey(body: body, styleID: recipe.hairStyleID)
        let poseKey = "\(body)|\(styleKey ?? "-")|\(pose.cacheKey)"
        let grid: [UInt8]
        if let cached = poseCache[poseKey] { grid = cached } else {
            grid = PoseComposer.indexGrid(kit: kit, manifest: manifest, body: body, styleKey: styleKey, pose: pose)
            poseCache[poseKey] = grid
        }
        let imageKey = "\(poseKey)|\(recipe.hairPaletteID)|\(recipe.skinPaletteID)|\(items.joined(separator: ","))|a\(ascension)"
        if let cached = imageCache[imageKey] { return cached }
        let pal = PoseComposer.palette(kit: kit, manifest: manifest, hairID: recipe.hairPaletteID, skinID: recipe.skinPaletteID)
        let W = CharacterKit.width, H = CharacterKit.height
        var bytes = [UInt8](repeating: 0, count: W * H * 4)
        for i in 0..<(W * H) {
            let v = Int(grid[i]); if v == 0 || v > pal.count { continue }
            let c = pal[v - 1]
            bytes[i * 4] = c.0; bytes[i * 4 + 1] = c.1; bytes[i * 4 + 2] = c.2; bytes[i * 4 + 3] = 255
        }
        if ascension >= 1 { paintAscendedEyes(&bytes, grid: grid, kit: kit, body: body, pose: pose) }
        // Items were drawn on the rest pose; the same row remap moves them with the breath and keeps the feet planted.
        for id in items {
            guard let rest = itemLayer(id, body: body) else { continue }
            let moved = PoseComposer.remapRows(rest, manifest: manifest, pose: pose, empty: 0)
            for i in 0..<(W * H) where moved[i] != 0 {
                let v = moved[i]   // memory-order RGBA read little-endian: R in the low byte
                bytes[i * 4] = UInt8(v & 0xFF); bytes[i * 4 + 1] = UInt8((v >> 8) & 0xFF); bytes[i * 4 + 2] = UInt8((v >> 16) & 0xFF); bytes[i * 4 + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        imageCache[imageKey] = image; imageOrder.append(imageKey)
        if imageOrder.count > imageCap { imageCache.removeValue(forKey: imageOrder.removeFirst()) }
        return image
    }
}

/// Tick-driven state machine for the locked idle and flex rules (12 ticks/s).
@MainActor
final class CharacterActor {
    typealias Step = (CharacterPose, Int)
    private(set) var pose = CharacterPose.rest
    private var sequence: [Step] = []
    private var isFlex = false
    private var stepIndex = 0, stepTicks = 0
    private var ticksUntilFlex: Int
    private var blinkIn = Int.random(in: 10...60)
    private var blinkQueue: [Int] = []
    private var sway = 0, swayHold = Int.random(in: 6...48)
    private let ticksPerSecond: Int
    private let flexInterval: ClosedRange<Double>

    init(ticksPerSecond: Int, flexInterval: ClosedRange<Double>) {
        self.ticksPerSecond = ticksPerSecond; self.flexInterval = flexInterval
        ticksUntilFlex = Int(Double.random(in: flexInterval) * Double(ticksPerSecond))
        startIdle()
    }

    private func r(_ a: Int, _ b: Int) -> Int { Int.random(in: a...b) }

    private func startIdle() {
        isFlex = false; stepIndex = 0; stepTicks = 0
        let deep = Double.random(in: 0..<1) < 0.2
        func p(_ k: Int, _ c: Int, _ h: Int, _ l: Int = 0) -> CharacterPose { var q = CharacterPose(); q.breathKey = k; q.torsoRise = c; q.headDip = h; q.hairLag = l; return q }
        sequence = [(p(0,0,0), r(8,16)), (p(1,0,0), 1), (p(1,1,0), 2), (p(2,1,0), deep ? r(12,16) : r(6,9)),
                    (p(1,1,0), 2), (p(1,0,-1,-1), 1), (p(0,0,-1,0), r(3,5)), (p(0,0,0,1), 1)]
    }

    private func startFlex() {
        isFlex = true; stepIndex = 0; stepTicks = 0
        func p(_ a: String, _ o: Int, grin: Bool = false, glint: Bool = false, l: Int = 0) -> CharacterPose { var q = CharacterPose(); q.arm = a; q.bounce = o; q.grin = grin; q.glint = glint; q.hairLag = l; return q }
        sequence = [(p("", -1), 3), (p("raise", 0, l: 1), 1), (p("flex", 2, grin: true, l: 1), 2), (p("flex", 1, grin: true), 3),
                    (p("pump", 1, grin: true), 3), (p("flex", 1, grin: true), 2), (p("pump", 1, grin: true, glint: true), 5), (p("flex", 1, grin: true), 3),
                    (p("pump", 1, grin: true), 3), (p("flex", 1, grin: true), 10), (p("raise", 0, l: -1), 1), (p("", -1, l: -1), 2)]
    }

    func tick(canFlex: Bool) {
        var current = sequence[stepIndex].0
        stepTicks += 1
        if stepTicks >= sequence[stepIndex].1 {
            stepTicks = 0; stepIndex += 1
            if stepIndex >= sequence.count {
                if isFlex {
                    startIdle(); ticksUntilFlex = Int(Double.random(in: flexInterval) * Double(ticksPerSecond))
                } else if canFlex && ticksUntilFlex <= 0 {
                    startFlex()
                } else { startIdle() }
                current = sequence[stepIndex].0
            }
        }
        if !isFlex { ticksUntilFlex -= 1 }
        var blink = 0
        if !current.grin {
            if !blinkQueue.isEmpty { blink = blinkQueue.removeFirst() }
            else { blinkIn -= 1; if blinkIn <= 0 { blinkIn = r(30, 72); blinkQueue = [2, 2, 1]; if Double.random(in: 0..<1) < 0.15 { blinkQueue += [0, 0, 1, 2, 1] }; blink = 1 } }
        }
        swayHold -= 1
        if swayHold <= 0 { if sway != 0 { sway = 0; swayHold = r(6, 14) } else { sway = Bool.random() ? -1 : 1; swayHold = r(8, 20) } }
        current.hairSway = sway; current.blink = blink
        pose = current
    }
}

/// The character as configured by an `AvatarRecipe`, animating. Static rest pose under Reduce Motion.
struct LayeredCharacterView: View {
    let recipe: AvatarRecipe
    var scale: CGFloat = 2
    var ascension = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var actor: CharacterActor?

    private var store: CharacterKitStore { CharacterKitStore.shared }

    var body: some View {
        let tps = store.manifest?.ticksPerSecond ?? 12
        Group {
            if reduceMotion || actor == nil {
                frame(store.image(recipe: recipe, pose: .rest, ascension: ascension))
            } else {
                TimelineView(.periodic(from: .now, by: 1.0 / Double(tps))) { _ in
                    frame(store.image(recipe: recipe, pose: actor?.pose ?? .rest, ascension: ascension))
                }
            }
        }
        .onAppear {
            guard actor == nil, let m = store.manifest else { return }
            let lo = m.flex.intervalSeconds.first ?? 9, hi = m.flex.intervalSeconds.last ?? 11
            actor = CharacterActor(ticksPerSecond: m.ticksPerSecond, flexInterval: lo...hi)
        }
        .task(id: recipe) {
            // drive the actor at the kit's tick rate; TimelineView only redraws
            guard let m = store.manifest else { return }
            let canFlex = m.canFlex(body: recipe.baseBody.rawValue)
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1000 / m.ticksPerSecond))
                if !reduceMotion { actor?.tick(canFlex: canFlex) }
            }
        }
    }

    @ViewBuilder
    private func frame(_ image: CGImage?) -> some View {
        if let image {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .frame(width: CGFloat(CharacterKit.width) * scale, height: CGFloat(CharacterKit.height) * scale)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(NeoTokyo.Text.muted, style: StrokeStyle(lineWidth: 1, dash: [4]))
                .frame(width: CGFloat(CharacterKit.width) * scale, height: CGFloat(CharacterKit.height) * scale)
                .overlay(Text("hero.kit.v2").font(HeroFont.caption).foregroundStyle(NeoTokyo.Text.muted))
        }
    }
}

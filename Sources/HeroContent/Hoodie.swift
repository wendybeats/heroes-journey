import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif

// Port of sprite-kit v3.1 `hoodie/swift/IdleScheduler.swift` and `HoodieComposer.swift`
// (kept verbatim under assets/sprites/hero.kit.v3/source/swift-drafts). Logic is unchanged;
// the only edits are: the random generator is injectable so the schedule can be simulated
// with a seed, and the composer returns an RGBA buffer instead of an SKTexture so it can be
// tested on CI without SpriteKit and wrapped in a CGImage by the app.

public struct HoodiePose: Hashable, Sendable {
    public enum Head: String, Decodable, Sendable { case N, L, R }
    public var f = 0            // 0 relaxed, 1 reach, 2 pocketed
    public var head: Head = .N  // rows < neckRow come from this head; matching hair layer
    public var o = 0            // torso offset px (+ up), rows < legsFixedFromRow
    public var s = 0            // upper-hair lag px (+ right), rows < hairLagRowsBelow
    public var b = 0            // blink 0/1/2; patch set chosen by head (N/L/R)
    public init(f: Int = 0, head: Head = .N, o: Int = 0, s: Int = 0, b: Int = 0) { self.f = f; self.head = head; self.o = o; self.s = s; self.b = b }
    /// Static pose for Reduce Motion: hands pocketed, looking ahead.
    public static let pocketed = HoodiePose(f: 2)
    public var cacheKey: String { "\(f)|\(head.rawValue)|\(o)|\(s)|\(b)" }
}

public struct HoodieClipConfig: Decodable, Sendable {
    public struct PosePatch: Decodable, Sendable { public var f: Int?; public var head: HoodiePose.Head?; public var o: Int?; public var s: Int?; public var b: Int? }
    public enum Length: Decodable, Sendable {
        case fixed(Int), range(Int, Int)
        public init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let n = try? c.decode(Int.self) { self = .fixed(n); return }
            struct R: Decodable { let min: Int; let max: Int }
            let r = try c.decode(R.self); self = .range(r.min, r.max)
        }
    }
    public struct Step: Decodable, Sendable {
        public let patch: PosePatch; public let length: Length
        public init(from d: Decoder) throws {
            var c = try d.unkeyedContainer()
            patch = try c.decode(PosePatch.self); length = try c.decode(Length.self)
        }
    }
    public struct Schedule: Decodable, Sendable {
        public let glanceEverySec: [Double], glanceAlternateChance: Double, glanceBlinkChance: Double
        public let handsInForSec: [Double], handsOutForSec: [Double]
        public let blinkEverySec: [Double], doubleBlinkChance: Double
        public let startState: String, firstEnterAfterSec: Double, settleAfterHandsSec: Double
    }
    public let tickRate: Int
    public let clips: [String: [Step]]
    public let schedule: Schedule

    public static func decode(_ data: Data) throws -> HoodieClipConfig { try JSONDecoder().decode(HoodieClipConfig.self, from: data) }
}

/// Picks clips on timers and emits one pose per tick. Not thread-safe; drive from one loop.
public final class HoodieIdleScheduler<RNG: RandomNumberGenerator> {
    private let cfg: HoodieClipConfig
    private var rng: RNG
    public private(set) var handsIn: Bool
    private var clip: [HoodieClipConfig.PosePatch] = [], ci = 0
    public private(set) var clipName = "idle"
    private var glanceT = 0.0, handsT = 0.0, blinkT = 0.0
    private var lastLeft = false
    /// True on the tick a clip started; the name is `clipName`. For simulations and tests.
    public private(set) var startedClipThisTick = false

    public init(config: HoodieClipConfig, rng: RNG) {
        cfg = config; self.rng = rng
        handsIn = config.schedule.startState == "in"
        // All stored properties are initialised above; the draft's `Bool.random()` now uses the injected generator.
        lastLeft = Bool.random(using: &self.rng)
        handsT = config.schedule.firstEnterAfterSec
        glanceT = rand(config.schedule.glanceEverySec); blinkT = rand(config.schedule.blinkEverySec)
    }

    private func rand(_ r: [Double]) -> Double { r[0] == r[1] ? r[0] : Double.random(in: r[0]...r[1], using: &rng) }

    private func play(_ name: String) {
        guard let steps = cfg.clips[name] else { return }
        clip = steps.flatMap { step -> [HoodieClipConfig.PosePatch] in
            let n: Int
            switch step.length { case .fixed(let k): n = k; case .range(let a, let b): n = Int.random(in: a...b, using: &rng) }
            return Array(repeating: step.patch, count: n)
        }
        ci = 0; clipName = name; startedClipThisTick = true
    }

    public func tick() -> HoodiePose {
        startedClipThisTick = false
        let s = cfg.schedule, dt = 1.0 / Double(cfg.tickRate)
        glanceT -= dt; handsT -= dt; blinkT -= dt

        if !clip.isEmpty && ci >= clip.count {            // clip finished
            if clipName == "enter" { handsIn = true;  handsT = rand(s.handsInForSec) }
            if clipName == "exit"  { handsIn = false; handsT = rand(s.handsOutForSec) }
            if clipName == "enter" || clipName == "exit" { glanceT = max(glanceT, s.settleAfterHandsSec) }
            clip = []; clipName = "idle"
        }
        if clip.isEmpty {                                  // idle: hands > glance > blink
            if handsT <= 0 { play(handsIn ? "exit" : "enter") }
            else if glanceT <= 0 {
                let alternate = Double.random(in: 0..<1, using: &rng) < s.glanceAlternateChance
                let left = alternate ? !lastLeft : lastLeft
                lastLeft = left
                let blink = Double.random(in: 0..<1, using: &rng) < s.glanceBlinkChance
                play((left ? "glanceLeft" : "glanceRight") + (blink ? "Blink" : "")); glanceT = rand(s.glanceEverySec)
            } else if blinkT <= 0 {
                play(Double.random(in: 0..<1, using: &rng) < s.doubleBlinkChance ? "doubleBlink" : "blink")
                blinkT = rand(s.blinkEverySec)
            }
        }
        var p = HoodiePose(f: handsIn ? 2 : 0)
        if ci < clip.count {
            let q = clip[ci]; ci += 1
            if let v = q.f { p.f = v }; if let v = q.head { p.head = v }
            if let v = q.o { p.o = v }; if let v = q.s { p.s = v }; if let v = q.b { p.b = v }
        }
        return p
    }
}

/// Deterministic generator for simulations (SplitMix64).
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public struct HoodieManifest: Decodable, Sendable {
    public struct Rig: Decodable, Sendable { public let neckRow: Int; public let legsFixedFromRow: Int; public let hairLagRowsBelow: Int }
    public struct Palette: Decodable, Sendable {
        public let hairKey: [String], skinKey: [String]
        public let hair: [String: [String]], skin: [String: [String]]
        /// Item layers are authored in `itemKey`; an item's `palette` names a ramp in `item` (doc 29).
        public let itemKey: [String]?
        public let item: [String: [String]]?
    }
    /// An equippable item's layers (doc 29). `frames`: gender → frame key → path, where the key is
    /// `all` (one layer for every pose; legs and feet never move), `0`/`1`/`2` (per body frame) or
    /// `L`/`R` (per head turn, for head and face items).
    public struct ItemLayer: Decodable, Sendable {
        public let slot: String
        public let frames: [String: [String: String]]
        public let palette: String?
        public func path(gender g: String, pose p: HoodiePose) -> String? {
            guard let f = frames[g] else { return nil }
            if let all = f["all"] { return all }
            if p.head != .N, let turned = f[p.head.rawValue] { return turned }
            return f[String(p.f)]
        }
    }
    /// Draw order (doc 29): `back` before the body; `head`, `face`, `effect` over the front hair; the rest between body and front hair.
    public static let itemSlotOrder = ["back", "feet", "legs", "body", "hand", "head", "face", "effect"]
    public static let overHairSlots: Set<String> = ["head", "face", "effect"]
    public enum JSONValue: Decodable, Sendable {
        case int(Int), str(String)
        public init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let i = try? c.decode(Int.self) { self = .int(i) } else { self = .str(try c.decode(String.self)) }
        }
    }
    public struct Hair: Decodable, Sendable { public let backLayers: [String] }
    public let cell: [Int]; public let pngScale: Int; public let rig: Rig
    public let bodies: [String: [String: String]]      // gender -> "0"/"1"/"2" -> path
    public let heads: [String: [String: String]]       // gender -> "L"/"R" -> path
    public let styles: [String: [String]]
    public let hair: Hair
    public let eyePatches: [String: [String: [String: [[JSONValue]]]]] // gender -> head -> "1"/"2" -> [[x,y,"#hex"]]
    public let palette: Palette
    /// item id → layers. Optional; a kit without items composes exactly as before.
    public let items: [String: ItemLayer]?

    /// Every item layer path (test B for items).
    public var allItemLayerPaths: [String] {
        Set((items ?? [:]).values.flatMap { $0.frames.values.flatMap { $0.values } }).sorted()
    }
    /// Equipped item ids sorted into draw order; unknown ids and ids without layers are dropped.
    public func drawableItems(_ ids: [String]) -> [String] {
        ids.filter { items?[$0] != nil }.sorted { a, b in
            let ia = Self.itemSlotOrder.firstIndex(of: items![a]!.slot) ?? 99, ib = Self.itemSlotOrder.firstIndex(of: items![b]!.slot) ?? 99
            return ia == ib ? a < b : ia < ib
        }
    }

    public static func decode(_ data: Data) throws -> HoodieManifest { try JSONDecoder().decode(HoodieManifest.self, from: data) }

    public static func hairPath(_ g: String, _ st: String, _ part: String, _ head: HoodiePose.Head) -> String {
        switch head {
        case .N: return "hair/neutral/\(g)_hair_\(st)_\(part).png"
        case .L: return "hair/directional/\(g)_\(st)_hair_\(part)_look_left.png"
        case .R: return "hair/directional/\(g)_\(st)_hair_\(part)_look_right.png"
        }
    }

    /// Every layer path the manifest implies (test B).
    public var allLayerPaths: [String] {
        var out: [String] = []
        for (_, frames) in bodies { out += frames.values }
        for (_, dirs) in heads { out += dirs.values }
        for (g, sts) in styles {
            for st in sts {
                for head in [HoodiePose.Head.N, .L, .R] {
                    out.append(Self.hairPath(g, st, "front", head))
                    if hair.backLayers.contains(st) { out.append(Self.hairPath(g, st, "back", head)) }
                }
            }
        }
        return out.sorted()
    }
}

/// Loads a layer PNG (8x, binary alpha) as 1x RGBA pixels, memory-order RGBA read as little-endian UInt32.
public protocol HoodieLayerLoader: Sendable {
    func load(_ relativePath: String) -> [UInt32]?
}

/// Composites poses. Pipeline mirrors preview/hoodie_all_variants.html:
/// back hair -> head (rows < neck) + body (rows >= neck) -> blink patch -> front hair
/// -> torso offset (rows < legs row) -> palette swap. Output buffers are cached.
public final class HoodieComposer {
    public let manifest: HoodieManifest
    public let width: Int, height: Int
    private let loader: HoodieLayerLoader
    private var layers: [String: [UInt32]] = [:]
    private var cache: [String: [UInt32]] = [:]
    private var cacheOrder: [String] = []
    public let cacheLimit: Int
    public var cachedPoseCount: Int { cache.count }
    public var loadedLayerCount: Int { layers.count }

    public init(manifest: HoodieManifest, loader: HoodieLayerLoader, cacheLimit: Int = 900) {
        self.manifest = manifest; self.loader = loader; self.cacheLimit = cacheLimit
        width = manifest.cell[0]; height = manifest.cell[1]
    }

    private func layer(_ rel: String) -> [UInt32]? {
        if let l = layers[rel] { return l }
        guard let l = loader.load(rel) else { return nil }
        layers[rel] = l; return l
    }

    // Colors are stored as memory-order RGBA read as little-endian UInt32 (0xAABBGGRR).
    public static func pack(_ hex: String) -> UInt32 {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return 0xFF00_0000 | ((v & 0xFF) << 16) | (v & 0xFF00) | ((v >> 16) & 0xFF)
    }

    /// gender "male"/"female"; style e.g. "medium" or "bald"; hairColor/skin keys from the manifest palette.
    public func pixels(for p: HoodiePose, gender g: String, style st: String, hairColor hc: String, skin sk: String, items equipped: [String] = []) -> [UInt32] {
        let drawn = manifest.drawableItems(equipped)
        let key = "\(g)|\(st)|\(hc)|\(sk)|\(p.cacheKey)|\(drawn.joined(separator: ","))"
        if let hit = cache[key] { return hit }
        let W = width, H = height, rig = manifest.rig
        var px = [UInt32](repeating: 0, count: W * H)
        func blit(_ src: [UInt32]?, rows: (Int) -> Bool, lag: Bool) {
            guard let src = src else { return }
            for y in 0..<H where rows(y) {
                let sh = lag && y < rig.hairLagRowsBelow ? p.s : 0
                for x in 0..<W { let sx = x - sh; if sx < 0 || sx >= W { continue }
                    let v = src[y * W + sx]; if v != 0 { px[y * W + x] = v } }
            }
        }
        // Item layers, recoloured from the item key palette to the item's ramp before compositing (doc 29).
        func itemPixels(_ id: String) -> [UInt32]? {
            guard let item = manifest.items?[id], let rel = item.path(gender: g, pose: p), var src = layer(rel) else { return nil }
            if let ramp = item.palette, let key = manifest.palette.itemKey, let colors = manifest.palette.item?[ramp] {
                var swap: [UInt32: UInt32] = [:]
                for (k, v) in zip(key, colors) { swap[Self.pack(k)] = Self.pack(v) }
                for i in 0..<src.count where src[i] != 0 { if let v = swap[src[i]] { src[i] = v } }
            }
            return src
        }
        func blitItems(_ ids: [String]) { for id in ids { blit(itemPixels(id), rows: { _ in true }, lag: false) } }
        let bySlot = Dictionary(grouping: drawn) { manifest.items![$0]!.slot }
        let backItems = bySlot["back"] ?? []
        let overHair = drawn.filter { HoodieManifest.overHairSlots.contains(manifest.items![$0]!.slot) }
        let midItems = drawn.filter { !HoodieManifest.overHairSlots.contains(manifest.items![$0]!.slot) && manifest.items![$0]!.slot != "back" }

        let bald = st == "bald"
        let body = manifest.bodies[g]?[String(p.f)].flatMap(layer)
        let head = p.head == .N ? body : manifest.heads[g]?[p.head.rawValue].flatMap(layer)
        if !bald { blit(layer(HoodieManifest.hairPath(g, st, "back", p.head)), rows: { _ in true }, lag: true) }
        blitItems(backItems)
        blit(head, rows: { $0 < rig.neckRow }, lag: false)
        blit(body, rows: { $0 >= rig.neckRow }, lag: false)
        if p.b > 0, let patch = manifest.eyePatches[g]?[p.head.rawValue]?[String(p.b)] {
            for e in patch { if case .int(let x) = e[0], case .int(let y) = e[1], case .str(let h) = e[2] { px[y * W + x] = Self.pack(h) } }
        }
        blitItems(midItems)
        if !bald { blit(layer(HoodieManifest.hairPath(g, st, "front", p.head)), rows: { _ in true }, lag: true) }
        blitItems(overHair)

        // torso offset: rows above the planted legs move by o (+ up); the gap repeats the first leg row
        var out = [UInt32](repeating: 0, count: W * H)
        for d in 0..<H {
            var s = d < rig.legsFixedFromRow ? d + p.o : d
            if p.o > 0 && d >= rig.legsFixedFromRow - p.o && d < rig.legsFixedFromRow { s = rig.legsFixedFromRow }
            if s < 0 || s >= H { continue }
            for x in 0..<W { out[d * W + x] = px[s * W + x] }
        }
        // palette swap (placeholder hair ramp + base skin ramp -> chosen ramps)
        var swap: [UInt32: UInt32] = [:]
        let pal = manifest.palette
        if let ramp = pal.hair[hc] { for (k, v) in zip(pal.hairKey, ramp) { swap[Self.pack(k)] = Self.pack(v) } }
        if let ramp = pal.skin[sk] { for (k, v) in zip(pal.skinKey, ramp) { swap[Self.pack(k)] = Self.pack(v) } }
        for i in 0..<out.count where out[i] != 0 { if let v = swap[out[i]] { out[i] = v } }

        cache[key] = out; cacheOrder.append(key)
        if cacheOrder.count > cacheLimit { cache.removeValue(forKey: cacheOrder.removeFirst()) }
        return out
    }
}

#if canImport(CoreGraphics)
/// Decodes the 8x PNGs with ImageIO in sRGB and samples each block's top-left pixel (as the draft did).
public struct CGHoodieLayerLoader: HoodieLayerLoader {
    public let root: URL
    public let cell: (Int, Int)
    public let scale: Int
    public init(root: URL, manifest: HoodieManifest) { self.root = root; cell = (manifest.cell[0], manifest.cell[1]); scale = manifest.pngScale }

    public func load(_ rel: String) -> [UInt32]? {
        let url = root.appendingPathComponent(rel)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let bw = img.width, bh = img.height
        var big = [UInt32](repeating: 0, count: bw * bh)
        big.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: bw, height: bh, bitsPerComponent: 8, bytesPerRow: bw * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.draw(img, in: CGRect(x: 0, y: 0, width: bw, height: bh))
        }
        let (W, H) = cell, s = scale
        guard bw >= W * s, bh >= H * s else { return nil }
        var out = [UInt32](repeating: 0, count: W * H)
        for y in 0..<H { for x in 0..<W {
            let p = big[(y * s) * bw + x * s]
            out[y * W + x] = (p >> 24) == 0 ? 0 : p      // binary alpha in the source
        } }
        return out
    }

    /// Decode any 1x RGBA PNG (used by the golden test) into the same memory-order layout.
    public static func decode1x(_ url: URL) -> (width: Int, height: Int, pixels: [UInt32])? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let w = img.width, h = img.height
        var px = [UInt32](repeating: 0, count: w * h)
        px.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        for i in 0..<px.count where (px[i] >> 24) == 0 { px[i] = 0 }
        return (w, h, px)
    }
}
#endif

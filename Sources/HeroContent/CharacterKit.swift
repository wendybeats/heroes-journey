import Foundation
import HeroDomain

/// The authored layered character kit (`assets/sprites/hero.kit.v2/kit.json`): palette-indexed
/// layer grids plus pose patches. Pure data; `PoseComposer` turns it into an index grid.
public struct CharacterKit: Codable, Sendable, Equatable {
    public struct Patch: Codable, Sendable, Equatable {
        public let x: Int, y: Int, v: UInt8
        public init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            x = try c.decode(Int.self); y = try c.decode(Int.self); v = UInt8(try c.decode(Int.self))
        }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer(); try c.encode(x); try c.encode(y); try c.encode(Int(v))
        }
    }
    public struct Point: Codable, Sendable, Equatable {
        public let x: Int, y: Int
        public init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer(); x = try c.decode(Int.self); y = try c.decode(Int.self)
        }
        public func encode(to encoder: Encoder) throws { var c = encoder.unkeyedContainer(); try c.encode(x); try c.encode(y) }
    }
    public struct Eyes: Codable, Sendable, Equatable { public let half: [Patch]; public let closed: [Patch] }
    public struct MaleRig: Codable, Sendable, Equatable {
        public let deltas: [[Patch]]
        public let erase: [Point]
        public let arms: [String: [Patch]]
        public let grin: [Patch]
        public let glint: [Patch]
        public let eye: Eyes
    }
    public struct FemaleRig: Codable, Sendable, Equatable { public let eye: Eyes }

    public static let width = 64, height = 128
    static let glyphs = Array("123456789abcdefgh")

    public let pal: [String]
    /// layer name → (row string → glyph row). Rows absent from the dictionary are empty.
    public let layers: [String: [String: String]]
    public let male: MaleRig
    public let female: FemaleRig

    public static func decode(_ data: Data) throws -> CharacterKit { try JSONDecoder().decode(CharacterKit.self, from: data) }

    /// Decode a layer into a W×H index grid (0 = transparent, 1…17 = palette index).
    public func grid(for layer: String) -> [UInt8]? {
        guard let rows = layers[layer] else { return nil }
        var g = [UInt8](repeating: 0, count: Self.width * Self.height)
        for (rowKey, s) in rows {
            guard let y = Int(rowKey), y >= 0, y < Self.height else { continue }
            for (x, ch) in s.enumerated() where x < Self.width && ch != "." {
                if let i = Self.glyphs.firstIndex(of: ch) { g[y * Self.width + x] = UInt8(i + 1) }
            }
        }
        return g
    }
}

/// App-facing mapping from stable option IDs to kit data (`kit-manifest.json`).
public struct CharacterKitManifest: Codable, Sendable, Equatable {
    public struct Rig: Codable, Sendable, Equatable { public let tip: Int, neck: Int, waist: Int, seam: Int }
    public struct Flex: Codable, Sendable, Equatable {
        public let bodies: [String]
        public let intervalSeconds: [Double]
        enum CodingKeys: String, CodingKey { case bodies, intervalSeconds = "interval_seconds" }
    }
    public let schemaVersion: Int
    public let assetSetID: AssetSetID
    public let status: SpriteManifest.Status
    public let ticksPerSecond: Int
    public let rigRows: Rig
    public let hairIndices: [Int]
    public let skinIndices: [Int]
    /// body → (style ID → kit style key, null for bald)
    public let styles: [String: [String: String?]]
    public let hairRamps: [String: [String]]
    public let skinRamps: [String: [String]]
    public let flex: Flex

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", assetSetID = "asset_set_id", status, ticksPerSecond = "ticks_per_second"
        case rigRows = "rig_rows", hairIndices = "hair_indices", skinIndices = "skin_indices", styles
        case hairRamps = "hair_ramps", skinRamps = "skin_ramps", flex
    }

    public static func decode(_ data: Data) throws -> CharacterKitManifest { try JSONDecoder().decode(CharacterKitManifest.self, from: data) }

    public func styleKey(body: String, styleID: String) -> String? {
        guard let s = styles[body]?[styleID] else { return nil }
        return s
    }
    public func canFlex(body: String) -> Bool { flex.bodies.contains(body) }
}

/// One pose, in the kit's own terms (see source/README.md "Locked animation rules").
public struct CharacterPose: Hashable, Sendable {
    public var breathKey: Int = 0        // k: 0 rest, 1/2 breath shading keyframes
    public var torsoRise: Int = 0        // c: torso band +1 on inhale
    public var headDip: Int = 0          // h: head −1 on exhale
    public var arm: String = ""          // a: "", raise, flex, pump (male only)
    public var bounce: Int = 0           // o: whole body above the seam
    public var grin: Bool = false        // f
    public var glint: Bool = false       // g
    public var hairLag: Int = 0          // l: hair tips lag
    public var hairSway: Int = 0         // s: ±1 horizontal for tip rows
    public var blink: Int = 0            // b: 0 open, 1 half, 2 closed
    public init() {}
    public static let rest = CharacterPose()
    /// Stable, collision-free cache key (hashValue is randomized per process and may collide).
    public var cacheKey: String { "\(breathKey)|\(torsoRise)|\(headDip)|\(arm)|\(bounce)|\(grin ? 1 : 0)|\(glint ? 1 : 0)|\(hairLag)|\(hairSway)|\(blink)" }
}

/// Port of the approved preview's `poseIdx` (assets/sprites/hero.kit.v2/source/previews/animated_variants.html).
/// Pure: same inputs → same grid. Callers cache.
public enum PoseComposer {
    public static func indexGrid(kit: CharacterKit, manifest: CharacterKitManifest, body: String, styleKey: String?, pose p: CharacterPose) -> [UInt8] {
        let W = CharacterKit.width, H = CharacterKit.height
        var bodyGrid = kit.grid(for: "\(body)_body_bald") ?? [UInt8](repeating: 0, count: W * H)
        if body == "male" {
            let m = kit.male
            let erased = Set(m.erase.map { $0.y * W + $0.x })
            let armed = !p.arm.isEmpty
            if p.breathKey > 0, p.breathKey - 1 < m.deltas.count {
                for d in m.deltas[p.breathKey - 1] where !(armed && erased.contains(d.y * W + d.x)) { bodyGrid[d.y * W + d.x] = d.v }
            }
            if armed {
                for i in erased { bodyGrid[i] = 0 }
                for d in m.arms[p.arm] ?? [] { bodyGrid[d.y * W + d.x] = d.v }
            }
            if p.grin { for d in m.grin { bodyGrid[d.y * W + d.x] = d.v } }
        }
        if p.blink > 0 {
            let eyes = body == "male" ? kit.male.eye : kit.female.eye
            for d in (p.blink == 1 ? eyes.half : eyes.closed) { bodyGrid[d.y * W + d.x] = d.v }
        }
        var idx = [UInt8](repeating: 0, count: W * H)
        let back = styleKey.flatMap { kit.grid(for: "\(body)_hair_\($0)_back") }
        let front = styleKey.flatMap { kit.grid(for: "\(body)_hair_\($0)_front") }
        for layer in [back, bodyGrid, front] {
            guard let layer else { continue }
            for i in 0..<(W * H) where layer[i] != 0 { idx[i] = layer[i] }
        }
        if p.glint && body == "male" { for d in kit.male.glint { idx[d.y * W + d.x] = d.v } }

        // Row remap: legs fixed, body bounce, torso breath, head dip, hair tips lag.
        let r = manifest.rigRows
        var src = [Int](repeating: -1, count: H)
        let bands: [(Int, Int, Int)] = [
            (r.seam, H, 0), (r.waist, r.seam, p.bounce), (r.neck, r.waist, p.bounce + p.torsoRise),
            (r.tip, r.neck, p.bounce + p.headDip), (0, r.tip, p.bounce + p.headDip - p.hairLag),
        ]
        for (a, b, o) in bands { for s in a..<b { let d = s - o; if d >= 0 && d < H { src[d] = s } } }
        var top = 0
        while top < H && src[top] < 0 { top += 1 }
        if top < H - 1 { for d in stride(from: H - 2, through: top, by: -1) where src[d] < 0 { src[d] = src[d + 1] } }
        var out = [UInt8](repeating: 0, count: W * H)
        for d in 0..<H {
            let s = src[d]; if s < 0 { continue }
            let shift = s < r.tip ? p.hairSway : 0
            for x in 0..<W { let sx = x - shift; if sx >= 0 && sx < W { out[d * W + x] = idx[s * W + sx] } }
        }
        return out
    }

    /// Palette for a colorway: base palette with hair and skin ramps substituted, as 0…255 RGB triples.
    public static func palette(kit: CharacterKit, manifest: CharacterKitManifest, hairID: String, skinID: String) -> [(UInt8, UInt8, UInt8)] {
        var pal = kit.pal.map(rgb)
        if let ramp = manifest.hairRamps[hairID] { for (j, i) in manifest.hairIndices.enumerated() where j < ramp.count && i - 1 < pal.count { pal[i - 1] = rgb(ramp[j]) } }
        if let ramp = manifest.skinRamps[skinID] { for (j, i) in manifest.skinIndices.enumerated() where j < ramp.count && i - 1 < pal.count { pal[i - 1] = rgb(ramp[j]) } }
        return pal
    }

    static func rgb(_ hex: String) -> (UInt8, UInt8, UInt8) {
        guard let c = DesignTokens.rgb(hex) else { return (255, 0, 255) }
        return (UInt8(c.r * 255 + 0.5), UInt8(c.g * 255 + 0.5), UInt8(c.b * 255 + 0.5))
    }
}

import SpriteKit
import CoreGraphics
import ImageIO

// Composites hoodie poses from the 8x layer PNGs described in hoodie_manifest.json.
// Pairs with IdleScheduler: `composer.texture(for: scheduler.tick(), ...)`.
// Pipeline mirrors preview/hoodie_all_variants.html:
//   back hair -> head (rows < neck) + body (rows >= neck) -> blink patch -> front hair
//   -> torso offset (rows < legs row) -> palette swap -> cached SKTexture.

final class HoodieComposer {
    struct Manifest: Decodable {
        struct Rig: Decodable { let neckRow: Int; let legsFixedFromRow: Int; let hairLagRowsBelow: Int }
        struct Palette: Decodable {
            let hairKey: [String], skinKey: [String]
            let hair: [String: [String]], skin: [String: [String]]
        }
        let cell: [Int]; let pngScale: Int; let rig: Rig
        let bodies: [String: [String: String]]      // gender -> "0"/"1"/"2" -> path
        let heads: [String: [String: String]]       // gender -> "L"/"R" -> path
        let eyePatches: [String: [String: [String: [[JSONValue]]]]] // gender -> head -> "1"/"2" -> [[x,y,"#hex"]]
        let palette: Palette
    }
    enum JSONValue: Decodable {
        case int(Int), str(String)
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let i = try? c.decode(Int.self) { self = .int(i) } else { self = .str(try c.decode(String.self)) }
        }
    }

    private let m: Manifest, root: URL, W: Int, H: Int
    private var layers: [String: [UInt32]] = [:]    // path -> 1x RGBA pixels (0 = transparent)
    private let cache = NSCache<NSString, SKTexture>()

    init(manifestURL: URL) throws {
        m = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
        root = manifestURL.deletingLastPathComponent(); W = m.cell[0]; H = m.cell[1]
        cache.countLimit = 900
    }

    // MARK: layer loading (8x PNG -> 1x by sampling each block's top-left pixel)
    private func layer(_ rel: String) -> [UInt32]? {
        if let l = layers[rel] { return l }
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
        let s = m.pngScale; var out = [UInt32](repeating: 0, count: W * H)
        for y in 0..<H { for x in 0..<W {
            let p = big[(y * s) * bw + x * s]
            out[y * W + x] = (p >> 24) == 0 ? 0 : p      // binary alpha in the source
        } }
        layers[rel] = out; return out
    }

    // Colors are stored as memory-order RGBA read as little-endian UInt32 (0xAABBGGRR).
    private static func pack(_ hex: String) -> UInt32 {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return 0xFF00_0000 | ((v & 0xFF) << 16) | (v & 0xFF00) | ((v >> 16) & 0xFF)
    }

    private func hairPath(_ g: String, _ st: String, _ part: String, _ head: Pose.Head) -> String {
        switch head {
        case .N: return "hair/neutral/\(g)_hair_\(st)_\(part).png"
        case .L: return "hair/directional/\(g)_\(st)_hair_\(part)_look_left.png"
        case .R: return "hair/directional/\(g)_\(st)_hair_\(part)_look_right.png"
        }
    }

    /// gender "male"/"female"; style e.g. "medium" or "bald"; hairColor/skin keys from the manifest palette.
    func texture(for p: Pose, gender g: String, style st: String, hairColor hc: String, skin sk: String) -> SKTexture? {
        let key = "\(g)|\(st)|\(hc)|\(sk)|\(p.f)|\(p.head)|\(p.o)|\(p.s)|\(p.b)" as NSString
        if let t = cache.object(forKey: key) { return t }
        let rig = m.rig
        var px = [UInt32](repeating: 0, count: W * H)
        func blit(_ src: [UInt32]?, rows: (Int) -> Bool, lag: Bool) {
            guard let src = src else { return }
            for y in 0..<H where rows(y) {
                let sh = lag && y < rig.hairLagRowsBelow ? p.s : 0
                for x in 0..<W { let sx = x - sh; if sx < 0 || sx >= W { continue }
                    let v = src[y * W + sx]; if v != 0 { px[y * W + x] = v } }
            }
        }
        let bald = st == "bald"
        let body = m.bodies[g]?[String(p.f)].flatMap(layer)
        let head = p.head == .N ? body : m.heads[g]?[p.head.rawValue].flatMap(layer)
        if !bald { blit(layer(hairPath(g, st, "back", p.head)), rows: { _ in true }, lag: true) }
        blit(head, rows: { $0 < rig.neckRow }, lag: false)
        blit(body, rows: { $0 >= rig.neckRow }, lag: false)
        if p.b > 0, let patch = m.eyePatches[g]?[p.head.rawValue]?[String(p.b)] {
            for e in patch { if case .int(let x) = e[0], case .int(let y) = e[1], case .str(let h) = e[2] { px[y * W + x] = Self.pack(h) } }
        }
        if !bald { blit(layer(hairPath(g, st, "front", p.head)), rows: { _ in true }, lag: true) }

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
        let pal = m.palette
        if let ramp = pal.hair[hc] { for (k, v) in zip(pal.hairKey, ramp) { swap[Self.pack(k)] = Self.pack(v) } }
        if let ramp = pal.skin[sk] { for (k, v) in zip(pal.skinKey, ramp) { swap[Self.pack(k)] = Self.pack(v) } }
        for i in 0..<out.count where out[i] != 0 { if let v = swap[out[i]] { out[i] = v } }

        let img: CGImage? = out.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        guard let cg = img else { return nil }
        let t = SKTexture(cgImage: cg); t.filteringMode = .nearest
        cache.setObject(t, forKey: key); return t
    }
}

// Usage:
// let composer = try HoodieComposer(manifestURL: Bundle.main.url(forResource: "hoodie_manifest", withExtension: "json")!)
// let scheduler = IdleScheduler(config: clipConfig)
// every 1/12 s:
//   sprite.texture = composer.texture(for: scheduler.tick(), gender: "female", style: "ponytail", hairColor: "Auburn", skin: "Tan")
//   sprite.setScale(3)   // integer scales keep pixels crisp

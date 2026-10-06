import XCTest
import HeroDomain
@testable import HeroContent

/// Sprite kit v3.1 acceptance tests A–C (README "TESTS"). D (device profiling) is manual.
final class HoodieKitTests: XCTestCase {
    static let kitRoot = RepoFiles.root.appendingPathComponent("assets/sprites/hero.kit.v3/hoodie")

    func loadKit() throws -> (HoodieManifest, HoodieClipConfig) {
        (try HoodieManifest.decode(Data(contentsOf: Self.kitRoot.appendingPathComponent("hoodie_manifest.json"))),
         try HoodieClipConfig.decode(Data(contentsOf: Self.kitRoot.appendingPathComponent("hoodie_clips.json"))))
    }

    #if canImport(CoreGraphics)
    struct GoldenIndex: Decodable {
        struct Case: Decodable {
            struct P: Decodable { let f: Int; let head: String; let o: Int; let s: Int; let b: Int }
            let name: String, gender: String, style: String, hairColor: String, skin: String, pose: P
        }
        let cases: [Case]
    }

    /// A. Every golden matches pixel-for-pixel at 1x. Never "fix" goldens.
    func testGoldensMatchExactly() throws {
        let (m, _) = try loadKit()
        let composer = HoodieComposer(manifest: m, loader: CGHoodieLayerLoader(root: Self.kitRoot, manifest: m))
        let goldenDir = Self.kitRoot.appendingPathComponent("tests/golden")
        let index = try JSONDecoder().decode(GoldenIndex.self, from: Data(contentsOf: goldenDir.appendingPathComponent("goldens.json")))
        XCTAssertEqual(index.cases.count, 128)
        var failures: [String] = []
        for c in index.cases {
            let pose = HoodiePose(f: c.pose.f, head: HoodiePose.Head(rawValue: c.pose.head)!, o: c.pose.o, s: c.pose.s, b: c.pose.b)
            let got = composer.pixels(for: pose, gender: c.gender, style: c.style, hairColor: c.hairColor, skin: c.skin)
            guard let exp = CGHoodieLayerLoader.decode1x(goldenDir.appendingPathComponent(c.name)) else { failures.append("\(c.name): cannot decode golden"); continue }
            XCTAssertEqual(exp.width, 64); XCTAssertEqual(exp.height, 128)
            if exp.pixels != got {
                let differing = zip(exp.pixels, got).filter { $0 != $1 }.count
                failures.append("\(c.name): \(differing) px differ")
                try? writeDiff(name: c.name, expected: exp.pixels, actual: got, width: 64, height: 128)
            }
        }
        XCTAssertTrue(failures.isEmpty, "golden mismatches:\n" + failures.joined(separator: "\n"))
    }

    /// Writes a diff image (magenta where pixels differ) next to the test products for inspection.
    private func writeDiff(name: String, expected: [UInt32], actual: [UInt32], width: Int, height: Int) throws {
        var diff = actual
        for i in 0..<diff.count where expected[i] != actual[i] { diff[i] = 0xFFFF_00FF }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hoodie-golden-diffs", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("diff_" + name)
        diff.withUnsafeMutableBytes { buf in
            if let ctx = CGContext(data: buf.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
               let img = ctx.makeImage(), let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
            }
        }
        print("diff written:", url.path)
    }

    /// B. Every file the manifest implies loads.
    func testEveryManifestLayerLoads() throws {
        let (m, _) = try loadKit()
        let loader = CGHoodieLayerLoader(root: Self.kitRoot, manifest: m)
        let paths = m.allLayerPaths
        XCTAssertEqual(paths.count, 37, "unexpected path count \(paths.count)")
        var missing: [String] = []
        for p in paths where loader.load(p) == nil { missing.append(p) }
        XCTAssertTrue(missing.isEmpty, "layers failed to load: \(missing)")
    }
    #endif

    /// C. Ten simulated minutes with a seeded generator.
    func testSchedulerSimulation() throws {
        let (_, cfg) = try loadKit()
        XCTAssertEqual(cfg.tickRate, 12)
        let sched = HoodieIdleScheduler(config: cfg, rng: SeededRandomNumberGenerator(seed: 7))
        let ticks = cfg.tickRate * 600
        var poses: [HoodiePose] = []; var names: [String] = []; var glanceStarts: [Int] = []
        var exitEnds: [Int] = []; var enterStarts: [Int] = []
        var prevName = "idle"
        for t in 0..<ticks {
            let p = sched.tick(); poses.append(p); names.append(sched.clipName)
            if sched.startedClipThisTick && sched.clipName.hasPrefix("glance") { glanceStarts.append(t) }
            if sched.startedClipThisTick && sched.clipName == "enter" { enterStarts.append(t) }
            if prevName == "exit" && sched.clipName != "exit" { exitEnds.append(t) }
            prevName = sched.clipName
        }
        // glance starts 3–6.5 s apart
        let gaps = zip(glanceStarts, glanceStarts.dropFirst()).map { Double($1 - $0) / 12 }
        XCTAssertGreaterThan(gaps.count, 50)
        XCTAssertGreaterThanOrEqual(gaps.min() ?? 0, 3.0 - 1.0 / 12)
        XCTAssertLessThanOrEqual(gaps.max() ?? 99, 6.5)
        // hands-out ≈ 3 s from the end of exit to the start of enter, plus waiting for an in-progress glance
        var spans: [Double] = []
        for end in exitEnds { if let next = enterStarts.first(where: { $0 >= end }) { spans.append(Double(next - end) / 12) } }
        XCTAssertGreaterThan(spans.count, 10)
        XCTAssertGreaterThanOrEqual(spans.min() ?? 0, 3.0 - 1.0 / 12)
        XCTAssertLessThanOrEqual(spans.max() ?? 99, 3.0 + 3.0, "at most one in-progress glance of waiting")
        // no single-frame flicker on the body frame
        for i in 2..<poses.count { XCTAssertFalse(poses[i - 2].f == poses[i].f && poses[i - 1].f != poses[i].f, "flicker at tick \(i)") }
        // relaxed (0) and pocketed (2) never adjacent
        for i in 1..<poses.count { XCTAssertFalse(Set([poses[i - 1].f, poses[i].f]) == Set([0, 2]), "0<->2 without reach at tick \(i)") }
        // blinks never on transition ticks
        for (i, p) in poses.enumerated() where p.b > 0 { XCTAssertTrue(p.o == 0 && p.s == 0, "blink on transition at tick \(i)") }
        // legs never move is a composer property; spot-check via o range
        XCTAssertTrue(poses.allSatisfy { (-1...1).contains($0.o) })
    }

    func testSeededGeneratorIsDeterministic() throws {
        let (_, cfg) = try loadKit()
        let a = HoodieIdleScheduler(config: cfg, rng: SeededRandomNumberGenerator(seed: 42))
        let b = HoodieIdleScheduler(config: cfg, rng: SeededRandomNumberGenerator(seed: 42))
        for _ in 0..<600 { XCTAssertEqual(a.tick(), b.tick()) }
    }

    /// Doc 32: the hoodie kit is legacy. Every evolution renders the canonical body; the hoodie is a starter item.
    func testBundleEvolutionsMapOutfits() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        for level in [1, 4, 5, 10, 20] { XCTAssertEqual(bundle.evolution(forLevel: level)?.outfit, "suit", "level \(level)") }
        XCTAssertEqual(bundle.evolution(forLevel: 1)?.ascensionTier, 0); XCTAssertEqual(bundle.evolution(forLevel: 5)?.ascensionTier, 1)
        XCTAssertEqual(bundle.starterEquipment[.body], "item.hoodie.starter")
    }

    #if canImport(CoreGraphics)
    /// E. Item layers (doc 29): every item path loads, an unknown item is ignored, and the trainers (owner
    /// handoff v3, rows 109–122) change only the feet rows (legs are fixed, so one layer serves every pose).
    func testItemLayersComposeOnlyWhereAuthored() throws {
        let (m, _) = try loadKit()
        let loader = CGHoodieLayerLoader(root: Self.kitRoot, manifest: m)
        XCTAssertFalse(m.allItemLayerPaths.isEmpty)
        for p in m.allItemLayerPaths { XCTAssertNotNil(loader.load(p), "item layer missing: \(p)") }
        XCTAssertEqual(m.drawableItems(["item.nothing", "item.shoes.clean"]), ["item.shoes.clean"])
        let composer = HoodieComposer(manifest: m, loader: loader)
        for g in ["male", "female"] {
            for pose in [HoodiePose(f: 0), HoodiePose(f: 1, head: .L, o: 1), .pocketed] {
                let bare = composer.pixels(for: pose, gender: g, style: "bald", hairColor: "Black", skin: "Light")
                let shod = composer.pixels(for: pose, gender: g, style: "bald", hairColor: "Black", skin: "Light", items: ["item.shoes.clean"])
                XCTAssertNotEqual(bare, shod, "\(g) \(pose.cacheKey): the trainers must show")
                let W = composer.width
                for i in 0..<bare.count where bare[i] != shod[i] { XCTAssertGreaterThanOrEqual(i / W, 109, "\(g): changed pixel above the feet at row \(i / W)") }
                // A cap hides the hair: with the cap on, a styled head composes like the bald one plus the cap rows.
                let styled = composer.pixels(for: pose, gender: g, style: g == "male" ? "wolf" : "long", hairColor: "Black", skin: "Light", items: ["item.cap.testmax"])
                let baldCap = composer.pixels(for: pose, gender: g, style: "bald", hairColor: "Black", skin: "Light", items: ["item.cap.testmax"])
                XCTAssertEqual(styled, baldCap, "\(g): hair must be hidden under a head item")
                XCTAssertEqual(composer.pixels(for: pose, gender: g, style: "bald", hairColor: "Black", skin: "Light", items: ["item.nothing"]), bare)
            }
        }
    }
    #endif
}

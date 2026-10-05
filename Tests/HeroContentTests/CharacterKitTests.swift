import XCTest
import HeroDomain
@testable import HeroContent

final class CharacterKitTests: XCTestCase {
    func load() throws -> (CharacterKit, CharacterKitManifest) {
        (try CharacterKit.decode(RepoFiles.data("assets/sprites/hero.kit.v2/kit.json")),
         try CharacterKitManifest.decode(RepoFiles.data("assets/sprites/hero.kit.v2/kit-manifest.json")))
    }

    func testKitDecodesAndEveryManifestStyleHasALayer() throws {
        let (kit, m) = try load()
        XCTAssertEqual(kit.pal.count, 17)
        for (body, styles) in m.styles {
            XCTAssertNotNil(kit.grid(for: "\(body)_body_bald"), "missing body layer for \(body)")
            for (id, key) in styles {
                guard let key else { continue }
                XCTAssertNotNil(kit.grid(for: "\(body)_hair_\(key)_front"), "style \(id) has no front layer")
            }
        }
        for (id, ramp) in m.hairRamps.merging(m.skinRamps, uniquingKeysWith: { a, _ in a }) {
            XCTAssertEqual(ramp.count, 5, "ramp \(id) must have 5 shades")
        }
    }

    func testBundleAvatarOptionsMatchKitManifest() throws {
        let (_, m) = try load()
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        for body in bundle.avatarOptions.baseBodies {
            for style in bundle.avatarOptions.hairStyles(for: body) {
                XCTAssertTrue(m.styles[body]?.keys.contains(style) == true, "bundle style \(style) for \(body) is not in the kit")
            }
        }
        for skin in bundle.avatarOptions.skinPalettes { XCTAssertNotNil(m.skinRamps[skin], "skin \(skin) has no ramp") }
        for hair in bundle.avatarOptions.hairPalettes { XCTAssertNotNil(m.hairRamps[hair], "hair \(hair) has no ramp") }
        XCTAssertEqual(bundle.evolution(forLevel: 5)?.assetSetID, m.assetSetID, "the suit kit is the Level 5 evolution")
    }

    func testRestPoseIsUnionOfLayersAndStandsOnPivot() throws {
        let (kit, m) = try load()
        let W = CharacterKit.width
        let g = PoseComposer.indexGrid(kit: kit, manifest: m, body: "male", styleKey: "wolf", pose: .rest)
        let body = kit.grid(for: "male_body_bald")!, front = kit.grid(for: "male_hair_wolf_front")!, back = kit.grid(for: "male_hair_wolf_back")!
        for i in 0..<g.count {
            let expected = front[i] != 0 ? front[i] : (body[i] != 0 ? body[i] : back[i])
            XCTAssertEqual(g[i], expected, "pixel \(i) differs from layer union")
        }
        XCTAssertTrue((0..<W).contains { g[122 * W + $0] != 0 }, "feet on pivot row 122")
        XCTAssertFalse((0..<W).contains { g[123 * W + $0] != 0 }, "nothing below the feet")
    }

    func testBreathMovesTorsoButLegsStayPlanted() throws {
        let (kit, m) = try load()
        let W = CharacterKit.width
        var p = CharacterPose(); p.breathKey = 2; p.torsoRise = 1
        let rest = PoseComposer.indexGrid(kit: kit, manifest: m, body: "female", styleKey: "long", pose: .rest)
        let inhale = PoseComposer.indexGrid(kit: kit, manifest: m, body: "female", styleKey: "long", pose: p)
        XCTAssertNotEqual(rest, inhale)
        for y in m.rigRows.seam..<CharacterKit.height {
            XCTAssertEqual(Array(rest[(y * W)..<((y + 1) * W)]), Array(inhale[(y * W)..<((y + 1) * W)]), "row \(y) below the seam must not move")
        }
        // torso row 40 of the inhale equals rest row 41 (shifted up one)
        XCTAssertEqual(Array(inhale[(40 * W)..<(41 * W)]), Array(rest[(41 * W)..<(42 * W)]))
    }

    func testFlexAndBlinkChangePixelsOnlyWhereExpected() throws {
        let (kit, m) = try load()
        let W = CharacterKit.width
        var flex = CharacterPose(); flex.arm = "flex"; flex.grin = true; flex.glint = true
        let rest = PoseComposer.indexGrid(kit: kit, manifest: m, body: "male", styleKey: nil, pose: .rest)
        let flexed = PoseComposer.indexGrid(kit: kit, manifest: m, body: "male", styleKey: nil, pose: flex)
        let changed = (0..<rest.count).filter { rest[$0] != flexed[$0] }
        XCTAssertGreaterThan(changed.count, 100, "flex arm should redraw a substantial region")
        XCTAssertTrue(changed.allSatisfy { $0 / W < m.rigRows.seam }, "flex never touches the legs")
        var blink = CharacterPose(); blink.blink = 2
        let closed = PoseComposer.indexGrid(kit: kit, manifest: m, body: "male", styleKey: nil, pose: blink)
        let blinkChanged = (0..<rest.count).filter { rest[$0] != closed[$0] }
        XCTAssertEqual(blinkChanged.count, kit.male.eye.closed.filter { rest[$0.y * W + $0.x] != $0.v }.count)
    }

    private func arr(_ c: (UInt8, UInt8, UInt8)) -> [UInt8] { [c.0, c.1, c.2] }

    func testPaletteSubstitution() throws {
        let (kit, m) = try load()
        let pal = PoseComposer.palette(kit: kit, manifest: m, hairID: "hair.silver", skinID: "skin.deep")
        XCTAssertEqual(pal.count, 17)
        XCTAssertEqual(arr(pal[12]), arr(PoseComposer.rgb("#3c4150")))   // index 13 → darkest silver
        XCTAssertEqual(arr(pal[9]), arr(PoseComposer.rgb("#28150c")))    // index 10 → darkest deep skin
        XCTAssertEqual(arr(pal[0]), arr(PoseComposer.rgb("#101118")))    // outline untouched
        let unknown = PoseComposer.palette(kit: kit, manifest: m, hairID: "hair.nope", skinID: "skin.nope")
        XCTAssertEqual(arr(unknown[12]), arr(PoseComposer.rgb(kit.pal[12])), "unknown ramp keeps the authored placeholder")
    }

    /// Doc 29 / owner handoff v3: the suit kit's item layers decode, every file exists, draw order follows the
    /// slot list, and the shared row remap is the identity at rest and moves only the torso band on a breath.
    func testItemLayersAndRowRemap() throws {
        let (_, m) = try load()
        let items = try XCTUnwrap(m.items)
        XCTAssertEqual(items.count, 9)
        for (id, item) in items {
            XCTAssertTrue(CharacterKitManifest.itemSlotOrder.contains(item.slot), "\(id) slot \(item.slot)")
            for (body, rel) in item.frames {
                XCTAssertTrue(["male", "female"].contains(body))
                XCTAssertTrue(FileManager.default.fileExists(atPath: RepoFiles.root.appendingPathComponent("assets/sprites/hero.kit.v2/\(rel)").path), "\(id) \(body): missing \(rel)")
            }
        }
        XCTAssertEqual(m.drawableItems(["item.shades.row", "item.shoes.clean", "item.nothing", "item.belt.lifting"]), ["item.shoes.clean", "item.belt.lifting", "item.shades.row"])
        let W = CharacterKit.width, H = CharacterKit.height
        var layer = [Int](repeating: 0, count: W * H)
        for y in 0..<H { layer[y * W + 10] = y + 1 }   // one column, row number + 1
        XCTAssertEqual(PoseComposer.remapRows(layer, manifest: m, pose: .rest, empty: 0), layer, "rest pose is the identity")
        var breath = CharacterPose(); breath.torsoRise = 1
        let moved = PoseComposer.remapRows(layer, manifest: m, pose: breath, empty: 0)
        let r = m.rigRows
        XCTAssertEqual(moved[(r.seam + 2) * W + 10], layer[(r.seam + 2) * W + 10], "legs stay planted")
        XCTAssertEqual(moved[(r.neck + 5 - 1) * W + 10], layer[(r.neck + 5) * W + 10], "torso rows rise by one on the inhale")
    }
}

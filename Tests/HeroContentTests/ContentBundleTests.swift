import XCTest
import HeroDomain
@testable import HeroContent

/// Loads the real files under Content/ and assets/ so a broken JSON edit fails CI.
enum RepoFiles {
    static var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    static func data(_ relative: String) throws -> Data {
        try Data(contentsOf: root.appendingPathComponent(relative))
    }
}

final class ContentBundleTests: XCTestCase {
    func testBundleDecodesAndIsInternallyConsistent() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        XCTAssertEqual(bundle.schemaVersion, 1)
        XCTAssertEqual(bundle.families.count, 6)
        XCTAssertEqual(bundle.attributes.map(\.id), ["strength", "endurance", "knowledge", "mindfulness"])
        XCTAssertEqual(bundle.integrityProblems(), [])
    }

    func testDevRulesetDecodesAndCoversEveryFamily() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let ruleset = try ProgressionRuleset.decode(RepoFiles.data("Content/v1/ruleset.dev-1.json"))
        XCTAssertEqual(ruleset.status, .dev, "dev balance must stay marked dev until simulated")
        XCTAssertEqual(ruleset.levelThresholdsTotalXP.count, 10)
        XCTAssertEqual(ruleset.levelThresholdsTotalXP.first, 0)
        XCTAssertEqual(ruleset.levelThresholdsTotalXP, ruleset.levelThresholdsTotalXP.sorted(), "monotonic")
        XCTAssertEqual(bundle.integrityProblems(against: ruleset), [])
    }

    func testLevelRewardsAndEvolutions() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let rewards = bundle.levelRewards
        XCTAssertEqual(Set(rewards.keys), Set(2...10), "every level 2–10 has a reward (doc 05)")
        XCTAssertEqual(bundle.evolution(forLevel: 1)?.id, "ev1_awakened")
        XCTAssertEqual(bundle.evolution(forLevel: 4)?.id, "ev1_awakened")
        XCTAssertEqual(bundle.evolution(forLevel: 5)?.id, "ev2_evolution1")
        XCTAssertEqual(bundle.evolution(forLevel: 12)?.id, "ev3_evolution2")
        XCTAssertNotNil(bundle.defaultBackdrop)
    }

    func testEndToEndLoopWithRealContent() throws {
        // create character → log one activity → evaluate → commit → visible level (doc 15 milestone)
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let ruleset = try ProgressionRuleset.decode(RepoFiles.data("Content/v1/ruleset.dev-1.json"))
        let type = try XCTUnwrap(bundle.activityType("boxing"))
        let user = UserID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let e = ActivityEvent(userID: user, activityTypeID: type.id, familyID: type.familyID, startedAt: now, durationSeconds: 3600, source: .manual, verification: .selfReported, createdAt: now)
        var ledger = ProgressionLedger()
        let ctx = ledger.context(for: e, ruleset: ruleset, events: [e], levelRewards: bundle.levelRewards, calendar: .current)
        let p = ProgressionEngine.evaluate(event: e, ruleset: ruleset, context: ctx)
        XCTAssertGreaterThan(p.xp, 0)
        XCTAssertNotNil(p.attributes["endurance"])
        ledger.commit(p, for: e, at: now)
        let s = ledger.snapshot(ruleset: ruleset)
        XCTAssertEqual(s.level, ruleset.level(forTotalXP: p.xp))
        XCTAssertEqual(bundle.evolution(forLevel: s.level)?.assetSetID, "hero.body.ev1")
    }

    func testSpriteManifestDecodesAndFramesExist() throws {
        let folder = "assets/sprites/hero.body.ev1/rev1"
        let m = try SpriteManifest.decode(RepoFiles.data("\(folder)/manifest.json"))
        XCTAssertEqual(m.assetSetID, "hero.body.ev1")
        XCTAssertEqual(m.canvas.width, 64); XCTAssertEqual(m.canvas.height, 96)
        let idle = try XCTUnwrap(m.idle)
        XCTAssertGreaterThanOrEqual(idle.frames.count, 4)
        for frame in idle.frames {
            XCTAssertTrue(FileManager.default.fileExists(atPath: RepoFiles.root.appendingPathComponent("\(folder)/\(frame)").path), "missing \(frame)")
        }
    }

    func testDesignTokensDecodeAndAreValidHex() throws {
        let t = try DesignTokens.decode(RepoFiles.data("Content/v1/design-tokens.json"))
        XCTAssertEqual(t.themeID, "neo_tokyo_dark")
        for group in [t.surface, t.text, t.accent, t.attribute] {
            for (name, c) in group {
                XCTAssertNotNil(DesignTokens.rgb(c.hex), "bad hex for \(name)")
                if let dim = c.dim { XCTAssertNotNil(DesignTokens.rgb(dim), "bad dim hex for \(name)") }
            }
        }
        XCTAssertEqual(t.attribute["strength"]?.hex, t.accent["pink"]?.hex, "attribute colors alias accents (doc 19)")
        XCTAssertEqual(t.attribute["mindfulness"]?.hex, t.accent["green"]?.hex)
    }
}

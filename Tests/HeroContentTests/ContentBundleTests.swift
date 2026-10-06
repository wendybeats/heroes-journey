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
        XCTAssertEqual(bundle.families.count, 7)
        XCTAssertEqual(bundle.attributes.map(\.id), ["strength", "endurance", "knowledge", "mindfulness"])
        XCTAssertEqual(bundle.integrityProblems(), [])
        XCTAssertGreaterThanOrEqual(bundle.exerciseDefinitions.count, 20)
        XCTAssertEqual(bundle.exercise("bench_press")?.defaultSetType, .weighted)
        XCTAssertEqual(bundle.exercise("plank")?.defaultSetType, .timed)
        XCTAssertEqual(bundle.healthWorkoutMapping.map["running"], "running")
        XCTAssertEqual(bundle.healthWorkoutMapping.map["traditionalStrengthTraining"], "weightlifting")
    }

    func testDevRulesetDecodesAndCoversEveryFamily() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let ruleset = try ProgressionRuleset.decode(RepoFiles.data("Content/v1/ruleset.dev-5.json"))
        XCTAssertEqual(ruleset.status, .dev, "dev balance must stay marked dev until simulated")
        XCTAssertEqual(ruleset.levelThresholdsTotalXP.count, 100, "100 levels (owner, 2026-10-02)")
        XCTAssertEqual(ruleset.dailyActivityXPCap, 40)
        XCTAssertEqual(ruleset.bondGrant, .init(xp: 12, primaryPoints: 6, secondaryPoints: 4))
        XCTAssertEqual(ruleset.levelThresholdsTotalXP.first, 0)
        XCTAssertEqual(ruleset.levelThresholdsTotalXP, ruleset.levelThresholdsTotalXP.sorted(), "monotonic")
        XCTAssertEqual(ruleset.structuredWorkout?.defaultMinutes, 45)
        XCTAssertEqual(ruleset.structuredWorkout?.minutesPerValidSet, 2.5)
        XCTAssertEqual(ruleset.sessionBaseXP, 15); XCTAssertEqual(ruleset.healthHistoryWindowDays, 7)
        XCTAssertEqual(ruleset.goalXP, ["primary": 30, "secondary": 20, "small_win": 12])
        XCTAssertEqual(ruleset.dailyQuest?.durationMinutes, 240, "owner decision 2026-10-02")
        XCTAssertEqual(ruleset.dailyQuest?.rewardTable.map(\.tier), ["common", "uncommon", "rare"])
        XCTAssertEqual(ruleset.dailyQuest?.rewardTable.map(\.xp), [10, 15, 25])
        XCTAssertEqual(ruleset.dailyQuest?.pityRareAfter, 7); XCTAssertEqual(ruleset.dailyQuest?.tradeInXP?["rare"], 25, "doc 29")
        XCTAssertEqual(bundle.quests.count, 5, "the first walk, Protein Row and three gym quests (doc 28)")
        XCTAssertEqual(bundle.defaultQuest?.returnLines.keys.sorted(), ["common", "rare", "uncommon"])
        let archived = try ProgressionRuleset.decode(RepoFiles.data("Content/v1/ruleset.dev-1.json"))
        XCTAssertEqual(archived.status, .archived, "superseded rulesets stay decodable for audit")
        XCTAssertEqual(bundle.integrityProblems(against: ruleset), [])
        let previous = try ProgressionRuleset.decode(RepoFiles.data("Content/v1/ruleset.dev-4.json"))
        XCTAssertEqual(previous.status, .archived)
    }

    func testGoalTemplatesDecodeAndCoverEverySlot() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        XCTAssertGreaterThanOrEqual(bundle.goalTemplates.count, 40)
        for slot in GoalSlot.allCases { XCTAssertTrue(bundle.goalTemplates.contains { $0.slot == slot }, "slot \(slot)") }
        for interest in ["learning", "mindfulness"] {
            XCTAssertGreaterThanOrEqual(bundle.goalTemplates.filter { $0.slot == .secondary && $0.tags.contains(interest) }.count, 6, interest)
        }
        XCTAssertGreaterThanOrEqual(bundle.goalTemplates.filter { $0.slot == .smallWin }.count, 20)
        XCTAssertEqual(bundle.goalTemplate("goal.rest.steps")?.rule, .steps(base: 5000, perLevel: 400))
        XCTAssertEqual(bundle.goalTemplate("goal.train.strength")?.rule, .activityFamily(family: "strength", minMinutes: 30))
        XCTAssertTrue(bundle.goalTemplates.allSatisfy { $0.lines.count >= 2 }, "every goal needs at least two lines so repeats read differently")
        // Round-trip: the rule enum's hand-written Codable must survive encode → decode.
        let data = try JSONEncoder().encode(bundle.goalTemplates)
        XCTAssertEqual(try JSONDecoder().decode([GoalTemplate].self, from: data), bundle.goalTemplates)
    }

    func testStoryContentDecodesAndResolvesTheWorldName() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        XCTAssertEqual(bundle.characters.map(\.id), ["guide.elder", "hero", "chad_colossus"])
        XCTAssertEqual(Array(bundle.storyChapters.map(\.id).prefix(2)), ["chapter.awakening", "chapter.first_training"])
        XCTAssertEqual(bundle.storyChapters.count, 15)
        let awakening = try XCTUnwrap(bundle.chapter("chapter.awakening"))
        XCTAssertEqual(awakening.then, "create_character"); XCTAssertEqual(awakening.beats.count, 10)
        XCTAssertEqual(awakening.beats.first?.speaker, "hero"); XCTAssertEqual(awakening.beats.last?.lines.last?.text, "First things first. Do you remember who you are?")
        // Owner rewrite 2026-10-05: the world is not named in the awakening any more; the placeholder still resolves.
        XCTAssertEqual(bundle.worldName, "Neo Tokyo", "placeholder per docs/26 §2")
        let sample = try JSONDecoder().decode(ContentBundle.StoryLine.self, from: Data(#"{"text": "Welcome to {world}.", "without_world": "Welcome."}"#.utf8))
        XCTAssertEqual(sample.resolved(worldName: nil), "Welcome."); XCTAssertEqual(sample.resolved(worldName: "Neo Tokyo"), "Welcome to Neo Tokyo.")
        let resolution = try XCTUnwrap(bundle.chapter("chapter.colossus_resolution"))
        XCTAssertEqual(resolution.nextChapter, "chapter.up"); XCTAssertEqual(bundle.chapter("chapter.up")?.backdropID, "backdrop.colossus_gym.exterior_01")
        XCTAssertNil(bundle.chapter("chapter.up")?.nextChapter)
        XCTAssertEqual(bundle.defaultQuest?.backdropID, "backdrop.first_walk"); XCTAssertEqual(bundle.defaultQuest?.walkAssetSetID, "hero.walk.hooded")
        XCTAssertEqual(bundle.backdrop("backdrop.first_walk")?.role, "quest")
        XCTAssertEqual(bundle.defaultBackdrop?.id, "backdrop.rain_district", "story and quest backdrops are never the home scene")
        // Round trip keeps the single-string and the {text, without_world} forms.
        let data = try JSONEncoder().encode(bundle.storyChapters)
        XCTAssertEqual(try JSONDecoder().decode([ContentBundle.StoryChapter].self, from: data), bundle.storyChapters)
        XCTAssertEqual(bundle.integrityProblems(), [])
    }

    func testCampaignContentResolvesAndCoversLevelsOneToTen() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        XCTAssertEqual(bundle.campaign.chapters.map(\.id), ["chapter.under_city"])
        let levels = bundle.campaign.milestones.map(\.level)
        XCTAssertEqual(levels, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        XCTAssertEqual(bundle.campaign.milestone("under_city.10.resolution")?.trigger, .manual)
        XCTAssertEqual(bundle.campaign.milestone("under_city.10.resolution")?.teaseArea, "central_hill")
        XCTAssertEqual(bundle.campaign.milestone("under_city.2.home")?.unlockFeature, "home_room")
        XCTAssertEqual(bundle.chapter("chapter.home")?.then, "room", "the home chapter lands in the room (owner QA 2026-10-05)")
        XCTAssertTrue(bundle.levelRewards.isEmpty, "nothing is granted on level-up yet (owner 2026-10-05)")
        XCTAssertEqual(bundle.quests.map(\.id), ["quest.lower_district", "quest.protein_row", "quest.colossus_gym_01", "quest.colossus_gym_02", "quest.colossus_gym_03"])
        XCTAssertEqual(bundle.quests[1].unlockedByMilestone, "under_city.3.protein_row"); XCTAssertNil(bundle.quests[1].durationMinutes, "the Row keeps the ruleset duration")
        XCTAssertEqual(bundle.quests[2].durationMinutes, 480); XCTAssertEqual(bundle.quests[2].unlockedByMilestone, "under_city.5.gym_unlock")
        XCTAssertEqual(bundle.character("guide.elder")?.displayName, "Cairon"); XCTAssertEqual(bundle.character("chad_colossus")?.displayName, "Colossus", "working title (owner 2026-10-05)")
        XCTAssertEqual(bundle.character("chad_colossus")?.portraitAssetSetID, "portrait.colossus", "owner handoff 2026-10-06")
        XCTAssertEqual(bundle.character("chad_colossus")?.spriteAssetSetID, "npc.colossus")
        let npc = try SpriteManifest.decode(RepoFiles.data("assets/sprites/npc.colossus/rev1/manifest.json"))
        XCTAssertEqual(npc.canvas.width, 96); XCTAssertEqual(npc.canvas.height, 176); XCTAssertEqual(npc.kind, .body)
        XCTAssertEqual(bundle.integrityProblems(), [])
    }

    func testAreasCoverTheCampaign() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        XCTAssertEqual(bundle.areas.count, 13)
        XCTAssertEqual(bundle.area(forLevel: 1)?.id, "under_city"); XCTAssertEqual(bundle.area(forLevel: 10)?.id, "under_city")
        XCTAssertEqual(bundle.area(forLevel: 11)?.id, "colossus_gym"); XCTAssertEqual(bundle.area(forLevel: 100)?.id, "ascension_boundary")
        XCTAssertEqual(bundle.area("grand_court")?.antagonist, "The Mirror")
        XCTAssertEqual(bundle.defaultQuest?.displayName, "Under City")
    }

    func testLevelRewardsAndEvolutions() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let rewards = bundle.levelRewards
        XCTAssertTrue(rewards.isEmpty, "owner 2026-10-05: level-up grants are off; the former level rewards stay defined as unassigned")
        XCTAssertEqual(bundle.rewards.filter { $0.trigger.type == "unassigned" }.count, 10, "the ten former level rewards are kept for the chapter to assign")
        XCTAssertEqual(bundle.evolution(forLevel: 1)?.id, "ev1_awakened")
        // Doc 32: evolutions are ascension tiers on one canonical body; the starter outfit is items.
        XCTAssertEqual(bundle.evolutions.map { $0.ascensionTier ?? -1 }, [0, 1, 2, 3])
        XCTAssertEqual(Set(bundle.evolutions.map { $0.outfit ?? "" }), ["suit"])
        let starter = bundle.starterEquipment
        XCTAssertEqual(Set(starter.keys), [.body, .legs, .feet]); XCTAssertEqual(starter[.body], "item.hoodie.starter")
        XCTAssertEqual(bundle.items.filter(\.isStarter).count, 3)
        XCTAssertEqual(bundle.evolution(forLevel: 4)?.id, "ev1_awakened")
        XCTAssertEqual(bundle.evolution(forLevel: 5)?.id, "ev2_evolution1")
        XCTAssertEqual(bundle.evolution(forLevel: 12)?.id, "ev3_evolution2")
        XCTAssertEqual(bundle.evolution(forLevel: 20)?.id, "ev4_evolution3")
        XCTAssertEqual(bundle.evolution(forLevel: 99)?.id, "ev4_evolution3")
        XCTAssertNotNil(bundle.defaultBackdrop)
    }

    func testEndToEndLoopWithRealContent() throws {
        // create character → log one activity → evaluate → commit → visible level (doc 15 milestone)
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let ruleset = try ProgressionRuleset.decode(RepoFiles.data("Content/v1/ruleset.dev-5.json"))
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
        XCTAssertEqual(bundle.evolution(forLevel: s.level)?.assetSetID, "hero.kit.v2", "doc 32: one canonical body from Level 1")
    }

    func testSpriteManifestDecodesAndFramesExist() throws {
        let folder = "assets/sprites/hero.body.ev1/rev2"
        let m = try SpriteManifest.decode(RepoFiles.data("\(folder)/manifest.json"))
        XCTAssertEqual(m.assetSetID, "hero.body.ev1")
        XCTAssertEqual(m.canvas.width, 64); XCTAssertEqual(m.canvas.height, 128)
        XCTAssertNotEqual(m.status, .retired)
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
        XCTAssertEqual(t.attribute["endurance"]?.hex, t.accent["blue"]?.hex)
        XCTAssertEqual(t.attribute["mindfulness"]?.hex, t.accent["green"]?.hex)
        XCTAssertEqual(t.attribute["knowledge"]?.hex, t.accent["coral"]?.hex)
        XCTAssertEqual(t.hierarchy.primary, "gold")
        for name in [t.hierarchy.primary, t.hierarchy.tertiary, t.hierarchy.destructive] + t.hierarchy.fallback {
            XCTAssertNotNil(t.accent[name], "hierarchy names unknown accent \(name)")
        }
    }

    func testBundledFontsMatchTokenPostScriptNames() throws {
        let t = try DesignTokens.decode(RepoFiles.data("Content/v1/design-tokens.json"))
        XCTAssertEqual(t.type.uiFamily, "Plus Jakarta Sans")
        for (role, ps) in t.type.postscript {
            let path = RepoFiles.root.appendingPathComponent("App/Resources/Fonts/\(ps).ttf").path
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "missing font for \(role): \(ps).ttf")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: RepoFiles.root.appendingPathComponent("App/Resources/Fonts/OFL.txt").path), "font license must ship")
    }

    /// Doc 29: every quest has tiered loot pools that resolve, and the tooltip preview is one reward per tier.
    func testQuestLootPoolsResolve() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        for q in bundle.quests {
            XCTAssertFalse(q.lootPools.isEmpty, "\(q.id) has no loot")
            XCTAssertEqual(q.lootPools.map { $0.tier }, ["common", "uncommon", "rare"], q.id.rawValue)
            for pool in q.lootPools { for r in pool.rewards { XCTAssertNotNil(bundle.reward(r)?.grants.first?.itemID, "\(q.id) \(r) must grant an item") } }
            XCTAssertEqual(q.previewRewards.count, 3, q.id.rawValue)
        }
        XCTAssertEqual(bundle.quest("quest.protein_row")?.loot?["rare"], ["reward.quest.row_shades"])
        let allLoot: [RewardID] = bundle.quests.flatMap { q in q.lootPools.flatMap { $0.rewards } }
        XCTAssertEqual(Set(allLoot).count, 9, "nine quest items across chapter one")
    }

    /// Doc 29: every quest item has its inventory still and a one-sentence description for the claim moment.
    func testQuestItemsHaveStillsAndDescriptions() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let questItems = Set(bundle.quests.flatMap { q in q.lootPools.flatMap { $0.rewards } }.compactMap { bundle.reward($0)?.grants.first?.itemID })
        XCTAssertEqual(questItems.count, 9)
        for id in questItems {
            let item = try XCTUnwrap(bundle.item(id))
            XCTAssertEqual(item.iconAssetSetID?.rawValue.hasPrefix("icon.item."), true, id.rawValue)
            let sentence = try XCTUnwrap(item.description, id.rawValue)
            XCTAssertTrue(sentence.hasSuffix("."), id.rawValue); XCTAssertLessThan(sentence.count, 140, id.rawValue)
            let manifest = try SpriteManifest.decode(RepoFiles.data("assets/sprites/\(item.iconAssetSetID!.rawValue)/rev1/manifest.json"))
            XCTAssertEqual(manifest.kind, .icon)
        }
        for tier in ["common", "uncommon", "rare", "legendary"] {
            XCTAssertEqual(try SpriteManifest.decode(RepoFiles.data("assets/sprites/icon.cache.\(tier)/rev1/manifest.json")).kind, .icon)
        }
    }
}

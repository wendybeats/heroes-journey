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
        XCTAssertNil(ruleset.dailyActivityXPCap, "owner 2026-10-17: strain replaced the hard cap")
        let strain = try XCTUnwrap(ruleset.dailyActivityStrain)
        XCTAssertEqual(strain.fullCreditXP, 120, "dev-5e: a session and a non-workout action both fit in a day at full credit")
        XCTAssertEqual(strain.bands.map(\.upTo), [200, 400]); XCTAssertEqual(strain.bands.map(\.rate), [0.5, 0.25])
        XCTAssertEqual(strain.credited(upToRaw: 400), 210, "a day tops out at 120 + 40 + 50"); XCTAssertEqual(strain.credited(upToRaw: 1000), 210)
        XCTAssertEqual(ruleset.bondGrant, .init(xp: 12, primaryPoints: 6, secondaryPoints: 4))
        XCTAssertEqual(ruleset.steps, .init(xpPerThousand: 4, dailyCapXP: 40, minDelta: 500), "owner 2026-10-17: steps earn, 10k = 40 a day")
        XCTAssertEqual(bundle.activityType("steps")?.loggingMode, .automatic, "steps come from Health, never by hand")
        XCTAssertEqual(bundle.goalCategories.map(\.id), ["body", "mind", "calm", "make", "order"], "doc 40 #17: the five categories")
        XCTAssertTrue(bundle.goalTemplates.allSatisfy { $0.category != nil }, "every template names a category")
        XCTAssertEqual(bundle.goalTemplates.filter { $0.needs != nil }.map(\.id.rawValue).sorted(), ["goal.create.music", "goal.create.photo"])
        XCTAssertEqual(ruleset.levelThresholdsTotalXP.first, 0)
        XCTAssertEqual(ruleset.levelThresholdsTotalXP, ruleset.levelThresholdsTotalXP.sorted(), "monotonic")
        XCTAssertEqual(ruleset.structuredWorkout?.defaultMinutes, 45)
        XCTAssertEqual(ruleset.structuredWorkout?.minutesPerValidSet, 2.5)
        XCTAssertEqual(ruleset.sessionBaseXP, 15); XCTAssertEqual(ruleset.healthHistoryWindowDays, 7)
        XCTAssertEqual(ruleset.goalXP, ["primary": 30, "secondary": 20, "small_win": 12])
        XCTAssertEqual(ruleset.dailyQuest?.durationMinutes, 240, "owner decision 2026-10-02")
        XCTAssertEqual(ruleset.dailyQuest?.rewardTable.map(\.tier), ["common", "uncommon", "rare", "page"], "doc 33: the page row only counts where a quest has a page pool")
        XCTAssertEqual(ruleset.dailyQuest?.rewardTable.map(\.xp), [10, 15, 25, 12])
        // Owner QA 2026-10-16: a page is found beside the gear; the row stays for replay at weight 0 and the page rolls on its own.
        XCTAssertEqual(ruleset.dailyQuest?.rewardTable.last?.weight, 0); XCTAssertEqual(ruleset.dailyQuest?.pageChance, 0.5)
        XCTAssertEqual(ruleset.dailyQuest?.pityRareAfter, 7); XCTAssertEqual(ruleset.dailyQuest?.tradeInXP?["rare"], 25, "doc 29")
        XCTAssertEqual(bundle.quests.count, 5, "the first walk, Protein Row and three gym quests (doc 28)")
        // Doc 40 #13: Cairon speaks once before the Face Colossus card; the scene is content on the manual beat.
        let boss = try XCTUnwrap(bundle.campaign.milestones.first { $0.trigger == .manual })
        XCTAssertEqual(boss.offerChapter, "chapter.colossus_offer"); XCTAssertNotNil(bundle.chapter("chapter.colossus_offer"))
        // Owner 2026-10-16: the hero is always on the left; every other speaker stands on the right.
        for c in bundle.characters { XCTAssertEqual(c.side, c.id == "hero" ? "left" : "right", c.id.rawValue) }
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
        // Owner 2026-10-12: five general physical prescriptions; the activity decides the attribute. No combat-specific goal.
        let physical: [FamilyID] = ["strength", "cardio", "combat", "mobility"]
        XCTAssertEqual(bundle.goalTemplate("goal.train.strength")?.rule, .anyFamily(families: physical, minMinutes: 30))
        XCTAssertEqual(bundle.goalTemplate("goal.train.strength")?.title, "Train for 30 min")
        XCTAssertEqual(bundle.goalTemplate("goal.train.strength.sets")?.rule, .anyFamily(families: physical, minMinutes: 10))
        XCTAssertEqual(bundle.goalTemplate("goal.train.cardio.long")?.rule, .anyFamily(families: physical, minMinutes: 45))
        XCTAssertEqual(bundle.goalTemplate("goal.rest.mobility")?.title, "Recover for 10 min")
        XCTAssertNil(bundle.goalTemplate("goal.train.combat"))
        for f in physical { XCTAssertEqual(bundle.goalTemplates.filter { $0.slot == .primary && $0.tags.contains("training") && $0.tags.contains(f.rawValue) }.count, 5, "\(f): the five physical prescriptions") }
        XCTAssertTrue(bundle.goalTemplates.allSatisfy { $0.lines.count >= 2 }, "every goal needs at least two lines so repeats read differently")
        // Round-trip: the rule enum's hand-written Codable must survive encode → decode.
        let data = try JSONEncoder().encode(bundle.goalTemplates)
        XCTAssertEqual(try JSONDecoder().decode([GoalTemplate].self, from: data), bundle.goalTemplates)
    }

    func testStoryContentDecodesAndResolvesTheWorldName() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        XCTAssertEqual(bundle.characters.map(\.id), ["guide.elder", "hero", "chad_colossus", "npc.gym.lifter_01", "npc.gym.lifter_02", "npc.gym.lifter_03"])
        XCTAssertEqual(Array(bundle.storyChapters.map(\.id).prefix(2)), ["chapter.awakening", "chapter.first_training"])
        XCTAssertEqual(bundle.storyChapters.count, 18, "doc 40 #13 added the scene before the Face Colossus card")
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
        // Owner 2026-10-16: Colossus is fought inside Area 1, so the gym nests in the Under City band and the rest moved up one.
        XCTAssertEqual(bundle.area("colossus_gym")?.levels, [5, 10]); XCTAssertEqual(bundle.area("central_hill")?.levels, [11, 18])
        XCTAssertEqual(bundle.area("ascension_boundary")?.levels, [82, 100])
        XCTAssertEqual(bundle.area(forLevel: 1)?.id, "under_city"); XCTAssertEqual(bundle.area(forLevel: 10)?.id, "under_city")
        XCTAssertEqual(bundle.area(forLevel: 11)?.id, "central_hill"); XCTAssertEqual(bundle.area(forLevel: 100)?.id, "ascension_boundary")
        XCTAssertEqual(bundle.area(forLevel: 7)?.id, "under_city", "the band wins over the nested gym for level lookups")
        XCTAssertEqual(bundle.area("grand_court")?.antagonist, "The Mirror")
        XCTAssertEqual(bundle.defaultQuest?.displayName, "Under City")
    }

    func testLevelRewardsAndEvolutions() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let rewards = bundle.levelRewards
        XCTAssertTrue(rewards.isEmpty, "owner 2026-10-05: level-up grants are off; the former level rewards stay defined as unassigned")
        XCTAssertEqual(bundle.rewards.filter { $0.trigger.type == "unassigned" }.count, 9, "the former level rewards are kept for the chapter to assign; doc 33 gave the rain to Protein Row")
        XCTAssertEqual(bundle.evolution(forLevel: 1)?.id, "ev1_awakened")
        // Doc 32: evolutions are ascension tiers on one canonical body; the starter outfit is items.
        XCTAssertEqual(bundle.evolutions.map { $0.ascensionTier ?? -1 }, [0, 1, 2, 3, 4, 5], "doc 38: six states")
        // Owner 2026-10-06: the first Ascension is a cutscene; its scene is content on the evolution and must resolve.
        XCTAssertEqual(bundle.evolution(forLevel: 8)?.ascensionChapter, "chapter.ascension_1", "owner 2026-10-16: tier I at Level 8")
        XCTAssertEqual(bundle.chapter("chapter.ascension_1")?.then, "return"); XCTAssertEqual(bundle.chapter("chapter.ascension_1")?.beats.first?.speaker, "guide.elder")
        XCTAssertNil(bundle.evolution(forLevel: 1)?.ascensionChapter)
        XCTAssertEqual(bundle.evolution(forLevel: 18)?.ascensionChapter, "chapter.ascension_2"); XCTAssertEqual(bundle.evolution(forLevel: 10)?.ascensionChapter, "chapter.ascension_1", "Level 10 is still tier I")
        XCTAssertEqual(Set(bundle.evolutions.map { $0.outfit ?? "" }), ["suit"])
        let starter = bundle.starterEquipment
        XCTAssertEqual(Set(starter.keys), [.body, .legs, .feet]); XCTAssertEqual(starter[.body], "item.hoodie.starter")
        XCTAssertEqual(bundle.items.filter(\.isStarter).count, 3)
        XCTAssertEqual(bundle.evolution(forLevel: 7)?.id, "ev1_awakened")
        XCTAssertEqual(bundle.evolution(forLevel: 8)?.id, "ev2_evolution1")
        XCTAssertEqual(bundle.evolution(forLevel: 18)?.id, "ev3_evolution2")
        XCTAssertEqual(bundle.evolution(forLevel: 30)?.id, "ev4_evolution3"); XCTAssertEqual(bundle.evolution(forLevel: 46)?.id, "ev5_evolution4")
        XCTAssertEqual(bundle.evolution(forLevel: 99)?.id, "ev6_evolution5")
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

    /// Doc 33: beats wait for their quest; challenges resolve; the ruleset prices them.
    func testChallengesAndHeldBeatsResolve() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let ruleset = try ProgressionRuleset.decode(RepoFiles.data("Content/v1/ruleset.dev-5.json"))
        XCTAssertEqual(bundle.campaign.milestone("under_city.6.enter")?.requiresQuest, "quest.colossus_gym_01")
        XCTAssertEqual(bundle.campaign.milestone("under_city.8.reveal")?.requiresQuest, "quest.colossus_gym_02")
        XCTAssertEqual(bundle.campaign.milestone("under_city.10.resolution")?.requiresQuest, "quest.colossus_gym_03")
        let gate = bundle.campaign.milestone("under_city.10.resolution")?.requiresAreaQuests
        XCTAssertEqual(gate?.areaID, "colossus_gym"); XCTAssertEqual(gate?.count, 3, "doc 34: the boss waits for three gym runs"); XCTAssertEqual(gate?.heldLines.count, 3)
        XCTAssertNotNil(bundle.campaign.milestone("under_city.6.enter")?.heldLine)
        XCTAssertNil(bundle.campaign.milestone("under_city.5.gym_unlock")?.requiresQuest)
        XCTAssertEqual(bundle.challenges.count, 7, "Cairon's four and the three lifters'")
        XCTAssertEqual(Set(bundle.challenges.filter { $0.characterID == "guide.elder" }.map(\.attributeID)), ["strength", "endurance", "knowledge", "mindfulness"])
        let spot = try XCTUnwrap(bundle.challenge("challenge.gym.lifter_01.spot"))
        XCTAssertEqual(spot.availableAfterQuest, "quest.colossus_gym_01"); XCTAssertEqual(spot.sets.count, 2); XCTAssertEqual(spot.set(forMeeting: 2)?.offer, spot.sets[0].offer, "sets cycle")
        XCTAssertEqual(bundle.character("npc.gym.lifter_01")?.spriteAssetSetID, "npc.gym.lifter_01")
        XCTAssertEqual(bundle.character("guide.elder")?.cardPortrait, "portrait.guide_elder.left"); XCTAssertEqual(bundle.character("guide.elder")?.spriteAssetSetID, "npc.guide_elder")
        XCTAssertEqual(ruleset.challenges?.grant["hard"]?.points, 1); XCTAssertEqual(ruleset.challenges?.grant["easy"]?.loseXP, 2)
        XCTAssertEqual(ruleset.challenges?.cadence.chancePerDay, 0.45); XCTAssertEqual(ruleset.challenges?.cadence.maxGapDays, 2)
        XCTAssertEqual(bundle.integrityProblems(against: ruleset), [])
        // Every difficulty word in content has a grant and a multiple in the ruleset.
        for ch in bundle.challenges { XCTAssertNotNil(ruleset.challenges?.grant[ch.difficulty], ch.id.rawValue); XCTAssertNotNil(ruleset.challenges?.difficulty[ch.difficulty], ch.id.rawValue) }
    }

    /// Doc 29: every quest has tiered loot pools that resolve, and the tooltip preview is one reward per tier.
    func testQuestLootPoolsResolve() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        for q in bundle.quests {
            XCTAssertFalse(q.lootPools.isEmpty, "\(q.id) has no loot")
            // Doc 33: the gym quests also carry a page pool (Colossus's log); the walks do not.
            let isGym = q.id.rawValue.hasPrefix("quest.colossus_gym")
            XCTAssertEqual(q.lootPools.map { $0.tier }, isGym ? ["common", "uncommon", "rare", "page"] : ["common", "uncommon", "rare"], q.id.rawValue)
            for pool in q.lootPools { for r in pool.rewards { XCTAssertNotNil(bundle.reward(r)?.grants.first?.itemID, "\(q.id) \(r) must grant an item") } }
            XCTAssertEqual(q.previewRewards.count, isGym ? 4 : 3, q.id.rawValue)
            if isGym { XCTAssertEqual(q.loot?["page"]?.count, 4, "\(q.id): four pages per gym quest, overlapping so every page is reachable") }
        }
        XCTAssertEqual(bundle.quest("quest.protein_row")?.loot?["rare"], ["reward.quest.row_shades"])
        let allLoot: [RewardID] = bundle.quests.flatMap { q in q.lootPools.flatMap { $0.rewards } }
        XCTAssertEqual(Set(allLoot).count, 17, "nine quest items plus eight log pages across chapter one")
        let pageRewards = Set(bundle.quests.flatMap { $0.loot?["page"] ?? [] })
        XCTAssertEqual(pageRewards.count, 8, "every page is in some gym quest's pool")
    }

    /// Doc 29: every quest item has its inventory still and a one-sentence description for the claim moment.
    func testQuestItemsHaveStillsAndDescriptions() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let questItems = Set(bundle.quests.flatMap { q in q.lootPools.flatMap { $0.rewards } }.compactMap { bundle.reward($0)?.grants.first?.itemID })
        XCTAssertEqual(questItems.count, 17, "nine wearables and eight log pages")
        XCTAssertEqual(questItems.filter { bundle.item($0)?.slot == .collectible }.count, 8)
        for id in questItems {
            let item = try XCTUnwrap(bundle.item(id))
            XCTAssertEqual(item.slot.isWearable, item.slot != .collectible, id.rawValue)
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

    /// Doc 33 §C: the between-beat content. Repeat exchanges on the gym quests (the first completion plays the
    /// end scene, later ones cycle the short exchanges), Row rumours gated on milestones, story-aware goal lines
    /// gated on flags the app can raise, and the rain on Protein Row stops once that quest is done.
    func testBetweenBeatContent() throws {
        let bundle = try ContentBundle.decode(RepoFiles.data("Content/v1/bundle.json"))
        let gym1 = try XCTUnwrap(bundle.quest("quest.colossus_gym_01"))
        XCTAssertEqual(gym1.repeatExchanges?.count, 3)
        XCTAssertNil(gym1.repeatExchange(forCompletion: 1), "the first completion plays the end scene, not an exchange")
        XCTAssertEqual(gym1.repeatExchange(forCompletion: 2), gym1.repeatExchanges?[0])
        XCTAssertEqual(gym1.repeatExchange(forCompletion: 4), gym1.repeatExchanges?[2])
        XCTAssertEqual(gym1.repeatExchange(forCompletion: 5), gym1.repeatExchanges?[0], "exchanges cycle")
        XCTAssertNil(bundle.quest("quest.lower_district")?.repeatExchange(forCompletion: 2), "the walks have none")
        for q in bundle.quests { for x in q.repeatExchanges ?? [] { XCTAssertLessThanOrEqual(x.flatMap(\.lines).count, 4, "\(q.id): an exchange is short") } }
        XCTAssertEqual(bundle.rumours.count, 12)
        let milestoneIDs = Set(bundle.campaign.chapters.flatMap { $0.milestones.map(\.id) })
        for r in bundle.rumours { XCTAssertTrue(milestoneIDs.contains(r.after), "rumour gated on unknown milestone \(r.after.rawValue)") }
        XCTAssertEqual(bundle.rumours.filter { $0.after == "under_city.3.protein_row" }.count, 6, "six rumours open with the Row")
        let storyLined = bundle.goalTemplates.filter { !$0.storyLines.isEmpty }
        XCTAssertEqual(storyLined.map(\.id.rawValue).sorted(), ["goal.rest.walk", "goal.train.strength"], "the Central Hill line stays in drafts until chapter two")
        for t in storyLined { for s in t.storyLines { XCTAssertFalse(s.lines.isEmpty, t.id.rawValue); XCTAssertTrue(milestoneIDs.contains(MilestoneID(s.after)) || s.after.hasPrefix("quest."), "\(t.id): \(s.after)") } }
        let rain = try XCTUnwrap(bundle.reward("reward.l3.world"))
        XCTAssertEqual(rain.trigger.questID, "quest.protein_row", "the rain stops when Protein Row is first completed, not at a level")
        XCTAssertEqual(rain.displayName, "The rain stops")
        XCTAssertEqual(bundle.rewards(onCompleting: "quest.protein_row").map(\.id), ["reward.l3.world"])
        XCTAssertTrue(bundle.rewards(onCompleting: "quest.lower_district").isEmpty)
    }
}

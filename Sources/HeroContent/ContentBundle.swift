import Foundation
import HeroDomain

/// Decoded `Content/v1/bundle.json`. Every object carries a stable ID; the bundle carries
/// a content version so a future revision can be diffed and migrated (doc 10, doc 11).
public struct ContentBundle: Codable, Sendable, Equatable {
    public struct Family: Codable, Sendable, Equatable {
        public let id: FamilyID
        public let displayName: String
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name" }
    }
    public struct ActivityType: Codable, Sendable, Equatable {
        public enum LoggingMode: String, Codable, Sendable { case simple, detailed }
        public let id: ActivityTypeID
        public let familyID: FamilyID
        public let displayName: String
        public let defaultDurationSeconds: Int?
        public let loggingMode: LoggingMode
        /// Optional facts the manual log offers for this activity: `sets`, `distance`, `rounds`.
        public let loggingExtras: [String]?
        enum CodingKeys: String, CodingKey {
            case id, familyID = "family_id", displayName = "display_name"
            case defaultDurationSeconds = "default_duration_seconds", loggingMode = "logging_mode", loggingExtras = "logging_extras"
        }
        public func offers(_ extra: String) -> Bool { loggingExtras?.contains(extra) == true }
    }
    public struct Attribute: Codable, Sendable, Equatable {
        public let id: AttributeID
        public let displayName: String
        public let token: String
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name", token }
    }
    public struct Evolution: Codable, Sendable, Equatable {
        public let id: EvolutionID
        public let displayName: String
        public let minLevel: Int
        public let assetSetID: AssetSetID
        /// Legacy renderer hint. Since doc 32 every evolution renders the canonical body; kept for old content.
        public let outfit: String?
        /// Doc 32: the ascension tier this evolution confers (0 = none). Effects around the body, never a new body.
        public let ascensionTier: Int?
        /// Owner 2026-10-06: the scene that plays right after this evolution's Ascension takeover (the guide explains what happened).
        public let ascensionChapter: String?
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name", minLevel = "min_level", assetSetID = "asset_set_id", outfit, ascensionTier = "ascension_tier", ascensionChapter = "ascension_chapter" }
    }
    public struct Item: Codable, Sendable, Equatable {
        public let id: ItemID
        public let displayName: String
        public let slot: AvatarRecipe.Slot
        public let rarity: String
        public let assetSetID: AssetSetID
        /// Inventory still (`kind: icon`) for the claim modal, loot box and room list (doc 29).
        public let iconAssetSetID: AssetSetID?
        /// One sentence, shown when the item is claimed.
        public let description: String?
        /// Doc 32: part of the starter outfit, owned by everyone and worn until the player changes it.
        public let starter: Bool?
        public var isStarter: Bool { starter == true }
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name", slot, rarity, assetSetID = "asset_set_id", iconAssetSetID = "icon_asset_set_id", description, starter }
    }
    public struct Reward: Codable, Sendable, Equatable {
        public struct Trigger: Codable, Sendable, Equatable {
            public let type: String
            public let level: Int?
        }
        public struct Grant: Codable, Sendable, Equatable {
            public let type: String
            public let itemID: ItemID?
            public let evolutionID: EvolutionID?
            public let backdropID: BackdropID?
            public let reactionID: String?
            enum CodingKeys: String, CodingKey {
                case type, itemID = "item_id", evolutionID = "evolution_id", backdropID = "backdrop_id", reactionID = "reaction_id"
            }
        }
        public let id: RewardID
        public let trigger: Trigger
        public let grants: [Grant]
    }
    public struct Backdrop: Codable, Sendable, Equatable {
        public let id: BackdropID
        public let displayName: String
        public let palette: String
        public let assetSetID: AssetSetID
        public let isDefault: Bool?
        /// `home` (selectable scene, default), `story` (dialogue staging), `quest` (scrolled panorama).
        public let role: String?
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name", palette, assetSetID = "asset_set_id", isDefault = "default", role }
        public var isHomeScene: Bool { role == nil || role == "home" }
    }
    public struct ExerciseDefinition: Codable, Sendable, Equatable {
        public let id: ExerciseID
        public let displayName: String
        public let defaultSetType: SetType
        public let muscleGroup: String
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name", defaultSetType = "default_set_type", muscleGroup = "muscle_group" }
    }
    public struct HealthWorkoutMapping: Codable, Sendable, Equatable {
        public let fallbackActivityType: ActivityTypeID
        public let map: [String: ActivityTypeID]
        enum CodingKeys: String, CodingKey { case fallbackActivityType = "fallback_activity_type", map }
    }
    public struct AvatarOptions: Codable, Sendable, Equatable {
        public let baseBodies: [String]
        public let skinPalettes: [String]
        public let hairStylesByBody: [String: [String]]
        public let hairPalettes: [String]
        public let displayNames: [String: String]
        enum CodingKeys: String, CodingKey {
            case baseBodies = "base_bodies", skinPalettes = "skin_palettes", hairStylesByBody = "hair_styles_by_body"
            case hairPalettes = "hair_palettes", displayNames = "display_names"
        }
        public func hairStyles(for body: String) -> [String] { hairStylesByBody[body] ?? [] }
        public func displayName(_ id: String) -> String { displayNames[id] ?? id }
    }

    public let schemaVersion: Int
    public let contentVersion: String
    public let families: [Family]
    public let activityTypes: [ActivityType]
    public let attributes: [Attribute]
    public let evolutions: [Evolution]
    public let items: [Item]
    public let rewards: [Reward]
    public let backdrops: [Backdrop]
    public let avatarOptions: AvatarOptions
    public let exerciseDefinitions: [ExerciseDefinition]
    public let healthWorkoutMapping: HealthWorkoutMapping
    /// Daily goal templates (doc 24). Copy and rules are content, selection is domain.
    public let goalTemplates: [GoalTemplate]
    /// Daily quests (doc 24). One in MVP; copy lives here, duration and rewards in the ruleset.
    public let quests: [Quest]
    /// Undecided until the owner names the world; lines carry a `without_world` variant meanwhile.
    public let worldName: String?
    public let characters: [Character]
    public let storyChapters: [StoryChapter]
    /// One per day on the stage screen, chosen by day number (owner QA 2026-10-02).
    public let dailyQuotes: [Quote]
    /// The campaign's areas (doc 26 §8–10): data only until area content exists.
    public let areas: [Area]
    /// Chapters of milestones bound to levels (doc 28). The director plays them; nothing else reads levels for story.
    public let campaign: Campaign

    public struct Area: Codable, Sendable, Equatable {
        public let id: AreaID
        public let displayName: String
        public let band: Int
        public let theme: String
        /// Inclusive level range the area spans in the provisional campaign order.
        public let levels: [Int]
        public let antagonist: String?
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name", band, theme, levels, antagonist }
        public var levelRange: ClosedRange<Int> { (levels.first ?? 1)...(levels.last ?? levels.first ?? 1) }
    }

    public struct Quote: Codable, Sendable, Equatable {
        public let text: String
        public let source: String
    }

    public struct Quest: Codable, Sendable, Equatable {
        public let id: QuestID
        public let displayName: String
        /// Panorama scrolled behind the walking character on departure.
        public let backdropID: BackdropID?
        /// Walk-cycle asset set (gender-neutral hooded figure until per-outfit walks exist).
        public let walkAssetSetID: AssetSetID?
        /// Said before the notification permission prompt at the first departure.
        public let notificationPrompt: String?
        /// Under the path on the departure screen.
        public let subtext: String?
        /// Rewards shown in the loot-box tooltip, in tier order. Optional: derived from `loot` when absent.
        public let lootPreview: [RewardID]?
        /// This quest's reward pools by tier (doc 29). The ruleset table rolls the tier; the app picks an
        /// ungranted reward from the pool. Absent = the ruleset row's reward.
        public let loot: [String: [RewardID]]?
        /// Campaign placement (doc 28). A quest with `unlocked_by_milestone` is offered once that milestone is complete.
        public let areaID: AreaID?
        public let unlockedByMilestone: MilestoneID?
        /// Overrides the ruleset's daily quest duration (owner 2026-10-05: gym quests run 8 h).
        public let durationMinutes: Int?
        /// Chapter played at the return reveal: the quest's end scene.
        public let onReturnChapter: String?
        /// Shown on departure.
        public let departLines: [String]
        /// Shown on Home while away.
        public let awayLines: [String]
        /// Keyed by reward tier (`common`, `uncommon`, `rare`); shown at return.
        public let returnLines: [String: [String]]
        /// Chapter played before departure on this quest, once (gym floors). Optional.
        public let onDepartChapter: String?
        public static let tierOrder = ["common", "uncommon", "rare"]
        /// One reward per tier for the loot tooltip: the explicit preview, else the first of each pool.
        public var previewRewards: [RewardID] { lootPreview ?? Self.tierOrder.compactMap { loot?[$0]?.first } }
        public var lootPools: [LootPool] { Self.tierOrder.compactMap { t in loot?[t].map { LootPool(tier: t, rewards: $0) } } }
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name", backdropID = "backdrop_id", walkAssetSetID = "walk_asset_set_id", notificationPrompt = "notification_prompt", subtext, lootPreview = "loot_preview", loot, areaID = "area_id", unlockedByMilestone = "unlocked_by_milestone", durationMinutes = "duration_minutes", onReturnChapter = "on_return_chapter", onDepartChapter = "on_depart_chapter", departLines = "depart_lines", awayLines = "away_lines", returnLines = "return_lines" }
    }

    /// A speaking character (doc 25). The hero is one too; its portrait is replaced by the live sprite after creation.
    public struct Character: Codable, Sendable, Equatable {
        public let id: CharacterID
        public let displayName: String
        /// Nil while the portrait is unauthored: the stage shows a named placeholder.
        public let portraitAssetSetID: AssetSetID?
        /// `left` or `right`: which side of the stage the portrait sits on; bubbles sit opposite.
        public let side: String
        /// Full-body sprite set for staging (NPCs), at the shared pixel scale. Optional; nil = portrait only.
        public let spriteAssetSetID: AssetSetID?
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name", portraitAssetSetID = "portrait_asset_set_id", side, spriteAssetSetID = "sprite_asset_set_id" }
    }

    /// One line of dialogue. Markdown emphasis (`**bold**`, `*italic*`) is allowed. `{world}` is the
    /// world name; while it is undecided the `without_world` variant is shown.
    public struct StoryLine: Codable, Sendable, Equatable {
        public let text: String
        public let withoutWorld: String?
        public init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer().decode(String.self) { text = single; withoutWorld = nil; return }
            let c = try decoder.container(keyedBy: CodingKeys.self)
            text = try c.decode(String.self, forKey: .text); withoutWorld = try c.decodeIfPresent(String.self, forKey: .withoutWorld)
        }
        public func encode(to encoder: Encoder) throws {
            if withoutWorld == nil { var c = encoder.singleValueContainer(); try c.encode(text) }
            else { var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(text, forKey: .text); try c.encode(withoutWorld, forKey: .withoutWorld) }
        }
        enum CodingKeys: String, CodingKey { case text, withoutWorld = "without_world" }
        /// Resolved copy for a world name (nil = undecided).
        public func resolved(worldName: String?) -> String {
            if let worldName { return text.replacingOccurrences(of: "{world}", with: worldName) }
            return withoutWorld ?? text.replacingOccurrences(of: " of {world}", with: "").replacingOccurrences(of: "{world}", with: "this world")
        }
    }
    public struct StoryBeat: Codable, Sendable, Equatable {
        public let speaker: CharacterID
        public let lines: [StoryLine]
    }
    public struct StoryChapter: Codable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let backdropID: BackdropID
        /// What follows the last line: `create_character`, `home`, `return` (back to wherever it was shown), or `room` (open the player's room).
        public let then: String
        public let beats: [StoryBeat]
        /// A chapter that plays straight after this one, on its own backdrop (owner 2026-10-05: the Colossus
        /// scene ends inside, the Central Hill tease is said outside). The milestone completes after the chain.
        public let nextChapter: String?
        enum CodingKeys: String, CodingKey { case id, title, backdropID = "backdrop_id", then, beats, nextChapter = "next_chapter" }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", contentVersion = "content_version"
        case families, activityTypes = "activity_types", attributes, evolutions, items, rewards, backdrops
        case avatarOptions = "avatar_options", exerciseDefinitions = "exercise_definitions", healthWorkoutMapping = "health_workout_mapping"
        case goalTemplates = "goal_templates", quests, worldName = "world_name", characters, storyChapters = "story_chapters", dailyQuotes = "daily_quotes", areas, campaign
    }

    public static func decode(_ data: Data) throws -> ContentBundle {
        try JSONDecoder().decode(ContentBundle.self, from: data)
    }

    // MARK: lookups

    public func activityType(_ id: ActivityTypeID) -> ActivityType? { activityTypes.first { $0.id == id } }
    public func family(_ id: FamilyID) -> Family? { families.first { $0.id == id } }
    public func evolution(_ id: EvolutionID) -> Evolution? { evolutions.first { $0.id == id } }
    public func item(_ id: ItemID) -> Item? { items.first { $0.id == id } }
    public func exercise(_ id: ExerciseID) -> ExerciseDefinition? { exerciseDefinitions.first { $0.id == id } }
    public func goalTemplate(_ id: GoalTemplateID) -> GoalTemplate? { goalTemplates.first { $0.id == id } }
    public func quest(_ id: QuestID) -> Quest? { quests.first { $0.id == id } }
    public var defaultQuest: Quest? { quests.first }
    public func character(_ id: CharacterID) -> Character? { characters.first { $0.id == id } }
    public func chapter(_ id: String) -> StoryChapter? { storyChapters.first { $0.id == id } }
    public func reward(_ id: RewardID) -> Reward? { rewards.first { $0.id == id } }
    public func area(_ id: AreaID) -> Area? { areas.first { $0.id == id } }
    /// The area whose level range holds `level` (doc 26 §10).
    public func area(forLevel level: Int) -> Area? { areas.first { $0.levelRange.contains(level) } }
    /// Deterministic per day number so everyone on day N reads the same line.
    public func quote(forDay day: Int) -> Quote? { dailyQuotes.isEmpty ? nil : dailyQuotes[max(0, day - 1) % dailyQuotes.count] }
    public func backdrop(_ id: BackdropID) -> Backdrop? { backdrops.first { $0.id == id } }
    /// Doc 32: the starter outfit, one item per slot, worn from character creation.
    public var starterEquipment: [AvatarRecipe.Slot: ItemID] {
        var out: [AvatarRecipe.Slot: ItemID] = [:]
        for item in items where item.isStarter && out[item.slot] == nil { out[item.slot] = item.id }
        return out
    }
    public var defaultBackdrop: Backdrop? { backdrops.first { $0.isDefault == true } ?? backdrops.first { $0.isHomeScene } }

    /// Level → reward IDs, the shape `EvaluationContext` wants.
    public var levelRewards: [Int: [RewardID]] {
        var out: [Int: [RewardID]] = [:]
        for reward in rewards where reward.trigger.type == "level" {
            if let level = reward.trigger.level { out[level, default: []].append(reward.id) }
        }
        return out
    }

    /// Evolution for a level: the highest `min_level` not exceeding it.
    public func evolution(forLevel level: Int) -> Evolution? {
        evolutions.filter { $0.minLevel <= level }.max { $0.minLevel < $1.minLevel }
    }

    /// Referential integrity. Returns every dangling reference; empty means valid.
    public func integrityProblems() -> [String] {
        var problems: [String] = []
        let familyIDs = Set(families.map(\.id))
        let itemIDs = Set(items.map(\.id))
        let evolutionIDs = Set(evolutions.map(\.id))
        let backdropIDs = Set(backdrops.map(\.id))
        func unique<T: Hashable>(_ ids: [T], _ label: String) {
            if Set(ids).count != ids.count { problems.append("duplicate \(label) ids") }
        }
        unique(families.map(\.id), "family"); unique(activityTypes.map(\.id), "activity_type")
        unique(attributes.map(\.id), "attribute"); unique(evolutions.map(\.id), "evolution")
        unique(items.map(\.id), "item"); unique(rewards.map(\.id), "reward"); unique(backdrops.map(\.id), "backdrop")
        unique(exerciseDefinitions.map(\.id), "exercise")
        let typeIDs = Set(activityTypes.map(\.id))
        for (kind, id) in healthWorkoutMapping.map where !typeIDs.contains(id) { problems.append("health mapping \(kind) → unknown activity \(id)") }
        if !typeIDs.contains(healthWorkoutMapping.fallbackActivityType) { problems.append("health mapping fallback is unknown") }
        if activityType("weightlifting") == nil || activityType("calisthenics") == nil { problems.append("strength logger needs weightlifting and calisthenics activity types") }
        for a in activityTypes where !familyIDs.contains(a.familyID) { problems.append("activity \(a.id) → unknown family \(a.familyID)") }
        for r in rewards {
            for g in r.grants {
                if let i = g.itemID, !itemIDs.contains(i) { problems.append("reward \(r.id) → unknown item \(i)") }
                if let e = g.evolutionID, !evolutionIDs.contains(e) { problems.append("reward \(r.id) → unknown evolution \(e)") }
                if let b = g.backdropID, !backdropIDs.contains(b) { problems.append("reward \(r.id) → unknown backdrop \(b)") }
            }
        }
        if !evolutions.contains(where: { $0.minLevel == 1 }) { problems.append("no evolution with min_level 1") }
        unique(goalTemplates.map(\.id), "goal_template")
        let attributeIDs = Set(attributes.map(\.id))
        for t in goalTemplates {
            if !attributeIDs.contains(t.attributeID) { problems.append("goal \(t.id) → unknown attribute \(t.attributeID)") }
            if t.lines.isEmpty { problems.append("goal \(t.id) has no lines") }
            if case let .activityFamily(f, _) = t.rule, !familyIDs.contains(f) { problems.append("goal \(t.id) → unknown family \(f)") }
            for tag in t.tags where familyIDs.contains(FamilyID(tag)) == false && !["training", "rest", "learning", "mindfulness", "creativity", "rare", "strength_goal", "energy", "calm", "discipline", "balance", "steps"].contains(tag) {
                problems.append("goal \(t.id) has unknown tag \(tag)")
            }
        }
        for slot in GoalSlot.allCases where !goalTemplates.contains(where: { $0.slot == slot }) { problems.append("no goal template for slot \(slot.rawValue)") }
        for f in families where !goalTemplates.contains(where: { $0.slot == .primary && $0.tags.contains("training") && $0.tags.contains(f.id.rawValue) }) {
            problems.append("no training-day primary goal for family \(f.id)")
        }
        if !goalTemplates.contains(where: { $0.slot == .primary && $0.tags.contains("rest") }) { problems.append("no rest-day primary goal") }
        unique(quests.map(\.id), "quest")
        if quests.isEmpty { problems.append("no quest defined") }
        for q in quests where q.departLines.isEmpty || q.awayLines.isEmpty { problems.append("quest \(q.id) is missing lines") }
        for q in quests {
            if let b = q.backdropID, !backdropIDs.contains(b) { problems.append("quest \(q.id) → unknown backdrop \(b)") }
            for r in q.lootPreview ?? [] where !rewards.contains(where: { $0.id == r }) { problems.append("quest \(q.id) loot preview → unknown reward \(r)") }
            for (tier, pool) in q.loot ?? [:] {
                if !Quest.tierOrder.contains(tier) { problems.append("quest \(q.id) loot tier \(tier) is not a reward tier") }
                for r in pool where !rewards.contains(where: { $0.id == r }) { problems.append("quest \(q.id) loot \(tier) → unknown reward \(r)") }
            }
        }
        if dailyQuotes.isEmpty { problems.append("no daily quotes") }
        unique(areas.map(\.id), "area")
        var expected = 1
        for area in areas.sorted(by: { $0.levelRange.lowerBound < $1.levelRange.lowerBound }) {
            if area.levels.count != 2 || area.levelRange.lowerBound != expected { problems.append("area \(area.id) levels must start at \(expected)") }
            expected = area.levelRange.upperBound + 1
        }
        if !areas.isEmpty && expected <= 1 { problems.append("areas must cover a contiguous range from level 1") }
        // Campaign: ids unique, references resolve, levels inside the chapter, at most one completion per chapter.
        unique(campaign.milestones.map(\.id.rawValue), "milestone")
        let areaIDs = Set(areas.map(\.id)), chapterIDs = Set(storyChapters.map(\.id)), questIDs = Set(quests.map(\.id)), rewardIDsAll = Set(rewards.map(\.id))
        for ch in campaign.chapters {
            if !areaIDs.contains(ch.areaID) { problems.append("campaign chapter \(ch.id) → unknown area \(ch.areaID)") }
            if ch.milestones.filter(\.completesChapter).count > 1 { problems.append("campaign chapter \(ch.id) completes more than once") }
            for m in ch.milestones {
                if !ch.levelRange.contains(m.level) { problems.append("milestone \(m.id) level \(m.level) outside chapter \(ch.id)") }
                if let s = m.storyChapter, !chapterIDs.contains(s) { problems.append("milestone \(m.id) → unknown story chapter \(s)") }
                if let b = m.unlockBackdrop, !backdropIDs.contains(b) { problems.append("milestone \(m.id) → unknown backdrop \(b)") }
                if let q = m.unlockQuest, !questIDs.contains(q) { problems.append("milestone \(m.id) → unknown quest \(q)") }
                if let r = m.reward, !rewardIDsAll.contains(r) { problems.append("milestone \(m.id) → unknown reward \(r)") }
                if let t = m.teaseArea, !areaIDs.contains(t) { problems.append("milestone \(m.id) → unknown tease area \(t)") }
                if m.trigger == .manual && m.triggerLabel == nil { problems.append("milestone \(m.id) is manual but has no trigger_label") }
            }
        }
        let milestoneIDs = Set(campaign.milestones.map(\.id))
        for q in quests {
            if let g = q.unlockedByMilestone, !milestoneIDs.contains(g) { problems.append("quest \(q.id) → unknown milestone \(g)") }
            for c in [q.onReturnChapter, q.onDepartChapter].compactMap({ $0 }) where !chapterIDs.contains(c) { problems.append("quest \(q.id) → unknown chapter \(c)") }
        }
        unique(characters.map(\.id), "character"); unique(storyChapters.map(\.id), "story_chapter")
        let characterIDs = Set(characters.map(\.id))
        for ch in storyChapters {
            if !backdropIDs.contains(ch.backdropID) { problems.append("chapter \(ch.id) → unknown backdrop \(ch.backdropID)") }
            if !["create_character", "home", "return", "room"].contains(ch.then) { problems.append("chapter \(ch.id) has unknown 'then' \(ch.then)") }
            if let next = ch.nextChapter {
                if next == ch.id || !chapterIDs.contains(next) { problems.append("chapter \(ch.id) → unknown or self next_chapter \(next)") }
                else if storyChapters.first(where: { $0.id == next })?.nextChapter != nil { problems.append("chapter \(ch.id): next_chapter chains are one link long") }
            }
            if ch.beats.isEmpty { problems.append("chapter \(ch.id) has no beats") }
            for beat in ch.beats {
                if !characterIDs.contains(beat.speaker) { problems.append("chapter \(ch.id) → unknown speaker \(beat.speaker)") }
                if beat.lines.isEmpty { problems.append("chapter \(ch.id) has an empty beat") }
                for line in beat.lines where line.text.contains("{world}") && line.withoutWorld == nil && worldName == nil {
                    problems.append("chapter \(ch.id): line uses {world} with no world name and no without_world variant")
                }
            }
        }
        if defaultBackdrop?.isHomeScene != true { problems.append("default backdrop must be a home scene") }
        for ev in evolutions {
            if let c = ev.ascensionChapter, !chapterIDs.contains(c) { problems.append("evolution \(ev.id) → unknown ascension_chapter \(c)") }
        }
        return problems
    }

    /// Ruleset families must cover every content family, or an activity would silently earn nothing.
    public func integrityProblems(against ruleset: ProgressionRuleset) -> [String] {
        var problems = integrityProblems()
        let attributeIDs = Set(attributes.map(\.id.rawValue))
        for f in families {
            if ruleset.xpPerMinuteByFamily[f.id.rawValue] == nil { problems.append("ruleset has no xp rate for family \(f.id)") }
            for key in (ruleset.attributeWeightsByFamily[f.id.rawValue] ?? [:]).keys where !attributeIDs.contains(key) {
                problems.append("ruleset weights unknown attribute \(key) for family \(f.id)")
            }
        }
        if let quest = ruleset.dailyQuest {
            let rewardIDs = Set(rewards.map(\.id))
            if quest.rewardTable.isEmpty { problems.append("ruleset daily_quest has an empty reward table") }
            if quest.durationMinutes <= 0 { problems.append("ruleset daily_quest duration must be positive") }
            for entry in quest.rewardTable {
                if let r = entry.rewardID, !rewardIDs.contains(r) { problems.append("quest reward table → unknown reward \(r)") }
                for q in quests where q.returnLines[entry.tier]?.isEmpty ?? true { problems.append("quest \(q.id) has no return lines for tier \(entry.tier)") }
            }
        }
        return problems
    }
}

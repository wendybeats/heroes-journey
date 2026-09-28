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
        enum CodingKeys: String, CodingKey {
            case id, familyID = "family_id", displayName = "display_name"
            case defaultDurationSeconds = "default_duration_seconds", loggingMode = "logging_mode"
        }
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
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name", minLevel = "min_level", assetSetID = "asset_set_id" }
    }
    public struct Item: Codable, Sendable, Equatable {
        public let id: ItemID
        public let displayName: String
        public let slot: AvatarRecipe.Slot
        public let rarity: String
        public let assetSetID: AssetSetID
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name", slot, rarity, assetSetID = "asset_set_id" }
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
        enum CodingKeys: String, CodingKey { case id, displayName = "display_name", palette, assetSetID = "asset_set_id", isDefault = "default" }
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

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", contentVersion = "content_version"
        case families, activityTypes = "activity_types", attributes, evolutions, items, rewards, backdrops
        case avatarOptions = "avatar_options"
    }

    public static func decode(_ data: Data) throws -> ContentBundle {
        try JSONDecoder().decode(ContentBundle.self, from: data)
    }

    // MARK: lookups

    public func activityType(_ id: ActivityTypeID) -> ActivityType? { activityTypes.first { $0.id == id } }
    public func family(_ id: FamilyID) -> Family? { families.first { $0.id == id } }
    public func evolution(_ id: EvolutionID) -> Evolution? { evolutions.first { $0.id == id } }
    public func item(_ id: ItemID) -> Item? { items.first { $0.id == id } }
    public var defaultBackdrop: Backdrop? { backdrops.first { $0.isDefault == true } ?? backdrops.first }

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
        for a in activityTypes where !familyIDs.contains(a.familyID) { problems.append("activity \(a.id) → unknown family \(a.familyID)") }
        for r in rewards {
            for g in r.grants {
                if let i = g.itemID, !itemIDs.contains(i) { problems.append("reward \(r.id) → unknown item \(i)") }
                if let e = g.evolutionID, !evolutionIDs.contains(e) { problems.append("reward \(r.id) → unknown evolution \(e)") }
                if let b = g.backdropID, !backdropIDs.contains(b) { problems.append("reward \(r.id) → unknown backdrop \(b)") }
            }
        }
        if !evolutions.contains(where: { $0.minLevel == 1 }) { problems.append("no evolution with min_level 1") }
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
        return problems
    }
}

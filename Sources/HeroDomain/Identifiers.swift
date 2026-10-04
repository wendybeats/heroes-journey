import Foundation

/// Stable content identifiers. These are the canonical identity of content objects
/// (AGENTS rule 7). Display names and asset filenames are never identity.
public struct StableID<Tag>: Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
    public var description: String { rawValue }
}

public enum ActivityTypeTag: Sendable {}
public enum FamilyTag: Sendable {}
public enum AttributeTag: Sendable {}
public enum RulesetTag: Sendable {}
public enum ItemTag: Sendable {}
public enum EvolutionTag: Sendable {}
public enum RewardTag: Sendable {}
public enum AssetSetTag: Sendable {}
public enum BackdropTag: Sendable {}
public enum CharacterTag: Sendable {}
public enum AreaTag: Sendable {}

public typealias ActivityTypeID = StableID<ActivityTypeTag>
public typealias FamilyID = StableID<FamilyTag>
public typealias AttributeID = StableID<AttributeTag>
public typealias RulesetID = StableID<RulesetTag>
public typealias ItemID = StableID<ItemTag>
public typealias EvolutionID = StableID<EvolutionTag>
public typealias RewardID = StableID<RewardTag>
public typealias AssetSetID = StableID<AssetSetTag>
public typealias BackdropID = StableID<BackdropTag>
public typealias CharacterID = StableID<CharacterTag>
public typealias AreaID = StableID<AreaTag>

/// Client-generated, globally unique event identity. Generated once at log time and
/// reused on every retry so the server can deduplicate submissions (doc 15 §3, "request retry").
public struct ActivityEventID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
    public var description: String { rawValue.uuidString }
}

public struct UserID: Hashable, Codable, Sendable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

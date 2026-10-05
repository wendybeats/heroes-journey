import Foundation

/// The saved avatar is a recipe of stable IDs, never a rendered image (doc 07).
public struct AvatarRecipe: Hashable, Codable, Sendable {
    public static let schemaVersion = 1

    public enum BaseBody: String, Codable, Sendable, CaseIterable { case male, female }
    public enum Slot: String, Codable, Sendable, CaseIterable { case head, face, body, waist, legs, feet, hand, back, effect }

    public var name: String
    public var baseBody: BaseBody
    public var skinPaletteID: String
    public var hairStyleID: String
    public var hairPaletteID: String
    public var evolutionID: EvolutionID
    public var equipped: [Slot: ItemID]
    public var backdropID: BackdropID
    public let schemaVersion: Int

    public init(name: String, baseBody: BaseBody, skinPaletteID: String, hairStyleID: String, hairPaletteID: String, evolutionID: EvolutionID, equipped: [Slot: ItemID] = [:], backdropID: BackdropID) {
        self.name = name; self.baseBody = baseBody; self.skinPaletteID = skinPaletteID
        self.hairStyleID = hairStyleID; self.hairPaletteID = hairPaletteID
        self.evolutionID = evolutionID; self.equipped = equipped; self.backdropID = backdropID
        self.schemaVersion = Self.schemaVersion
    }
}

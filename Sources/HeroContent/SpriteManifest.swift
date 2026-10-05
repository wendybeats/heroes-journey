import Foundation
import HeroDomain

/// Decoded `assets/sprites/<asset_set_id>/rev<N>/manifest.json` (see assets/sprites/README.md).
/// The renderer consumes only this; it never inspects filenames for meaning.
public struct SpriteManifest: Codable, Sendable, Equatable {
    public struct Point: Codable, Sendable, Equatable { public let x: Int; public let y: Int }
    public struct Size: Codable, Sendable, Equatable { public let width: Int; public let height: Int }
    public struct Animation: Codable, Sendable, Equatable {
        public let frames: [String]
        public let frameDurationMs: Int
        public let loop: Bool
        public let posterFrame: Int?
        enum CodingKeys: String, CodingKey { case frames, frameDurationMs = "frame_duration_ms", loop, posterFrame = "poster_frame" }
    }
    /// Doc 27 lifecycle. `accepted` and `retired` are the pre-2026-10-04 names, kept readable.
    public enum Status: String, Codable, Sendable {
        case concept, draft, review, approved, deprecated, archived
        case accepted, retired
        /// Whether a revision may be loaded by the app at all (doc 27: production uses approved;
        /// drafts stay loadable until the first release so work in progress can be seen on device).
        public var isLoadable: Bool {
            switch self { case .approved, .accepted, .review, .draft: return true; case .concept, .deprecated, .archived, .retired: return false }
        }
        public var isApproved: Bool { self == .approved || self == .accepted }
    }
    public enum Kind: String, Codable, Sendable { case body, hair, item, backdrop, effect, portrait, icon }

    public let schemaVersion: Int
    public let assetSetID: AssetSetID
    public let revision: Int
    public let status: Status
    public let kind: Kind
    public let slot: AvatarRecipe.Slot?
    public let canvas: Size
    public let pivot: Point
    public let attachments: [String: Point]?
    public let layerOrder: Int?
    public let animations: [String: Animation]
    public let paletteRoles: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", assetSetID = "asset_set_id", revision, status, kind, slot, canvas, pivot
        case attachments, layerOrder = "layer_order", animations, paletteRoles = "palette_roles"
    }

    public static func decode(_ data: Data) throws -> SpriteManifest {
        try JSONDecoder().decode(SpriteManifest.self, from: data)
    }

    public var idle: Animation? { animations["idle"] }
}

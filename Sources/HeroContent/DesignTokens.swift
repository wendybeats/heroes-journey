import Foundation

/// Decoded `Content/v1/design-tokens.json`. Platform-neutral: hex strings and numbers.
/// The SwiftUI theme is *generated* from the same file (Tools/generate_theme_swift.py); this
/// type exists so tests can prove the generated Swift and the JSON agree.
public struct DesignTokens: Codable, Sendable, Equatable {
    public struct Color: Codable, Sendable, Equatable {
        public let hex: String
        public let dim: String?
        public let role: String?
    }
    public struct BackdropPalette: Codable, Sendable, Equatable {
        public let shades: [String]
        public let source: String?
    }
    public let schemaVersion: Int
    public let contentVersion: String
    public let themeID: String
    public let surface: [String: Color]
    public let text: [String: Color]
    public let accent: [String: Color]
    public let attribute: [String: Color]
    public let backdropPalettes: [String: BackdropPalette]
    public let radius: [String: Double]
    public let spacing: [String: Double]
    public let motion: [String: Double]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version", contentVersion = "content_version", themeID = "theme_id"
        case surface, text, accent, attribute, backdropPalettes = "backdrop_palettes", radius, spacing, motion
    }

    public static func decode(_ data: Data) throws -> DesignTokens {
        try JSONDecoder().decode(DesignTokens.self, from: data)
    }

    /// sRGB components 0…1 for a `#RRGGBB` string, or nil if malformed.
    public static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        var s = Substring(hex)
        if s.hasPrefix("#") { s = s.dropFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }
}

import Foundation

/// Versioned, data-driven progression rules (doc 05). Decoded from `Content/v1/ruleset.*.json`.
/// The engine reads only this struct; it never has family- or activity-specific branches.
public struct ProgressionRuleset: Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable { case dev, active, archived }

    public struct DailyTaper: Codable, Sendable, Equatable {
        public let fullCreditMinutes: Double
        public let taperRate: Double
        public let hardCapMinutes: Double
        public init(fullCreditMinutes: Double, taperRate: Double, hardCapMinutes: Double) {
            self.fullCreditMinutes = fullCreditMinutes; self.taperRate = taperRate; self.hardCapMinutes = hardCapMinutes
        }
        enum CodingKeys: String, CodingKey {
            case fullCreditMinutes = "full_credit_minutes", taperRate = "taper_rate", hardCapMinutes = "hard_cap_minutes"
        }
    }

    public let id: RulesetID
    public let version: Int
    public let status: Status
    public let xpPerMinuteByFamily: [String: Double]
    public let attributeWeightsByFamily: [String: [String: Double]]
    public let attributePointsPerXP: Double
    public let verificationMultiplier: [String: Double]
    public let dailyTaper: DailyTaper
    public let minimumDurationSeconds: Int
    /// Total XP required to *reach* each level; index 0 is Level 1 (always 0).
    public let levelThresholdsTotalXP: [Int]

    enum CodingKeys: String, CodingKey {
        case id, version, status
        case xpPerMinuteByFamily = "xp_per_minute_by_family"
        case attributeWeightsByFamily = "attribute_weights_by_family"
        case attributePointsPerXP = "attribute_points_per_xp"
        case verificationMultiplier = "verification_multiplier"
        case dailyTaper = "daily_taper"
        case minimumDurationSeconds = "minimum_duration_seconds"
        case levelThresholdsTotalXP = "level_thresholds_total_xp"
    }

    public init(id: RulesetID, version: Int, status: Status, xpPerMinuteByFamily: [String: Double], attributeWeightsByFamily: [String: [String: Double]], attributePointsPerXP: Double, verificationMultiplier: [String: Double], dailyTaper: DailyTaper, minimumDurationSeconds: Int, levelThresholdsTotalXP: [Int]) {
        self.id = id; self.version = version; self.status = status
        self.xpPerMinuteByFamily = xpPerMinuteByFamily; self.attributeWeightsByFamily = attributeWeightsByFamily
        self.attributePointsPerXP = attributePointsPerXP; self.verificationMultiplier = verificationMultiplier
        self.dailyTaper = dailyTaper; self.minimumDurationSeconds = minimumDurationSeconds
        self.levelThresholdsTotalXP = levelThresholdsTotalXP
    }

    /// Level for a total XP amount. Levels are content, not a technical maximum (doc 05):
    /// XP beyond the last threshold stays at the last defined level until content adds more.
    public func level(forTotalXP xp: Int) -> Int {
        var level = 1
        for (index, threshold) in levelThresholdsTotalXP.enumerated() where xp >= threshold {
            level = index + 1
        }
        return level
    }

    /// XP still needed to reach the next level, or nil at the last defined level.
    public func xpToNextLevel(fromTotalXP xp: Int) -> Int? {
        let next = level(forTotalXP: xp)  // index of next threshold == current level
        guard next < levelThresholdsTotalXP.count else { return nil }
        return levelThresholdsTotalXP[next] - xp
    }

    /// Decode from JSON, e.g. the bytes of `Content/v1/ruleset.dev-1.json`.
    public static func decode(_ data: Data) throws -> ProgressionRuleset {
        try JSONDecoder().decode(ProgressionRuleset.self, from: data)
    }
}

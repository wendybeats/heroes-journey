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

    public struct StructuredWorkout: Codable, Sendable, Equatable {
        public let defaultMinutes: Double
        public let liveThresholdMinutes: Double
        public let minutesPerValidSet: Double
        public let maxCreditedMinutes: Double
        public init(defaultMinutes: Double, liveThresholdMinutes: Double, minutesPerValidSet: Double, maxCreditedMinutes: Double) {
            self.defaultMinutes = defaultMinutes; self.liveThresholdMinutes = liveThresholdMinutes
            self.minutesPerValidSet = minutesPerValidSet; self.maxCreditedMinutes = maxCreditedMinutes
        }
        enum CodingKeys: String, CodingKey {
            case defaultMinutes = "default_minutes", liveThresholdMinutes = "live_threshold_minutes"
            case minutesPerValidSet = "minutes_per_valid_set", maxCreditedMinutes = "max_credited_minutes"
        }
    }

    /// Doc 24. One quest per day, unlocked by the goal count, resolved after `durationMinutes`.
    public struct DailyQuest: Codable, Sendable, Equatable {
        public struct RewardEntry: Codable, Sendable, Equatable {
            public let weight: Double
            public let xp: Int
            /// `common` / `uncommon` / `rare`; the bundle's quest copy is keyed by it.
            public let tier: String
            /// Optional content reward (bundle `rewards`) granted once.
            public let rewardID: RewardID?
            public init(weight: Double, xp: Int, tier: String, rewardID: RewardID? = nil) { self.weight = weight; self.xp = xp; self.tier = tier; self.rewardID = rewardID }
            enum CodingKeys: String, CodingKey { case weight, xp, tier, rewardID = "reward_id" }
        }
        public let durationMinutes: Int
        /// `all_goals` is the only rule in MVP; kept as data so partial credit is a value change.
        public let unlockRule: String
        public let rewardTable: [RewardEntry]
        public init(durationMinutes: Int, unlockRule: String, rewardTable: [RewardEntry]) { self.durationMinutes = durationMinutes; self.unlockRule = unlockRule; self.rewardTable = rewardTable }
        enum CodingKeys: String, CodingKey { case durationMinutes = "duration_minutes", unlockRule = "unlock_rule", rewardTable = "reward_table" }
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
    /// Credit rule for structured strength sessions (nil = duration only).
    public let structuredWorkout: StructuredWorkout?
    /// Flat XP for any event that earns at least one credited minute (doc 00 §3: participation
    /// creates progress). Not tapered. Nil/0 = off.
    public let sessionBaseXP: Int?
    /// On the first Health sync, imported workouts older than this are history only (doc 15
    /// "history import"). Nil = import everything with full credit.
    public let healthHistoryWindowDays: Int?
    /// Flat XP per completed goal, by slot (`primary`, `secondary`, `small_win`). Nil = goals earn nothing.
    public let goalXP: [String: Int]?
    public let dailyQuest: DailyQuest?
    /// Cross-family cap on activity XP per local day (dev-5). Goals and quests are outside it. Nil = no cap.
    public let dailyActivityXPCap: Int?

    enum CodingKeys: String, CodingKey {
        case id, version, status
        case xpPerMinuteByFamily = "xp_per_minute_by_family"
        case attributeWeightsByFamily = "attribute_weights_by_family"
        case attributePointsPerXP = "attribute_points_per_xp"
        case verificationMultiplier = "verification_multiplier"
        case dailyTaper = "daily_taper"
        case minimumDurationSeconds = "minimum_duration_seconds"
        case levelThresholdsTotalXP = "level_thresholds_total_xp"
        case structuredWorkout = "structured_workout"
        case sessionBaseXP = "session_base_xp", healthHistoryWindowDays = "health_history_window_days", goalXP = "goal_xp", dailyQuest = "daily_quest", dailyActivityXPCap = "daily_activity_xp_cap"
    }

    public init(id: RulesetID, version: Int, status: Status, xpPerMinuteByFamily: [String: Double], attributeWeightsByFamily: [String: [String: Double]], attributePointsPerXP: Double, verificationMultiplier: [String: Double], dailyTaper: DailyTaper, minimumDurationSeconds: Int, levelThresholdsTotalXP: [Int], structuredWorkout: StructuredWorkout? = nil, sessionBaseXP: Int? = nil, healthHistoryWindowDays: Int? = nil, goalXP: [String: Int]? = nil, dailyQuest: DailyQuest? = nil, dailyActivityXPCap: Int? = nil) {
        self.id = id; self.version = version; self.status = status
        self.xpPerMinuteByFamily = xpPerMinuteByFamily; self.attributeWeightsByFamily = attributeWeightsByFamily
        self.attributePointsPerXP = attributePointsPerXP; self.verificationMultiplier = verificationMultiplier
        self.dailyTaper = dailyTaper; self.minimumDurationSeconds = minimumDurationSeconds
        self.levelThresholdsTotalXP = levelThresholdsTotalXP; self.structuredWorkout = structuredWorkout
        self.sessionBaseXP = sessionBaseXP; self.healthHistoryWindowDays = healthHistoryWindowDays; self.goalXP = goalXP; self.dailyQuest = dailyQuest; self.dailyActivityXPCap = dailyActivityXPCap
    }

    /// Minutes an event is credited for before the daily taper. Any session that records sets
    /// (the strength logger, or a manual log with a set count) gets a floor of `minutesPerValidSet`
    /// per set and a cap; everything else is its duration.
    public func creditedMinutes(for event: ActivityEvent) -> Double {
        guard let sw = structuredWorkout, let sets = event.structuredSetCount, sets > 0 else { return event.durationMinutes }
        return min(max(event.durationMinutes, Double(sets) * sw.minutesPerValidSet), sw.maxCreditedMinutes)
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

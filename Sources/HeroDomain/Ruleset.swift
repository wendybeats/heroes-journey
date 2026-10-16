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
        /// Pity (doc 29): after this many resolved runs without a `rare` roll, the next roll is rare. nil = off.
        public let pityRareAfter: Int?
        /// Trade-in (doc 29): bonus XP by tier when the return grants nothing new (the pool is owned). Absent tier = 0.
        public let tradeInXP: [String: Int]?
        /// Doc 33 found pages, owner QA 2026-10-16: a page is found beside the gear, never instead of it. The chance, per
        /// return, that a quest with a page pool also hands over its next unowned page. nil or 0 = pages only through the table.
        public let pageChance: Double?
        public init(durationMinutes: Int, unlockRule: String, rewardTable: [RewardEntry], pityRareAfter: Int? = nil, tradeInXP: [String: Int]? = nil, pageChance: Double? = nil) {
            self.durationMinutes = durationMinutes; self.unlockRule = unlockRule; self.rewardTable = rewardTable; self.pityRareAfter = pityRareAfter; self.tradeInXP = tradeInXP; self.pageChance = pageChance
        }
        enum CodingKeys: String, CodingKey { case durationMinutes = "duration_minutes", unlockRule = "unlock_rule", rewardTable = "reward_table", pityRareAfter = "pity_rare_after", tradeInXP = "trade_in_xp", pageChance = "page_chance" }
    }

    /// Onboarding's starting grant (owner, 2026-10-02). Small next to the first goals.
    public struct BondGrant: Codable, Sendable, Equatable {
        public let xp: Int
        public let primaryPoints: Int
        public let secondaryPoints: Int
        public init(xp: Int, primaryPoints: Int, secondaryPoints: Int) { self.xp = xp; self.primaryPoints = primaryPoints; self.secondaryPoints = secondaryPoints }
        enum CodingKeys: String, CodingKey { case xp, primaryPoints = "primary_points", secondaryPoints = "secondary_points" }
    }

    /// Doc 33: challenges. Difficulty words map to a multiple of the level's balanced stat share; grants are
    /// XP plus at most one attribute point (owner: challenges test the build, they do not build it); the
    /// training bonus lets today's activity in the tested family move the odds; cadence is 2–4 a week.
    public struct Challenges: Codable, Sendable, Equatable {
        public struct Grant: Codable, Sendable, Equatable {
            public let xp: Int
            public let points: Int
            public let loseXP: Int
            public init(xp: Int, points: Int, loseXP: Int) { self.xp = xp; self.points = points; self.loseXP = loseXP }
            enum CodingKeys: String, CodingKey { case xp, points, loseXP = "lose_xp" }
        }
        public struct Cadence: Codable, Sendable, Equatable {
            public let fromLevel: Int
            public let chancePerDay: Double
            public let minGapDays: Int
            public let maxGapDays: Int
            public init(fromLevel: Int, chancePerDay: Double, minGapDays: Int, maxGapDays: Int) { self.fromLevel = fromLevel; self.chancePerDay = chancePerDay; self.minGapDays = minGapDays; self.maxGapDays = maxGapDays }
            enum CodingKeys: String, CodingKey { case fromLevel = "from_level", chancePerDay = "chance_per_day", minGapDays = "min_gap_days", maxGapDays = "max_gap_days" }
        }
        public struct TrainingBonus: Codable, Sendable, Equatable {
            public let targetSharePerMinute: Double
            public let maxTargetShare: Double
            public init(targetSharePerMinute: Double, maxTargetShare: Double) { self.targetSharePerMinute = targetSharePerMinute; self.maxTargetShare = maxTargetShare }
            enum CodingKeys: String, CodingKey { case targetSharePerMinute = "target_share_per_minute", maxTargetShare = "max_target_share" }
        }
        /// difficulty word → multiple of the balanced share (easy 0.6, standard 0.8, hard 1.1).
        public let difficulty: [String: Double]
        /// difficulty word → grant.
        public let grant: [String: Grant]
        public let cadence: Cadence
        public let trainingBonus: TrainingBonus
        /// p ≥ likely → "Likely"; p ≥ even → "Even"; else "Long shot".
        public let bandLikely: Double
        public let bandEven: Double
        public init(difficulty: [String: Double], grant: [String: Grant], cadence: Cadence, trainingBonus: TrainingBonus, bandLikely: Double = 0.75, bandEven: Double = 0.45) {
            self.difficulty = difficulty; self.grant = grant; self.cadence = cadence; self.trainingBonus = trainingBonus; self.bandLikely = bandLikely; self.bandEven = bandEven
        }
        enum CodingKeys: String, CodingKey { case difficulty, grant, cadence, trainingBonus = "training_bonus", bandLikely = "band_likely", bandEven = "band_even" }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            difficulty = try c.decode([String: Double].self, forKey: .difficulty); grant = try c.decode([String: Grant].self, forKey: .grant)
            cadence = try c.decode(Cadence.self, forKey: .cadence); trainingBonus = try c.decode(TrainingBonus.self, forKey: .trainingBonus)
            bandLikely = try c.decodeIfPresent(Double.self, forKey: .bandLikely) ?? 0.75; bandEven = try c.decodeIfPresent(Double.self, forKey: .bandEven) ?? 0.45
        }
    }

    /// Doc 36/37 boss combat tuning. Shares in, effects out; every number here is a balance knob.
    public struct BossCombat: Codable, Sendable, Equatable {
        public let masteryExponent: Double
        public let playerStaminaBase: Double
        public let staminaEnduranceBonus: Double
        public let staminaEnduranceExponent: Double
        public let attackBase: Double
        public let guardBaseReduction: Double
        public let guardMaxReduction: Double
        public let deflectBonusReduction: Double
        public let deflectBreakDamage: Double
        public let analyzeBaseBreak: Double
        public let centerBaseRecoveryShare: Double
        public let centerStacks: Int
        public let centerStrongShare: Double
        public let centerStrongStacks: Int
        public let pressurePerStack: Double
        public let pressureCap: Int
        public let brokenMultiplier: Double
        public let maxTurns: Int
        public let variance: Double
        public init(masteryExponent: Double = 0.6, playerStaminaBase: Double = 100, staminaEnduranceBonus: Double = 0.11, staminaEnduranceExponent: Double = 0.75, attackBase: Double = 9, guardBaseReduction: Double = 0.35, guardMaxReduction: Double = 0.75, deflectBonusReduction: Double = 0.15, deflectBreakDamage: Double = 1, analyzeBaseBreak: Double = 0.85, centerBaseRecoveryShare: Double = 0.04, centerStacks: Int = 1, centerStrongShare: Double = 1.5, centerStrongStacks: Int = 2, pressurePerStack: Double = 0.15, pressureCap: Int = 3, brokenMultiplier: Double = 3, maxTurns: Int = 40, variance: Double = 0) {
            self.masteryExponent = masteryExponent; self.playerStaminaBase = playerStaminaBase; self.staminaEnduranceBonus = staminaEnduranceBonus; self.staminaEnduranceExponent = staminaEnduranceExponent
            self.attackBase = attackBase; self.guardBaseReduction = guardBaseReduction; self.guardMaxReduction = guardMaxReduction; self.deflectBonusReduction = deflectBonusReduction; self.deflectBreakDamage = deflectBreakDamage
            self.analyzeBaseBreak = analyzeBaseBreak; self.centerBaseRecoveryShare = centerBaseRecoveryShare; self.centerStacks = centerStacks; self.centerStrongShare = centerStrongShare; self.centerStrongStacks = centerStrongStacks
            self.pressurePerStack = pressurePerStack; self.pressureCap = pressureCap; self.brokenMultiplier = brokenMultiplier; self.maxTurns = maxTurns; self.variance = variance
        }
        enum CodingKeys: String, CodingKey {
            case masteryExponent = "mastery_exponent", playerStaminaBase = "player_stamina_base", staminaEnduranceBonus = "stamina_endurance_bonus", staminaEnduranceExponent = "stamina_endurance_exponent"
            case attackBase = "attack_base", guardBaseReduction = "guard_base_reduction", guardMaxReduction = "guard_max_reduction", deflectBonusReduction = "deflect_bonus_reduction", deflectBreakDamage = "deflect_break_damage"
            case analyzeBaseBreak = "analyze_base_break", centerBaseRecoveryShare = "center_base_recovery_share", centerStacks = "center_stacks", centerStrongShare = "center_strong_share", centerStrongStacks = "center_strong_stacks"
            case pressurePerStack = "pressure_per_stack", pressureCap = "pressure_cap", brokenMultiplier = "broken_multiplier", maxTurns = "max_turns", variance
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            masteryExponent = try c.decode(Double.self, forKey: .masteryExponent); playerStaminaBase = try c.decode(Double.self, forKey: .playerStaminaBase)
            staminaEnduranceBonus = try c.decode(Double.self, forKey: .staminaEnduranceBonus); staminaEnduranceExponent = try c.decode(Double.self, forKey: .staminaEnduranceExponent)
            attackBase = try c.decode(Double.self, forKey: .attackBase); guardBaseReduction = try c.decode(Double.self, forKey: .guardBaseReduction); guardMaxReduction = try c.decode(Double.self, forKey: .guardMaxReduction)
            deflectBonusReduction = try c.decode(Double.self, forKey: .deflectBonusReduction); deflectBreakDamage = try c.decode(Double.self, forKey: .deflectBreakDamage)
            analyzeBaseBreak = try c.decode(Double.self, forKey: .analyzeBaseBreak); centerBaseRecoveryShare = try c.decode(Double.self, forKey: .centerBaseRecoveryShare)
            centerStacks = try c.decode(Int.self, forKey: .centerStacks); centerStrongShare = try c.decode(Double.self, forKey: .centerStrongShare); centerStrongStacks = try c.decode(Int.self, forKey: .centerStrongStacks)
            pressurePerStack = try c.decode(Double.self, forKey: .pressurePerStack); pressureCap = try c.decode(Int.self, forKey: .pressureCap); brokenMultiplier = try c.decode(Double.self, forKey: .brokenMultiplier)
            maxTurns = try c.decodeIfPresent(Int.self, forKey: .maxTurns) ?? 40; variance = try c.decodeIfPresent(Double.self, forKey: .variance) ?? 0
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
    public let bondGrant: BondGrant?
    /// Doc 33 challenges; absent = no challenges are offered.
    public let challenges: Challenges?
    /// Doc 33: the chance a goal's story-aware line replaces its normal line once its flag is set (about 0.1).
    public let goalStoryLineChance: Double?
    /// Doc 36/37 boss combat; absent = no boss can be fought.
    public let bossCombat: BossCombat?

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
        case sessionBaseXP = "session_base_xp", healthHistoryWindowDays = "health_history_window_days", goalXP = "goal_xp", dailyQuest = "daily_quest", dailyActivityXPCap = "daily_activity_xp_cap", bondGrant = "bond_grant", challenges, goalStoryLineChance = "goal_story_line_chance", bossCombat = "boss_combat"
    }

    public init(id: RulesetID, version: Int, status: Status, xpPerMinuteByFamily: [String: Double], attributeWeightsByFamily: [String: [String: Double]], attributePointsPerXP: Double, verificationMultiplier: [String: Double], dailyTaper: DailyTaper, minimumDurationSeconds: Int, levelThresholdsTotalXP: [Int], structuredWorkout: StructuredWorkout? = nil, sessionBaseXP: Int? = nil, healthHistoryWindowDays: Int? = nil, goalXP: [String: Int]? = nil, dailyQuest: DailyQuest? = nil, dailyActivityXPCap: Int? = nil, bondGrant: BondGrant? = nil, challenges: Challenges? = nil, goalStoryLineChance: Double? = nil, bossCombat: BossCombat? = nil) {
        self.id = id; self.version = version; self.status = status
        self.xpPerMinuteByFamily = xpPerMinuteByFamily; self.attributeWeightsByFamily = attributeWeightsByFamily
        self.attributePointsPerXP = attributePointsPerXP; self.verificationMultiplier = verificationMultiplier
        self.dailyTaper = dailyTaper; self.minimumDurationSeconds = minimumDurationSeconds
        self.levelThresholdsTotalXP = levelThresholdsTotalXP; self.structuredWorkout = structuredWorkout
        self.sessionBaseXP = sessionBaseXP; self.healthHistoryWindowDays = healthHistoryWindowDays; self.goalXP = goalXP; self.dailyQuest = dailyQuest; self.dailyActivityXPCap = dailyActivityXPCap; self.bondGrant = bondGrant; self.challenges = challenges; self.goalStoryLineChance = goalStoryLineChance; self.bossCombat = bossCombat
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

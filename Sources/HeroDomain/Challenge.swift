import Foundation

// Doc 33 challenges. An unnamed person tests one attribute. The odds come from the player's stat against a
// target that scales with level; today's training in the tested family moves them. The roll, the stat and the
// bonus are written on the fact so the ledger explains every grant. Everything here is pure.

public enum ChallengeTag: Sendable {}
public typealias ChallengeID = StableID<ChallengeTag>

/// Carried on the `ActivityEvent` an accepted challenge creates. `won` is decided by the app from the seeded
/// roll and recorded here, like a quest's rolled reward index; the engine only prices it.
public struct ChallengeReference: Hashable, Codable, Sendable {
    public let challengeID: ChallengeID
    public let characterID: String
    public let attributeID: AttributeID
    /// Difficulty word as content declares it (`easy`, `standard`, `hard`); the ruleset maps it.
    public let difficulty: String
    /// The attribute value at acceptance, before the training bonus.
    public let stat: Int
    /// Points added by today's training in the tested family (doc 33 "train for it").
    public let trainingBonus: Double
    /// The target the roll was against, and the win probability that applied.
    public let target: Double
    public let probability: Double
    /// The seeded uniform roll in [0, 1); won when roll < probability.
    public let roll: Double
    public let won: Bool
    /// Which set of lines played (meeting count, cycling).
    public let setIndex: Int

    public init(challengeID: ChallengeID, characterID: String, attributeID: AttributeID, difficulty: String, stat: Int, trainingBonus: Double, target: Double, probability: Double, roll: Double, won: Bool, setIndex: Int) {
        self.challengeID = challengeID; self.characterID = characterID; self.attributeID = attributeID; self.difficulty = difficulty
        self.stat = stat; self.trainingBonus = trainingBonus; self.target = target; self.probability = probability; self.roll = roll; self.won = won; self.setIndex = setIndex
    }
    enum CodingKeys: String, CodingKey {
        case challengeID = "challenge_id", characterID = "character_id", attributeID = "attribute_id", difficulty, stat, trainingBonus = "training_bonus"
        case target, probability, roll, won, setIndex = "set_index"
    }

    public static func makeEvent(_ reference: ChallengeReference, userID: UserID, familyFallback: FamilyID, at now: Date, id: ActivityEventID = ActivityEventID()) -> ActivityEvent {
        ActivityEvent(id: id, userID: userID, activityTypeID: ActivityTypeID(reference.challengeID.rawValue), familyID: familyFallback, startedAt: now, durationSeconds: 0,
                      source: .challenge, verification: .selfReported, challenge: reference, createdAt: now)
    }
}

public enum ChallengeBand: String, Sendable, Equatable {
    case likely = "Likely", even = "Even", longShot = "Long shot"
}

public enum ChallengeMath {
    /// A balanced player's expected stat at `level`: the level's threshold priced in points, split across the attributes.
    public static func share(level: Int, ruleset: ProgressionRuleset, attributeCount: Int) -> Double {
        let t = ruleset.levelThresholdsTotalXP
        guard attributeCount > 0, !t.isEmpty else { return 1 }
        // Expected total XP partway through the level: the midpoint of this threshold and the next.
        let i = max(0, min(level - 1, t.count - 1))
        let xp = i + 1 < t.count ? Double(t[i] + t[i + 1]) / 2 : Double(t[i])
        return max(1, xp * ruleset.attributePointsPerXP / Double(attributeCount))
    }

    public static func target(difficulty: String, share: Double, ruleset: ProgressionRuleset) -> Double {
        max(1, share * (ruleset.challenges?.difficulty[difficulty] ?? 0.8))
    }

    /// Today's credited minutes per family, weighted by how much each family feeds the attribute, as a share of the target.
    public static func trainingBonus(minutesByFamily: [String: Double], attributeID: AttributeID, target: Double, ruleset: ProgressionRuleset) -> Double {
        guard let rules = ruleset.challenges?.trainingBonus else { return 0 }
        var weighted = 0.0
        for (family, minutes) in minutesByFamily {
            let w = ruleset.attributeWeightsByFamily[family]?[attributeID.rawValue] ?? 0
            weighted += max(0, minutes) * w
        }
        return min(rules.maxTargetShare, weighted * rules.targetSharePerMinute) * target
    }

    /// Logistic around the target; the spread is a third of it so a specialist is near-certain on their stat and a long shot off it.
    public static func winProbability(stat: Double, target: Double) -> Double {
        let spread = max(1, target / 3)
        return 1 / (1 + exp(-(stat - target) / spread))
    }

    public static func band(probability p: Double, ruleset: ProgressionRuleset) -> ChallengeBand {
        let likely = ruleset.challenges?.bandLikely ?? 0.75, even = ruleset.challenges?.bandEven ?? 0.45
        if p >= likely { return .likely }
        if p >= even { return .even }
        return .longShot
    }

    /// Deterministic uniform in [0, 1) from a string seed (challenge id + day + user), so a replay rolls the same.
    public static func roll(seed: String) -> Double {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in seed.utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01b3 }
        // splitmix finaliser
        h ^= h >> 30; h = h &* 0xbf58_476d_1ce4_e5b9; h ^= h >> 27; h = h &* 0x94d0_49bb_1331_11eb; h ^= h >> 31
        return Double(h >> 11) / Double(1 << 53)
    }

    /// Cadence (doc 33): one roll a day, never two days running, guaranteed by `maxGapDays` quiet days.
    /// `daysSinceLastOffer` is nil when there has never been one.
    public static func offersToday(level: Int, daysSinceLastOffer: Int?, seed: String, ruleset: ProgressionRuleset) -> Bool {
        guard let c = ruleset.challenges?.cadence, level >= c.fromLevel else { return false }
        // Never offered yet: the first eligible day offers, so a new player meets the system at once.
        guard let gap = daysSinceLastOffer else { return true }
        if gap <= c.minGapDays { return false }
        if gap > c.maxGapDays { return true }
        return roll(seed: seed) < c.chancePerDay
    }

    /// Wins and losses for one challenge, derived from the facts (proof of victory, doc 33).
    public static func record(challengeID: ChallengeID, events: [ActivityEvent]) -> (won: Int, lost: Int) {
        var won = 0, lost = 0
        for e in events { if let c = e.challenge, c.challengeID == challengeID { if c.won { won += 1 } else { lost += 1 } } }
        return (won, lost)
    }
}

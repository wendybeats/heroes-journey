import Foundation

// Doc 36 (owner master spec) and doc 37 (decisions). Boss combat is a pure, deterministic state machine:
// `BossEncounter.step(_:)` resolves one full turn and returns the events the presentation plays. Nothing here
// touches the ledger; a victory is a milestone completion and its grant goes through the engine as a story fact.
// `Tools/simulate_boss.py` is the reference implementation of the same arithmetic; the golden fixture it writes is
// replayed by `BossCombatTests`, so the two cannot drift.

public enum BossTag: Sendable {}
public typealias BossID = StableID<BossTag>

/// A boss is data (doc 36 §26). `pattern` names actions that cycle; each action says what it does.
public struct BossDefinition: Codable, Sendable, Equatable {
    public struct Action: Codable, Sendable, Equatable {
        /// Multiple of the boss's `attack`; 0 = this action does not hit.
        public let damage: Double
        /// Multiplies the boss's next hit (LOAD).
        public let loads: Double?
        /// Guard against this action deflects it: extra reduction, Break damage, a line.
        public let deflectable: Bool
        /// Stacks of the signature status added (MORE).
        public let pressure: Int?
        /// Permanent damage escalation added each time (MORE).
        public let escalate: Double?
        public let telegraph: String
        public let intent: String?
        public init(damage: Double, loads: Double? = nil, deflectable: Bool = false, pressure: Int? = nil, escalate: Double? = nil, telegraph: String, intent: String? = nil) {
            self.damage = damage; self.loads = loads; self.deflectable = deflectable; self.pressure = pressure; self.escalate = escalate; self.telegraph = telegraph; self.intent = intent
        }
        enum CodingKeys: String, CodingKey { case damage, loads, deflectable, pressure, escalate, telegraph, intent }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            damage = try c.decodeIfPresent(Double.self, forKey: .damage) ?? 0
            loads = try c.decodeIfPresent(Double.self, forKey: .loads)
            deflectable = try c.decodeIfPresent(Bool.self, forKey: .deflectable) ?? false
            pressure = try c.decodeIfPresent(Int.self, forKey: .pressure)
            escalate = try c.decodeIfPresent(Double.self, forKey: .escalate)
            telegraph = try c.decode(String.self, forKey: .telegraph)
            intent = try c.decodeIfPresent(String.self, forKey: .intent)
        }
    }
    public let id: BossID
    public let displayName: String
    public let characterID: CharacterID
    public let areaID: AreaID?
    /// The manual milestone this fight stands behind; winning completes it.
    public let milestoneID: MilestoneID?
    public let stamina: Double
    public let breakMax: Double
    public let attack: Double
    public let pattern: [String]
    public let actions: [String: Action]
    /// Event key → line: `first_deflect`, `escalate`, `first_break` (doc 36 §23).
    public let dialogue: [String: String]
    /// Surface key → one-line teaching copy: `attack`, `guard`, `break`, `pressure`, `analyze` (doc 36 §34).
    public let tutorial: [String: String]
    /// Cairon after a loss, by attempt (doc 37: the hint tightens; the last line repeats).
    public let lossLines: [String]
    /// Semantic state → asset set id: `idle`, `attack`, `buff`, `broken`, `defeat` (doc 36 §30).
    public let assets: [String: String]
    public let notes: String?

    public init(id: BossID, displayName: String, characterID: CharacterID, areaID: AreaID? = nil, milestoneID: MilestoneID? = nil, stamina: Double, breakMax: Double, attack: Double, pattern: [String], actions: [String: Action], dialogue: [String: String] = [:], tutorial: [String: String] = [:], lossLines: [String] = [], assets: [String: String] = [:], notes: String? = nil) {
        self.id = id; self.displayName = displayName; self.characterID = characterID; self.areaID = areaID; self.milestoneID = milestoneID
        self.stamina = stamina; self.breakMax = breakMax; self.attack = attack; self.pattern = pattern; self.actions = actions
        self.dialogue = dialogue; self.tutorial = tutorial; self.lossLines = lossLines; self.assets = assets; self.notes = notes
    }
    enum CodingKeys: String, CodingKey {
        case id, displayName = "display_name", characterID = "character_id", areaID = "area_id", milestoneID = "milestone_id", stamina, breakMax = "break", attack, pattern, actions, dialogue, tutorial, lossLines = "loss_lines", assets, notes
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(BossID.self, forKey: .id); displayName = try c.decode(String.self, forKey: .displayName)
        characterID = try c.decode(CharacterID.self, forKey: .characterID)
        areaID = try c.decodeIfPresent(AreaID.self, forKey: .areaID); milestoneID = try c.decodeIfPresent(MilestoneID.self, forKey: .milestoneID)
        stamina = try c.decode(Double.self, forKey: .stamina); breakMax = try c.decode(Double.self, forKey: .breakMax); attack = try c.decode(Double.self, forKey: .attack)
        pattern = try c.decode([String].self, forKey: .pattern); actions = try c.decode([String: Action].self, forKey: .actions)
        dialogue = try c.decodeIfPresent([String: String].self, forKey: .dialogue) ?? [:]
        tutorial = try c.decodeIfPresent([String: String].self, forKey: .tutorial) ?? [:]
        lossLines = try c.decodeIfPresent([String].self, forKey: .lossLines) ?? []
        assets = try c.decodeIfPresent([String: String].self, forKey: .assets) ?? [:]
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }
    /// The hint after the n-th loss (1-based); the last line repeats.
    public func lossLine(attempt: Int) -> String? {
        guard !lossLines.isEmpty else { return nil }
        return lossLines[max(0, min(attempt - 1, lossLines.count - 1))]
    }
}

/// The four verbs, one per attribute (doc 36 §2).
public enum CombatAction: String, Codable, Sendable, CaseIterable {
    case attack, `guard`, analyze, center
    public var attributeID: AttributeID {
        switch self { case .attack: return "strength"; case .`guard`: return "endurance"; case .analyze: return "knowledge"; case .center: return "mindfulness" }
    }
}

/// What a turn produced, in order. The presentation plays these; the numbers are already final (doc 36 §28).
public enum CombatEvent: Equatable, Sendable {
    case damage(Double, critical: Bool)
    case guarded(reduction: Double)
    case analyzed(breakDamage: Double)
    case breakDamage(Double, left: Double)
    /// `cancelled` names the telegraphed action an Analyze-Break skipped; nil when a Deflect broke him after his hit landed.
    case broken(cancelled: String?)
    case centered(cleared: Int, recovered: Double)
    case bossRecovered
    case bossAttack(name: String, incoming: Double, taken: Double, deflected: Bool)
    case bossLoad(multiplier: Double)
    case pressure(stacks: Int)
    case dialogue(key: String)
    case result(CombatResult)
}

public enum CombatResult: String, Codable, Sendable { case won, lost, stalled }

/// The player's four stats as shares of the balanced expected stat at their level (doc 37 §1). 0 = nothing
/// developed, 1 = balanced, ~3 = heavily specialised. Same-day training adds to the share the way it adds to
/// challenge odds (doc 37 §4).
public struct CombatShares: Hashable, Codable, Sendable {
    public var strength: Double, endurance: Double, knowledge: Double, mindfulness: Double
    public init(strength: Double, endurance: Double, knowledge: Double, mindfulness: Double) {
        self.strength = max(0, strength); self.endurance = max(0, endurance); self.knowledge = max(0, knowledge); self.mindfulness = max(0, mindfulness)
    }
    public func share(for action: CombatAction) -> Double {
        switch action { case .attack: return strength; case .`guard`: return endurance; case .analyze: return knowledge; case .center: return mindfulness }
    }
}

/// Doc 36 §26: the whole encounter as a value. Deterministic: the same actions from the same start replay the
/// same fight. Variance (off by default) is the only use of the seed.
public struct BossEncounter: Sendable {
    public let boss: BossDefinition
    public let rules: ProgressionRuleset.BossCombat
    public let shares: CombatShares
    public private(set) var playerStamina: Double
    public let playerStaminaMax: Double
    public private(set) var bossStamina: Double
    public var bossStaminaMax: Double { boss.stamina }
    public private(set) var breakNow: Double
    public var breakMax: Double { boss.breakMax }
    public private(set) var pressure = 0
    public private(set) var escalation = 0.0
    public private(set) var loaded = 1.0
    public private(set) var turn = 0
    public private(set) var patternIndex = 0
    public private(set) var isBroken = false
    public private(set) var result: CombatResult?
    public private(set) var flags: Set<String> = []
    public private(set) var breaks = 0, deflects = 0
    private var rng: SeededGenerator

    public init(boss: BossDefinition, rules: ProgressionRuleset.BossCombat, shares: CombatShares, seed: UInt64 = 0) {
        self.boss = boss; self.rules = rules; self.shares = shares
        playerStaminaMax = rules.playerStaminaBase * (1.0 + rules.staminaEnduranceBonus * pow(shares.endurance, rules.staminaEnduranceExponent))
        playerStamina = playerStaminaMax; bossStamina = boss.stamina; breakNow = boss.breakMax
        rng = SeededGenerator(seed: seed)
    }

    /// `(1 + share)^e`: every verb works at share 0; the stat multiplies it (doc 37 §2).
    public static func mastery(share: Double, rules: ProgressionRuleset.BossCombat) -> Double { pow(1.0 + max(0, share), rules.masteryExponent) }
    public func mastery(_ action: CombatAction) -> Double { Self.mastery(share: shares.share(for: action), rules: rules) }

    /// What the boss will do this turn, or nil while Broken (he is recovering).
    public var intent: String? { isBroken ? nil : boss.pattern[patternIndex % boss.pattern.count] }
    public var intentAction: BossDefinition.Action? { intent.flatMap { boss.actions[$0] } }
    /// The current effectiveness multiplier from Pressure (doc 36 §8).
    public var pressureMultiplier: Double { 1.0 - rules.pressurePerStack * Double(pressure) }
    /// How many stacks Center clears at this Mindfulness (doc 37 §7).
    public var centerStacks: Int { shares.mindfulness >= rules.centerStrongShare ? rules.centerStrongStacks : rules.centerStacks }

    /// Resolve one full turn: the player's action, then the boss's telegraphed action unless Broken or interrupted.
    @discardableResult
    public mutating func step(_ action: CombatAction) -> [CombatEvent] {
        guard result == nil else { return [] }
        var ev: [CombatEvent] = []
        turn += 1
        let intentName = intent, spec = intentAction
        let wasBroken = isBroken
        var guarding = 0.0
        switch action {
        case .attack:
            var dmg = rules.attackBase * mastery(.attack) * pressureMultiplier
            if wasBroken { dmg *= rules.brokenMultiplier }
            dmg = vary(dmg); bossStamina -= dmg
            ev.append(.damage(dmg, critical: wasBroken))
        case .`guard`:
            guarding = min(rules.guardMaxReduction, rules.guardBaseReduction * mastery(.`guard`))
            ev.append(.guarded(reduction: guarding))
        case .analyze:
            if wasBroken { ev.append(.analyzed(breakDamage: 0)) }
            else {
                let bd = rules.analyzeBaseBreak * mastery(.analyze) * pressureMultiplier
                ev.append(.analyzed(breakDamage: bd)); breakDamage(bd, cancelsPending: true, &ev)
            }
        case .center:
            let cleared = min(pressure, centerStacks); pressure -= cleared
            var heal = playerStaminaMax * rules.centerBaseRecoveryShare * mastery(.center)
            heal = min(heal, playerStaminaMax - playerStamina); playerStamina += heal
            ev.append(.centered(cleared: cleared, recovered: heal))
        }
        // The Broken window: one player action, then Break resets and the boss recovers without acting (doc 37 §6).
        if wasBroken {
            isBroken = false; breakNow = boss.breakMax
            ev.append(.bossRecovered)
            return finish(&ev)
        }
        if bossStamina <= 0 { return finish(&ev) }
        // A Break this turn cancelled the telegraphed action.
        guard !isBroken, let name = intentName, let spec else { return finish(&ev) }
        if spec.damage > 0 {
            let incoming = boss.attack * spec.damage * loaded * (1.0 + escalation)
            loaded = 1.0
            let deflected = guarding > 0 && spec.deflectable
            let reduction = min(rules.guardMaxReduction, guarding + (deflected ? rules.deflectBonusReduction : 0))
            let taken = vary(incoming * (1.0 - reduction)); playerStamina -= taken
            ev.append(.bossAttack(name: name, incoming: incoming, taken: taken, deflected: deflected))
            if deflected {
                deflects += 1
                if flags.insert("first_deflect").inserted { ev.append(.dialogue(key: "first_deflect")) }
                breakDamage(rules.deflectBreakDamage, cancelsPending: false, &ev)
            }
        }
        if let loads = spec.loads { loaded = loads; ev.append(.bossLoad(multiplier: loads)) }
        if let stacks = spec.pressure, stacks > 0 {
            pressure = min(rules.pressureCap, pressure + stacks)
            ev.append(.pressure(stacks: pressure))
            if flags.insert("escalate").inserted { ev.append(.dialogue(key: "escalate")) }
        }
        if let e = spec.escalate { escalation += e }
        patternIndex += 1
        return finish(&ev)
    }

    /// `cancelsPending`: an Analyze-Break lands before the telegraphed action, which is then skipped, not postponed.
    /// A Deflect-Break lands after the hit, so nothing is cancelled; the window simply follows.
    private mutating func breakDamage(_ amount: Double, cancelsPending: Bool, _ ev: inout [CombatEvent]) {
        guard !isBroken, amount > 0 else { return }
        breakNow -= amount
        ev.append(.breakDamage(amount, left: max(0, breakNow)))
        if breakNow <= 0 {
            isBroken = true; breaks += 1
            var cancelled: String? = nil
            if cancelsPending { cancelled = boss.pattern[patternIndex % boss.pattern.count]; patternIndex += 1 }
            ev.append(.broken(cancelled: cancelled))
            if flags.insert("first_break").inserted { ev.append(.dialogue(key: "first_break")) }
        }
    }

    private mutating func vary(_ x: Double) -> Double {
        guard rules.variance > 0 else { return x }
        let u = Double(rng.next() % 1_000_000) / 1_000_000
        return x * (1.0 + rules.variance * (2 * u - 1))
    }

    private mutating func finish(_ ev: inout [CombatEvent]) -> [CombatEvent] {
        if bossStamina <= 0 { result = .won }
        else if playerStamina <= 0 { result = .lost }
        else if turn >= rules.maxTurns { result = .stalled }
        if let result { ev.append(.result(result)) }
        return ev
    }
}

extension BossEncounter: Equatable {
    /// The generator is derived state (seed plus the draws the actions made), so equality reads the fight itself.
    public static func == (a: BossEncounter, b: BossEncounter) -> Bool {
        a.boss == b.boss && a.shares == b.shares && a.playerStamina == b.playerStamina && a.bossStamina == b.bossStamina && a.breakNow == b.breakNow
            && a.pressure == b.pressure && a.escalation == b.escalation && a.loaded == b.loaded && a.turn == b.turn && a.patternIndex == b.patternIndex
            && a.isBroken == b.isBroken && a.result == b.result && a.flags == b.flags && a.breaks == b.breaks && a.deflects == b.deflects
    }
}

public enum BossMath {
    /// Shares from ledger attributes: each stat over the balanced expected stat at the level, plus today's training
    /// as the challenge system credits it (a share of that same expected stat, capped).
    public static func shares(attributes: [AttributeID: Int], level: Int, minutesByFamily: [String: Double], ruleset: ProgressionRuleset, attributeCount: Int) -> CombatShares {
        let expected = ChallengeMath.share(level: level, ruleset: ruleset, attributeCount: attributeCount)
        func s(_ id: AttributeID) -> Double {
            let bonus = ChallengeMath.trainingBonus(minutesByFamily: minutesByFamily, attributeID: id, target: expected, ruleset: ruleset)
            return (Double(attributes[id] ?? 0) + bonus) / expected
        }
        return CombatShares(strength: s("strength"), endurance: s("endurance"), knowledge: s("knowledge"), mindfulness: s("mindfulness"))
    }
}

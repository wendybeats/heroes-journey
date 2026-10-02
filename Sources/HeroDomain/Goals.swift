import Foundation

// Daily goals (doc 24). Templates are content; the plan for a day is derived, deterministic per
// (user seed, day); completions are immutable facts that earn progression through the same
// engine as activities (architecture rules 1–3).

public enum GoalTemplateTag: Sendable {}
public typealias GoalTemplateID = StableID<GoalTemplateTag>

/// The three asks of a day (doc 22 §1).
public enum GoalSlot: String, Codable, Sendable, CaseIterable {
    case primary
    case secondary
    case smallWin = "small_win"
}

/// How a goal completes without a tap. Evaluated by `GoalEvaluator` over the day's facts.
public enum GoalCompletionRule: Hashable, Codable, Sendable {
    /// Tap only.
    case manual
    /// Any activity of `family` lasting at least `minMinutes` on the day.
    case activityFamily(family: FamilyID, minMinutes: Int)
    /// Daily step total at or above the goal's target. `base` grows by `perLevel` per level above 1.
    case steps(base: Int, perLevel: Int)
    /// A structured workout with at least `count` valid sets on the day.
    case workoutSets(count: Int)

    enum CodingKeys: String, CodingKey { case type, familyID = "family_id", minMinutes = "min_minutes", base, perLevel = "per_level", count }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "manual": self = .manual
        case "activity_family": self = .activityFamily(family: try c.decode(FamilyID.self, forKey: .familyID), minMinutes: try c.decodeIfPresent(Int.self, forKey: .minMinutes) ?? 1)
        case "steps": self = .steps(base: try c.decode(Int.self, forKey: .base), perLevel: try c.decodeIfPresent(Int.self, forKey: .perLevel) ?? 0)
        case "workout_sets": self = .workoutSets(count: try c.decodeIfPresent(Int.self, forKey: .count) ?? 1)
        case let other: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "unknown goal rule \(other)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .manual: try c.encode("manual", forKey: .type)
        case let .activityFamily(family, minMinutes):
            try c.encode("activity_family", forKey: .type); try c.encode(family, forKey: .familyID); try c.encode(minMinutes, forKey: .minMinutes)
        case let .steps(base, perLevel):
            try c.encode("steps", forKey: .type); try c.encode(base, forKey: .base); try c.encode(perLevel, forKey: .perLevel)
        case let .workoutSets(count):
            try c.encode("workout_sets", forKey: .type); try c.encode(count, forKey: .count)
        }
    }

    public var isManual: Bool { if case .manual = self { return true } else { return false } }
}

/// Content-defined goal (bundle `goal_templates`). Copy lives here, in the character's voice.
public struct GoalTemplate: Hashable, Codable, Sendable {
    public let id: GoalTemplateID
    public let slot: GoalSlot
    /// Shown as the row title. `{target}` is replaced with the day's target when the rule has one.
    public let title: String
    /// One line from the character; the plan picks one per day so a repeat reads differently.
    public let lines: [String]
    public let attributeID: AttributeID
    public let rule: GoalCompletionRule
    /// Selection tags: `training`, `rest`, a family id, an interest (`learning`, `mindfulness`),
    /// a motivation, `rare`. Matching the generator's inputs raises a template's weight.
    public let tags: [String]

    enum CodingKeys: String, CodingKey { case id, slot, title, lines, attributeID = "attribute_id", rule, tags }

    public init(id: GoalTemplateID, slot: GoalSlot, title: String, lines: [String], attributeID: AttributeID, rule: GoalCompletionRule, tags: [String]) {
        self.id = id; self.slot = slot; self.title = title; self.lines = lines; self.attributeID = attributeID; self.rule = rule; self.tags = tags
    }
}

/// What onboarding tells the generator (doc 23). Defaults are deliberate: a new user without
/// answers still gets a sensible day.
public struct GoalPreferences: Hashable, Codable, Sendable {
    public var primaryFamily: FamilyID
    /// `learning` or `mindfulness`.
    public var secondaryInterest: String
    public var trainingDaysPerWeek: Int
    public var motivation: String?

    public init(primaryFamily: FamilyID = "strength", secondaryInterest: String = "mindfulness", trainingDaysPerWeek: Int = 4, motivation: String? = nil) {
        self.primaryFamily = primaryFamily; self.secondaryInterest = secondaryInterest
        self.trainingDaysPerWeek = min(7, max(0, trainingDaysPerWeek)); self.motivation = motivation
    }

    /// Fixed weekday pattern per frequency (1 = Sunday … 7 = Saturday, Foundation's convention).
    /// A pattern, not a schedule the user edits: predictability is the point (doc 24).
    public var trainingWeekdays: Set<Int> {
        switch trainingDaysPerWeek {
        case ...0: return []
        case 1: return [4]
        case 2: return [3, 5]
        case 3: return [2, 4, 6]
        case 4: return [2, 3, 5, 6]
        case 5: return [2, 3, 4, 5, 6]
        case 6: return [2, 3, 4, 5, 6, 7]
        default: return [1, 2, 3, 4, 5, 6, 7]
        }
    }
}

/// A local calendar day as a sortable key ("2026-10-02"). Day boundary policy: ruleset `day_boundary`.
public struct DayKey: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: String
    public let year: Int, month: Int, day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
        rawValue = String(format: "%04d-%02d-%02d", year, month, day)
    }
    public init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let parts = raw.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad day key \(raw)")) }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
    public static func < (a: DayKey, b: DayKey) -> Bool { a.rawValue < b.rawValue }
    public var description: String { rawValue }

    public func date(calendar: Calendar) -> Date? { calendar.date(from: DateComponents(year: year, month: month, day: day)) }
    /// Whole days from `other` to self (positive when self is later).
    public func daysSince(_ other: DayKey, calendar: Calendar) -> Int {
        guard let a = other.date(calendar: calendar), let b = date(calendar: calendar) else { return 0 }
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }
}

/// One ask on one day. Derived from a template; the completion is a separate fact.
public struct DailyGoal: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let templateID: GoalTemplateID
    public let slot: GoalSlot
    public let day: DayKey
    /// Index into the template's `lines`.
    public let lineIndex: Int
    /// Resolved numeric target (steps), if the rule has one.
    public let target: Int?

    public init(id: UUID = UUID(), templateID: GoalTemplateID, slot: GoalSlot, day: DayKey, lineIndex: Int, target: Int?) {
        self.id = id; self.templateID = templateID; self.slot = slot; self.day = day; self.lineIndex = lineIndex; self.target = target
    }
}

public struct GoalPlan: Hashable, Codable, Sendable {
    public let day: DayKey
    public let goals: [DailyGoal]
    public let generatedAt: Date
    public init(day: DayKey, goals: [DailyGoal], generatedAt: Date) { self.day = day; self.goals = goals; self.generatedAt = generatedAt }
}

/// Immutable fact: a goal was completed, by whom (tap or which activity), when.
public struct GoalCompletion: Hashable, Codable, Sendable {
    public enum Source: Hashable, Codable, Sendable {
        case manual
        case activity(ActivityEventID)
        case steps(Int)
    }
    public let goalID: UUID
    public let templateID: GoalTemplateID
    public let day: DayKey
    public let source: Source
    /// The progression event derived from this completion (what the ledger references).
    public let activityEventID: ActivityEventID
    public let completedAt: Date

    public init(goalID: UUID, templateID: GoalTemplateID, day: DayKey, source: Source, activityEventID: ActivityEventID, completedAt: Date) {
        self.goalID = goalID; self.templateID = templateID; self.day = day; self.source = source; self.activityEventID = activityEventID; self.completedAt = completedAt
    }
}

/// Carried on the `ActivityEvent` a goal completion produces, so the engine can price it flat
/// (ruleset `goal_xp`) and credit the template's attribute.
public struct GoalReference: Hashable, Codable, Sendable {
    public let templateID: GoalTemplateID
    public let slot: GoalSlot
    public let attributeID: AttributeID
    public init(templateID: GoalTemplateID, slot: GoalSlot, attributeID: AttributeID) {
        self.templateID = templateID; self.slot = slot; self.attributeID = attributeID
    }
    enum CodingKeys: String, CodingKey { case templateID = "template_id", slot, attributeID = "attribute_id" }
}

// MARK: - generation

/// SplitMix64: tiny, seedable, deterministic across platforms. Used only for selection.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public enum GoalGenerator {
    /// Days inside which a template is not re-offered for the slot, pool permitting.
    public static func repeatWindow(_ slot: GoalSlot) -> Int {
        switch slot { case .primary: return 1; case .secondary: return 5; case .smallWin: return 7 }
    }
    /// Completion history considered for weighting.
    public static let historyWindowDays = 14

    public struct Inputs: Sendable {
        public let day: DayKey
        public let templates: [GoalTemplate]
        public let preferences: GoalPreferences
        public let level: Int
        public let history: [GoalPlan]
        public let completions: [GoalCompletion]
        public let seed: UInt64
        public let calendar: Calendar
        public init(day: DayKey, templates: [GoalTemplate], preferences: GoalPreferences, level: Int, history: [GoalPlan], completions: [GoalCompletion], seed: UInt64, calendar: Calendar) {
            self.day = day; self.templates = templates; self.preferences = preferences; self.level = level
            self.history = history; self.completions = completions; self.seed = seed; self.calendar = calendar
        }
    }

    /// Pure and deterministic: same inputs → same plan. One goal per slot; a slot with no
    /// eligible template is skipped rather than invented.
    public static func plan(_ inputs: Inputs, now: Date) -> GoalPlan {
        var rng = SeededGenerator(seed: inputs.seed ^ UInt64(truncatingIfNeeded: inputs.day.rawValue.hashValueStable))
        let isTrainingDay = Self.isTrainingDay(inputs.day, preferences: inputs.preferences, calendar: inputs.calendar)
        var goals: [DailyGoal] = []
        for slot in GoalSlot.allCases {
            guard let pick = select(slot: slot, inputs: inputs, trainingDay: isTrainingDay, rng: &rng) else { continue }
            let lineIndex = pick.lines.isEmpty ? 0 : Int(rng.next() % UInt64(pick.lines.count))
            goals.append(DailyGoal(templateID: pick.id, slot: slot, day: inputs.day, lineIndex: lineIndex, target: target(for: pick, level: inputs.level)))
        }
        return GoalPlan(day: inputs.day, goals: goals, generatedAt: now)
    }

    public static func isTrainingDay(_ day: DayKey, preferences: GoalPreferences, calendar: Calendar) -> Bool {
        guard let date = day.date(calendar: calendar) else { return true }
        return preferences.trainingWeekdays.contains(calendar.component(.weekday, from: date))
    }

    public static func target(for template: GoalTemplate, level: Int) -> Int? {
        if case let .steps(base, perLevel) = template.rule { return base + perLevel * max(0, level - 1) }
        return nil
    }

    private static func select(slot: GoalSlot, inputs: Inputs, trainingDay: Bool, rng: inout SeededGenerator) -> GoalTemplate? {
        let p = inputs.preferences
        var pool = inputs.templates.filter { $0.slot == slot }
        switch slot {
        case .primary:
            let mode = trainingDay ? "training" : "rest"
            pool = pool.filter { $0.tags.contains(mode) }
            if trainingDay {
                let own = pool.filter { $0.tags.contains(p.primaryFamily.rawValue) }
                if !own.isEmpty { pool = own }
            }
        case .secondary:
            let own = pool.filter { $0.tags.contains(p.secondaryInterest) }
            if !own.isEmpty { pool = own }
        case .smallWin:
            break
        }
        guard !pool.isEmpty else { return nil }

        // No repeats inside the slot's window, unless that empties the pool.
        let window = repeatWindow(slot)
        let recent = Set(inputs.history.filter { inputs.day.daysSince($0.day, calendar: inputs.calendar) <= window && $0.day < inputs.day }
            .flatMap(\.goals).filter { $0.slot == slot }.map(\.templateID))
        let fresh = pool.filter { !recent.contains($0.id) }
        if !fresh.isEmpty { pool = fresh }

        // Weight: motivation match up, rare down, completed-recently up, offered-but-skipped down.
        let recentPlans = inputs.history.filter { inputs.day.daysSince($0.day, calendar: inputs.calendar) <= historyWindowDays && $0.day < inputs.day }
        let offered = Set(recentPlans.flatMap(\.goals).map(\.templateID))
        let done = Set(inputs.completions.filter { inputs.day.daysSince($0.day, calendar: inputs.calendar) <= historyWindowDays }.map(\.templateID))
        let weighted: [(GoalTemplate, Double)] = pool.map { t in
            var w = 1.0
            if let m = p.motivation, t.tags.contains(m) { w *= 2 }
            if t.tags.contains("rare") { w *= 0.3 }
            if done.contains(t.id) { w *= 1.5 } else if offered.contains(t.id) { w *= 0.7 }
            return (t, w)
        }
        let total = weighted.reduce(0) { $0 + $1.1 }
        var roll = Double(rng.next() % 1_000_000) / 1_000_000 * total
        for (t, w) in weighted {
            roll -= w
            if roll < 0 { return t }
        }
        return weighted.last?.0
    }
}

extension String {
    /// FNV-1a over UTF-8: stable across runs and platforms, unlike `hashValue`.
    var hashValueStable: UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01B3 }
        return h
    }
}

// MARK: - evaluation

public enum GoalEvaluator {
    /// Goals in `plan` not yet completed that the day's facts satisfy, with the source that did it.
    /// `events` are the day's activity facts (goal-derived events excluded by the caller); `steps`
    /// is the day's total when known. Pure.
    public static func satisfied(plan: GoalPlan, templates: [GoalTemplate], completed: Set<UUID>, events: [ActivityEvent], steps: Int?) -> [(goal: DailyGoal, source: GoalCompletion.Source)] {
        var out: [(goal: DailyGoal, source: GoalCompletion.Source)] = []
        for goal in plan.goals where !completed.contains(goal.id) {
            guard let template = templates.first(where: { $0.id == goal.templateID }) else { continue }
            switch template.rule {
            case .manual:
                continue
            case let .activityFamily(family, minMinutes):
                if let e = events.first(where: { $0.familyID == family && $0.goal == nil && $0.durationSeconds >= minMinutes * 60 }) {
                    out.append((goal, .activity(e.id)))
                }
            case .steps:
                if let steps, let target = goal.target, steps >= target { out.append((goal, .steps(steps))) }
            case let .workoutSets(count):
                if let e = events.first(where: { $0.goal == nil && ($0.structuredSetCount ?? 0) >= count }) {
                    out.append((goal, .activity(e.id)))
                }
            }
        }
        return out
    }

    /// The progression fact for a completion. Duration is zero: goal XP is flat, not minute-based.
    public static func makeEvent(for goal: DailyGoal, template: GoalTemplate, userID: UserID, familyFallback: FamilyID, at now: Date, id: ActivityEventID = ActivityEventID()) -> ActivityEvent {
        let family: FamilyID
        if case let .activityFamily(f, _) = template.rule { family = f } else { family = familyFallback }
        return ActivityEvent(id: id, userID: userID, activityTypeID: ActivityTypeID(template.id.rawValue), familyID: family, startedAt: now, durationSeconds: 0,
                             source: .goal, verification: .selfReported, goal: GoalReference(templateID: template.id, slot: goal.slot, attributeID: template.attributeID), createdAt: now)
    }
}

// MARK: - the bond (onboarding's one grant)

/// The attributes behind the player's two onboarding choices. Priced by `ProgressionRuleset.BondGrant`.
public struct BondReference: Hashable, Codable, Sendable {
    public let primaryAttributeID: AttributeID
    public let secondaryAttributeID: AttributeID
    public init(primaryAttributeID: AttributeID, secondaryAttributeID: AttributeID) {
        self.primaryAttributeID = primaryAttributeID; self.secondaryAttributeID = secondaryAttributeID
    }
    enum CodingKeys: String, CodingKey { case primaryAttributeID = "primary_attribute_id", secondaryAttributeID = "secondary_attribute_id" }

    /// The attribute a family feeds most, from the ruleset's weights (ties: alphabetical, so it is stable).
    public static func attribute(forFamily family: String, ruleset: ProgressionRuleset, fallback: AttributeID) -> AttributeID {
        let weights = ruleset.attributeWeightsByFamily[family] ?? [:]
        guard let best = weights.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) else { return fallback }
        return AttributeID(best.key)
    }

    public static func makeEvent(primaryFamily: FamilyID, secondaryInterest: String, ruleset: ProgressionRuleset, userID: UserID, at now: Date, id: ActivityEventID = ActivityEventID()) -> ActivityEvent {
        let primary = attribute(forFamily: primaryFamily.rawValue, ruleset: ruleset, fallback: "strength")
        let secondary = attribute(forFamily: secondaryInterest, ruleset: ruleset, fallback: "mindfulness")
        return ActivityEvent(id: id, userID: userID, activityTypeID: "bond", familyID: primaryFamily, startedAt: now, durationSeconds: 0, source: .bond, verification: .selfReported,
                             bond: BondReference(primaryAttributeID: primary, secondaryAttributeID: secondary), createdAt: now)
    }
}

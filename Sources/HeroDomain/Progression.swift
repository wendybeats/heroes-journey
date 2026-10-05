import Foundation

/// Everything the pure calculation needs beyond the event and ruleset (doc 15 §2).
/// The caller (server, or a local preview) supplies it; the engine never reads state.
public struct EvaluationContext: Sendable, Equatable {
    /// Minutes already credited today, in the same family, before this event.
    public let priorEligibleMinutesToday: Double
    /// Activity XP already earned today across every family, before this event (dev-5 cap).
    public let priorActivityXPToday: Int
    /// Total XP before this event, used to detect level crossings.
    public let priorTotalXP: Int
    /// Reward IDs already granted; a level reward is proposed only if not already here.
    public let grantedRewardIDs: Set<RewardID>
    /// Level -> rewards that unlock on reaching it, from the content bundle.
    public let levelRewards: [Int: [RewardID]]

    public init(priorEligibleMinutesToday: Double, priorTotalXP: Int, grantedRewardIDs: Set<RewardID>, levelRewards: [Int: [RewardID]], priorActivityXPToday: Int = 0) {
        self.priorEligibleMinutesToday = priorEligibleMinutesToday
        self.priorActivityXPToday = priorActivityXPToday
        self.priorTotalXP = priorTotalXP
        self.grantedRewardIDs = grantedRewardIDs
        self.levelRewards = levelRewards
    }
}

/// The outcome of evaluating one event. Nothing here is committed; the caller commits it
/// atomically together with a `ProcessingRecord` (doc 15 §4).
public struct ProgressionProposal: Sendable, Equatable {
    public let activityEventID: ActivityEventID
    public let rulesetID: RulesetID
    public let xp: Int
    public let attributes: [AttributeID: Int]
    public let levelBefore: Int
    public let levelAfter: Int
    public let rewardsUnlocked: [RewardID]
    /// Minutes that counted at full or tapered credit; for the caller to roll into tomorrow's context.
    public let eligibleMinutes: Double

    public init(activityEventID: ActivityEventID, rulesetID: RulesetID, xp: Int, attributes: [AttributeID: Int], levelBefore: Int, levelAfter: Int, rewardsUnlocked: [RewardID], eligibleMinutes: Double) {
        self.activityEventID = activityEventID; self.rulesetID = rulesetID; self.xp = xp; self.attributes = attributes
        self.levelBefore = levelBefore; self.levelAfter = levelAfter; self.rewardsUnlocked = rewardsUnlocked; self.eligibleMinutes = eligibleMinutes
    }

    public var leveledUp: Bool { levelAfter > levelBefore }
    public var isEmpty: Bool { xp == 0 && attributes.isEmpty && rewardsUnlocked.isEmpty }
}

public enum ProgressionEngine {
    /// Pure and deterministic: same inputs → same proposal. No clocks, no randomness, no IO.
    public static func evaluate(event: ActivityEvent, ruleset: ProgressionRuleset, context: EvaluationContext) -> ProgressionProposal {
        let levelBefore = ruleset.level(forTotalXP: context.priorTotalXP)
        func empty() -> ProgressionProposal {
            ProgressionProposal(activityEventID: event.id, rulesetID: ruleset.id, xp: 0, attributes: [:], levelBefore: levelBefore, levelAfter: levelBefore, rewardsUnlocked: [], eligibleMinutes: 0)
        }
        var xp: Int
        var attributes: [AttributeID: Int] = [:]
        var credited = 0.0
        var questRewards: [RewardID] = []
        if let goal = event.goal {
            // Goal completion: flat, untapered, credited to the template's attribute (doc 24).
            xp = max(0, ruleset.goalXP?[goal.slot.rawValue] ?? 0)
            let points = Int((Double(xp) * ruleset.attributePointsPerXP).rounded(.down))
            if points > 0 { attributes[goal.attributeID] = points }
        } else if let bond = event.bond {
            // The bond seal: one permanent starting grant priced by the ruleset (rule 4).
            guard let grant = ruleset.bondGrant else { return empty() }
            xp = max(0, grant.xp)
            if grant.primaryPoints > 0 { attributes[bond.primaryAttributeID, default: 0] += grant.primaryPoints }
            if grant.secondaryPoints > 0 { attributes[bond.secondaryAttributeID, default: 0] += grant.secondaryPoints }
        } else if let story = event.story {
            // Story milestone: no XP (the ruleset may price it later); its reward is granted once.
            xp = 0
            if let reward = story.rewardID, !context.grantedRewardIDs.contains(reward) { questRewards.append(reward) }
        } else if let quest = event.quest {
            // Quest return: the rolled table entry's XP, plus its content reward if never granted.
            guard let table = ruleset.dailyQuest?.rewardTable, table.indices.contains(quest.rewardIndex) else { return empty() }
            let row = table[quest.rewardIndex]
            xp = max(0, row.xp)
            if let reward = quest.rewardID ?? row.rewardID, !context.grantedRewardIDs.contains(reward) {
                questRewards.append(reward)
            } else {
                // Nothing new to give: the would-be drop is traded in for XP by tier (doc 29). Still one fact, still idempotent.
                xp += max(0, ruleset.dailyQuest?.tradeInXP?[row.tier] ?? 0)
            }
        } else {
            guard let priced = activityXP(event: event, ruleset: ruleset, context: context) else { return empty() }
            xp = priced.xp; attributes = priced.attributes; credited = priced.credited
        }

        let levelAfter = ruleset.level(forTotalXP: context.priorTotalXP + xp)
        var rewards: [RewardID] = questRewards
        if levelAfter > levelBefore {
            for level in (levelBefore + 1)...levelAfter {
                for reward in context.levelRewards[level] ?? [] where !context.grantedRewardIDs.contains(reward) {
                    rewards.append(reward)
                }
            }
        }
        return ProgressionProposal(activityEventID: event.id, rulesetID: ruleset.id, xp: xp, attributes: attributes, levelBefore: levelBefore, levelAfter: levelAfter, rewardsUnlocked: rewards, eligibleMinutes: credited)
    }

    /// Minute-based pricing for real activity. Nil when the event earns nothing.
    private static func activityXP(event: ActivityEvent, ruleset: ProgressionRuleset, context: EvaluationContext) -> (xp: Int, attributes: [AttributeID: Int], credited: Double)? {
        guard event.durationSeconds >= ruleset.minimumDurationSeconds else { return nil }
        guard let xpPerMinute = ruleset.xpPerMinuteByFamily[event.familyID.rawValue] else { return nil }

        let minutes = ruleset.creditedMinutes(for: event)
        let credited = creditedMinutes(minutes, prior: context.priorEligibleMinutesToday, taper: ruleset.dailyTaper)
        let multiplier = ruleset.verificationMultiplier[event.verification.rawValue] ?? 1.0
        let base = credited > 0 ? (ruleset.sessionBaseXP ?? 0) : 0
        var xp = Int((credited * xpPerMinute * multiplier).rounded(.down)) + base
        // dev-5 (docs/21): a day of activity is worth at most the cap, whatever the mix of families.
        // Consistency sets the pace; volume past the cap is history, not progression.
        if let cap = ruleset.dailyActivityXPCap { xp = max(0, min(xp, cap - context.priorActivityXPToday)) }

        var attributes: [AttributeID: Int] = [:]
        let weights = ruleset.attributeWeightsByFamily[event.familyID.rawValue] ?? [:]
        for (attributeKey, weight) in weights {
            let points = Int((Double(xp) * ruleset.attributePointsPerXP * weight).rounded(.down))
            if points > 0 { attributes[AttributeID(attributeKey)] = points }
        }
        return (xp, attributes, credited)
    }

    /// Diminishing returns, not punishment (doc 05). Returns *credit-weighted* minutes.
    /// [0, fullCredit] → 1.0; (fullCredit, hardCap] → taperRate; beyond hardCap → 0.
    static func creditedMinutes(_ minutes: Double, prior: Double, taper: ProgressionRuleset.DailyTaper) -> Double {
        let start = max(0, prior)
        let end = start + max(0, minutes)
        let full = max(0, min(end, taper.fullCreditMinutes) - start)
        let tapered = max(0, min(end, taper.hardCapMinutes) - max(start, taper.fullCreditMinutes))
        return full + tapered * taper.taperRate
    }
}

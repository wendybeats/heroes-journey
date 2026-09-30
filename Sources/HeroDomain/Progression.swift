import Foundation

/// Everything the pure calculation needs beyond the event and ruleset (doc 15 §2).
/// The caller (server, or a local preview) supplies it; the engine never reads state.
public struct EvaluationContext: Sendable, Equatable {
    /// Minutes already credited today, in the same family, before this event.
    public let priorEligibleMinutesToday: Double
    /// Total XP before this event, used to detect level crossings.
    public let priorTotalXP: Int
    /// Reward IDs already granted; a level reward is proposed only if not already here.
    public let grantedRewardIDs: Set<RewardID>
    /// Level -> rewards that unlock on reaching it, from the content bundle.
    public let levelRewards: [Int: [RewardID]]

    public init(priorEligibleMinutesToday: Double, priorTotalXP: Int, grantedRewardIDs: Set<RewardID>, levelRewards: [Int: [RewardID]]) {
        self.priorEligibleMinutesToday = priorEligibleMinutesToday
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
        guard event.durationSeconds >= ruleset.minimumDurationSeconds else { return empty() }
        guard let xpPerMinute = ruleset.xpPerMinuteByFamily[event.familyID.rawValue] else { return empty() }

        let minutes = ruleset.creditedMinutes(for: event)
        let credited = creditedMinutes(minutes, prior: context.priorEligibleMinutesToday, taper: ruleset.dailyTaper)
        let multiplier = ruleset.verificationMultiplier[event.verification.rawValue] ?? 1.0
        let xp = Int((credited * xpPerMinute * multiplier).rounded(.down))

        var attributes: [AttributeID: Int] = [:]
        let weights = ruleset.attributeWeightsByFamily[event.familyID.rawValue] ?? [:]
        for (attributeKey, weight) in weights {
            let points = Int((Double(xp) * ruleset.attributePointsPerXP * weight).rounded(.down))
            if points > 0 { attributes[AttributeID(attributeKey)] = points }
        }

        let levelAfter = ruleset.level(forTotalXP: context.priorTotalXP + xp)
        var rewards: [RewardID] = []
        if levelAfter > levelBefore {
            for level in (levelBefore + 1)...levelAfter {
                for reward in context.levelRewards[level] ?? [] where !context.grantedRewardIDs.contains(reward) {
                    rewards.append(reward)
                }
            }
        }
        return ProgressionProposal(activityEventID: event.id, rulesetID: ruleset.id, xp: xp, attributes: attributes, levelBefore: levelBefore, levelAfter: levelAfter, rewardsUnlocked: rewards, eligibleMinutes: credited)
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

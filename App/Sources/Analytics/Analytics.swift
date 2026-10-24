import Foundation

// HER-6 (owner 2026-10-19): product analytics behind one protocol. Every event the app sends is named here and
// nowhere else, so the dictionary in docs/42 and this file are the same list. HeroDomain and HeroContent never see
// this; the app target owns it. Nothing from Apple Health leaves the device through analytics: no durations, no
// workout types, no step counts, only that something was logged and which family it fed.

/// One product event. Names follow PostHog's "[object] [verb]" convention; properties are primitives only.
enum AnalyticsEvent: Sendable {
    case onboardingCompleted(primaryFamily: String, secondaryInterest: String, healthConnected: Bool)
    case healthConnected
    /// The echo's Apple Health prompt (owner 2026-10-24). `reason`: first_log, reconnect, reoffer.
    case healthPromptAnswered(reason: String, connected: Bool)
    /// `source`: manual, structured_workout, health_import, steps. `first`: the first activity ever credited.
    case activityLogged(source: String, family: String, first: Bool)
    case goalCompleted(slot: String, attribute: String)
    case questDeparted(quest: String)
    case questClaimed(quest: String, tier: String?, page: Bool)
    case challengeOffered(challenge: String, character: String)
    case challengeResolved(challenge: String, won: Bool, probability: Double)
    case levelReached(level: Int)
    case ascensionReached(tier: Int)
    case bossAttempted(boss: String, result: String, turns: Int, staminaShare: Double)
    case chapterCompleted(chapter: String)

    var name: String {
        switch self {
        case .onboardingCompleted: return "onboarding completed"
        case .healthConnected: return "health connected"
        case .healthPromptAnswered: return "health prompt answered"
        case .activityLogged: return "activity logged"
        case .goalCompleted: return "goal completed"
        case .questDeparted: return "quest departed"
        case .questClaimed: return "quest claimed"
        case .challengeOffered: return "challenge offered"
        case .challengeResolved: return "challenge resolved"
        case .levelReached: return "level reached"
        case .ascensionReached: return "ascension reached"
        case .bossAttempted: return "boss attempted"
        case .chapterCompleted: return "chapter completed"
        }
    }

    var properties: [String: any Sendable] {
        switch self {
        case let .onboardingCompleted(primary, secondary, health): return ["primary_family": primary, "secondary_interest": secondary, "health_connected": health]
        case .healthConnected: return [:]
        case let .healthPromptAnswered(reason, connected): return ["reason": reason, "connected": connected]
        case let .activityLogged(source, family, first): return ["source": source, "family": family, "first": first]
        case let .goalCompleted(slot, attribute): return ["slot": slot, "attribute": attribute]
        case let .questDeparted(quest): return ["quest": quest]
        case let .questClaimed(quest, tier, page): return ["quest": quest, "tier": tier ?? "none", "page": page]
        case let .challengeOffered(challenge, character): return ["challenge": challenge, "character": character]
        case let .challengeResolved(challenge, won, probability): return ["challenge": challenge, "won": won, "probability": (probability * 100).rounded() / 100]
        case let .levelReached(level): return ["level": level]
        case let .ascensionReached(tier): return ["tier": tier]
        case let .bossAttempted(boss, result, turns, stamina): return ["boss": boss, "result": result, "turns": turns, "stamina_share": (stamina * 100).rounded() / 100]
        case let .chapterCompleted(chapter): return ["chapter": chapter]
        }
    }
}

/// The app talks to this; `PostHogAnalytics` is the only live implementation, `NoAnalytics` the default so previews,
/// tests and a build without the SDK send nothing.
protocol AnalyticsClient: Sendable {
    func track(_ event: AnalyticsEvent)
    /// Ties events to one person. Today the local user id; the account id once HER-17 lands (aliased, so cohorts survive).
    func identify(_ distinctID: String, properties: [String: any Sendable])
    /// The settings toggle. Off = nothing leaves the device and the queue is cleared.
    func setEnabled(_ enabled: Bool)
}

struct NoAnalytics: AnalyticsClient {
    func track(_ event: AnalyticsEvent) {}
    func identify(_ distinctID: String, properties: [String: any Sendable]) {}
    func setEnabled(_ enabled: Bool) {}
}

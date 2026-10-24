import Foundation
import PostHog

/// PostHog behind `AnalyticsClient` (HER-6). Configured for the minimum: our named events plus the SDK's app
/// lifecycle events (Application Opened / Backgrounded / Installed / Updated), which give D1–D30 retention. No
/// autocapture, no screen views, no element interactions, no session replay, no feature-flag calls.
final class PostHogAnalytics: AnalyticsClient, @unchecked Sendable {
    /// PostHog project API key: write-only and public by design (it ships in every client app), so it lives in
    /// source, not in a secret. US cloud. Project "Default project" in the Heroes Journey organisation.
    static let projectAPIKey = "phc_w8tQFGgm3jJuLfXmz3Vi38Rsaiz9JVnmJ7dqA74cDHzE"
    static let host = "https://us.i.posthog.com"

    private let sdk: PostHogSDK

    private init(sdk: PostHogSDK) { self.sdk = sdk }

    /// Call once at launch, before the state is loaded.
    static func start() -> PostHogAnalytics {
        let config = PostHogConfig(apiKey: projectAPIKey, host: host)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.rageClickConfig.enabled = false   // owner device run 2026-10-24: $rageclick arrived with interactions off; it has its own switch
        config.sessionReplay = false
        config.sendFeatureFlagEvent = false
        config.preloadFeatureFlags = false
        config.flushIntervalSeconds = 30
        PostHogSDK.shared.setup(config)
        return PostHogAnalytics(sdk: PostHogSDK.shared)
    }

    func track(_ event: AnalyticsEvent) {
        sdk.capture(event.name, properties: event.properties.mapValues { $0 as Any })
    }

    func identify(_ distinctID: String, properties: [String: any Sendable]) {
        sdk.identify(distinctID, userProperties: properties.mapValues { $0 as Any })
    }

    func setEnabled(_ enabled: Bool) {
        if enabled { sdk.optIn() } else { sdk.optOut() }
    }
}

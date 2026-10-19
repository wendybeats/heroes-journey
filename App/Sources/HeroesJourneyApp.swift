import SwiftUI

@main
struct HeroesJourneyApp: App {
    @State private var state: AppState

    init() {
        // HER-6: analytics is wired before the first view; the state owns the toggle and the hooks.
        let analytics = PostHogAnalytics.start()
        let loaded = AppState.load()
        loaded.analytics = analytics
        analytics.setEnabled(loaded.analyticsEnabled)
        analytics.identify(loaded.userID.rawValue.uuidString, properties: [:])
        _state = State(initialValue: loaded)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .preferredColorScheme(.dark)
                .tint(NeoTokyo.Hierarchy.primary)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if state.recipe == nil {
                OnboardingView()
            } else {
                HomeView()
            }
        }
        .background(NeoTokyo.Surface.base.ignoresSafeArea())
    }
}

import SwiftUI

@main
struct HeroesJourneyApp: App {
    @State private var state = AppState.load()

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

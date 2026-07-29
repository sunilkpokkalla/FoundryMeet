import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @State private var isOnboardingCompleted = false

    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                AuthView()
            } else if !authManager.sessionReady {
                ProgressView("Loading your network…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.surface.ignoresSafeArea())
            } else if !(authManager.hasCompletedOnboarding || isOnboardingCompleted) {
                OnboardingView(isOnboardingCompleted: Binding(
                    get: { self.isOnboardingCompleted },
                    set: { newValue in
                        self.isOnboardingCompleted = newValue
                        if newValue {
                            authManager.markOnboardingComplete()
                        }
                    }
                ))
            } else {
                TabView {
                    DiscoveryView()
                        .tabItem {
                            Label("Discover", systemImage: "sparkles")
                        }

                    NetworkingHubView()
                        .tabItem {
                            Label("Hub", systemImage: "globe")
                        }

                    SchedulingView()
                        .tabItem {
                            Label("Schedule", systemImage: "calendar")
                        }

                    MatchHistoryView()
                        .tabItem {
                            Label("History", systemImage: "clock")
                        }
                }
            }
        }
        .environmentObject(authManager)
        .environmentObject(AppRepository.shared)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

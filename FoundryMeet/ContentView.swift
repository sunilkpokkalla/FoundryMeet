import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var isOnboardingCompleted = false

    var body: some View {
        Group {
            if !hasSeenOnboarding && !isOnboardingCompleted {
                OnboardingView(isOnboardingCompleted: Binding(
                    get: { self.isOnboardingCompleted },
                    set: { newValue in
                        self.isOnboardingCompleted = newValue
                        if newValue {
                            self.hasSeenOnboarding = true
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
        .onAppear {
            // Reset for testing purposes
            hasSeenOnboarding = false
            isOnboardingCompleted = false
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

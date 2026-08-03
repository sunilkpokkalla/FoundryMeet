import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @State private var isOnboardingCompleted = false
    /// Cups splash only before login — never after the user is signed in.
    @State private var didFinishBrandSplash = false

    var body: some View {
        Group {
            if !authManager.hasResolvedAuth {
                // Waiting on Firebase — static logo, no cups motion.
                sessionLoadingScreen(message: nil)
            } else if !authManager.isAuthenticated {
                if !didFinishBrandSplash {
                    BrandSplashView {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            didFinishBrandSplash = true
                        }
                    }
                    .transition(.opacity)
                } else {
                    AuthView()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            } else if !authManager.sessionReady {
                sessionLoadingScreen(message: "Loading your network…")
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
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: didFinishBrandSplash)
        .environmentObject(authManager)
        .environmentObject(AppRepository.shared)
#if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-skipAuth"),
               !authManager.isAuthenticated {
                authManager.startDevSession()
            }
        }
#endif
    }

    private func sessionLoadingScreen(message: String?) -> some View {
        ZStack {
            AppColors.surface.ignoresSafeArea()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityLabel(message ?? "FoundryMeet")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

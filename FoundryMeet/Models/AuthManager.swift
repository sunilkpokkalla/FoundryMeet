import SwiftUI
import FirebaseAuth

#if DEBUG
/// Local sign-in shortcut for previewing the signed-in app before the Firebase user
/// directory is populated. Firebase rejects passwords under 6 characters, so these
/// credentials cannot exist as a real account. Compiled out of release builds.
enum DevAccount {
    static let email = "skpokkalla@gmail.com"
    static let password = "admin"
    static let userId = "dev-skpokkalla"

    static func matches(email: String, password: String) -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == Self.email && password == Self.password
    }
}
#endif

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User? = nil
    @Published private(set) var isDevSession: Bool = false
    @Published private(set) var sessionReady: Bool = false
    @Published var hasCompletedOnboarding: Bool = false

    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    private let repository = AppRepository.shared

    var userId: String? {
#if DEBUG
        if isDevSession { return DevAccount.userId }
#endif
        return currentUser?.uid
    }

    var email: String {
#if DEBUG
        if isDevSession { return DevAccount.email }
#endif
        return currentUser?.email ?? ""
    }

    var displayName: String {
        if let name = currentUser?.displayName, !name.isEmpty {
            return name
        }
        return email.components(separatedBy: "@").first ?? "Founder"
    }

    init() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                self.currentUser = user
                if self.isDevSession { return }
                if let user {
                    await self.bootstrapSession(
                        userId: user.uid,
                        email: user.email ?? "",
                        displayName: user.displayName ?? "",
                        useLocalStore: false
                    )
                } else {
                    self.isAuthenticated = false
                    self.sessionReady = false
                    self.hasCompletedOnboarding = false
                    self.repository.clearSession()
                }
            }
        }
    }

    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

#if DEBUG
    func startDevSession() {
        isDevSession = true
        Task {
            await bootstrapSession(
                userId: DevAccount.userId,
                email: DevAccount.email,
                displayName: "Sunil",
                useLocalStore: true
            )
        }
    }
#endif

    func signOut() {
#if DEBUG
        if isDevSession {
            isDevSession = false
            isAuthenticated = false
            sessionReady = false
            hasCompletedOnboarding = false
            repository.clearSession()
            return
        }
#endif
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }

    /// Removes profile data, then the Firebase Auth user. Apple requires this
    /// path because the app supports account creation.
    func deleteAccount() async throws {
#if DEBUG
        if isDevSession {
            try await repository.deleteAccountData()
            isDevSession = false
            isAuthenticated = false
            sessionReady = false
            hasCompletedOnboarding = false
            repository.clearSession()
            return
        }
#endif
        guard let user = Auth.auth().currentUser else {
            throw RepositoryError.notSignedIn
        }
        try await repository.deleteAccountData()
        do {
            try await user.delete()
        } catch {
            let ns = error as NSError
            if ns.code == AuthErrorCode.requiresRecentLogin.rawValue {
                throw RepositoryError.reauthenticationRequired
            }
            throw error
        }
        isAuthenticated = false
        sessionReady = false
        hasCompletedOnboarding = false
        repository.clearSession()
    }

    func markOnboardingComplete() {
        hasCompletedOnboarding = true
    }

    private func bootstrapSession(
        userId: String,
        email: String,
        displayName: String,
        useLocalStore: Bool
    ) async {
        sessionReady = false
        await repository.configure(
            userId: userId,
            email: email,
            displayName: displayName,
            useLocalStore: useLocalStore
        )
        hasCompletedOnboarding = repository.hasCompletedOnboarding(for: userId)
            || repository.profile?.onboardingCompleted == true
        isAuthenticated = true
        sessionReady = true
    }
}

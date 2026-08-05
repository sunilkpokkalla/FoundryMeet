import SwiftUI
import UIKit
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

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

enum AccountAuthProvider {
    case password
    case google
    case apple
    case unknown
}

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User? = nil
    @Published private(set) var isDevSession: Bool = false
    @Published private(set) var sessionReady: Bool = false
    /// True after Firebase Auth reports the first session state (signed in or out).
    @Published private(set) var hasResolvedAuth: Bool = false
    @Published var hasCompletedOnboarding: Bool = false

    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    private let repository = AppRepository.shared
    private let appleReauth = AppleReauthController()

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

    /// Provider used for the current session — drives the delete confirmation step.
    var accountAuthProvider: AccountAuthProvider {
#if DEBUG
        if isDevSession { return .password }
#endif
        let ids = Set((Auth.auth().currentUser?.providerData ?? []).map(\.providerID))
        if ids.contains("password") { return .password }
        if ids.contains("google.com") { return .google }
        if ids.contains("apple.com") { return .apple }
        return .unknown
    }

    var requiresPasswordToDelete: Bool {
#if DEBUG
        if isDevSession { return false }
#endif
        return accountAuthProvider == .password
    }

    init() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                self.currentUser = user
                self.hasResolvedAuth = true
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
    ///
    /// Firebase only allows `user.delete()` after a recent login. Instead of
    /// asking the user to leave the app, we reauthenticate in-place (password
    /// sheet, Google, or Apple), then finish the wipe.
    func deleteAccount(password: String? = nil) async throws {
#if DEBUG
        if isDevSession {
            try await repository.deleteAccountData()
            clearLocalAuthState()
            return
        }
#endif
        guard let user = Auth.auth().currentUser else {
            throw RepositoryError.notSignedIn
        }

        // Confirm identity first — never wipe Firestore until Auth delete can succeed.
        try await reauthenticateForDeletion(user: user, password: password)

        try await repository.deleteAccountData()

        do {
            try await user.delete()
        } catch {
            let ns = error as NSError
            if ns.code == AuthErrorCode.requiresRecentLogin.rawValue {
                // Rare second factor: reauth again and retry once.
                try await reauthenticateForDeletion(user: user, password: password)
                try await user.delete()
            } else {
                throw error
            }
        }

        clearLocalAuthState()
    }

    func markOnboardingComplete() {
        hasCompletedOnboarding = true
    }

    private func clearLocalAuthState() {
#if DEBUG
        isDevSession = false
#endif
        isAuthenticated = false
        sessionReady = false
        hasCompletedOnboarding = false
        repository.clearSession()
    }

    private func reauthenticateForDeletion(user: User, password: String?) async throws {
        switch accountAuthProvider {
        case .password:
            let trimmed = password?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else {
                throw RepositoryError.passwordRequiredForDelete
            }
            guard let email = user.email, !email.isEmpty else {
                throw RepositoryError.notSignedIn
            }
            let credential = EmailAuthProvider.credential(withEmail: email, password: trimmed)
            do {
                try await user.reauthenticate(with: credential)
            } catch {
                let ns = error as NSError
                if ns.code == AuthErrorCode.wrongPassword.rawValue
                    || ns.code == AuthErrorCode.invalidCredential.rawValue {
                    throw RepositoryError.wrongPasswordForDelete
                }
                throw error
            }

        case .google:
            try await reauthenticateWithGoogle(user)

        case .apple:
            try await reauthenticateWithApple(user)

        case .unknown:
            // No interactive provider — attempt a token refresh; Firebase may still accept delete.
            _ = try await user.getIDTokenResult(forcingRefresh: true)
        }
    }

    private func reauthenticateWithGoogle(_ user: User) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw RepositoryError.reauthenticationFailed
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        guard let presenter = TopViewController.current() else {
            throw RepositoryError.reauthenticationFailed
        }

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                throw RepositoryError.deleteCancelled
            }
            throw error
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw RepositoryError.reauthenticationFailed
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await user.reauthenticate(with: credential)
    }

    private func reauthenticateWithApple(_ user: User) async throws {
        let nonce = AuthCrypto.randomNonceString()
        let credential = try await appleReauth.requestCredential(hashedNonce: AuthCrypto.sha256(nonce))
        guard
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw RepositoryError.reauthenticationFailed
        }
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        try await user.reauthenticate(with: firebaseCredential)
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
        // If the first Firestore write raced Auth, retry once before entering the app.
        if repository.profile == nil && !useLocalStore {
            await repository.configure(
                userId: userId,
                email: email,
                displayName: displayName,
                useLocalStore: useLocalStore
            )
        }
        hasCompletedOnboarding = repository.hasCompletedOnboarding(for: userId)
            || repository.profile?.onboardingCompleted == true
        isAuthenticated = true
        sessionReady = true
    }
}

// MARK: - Reauth helpers

enum TopViewController {
    @MainActor
    static func current() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

enum AuthCrypto {
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class AppleReauthController: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func requestCredential(hashedNonce: String) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]
            request.nonce = hashedNonce
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        TopViewController.current()?.view.window
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: RepositoryError.reauthenticationFailed)
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let ns = error as NSError
        if ns.code == ASAuthorizationError.canceled.rawValue {
            continuation?.resume(throwing: RepositoryError.deleteCancelled)
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}

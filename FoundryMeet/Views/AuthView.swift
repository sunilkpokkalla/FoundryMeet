import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import GoogleSignIn

struct AuthView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var errorMessage = ""
    @State private var infoMessage = ""
    @State private var isLoading = false
    @State private var currentNonce: String?
    @State private var legalDocument: LegalDocument?
    @StateObject private var appleCoordinator = AppleSignInCoordinator()

    var body: some View {
        ZStack {
            AppColors.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)

                        Text("FoundryMeet")
                            .font(.system(size: 30, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(AppColors.onSurface)

                        Text(isSignUp ? "Create an account to join the network." : "Welcome back to the network.")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 36)

                    VStack(spacing: 12) {
                        authField("Email", text: $email, isSecure: false)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        authField("Password", text: $password, isSecure: true)

                        if isSignUp {
                            authField("Confirm password", text: $confirmPassword, isSecure: true)
                        }

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        if !infoMessage.isEmpty {
                            Text(infoMessage)
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 14) {
                        Button(action: handleAuth) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(AppColors.onPrimary)
                                } else {
                                    Text(isSignUp ? "Sign Up" : "Sign In")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(AppColors.primary)
                            .foregroundColor(AppColors.onPrimary)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)

                        if !isSignUp {
                            Button("Forgot password?") {
                                sendPasswordReset()
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.onSurfaceVariant)
                        }

                        Button {
                            withAnimation {
                                isSignUp.toggle()
                                errorMessage = ""
                                infoMessage = ""
                            }
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.secondary)
                        }

#if DEBUG
                        Button(action: authManager.startDevSession) {
                            Text("Skip sign-in (Debug)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.onSurfaceVariant)
                                .underline()
                        }
#endif
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 14) {
                        Text("Or continue with")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.onSurfaceVariant)

                        SignInWithAppleButton(.signIn) { request in
                            let nonce = randomNonceString()
                            currentNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = sha256(nonce)
                        } onCompletion: { result in
                            handleAppleResult(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 48)
                        .cornerRadius(12)

                        Button(action: handleGoogleTap) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text("Google")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.surfaceContainerLowest)
                            .foregroundColor(AppColors.onSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.hairline, lineWidth: 1)
                            )
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 24)

                    legalFooter
                        .padding(.horizontal, 28)
                        .padding(.bottom, 40)
                }
            }
        }
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(document: document)
        }
        .onAppear {
            appleCoordinator.onError = { errorMessage = $0 }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            Text("By continuing, you agree to FoundryMeet’s Terms of Use and acknowledge the Privacy Policy.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Privacy Policy") { legalDocument = .privacy }
                Button("Terms of Use") { legalDocument = .terms }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppColors.secondary)
        }
    }

    private func authField(_ title: String, text: Binding<String>, isSecure: Bool) -> some View {
        Group {
            if isSecure {
                SecureField(title, text: text)
            } else {
                TextField(title, text: text)
            }
        }
        .padding()
        .background(AppColors.surfaceContainerLowest)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.hairline, lineWidth: 1)
        )
    }

    private func handleAuth() {
        errorMessage = ""
        infoMessage = ""

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        if isSignUp, password != confirmPassword {
            errorMessage = "Passwords do not match."
            return
        }

#if DEBUG
        if !isSignUp, DevAccount.matches(email: trimmedEmail, password: password) {
            authManager.startDevSession()
            return
        }
#endif

        isLoading = true
        if isSignUp {
            Auth.auth().createUser(withEmail: trimmedEmail, password: password) { result, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error {
                        self.errorMessage = friendlyAuthError(error)
                        return
                    }
                    result?.user.sendEmailVerification(completion: nil)
                    self.infoMessage = "Account created. Check your email to verify."
                }
            }
        } else {
            Auth.auth().signIn(withEmail: trimmedEmail, password: password) { _, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error {
                        self.errorMessage = friendlyAuthError(error)
                    }
                }
            }
        }
    }

    private func sendPasswordReset() {
        errorMessage = ""
        infoMessage = ""
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmedEmail.contains("@") else {
            errorMessage = "Enter your email above, then tap Forgot password."
            return
        }
        isLoading = true
        Auth.auth().sendPasswordReset(withEmail: trimmedEmail) { error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error {
                    self.errorMessage = friendlyAuthError(error)
                } else {
                    self.infoMessage = "Password reset email sent."
                }
            }
        }
    }

    private func handleGoogleTap() {
        errorMessage = ""
        infoMessage = ""

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Google Sign-In is not configured."
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = topViewController() else {
            errorMessage = "Unable to present Google Sign-In."
            return
        }

        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
            if let error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    // User dismissed the sheet — not an error worth showing.
                    if (error as NSError).code == GIDSignInError.canceled.rawValue {
                        return
                    }
                    self.errorMessage = error.localizedDescription
                }
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Google Sign-In failed."
                }
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { _, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error {
                        self.errorMessage = friendlyAuthError(error)
                    }
                }
            }
        }
    }

    private func topViewController() -> UIViewController? {
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

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Apple Sign In failed."
                return
            }
            isLoading = true
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            Auth.auth().signIn(with: firebaseCredential) { _, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error {
                        self.errorMessage = friendlyAuthError(error)
                    }
                }
            }
        }
    }
}

private func friendlyAuthError(_ error: Error) -> String {
    let ns = error as NSError
    if let code = AuthErrorCode(rawValue: ns.code) {
        switch code {
        case .wrongPassword, .invalidCredential: return "Incorrect email or password."
        case .userNotFound: return "No account found for that email."
        case .emailAlreadyInUse: return "That email is already registered."
        case .weakPassword: return "Choose a stronger password (6+ characters)."
        case .networkError: return "Network error. Try again."
        case .invalidEmail: return "Enter a valid email address."
        default: break
        }
    }
    return error.localizedDescription
}

private func randomNonceString(length: Int = 32) -> String {
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

private func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hash = SHA256.hash(data: data)
    return hash.map { String(format: "%02x", $0) }.joined()
}

final class AppleSignInCoordinator: NSObject, ObservableObject {
    var onError: ((String) -> Void)?
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthManager())
    }
}

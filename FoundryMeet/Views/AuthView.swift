import SwiftUI
import FirebaseAuth

struct AuthView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            AppColors.surface.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .padding(.bottom, 8)
                    
                    Text("FoundryMeet")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColors.onSurface)
                    
                    Text(isSignUp ? "Create an account to join the network." : "Welcome back to the network.")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(AppColors.surfaceContainerLowest)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(AppColors.surfaceContainerLowest)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: handleAuth) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.onPrimary))
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.primary)
                        .foregroundColor(AppColors.onPrimary)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                    
                    Button(action: {
                        withAnimation {
                            isSignUp.toggle()
                            errorMessage = ""
                        }
                    }) {
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
                
                Spacer()
                
                // Placeholder for Social Auth
                VStack(spacing: 16) {
                    Text("Or continue with")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "applelogo")
                                Text("Apple")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.surfaceContainerHigh)
                            .foregroundColor(AppColors.onSurface)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text("Google")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.surfaceContainerHigh)
                            .foregroundColor(AppColors.onSurface)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func handleAuth() {
        errorMessage = ""
        
#if DEBUG
        if !isSignUp, DevAccount.matches(email: email, password: password) {
            authManager.startDevSession()
            return
        }
#endif
        
        isLoading = true
        
        if isSignUp {
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthManager())
    }
}

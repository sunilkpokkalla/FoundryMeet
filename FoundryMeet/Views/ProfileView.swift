import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var repository = AppRepository.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppColors.secondary.opacity(0.15))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(repository.profile?.initials ?? "FM")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(AppColors.secondary)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(repository.profile?.displayName ?? authManager.displayName)
                                .font(.system(size: 18, weight: .semibold))
                            Text(authManager.email)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.onSurfaceVariant)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let profile = repository.profile {
                    Section("Profile") {
                        row("Role", profile.role ?? "—")
                        row("Location", profile.location?.isEmpty == false ? profile.location! : "—")
                        row("Stage", profile.stage ?? "—")
                        row("Goal", profile.goal ?? "—")
                        row("Skills", profile.skills.isEmpty ? "—" : profile.skills.joined(separator: ", "))
                    }
                }

                Section {
                    Button(role: .destructive) {
                        authManager.signOut()
                        dismiss()
                    } label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.trailing)
        }
    }
}

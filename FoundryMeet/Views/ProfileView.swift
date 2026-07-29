import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var repository = AppRepository.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var displayName = ""
    @State private var role = ""
    @State private var location = ""
    @State private var stage = ""
    @State private var goal = ""
    @State private var industry = ""
    @State private var bio = ""
    @State private var skillsText = ""
    @State private var isDiscoverable = true
    @State private var statusMessage = ""
    @State private var showMessages = false
    @State private var showAddCredential = false
    @State private var credTitle = ""
    @State private var credIssuer = ""
    @State private var credURL = ""

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

                if isEditing {
                    Section("Edit profile") {
                        TextField("Name", text: $displayName)
                        TextField("Role", text: $role)
                        TextField("Location", text: $location)
                        TextField("Stage", text: $stage)
                        TextField("Goal", text: $goal)
                        TextField("Industry", text: $industry)
                        TextField("Skills (comma-separated)", text: $skillsText)
                        TextField("Bio", text: $bio, axis: .vertical)
                            .lineLimit(3...6)
                        Toggle("Show me in Discover", isOn: $isDiscoverable)
                    }
                } else if let profile = repository.profile {
                    Section("Profile") {
                        row("Role", profile.role ?? "—")
                        row("Location", profile.location?.isEmpty == false ? profile.location! : "—")
                        row("Stage", profile.stage ?? "—")
                        row("Goal", profile.goal ?? "—")
                        row("Industry", profile.industry ?? "—")
                        row("Skills", profile.skills.isEmpty ? "—" : profile.skills.joined(separator: ", "))
                        if let bio = profile.bio, !bio.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Bio")
                                Text(bio)
                                    .foregroundColor(AppColors.onSurfaceVariant)
                            }
                        }
                    }

                    Section("Verified credentials") {
                        if profile.credentials.isEmpty {
                            Text("Add degrees or certifications to your profile.")
                                .foregroundColor(AppColors.onSurfaceVariant)
                        } else {
                            ForEach(profile.credentials) { credential in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: credential.isVerified ? "checkmark.seal.fill" : "seal")
                                        .foregroundColor(credential.isVerified ? Color(hex: 0x2F6B3A) : AppColors.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(credential.title)
                                            .font(.system(size: 15, weight: .semibold))
                                        Text(credential.issuer)
                                            .font(.system(size: 13))
                                            .foregroundColor(AppColors.onSurfaceVariant)
                                        Text(credential.isVerified ? "Verified" : "Pending review")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(credential.isVerified ? Color(hex: 0x2F6B3A) : AppColors.secondary)
                                    }
                                    Spacer()
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task { try? await repository.removeCredential(id: credential.id) }
                                    } label: {
                                        Text("Delete")
                                    }
#if DEBUG
                                    if !credential.isVerified {
                                        Button {
                                            Task { try? await repository.verifyCredential(id: credential.id) }
                                        } label: {
                                            Text("Verify")
                                        }
                                        .tint(AppColors.secondary)
                                    }
#endif
                                }
                            }
                        }
                        Button("Add credential") { showAddCredential = true }
                    }
                }

                Section {
                    Button("Messages") { showMessages = true }
                }

                if !statusMessage.isEmpty {
                    Section {
                        Text(statusMessage)
                            .foregroundColor(AppColors.secondary)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditing ? "Cancel" : "Edit") {
                        if isEditing {
                            isEditing = false
                        } else {
                            loadDraft()
                            isEditing = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") { saveProfile() }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showMessages) {
                MessagesView()
            }
            .alert("Add credential", isPresented: $showAddCredential) {
                TextField("Title", text: $credTitle)
                TextField("Issuer", text: $credIssuer)
                TextField("URL", text: $credURL)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    Task {
                        try? await repository.addCredential(
                            title: credTitle,
                            issuer: credIssuer,
                            url: credURL
                        )
                        credTitle = ""
                        credIssuer = ""
                        credURL = ""
                    }
                }
            } message: {
                Text("Links are marked pending until verified.")
            }
        }
    }

    private func loadDraft() {
        guard let profile = repository.profile else { return }
        displayName = profile.displayName
        role = profile.role ?? ""
        location = profile.location ?? ""
        stage = profile.stage ?? ""
        goal = profile.goal ?? ""
        industry = profile.industry ?? ""
        bio = profile.bio ?? ""
        skillsText = profile.skills.joined(separator: ", ")
        isDiscoverable = profile.isDiscoverable
    }

    private func saveProfile() {
        guard var profile = repository.profile else { return }
        profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.role = role.isEmpty ? nil : role
        profile.location = location
        profile.stage = stage.isEmpty ? nil : stage
        profile.goal = goal.isEmpty ? nil : goal
        profile.industry = industry.isEmpty ? nil : industry
        profile.bio = bio.isEmpty ? nil : bio
        profile.skills = skillsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        profile.isDiscoverable = isDiscoverable
        Task {
            do {
                try await repository.updateProfile(profile)
                statusMessage = "Profile saved."
                isEditing = false
            } catch {
                statusMessage = error.localizedDescription
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

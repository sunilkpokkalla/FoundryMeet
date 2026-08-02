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
            ZStack(alignment: .top) {
                AppColors.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    accountHeader

                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            profileHero

                            if isEditing {
                                editSection
                            } else if let profile = repository.profile {
                                detailsSection(profile)
                                credentialsSection(profile)
                            }

                            actionsSection

                            if !statusMessage.isEmpty {
                                Text(statusMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.secondary)
                                    .padding(.horizontal, 24)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .hideSystemNavBar()
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

    private var accountHeader: some View {
        HStack {
            Button {
                if isEditing {
                    isEditing = false
                } else {
                    loadDraft()
                    isEditing = true
                }
            } label: {
                Text(isEditing ? "Cancel" : "Edit")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.onSurface)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Account")
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.3)
                .foregroundColor(AppColors.onSurface)

            Spacer()

            Button {
                if isEditing {
                    saveProfile()
                } else {
                    dismiss()
                }
            } label: {
                Text(isEditing ? "Save" : "Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.onSurface)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(AppColors.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.hairline)
                .frame(height: 1)
        }
    }

    private var profileHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.accentSoft)
                    .frame(width: 64, height: 64)
                Text(repository.profile?.initials ?? "FM")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppColors.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(repository.profile?.displayName ?? authManager.displayName)
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundColor(AppColors.onSurface)
                Text(authManager.email)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.onSurfaceVariant)
                if let role = repository.profile?.role, !role.isEmpty {
                    Text(role)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.secondary)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var editSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Edit profile")
            VStack(spacing: 0) {
                editField("Name", text: $displayName)
                divider
                editField("Role", text: $role)
                divider
                editField("Location", text: $location)
                divider
                editField("Stage", text: $stage)
                divider
                editField("Goal", text: $goal)
                divider
                editField("Industry", text: $industry)
                divider
                editField("Skills", text: $skillsText, placeholder: "Comma-separated")
                divider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    TextField("A short intro", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.onSurface)
                }
                .padding(.vertical, 14)
                divider
                Toggle(isOn: $isDiscoverable) {
                    Text("Show me in Discover")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.onSurface)
                }
                .tint(AppColors.secondary)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 20)
            .background(AppColors.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.hairline, lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    private func detailsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Profile")
            VStack(spacing: 0) {
                detailRow("Role", profile.role ?? "—")
                divider
                detailRow("Location", profile.location?.isEmpty == false ? profile.location! : "—")
                divider
                detailRow("Stage", profile.stage ?? "—")
                divider
                detailRow("Goal", profile.goal ?? "—")
                divider
                detailRow("Industry", profile.industry ?? "—")
                divider
                detailRow("Skills", profile.skills.isEmpty ? "—" : profile.skills.joined(separator: ", "))
                if let bio = profile.bio, !bio.isEmpty {
                    divider
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bio")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.onSurfaceVariant)
                        Text(bio)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.onSurface)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 20)
            .background(AppColors.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.hairline, lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    private func credentialsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionLabel("Credentials")
                Spacer()
                Button {
                    showAddCredential = true
                } label: {
                    Text("Add")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 24)
                .padding(.bottom, 8)
            }

            VStack(spacing: 0) {
                if profile.credentials.isEmpty {
                    Text("Add degrees or certifications to your profile.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                } else {
                    ForEach(Array(profile.credentials.enumerated()), id: \.element.id) { index, credential in
                        if index > 0 { divider }
                        credentialRow(credential)
                    }
                }
            }
            .padding(.horizontal, 20)
            .background(AppColors.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.hairline, lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    private func credentialRow(_ credential: VerifiedCredential) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: credential.isVerified ? "checkmark.seal.fill" : "seal")
                .font(.system(size: 18))
                .foregroundColor(credential.isVerified ? Color(hex: 0x2F6B3A) : AppColors.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(credential.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.onSurface)
                Text(credential.issuer)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.onSurfaceVariant)
                Text(credential.isVerified ? "Verified" : "Pending review")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(credential.isVerified ? Color(hex: 0x2F6B3A) : AppColors.secondary)
            }

            Spacer(minLength: 0)

            Button {
                Task { try? await repository.removeCredential(id: credential.id) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.onSurfaceVariant.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 14)
#if DEBUG
        .contextMenu {
            if !credential.isVerified {
                Button("Mark verified") {
                    Task { try? await repository.verifyCredential(id: credential.id) }
                }
            }
        }
#endif
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button {
                showMessages = true
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 15, weight: .medium))
                    Text("Messages")
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.onSurfaceVariant.opacity(0.5))
                }
                .foregroundColor(AppColors.onSurface)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(AppColors.surfaceContainerLowest)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                authManager.signOut()
                dismiss()
            } label: {
                Text("Sign Out")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: 0xB42318))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.surfaceContainerLowest)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(AppColors.onSurfaceVariant)
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColors.hairline)
            .frame(height: 1)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AppColors.onSurface)
            Spacer(minLength: 16)
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
    }

    private func editField(_ title: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.onSurfaceVariant)
            TextField(placeholder.isEmpty ? title : placeholder, text: text)
                .font(.system(size: 16))
                .foregroundColor(AppColors.onSurface)
        }
        .padding(.vertical, 12)
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
}

import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var repository = AppRepository.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var displayName = ""
    @State private var role = ""
    @State private var place: ResolvedPlace?
    @State private var stages: Set<StartupStage> = []
    @State private var goal = ""
    @State private var industry: Industry?
    @State private var bio = ""
    @State private var skills: Set<Skill> = []
    @State private var isDiscoverable = true
    @State private var statusMessage = ""
    @State private var showMessages = false
    @State private var showAddCredential = false
    @State private var showAvailability = false
    @State private var showReviewQueue = false
    @State private var credTitle = ""
    @State private var credIssuer = ""
    @State private var credURL = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false

    private var parsedRole: FounderRole? { FounderRole(rawValue: role) }

    /// Role is still free text here, so an off-taxonomy answer falls back to the
    /// widest stage list rather than hiding options from someone.
    private var editedRole: FounderRole { parsedRole ?? .builder }

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
            .sheet(isPresented: $showAvailability) {
                AvailabilityEditorView()
                    .environmentObject(repository)
            }
            .sheet(isPresented: $showReviewQueue) {
                CredentialReviewQueueView()
                    .environmentObject(repository)
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
                        statusMessage = "Credential submitted for review."
                    }
                }
            } message: {
                Text("Links are marked pending until a reviewer verifies them.")
            }
            .onChange(of: photoItem) { item in
                guard let item else { return }
                Task { await uploadPhoto(item) }
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
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack {
                    if let urlString = repository.profile?.photoURL,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                avatarFallback
                            }
                        }
                    } else {
                        avatarFallback
                    }

                    if isUploadingPhoto {
                        Circle().fill(Color.black.opacity(0.35))
                        ProgressView().tint(.white)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(repository.profile?.displayName ?? authManager.displayName)
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundColor(AppColors.onSurface)
                Text(authManager.email)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.onSurfaceVariant)
                Text("Tap photo to update")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.secondary)
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

    private var avatarFallback: some View {
        ZStack {
            Circle().fill(AppColors.accentSoft)
            Text(repository.profile?.initials ?? "FM")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.secondary)
        }
    }

    private var editSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Edit profile")
            VStack(spacing: 0) {
                editField("Name", text: $displayName)
                divider
                editField("Role", text: $role)
                divider
                VStack(alignment: .leading, spacing: 6) {
                    Text("Location")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    LocationField(place: $place)
                }
                .padding(.vertical, 12)
                divider
                VStack(alignment: .leading, spacing: 8) {
                    Text(parsedRole?.stageLabel ?? "Stage")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    ChipGrid(
                        items: editedRole.stages,
                        title: { $0.title },
                        isSelected: { stages.contains($0) },
                        onTap: { stages = editedRole.toggling($0, in: stages) }
                    )
                }
                .padding(.vertical, 12)
                divider
                editField("Goal", text: $goal)
                divider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Industry")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    ChipGrid(
                        items: Industry.allCases,
                        title: { $0.title },
                        isSelected: { industry == $0 },
                        onTap: { industry = industry == $0 ? nil : $0 }
                    )
                }
                .padding(.vertical, 12)
                divider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Skills")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.onSurfaceVariant)
                        Spacer()
                        Text("\(skills.count) of \(Skill.selectionLimit)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.onSurfaceVariant.opacity(0.7))
                    }
                    ChipGrid(
                        items: editedRole.skills,
                        title: { $0.title },
                        icon: { $0.icon },
                        isSelected: { skills.contains($0) },
                        isDisabled: { skills.count >= Skill.selectionLimit && !skills.contains($0) },
                        onTap: { skills = Skill.toggling($0, in: skills) },
                        minWidth: 132
                    )
                }
                .padding(.vertical, 12)
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
                detailRow("Stage", profile.stageSummary)
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
            Image(systemName: credential.isVerified ? "checkmark.seal.fill" : (credential.isRejected ? "xmark.seal.fill" : "seal"))
                .font(.system(size: 18))
                .foregroundColor(
                    credential.isVerified ? Color(hex: 0x2F6B3A)
                        : (credential.isRejected ? Color(hex: 0xB42318) : AppColors.secondary)
                )
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(credential.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.onSurface)
                Text(credential.issuer)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.onSurfaceVariant)
                Text(credential.isVerified ? "Verified" : (credential.isRejected ? "Rejected" : "Pending review"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(
                        credential.isVerified ? Color(hex: 0x2F6B3A)
                            : (credential.isRejected ? Color(hex: 0xB42318) : AppColors.secondary)
                    )
                if let reason = credential.rejectionReason, credential.isRejected {
                    Text(reason)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.onSurfaceVariant)
                }
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
                Button("Mark verified (debug)") {
                    Task { try? await repository.verifyCredential(id: credential.id) }
                }
            }
        }
#endif
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            actionRow(title: "Availability", icon: "calendar") {
                showAvailability = true
            }
            actionRow(title: "Messages", icon: "bubble.left.and.bubble.right") {
                showMessages = true
            }

            if repository.profile?.isReviewer == true {
                actionRow(title: "Credential review queue", icon: "checkmark.seal") {
                    showReviewQueue = true
                }
            }

#if DEBUG
            actionRow(title: "Enable reviewer (debug)", icon: "person.badge.shield.checkmark") {
                Task {
                    guard var profile = repository.profile else { return }
                    profile.isReviewer = true
                    try? await repository.updateProfile(profile)
                    statusMessage = "Reviewer mode enabled."
                }
            }
#endif

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

    private func actionRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                Text(title)
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

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = PhotoStorageService.jpegData(from: image)
            else {
                statusMessage = "Could not read that photo."
                return
            }
            try await repository.uploadProfilePhoto(jpeg)
            statusMessage = "Profile photo updated."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func loadDraft() {
        guard let profile = repository.profile else { return }
        displayName = profile.displayName
        role = profile.role ?? ""
        place = profile.place
        stages = Set(profile.stages.compactMap(StartupStage.init(rawValue:)))
        goal = profile.goal ?? ""
        industry = profile.industry.flatMap(Industry.init(rawValue:))
        bio = profile.bio ?? ""
        skills = Set(profile.skills.compactMap(Skill.parse))
        isDiscoverable = profile.isDiscoverable
    }

    private func saveProfile() {
        guard var profile = repository.profile else { return }
        profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.role = role.isEmpty ? nil : role
        profile.location = place?.displayName
        profile.latitude = place?.latitude
        profile.longitude = place?.longitude
        profile.stages = editedRole.stages.filter(stages.contains).map(\.rawValue)
        profile.goal = goal.isEmpty ? nil : goal
        profile.industry = industry?.rawValue
        profile.bio = bio.isEmpty ? nil : bio
        profile.skills = editedRole.skills.filter(skills.contains).map(\.rawValue)
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

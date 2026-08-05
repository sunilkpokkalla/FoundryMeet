import SwiftUI
import PhotosUI
import UIKit

@MainActor
struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var repository = AppRepository.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var displayName = ""
    @State private var role = ""
    @State private var place: ResolvedPlace?
    @State private var stages: Set<StartupStage> = []
    @State private var goal: NetworkingGoal?
    @State private var industry: Industry?
    @State private var lookingFor = ""
    @State private var canHelpWith = ""
    @State private var bio = ""
    @State private var buildingIdea = ""
    @State private var linkedInURL = ""
    @State private var skills: Set<Skill> = []
    /// Stored values with no chip to represent them. Carried through a save so
    /// editing an unrelated field cannot quietly delete them.
    @State private var unrecognizedSkills: [String] = []
    @State private var unrecognizedStages: [String] = []
    @State private var isDiscoverable = true
    @State private var statusMessage = ""
    @State private var showAddCredential = false
    @State private var showAvailability = false
    @State private var showReviewQueue = false
    @State private var legalDocument: LegalDocument?
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
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
            .sheet(isPresented: $showAvailability) {
                AvailabilityEditorView()
                    .environmentObject(repository)
            }
            .sheet(isPresented: $showReviewQueue) {
                CredentialReviewQueueView()
                    .environmentObject(repository)
            }
            .sheet(item: $legalDocument) { document in
                LegalDocumentView(document: document)
            }
            .sheet(isPresented: $showDeleteConfirm) {
                AppConfirmSheet(
                    title: "Delete account?",
                    message: "This permanently removes your FoundryMeet account and profile data. Your Apple or Google account stays intact. You may need to sign in again first if they ask for a recent login.",
                    cancelTitle: "Keep account",
                    confirmTitle: "Delete account",
                    isDestructive: true,
                    onCancel: {},
                    onConfirm: {
                        Task { await deleteAccount() }
                    }
                )
            }
            .sheet(isPresented: $showAddCredential) {
                AppFormSheet(
                    title: "Add credential",
                    message: "Links stay pending until a reviewer verifies them.",
                    fields: [
                        AppFormField(label: "Title", placeholder: "e.g. B.S. Computer Science", text: $credTitle),
                        AppFormField(label: "Issuer", placeholder: "e.g. Stanford", text: $credIssuer),
                        AppFormField(
                            label: "URL",
                            placeholder: "https://…",
                            text: $credURL,
                            keyboard: .URL,
                            autocapitalize: false
                        )
                    ],
                    cancelTitle: "Cancel",
                    confirmTitle: "Submit",
                    onCancel: {
                        credTitle = ""
                        credIssuer = ""
                        credURL = ""
                    },
                    onConfirm: {
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
                )
            }
            .onChange(of: photoItem) { item in
                guard let item else { return }
                Task { await uploadPhoto(item) }
            }
        }
    }

    private var accountHeader: some View {
        HStack(spacing: 12) {
            Button {
                if isEditing {
                    isEditing = false
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: isEditing ? "xmark" : "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.onSurface)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppColors.surfaceContainerLowest))
                    .overlay(Circle().stroke(AppColors.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isEditing ? "Cancel editing" : "Close account")

            Text(isEditing ? "Edit profile" : "Account")
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.3)
                .foregroundColor(AppColors.onSurface)

            Spacer()

            if isEditing {
                Button("Save") {
                    saveProfile()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.onPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppColors.primary)
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
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
                    ProfileAvatarView(
                        photoURL: repository.profile?.photoURL,
                        initials: repository.profile?.initials ?? "",
                        size: 72
                    )

                    if isUploadingPhoto {
                        Circle().fill(Color.black.opacity(0.35))
                        ProgressView().tint(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
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
                }
                if !isEditing {
                    Button {
                        loadDraft()
                        isEditing = true
                    } label: {
                        Text("Edit profile")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppColors.accentSoft.opacity(0.65))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                } else {
                    Text("Tap photo to update")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.secondary)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Role")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    ChipGrid(
                        items: FounderRole.allCases,
                        title: { $0.title },
                        icon: { $0.icon },
                        isSelected: { parsedRole == $0 },
                        onTap: { selectRole($0) },
                        minWidth: 140
                    )
                }
                .padding(.vertical, 12)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    ChipGrid(
                        items: editedRole.goals,
                        title: { $0.title },
                        icon: { $0.icon },
                        isSelected: { goal == $0 },
                        onTap: { goal = goal == $0 ? nil : $0 },
                        minWidth: 150
                    )
                }
                .padding(.vertical, 12)
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
                    Text("Looking for")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    TextField("e.g. Early eng hires, design partners, a technical co-founder", text: $lookingFor, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.onSurface)
                }
                .padding(.vertical, 14)
                divider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Can help with")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    TextField("e.g. GTM for B2B SaaS, fundraising intros, product reviews", text: $canHelpWith, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.onSurface)
                }
                .padding(.vertical, 14)
                divider
                VStack(alignment: .leading, spacing: 8) {
                    Text("What I'm building")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    TextField("One line on your product or idea", text: $buildingIdea, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.onSurface)
                }
                .padding(.vertical, 14)
                divider
                editField("LinkedIn", text: $linkedInURL, placeholder: "https://linkedin.com/in/…")
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
                detailRow("Looking for", profile.lookingFor?.isEmpty == false ? profile.lookingFor! : "—")
                divider
                detailRow("Can help with", profile.canHelpWith?.isEmpty == false ? profile.canHelpWith! : "—")
                divider
                detailRow("Industry", profile.industry ?? "—")
                divider
                detailRow("Skills", profile.skills.isEmpty ? "—" : profile.skills.joined(separator: ", "))
                if let idea = profile.buildingIdea, !idea.isEmpty {
                    divider
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Building")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.onSurfaceVariant)
                        Text(idea)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.onSurface)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
                }
                if let linkedIn = profile.linkedInURL, !linkedIn.isEmpty,
                   let url = URL(string: linkedIn) ?? URL(string: "https://\(linkedIn)") {
                    divider
                    Link(destination: url) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("LinkedIn")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.onSurfaceVariant)
                            Spacer(minLength: 12)
                            HStack(spacing: 4) {
                                Text("View profile")
                                    .font(.system(size: 15, weight: .semibold))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(AppColors.primary)
                        }
                        .padding(.vertical, 14)
                    }
                    .accessibilityLabel("Open LinkedIn profile")
                }
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

            if repository.profile?.isReviewer == true {
                actionRow(title: "Credential review queue", icon: "checkmark.seal") {
                    showReviewQueue = true
                }
            }

            Button {
                authManager.signOut()
                dismiss()
            } label: {
                Text("Sign Out")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.onSurface)
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

            Button {
                showDeleteConfirm = true
            } label: {
                HStack {
                    if isDeletingAccount {
                        ProgressView()
                    } else {
                        Text("Delete Account")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundColor(Color(hex: 0xB42318))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.surfaceContainerLowest)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: 0xB42318).opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeletingAccount)

            // Quiet footer — App Review needs these reachable; History is the wrong home.
            VStack(spacing: 10) {
                Text("Legal & support")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.onSurfaceVariant.opacity(0.8))

                HStack(spacing: 14) {
                    Button("Privacy") { legalDocument = .privacy }
                    Text("·").foregroundColor(AppColors.onSurfaceVariant.opacity(0.5))
                    Button("Terms") { legalDocument = .terms }
                    Text("·").foregroundColor(AppColors.onSurfaceVariant.opacity(0.5))
                    Button("Support") { legalDocument = .support }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 4)
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

    private static func normalizedLinkedInURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }
        if trimmed.lowercased().contains("linkedin.com") {
            return "https://\(trimmed)"
        }
        return "https://www.linkedin.com/in/\(trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
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
        stages = Set(profile.stages.compactMap(StartupStage.parse))
        unrecognizedStages = profile.stages.filter { StartupStage.parse($0) == nil }
        goal = profile.goal.flatMap(NetworkingGoal.init(rawValue:))
        industry = profile.industry.flatMap(Industry.init(rawValue:))
        lookingFor = profile.lookingFor ?? ""
        canHelpWith = profile.canHelpWith ?? ""
        bio = profile.bio ?? ""
        buildingIdea = profile.buildingIdea ?? ""
        linkedInURL = profile.linkedInURL ?? ""
        skills = Set(profile.skills.compactMap(Skill.parse))
        unrecognizedSkills = profile.skills.filter { Skill.parse($0) == nil }
        isDiscoverable = profile.isDiscoverable
    }

    /// Changing role here drops the answers that no longer exist for it, the
    /// same way onboarding does.
    private func selectRole(_ next: FounderRole) {
        role = next.rawValue
        stages = next.retainingValidStages(from: stages)
        skills = next.retainingValidSkills(from: skills)
        if let current = goal, !next.goals.contains(current) {
            goal = nil
        }
    }

    private func saveProfile() {
        guard var profile = repository.profile else { return }
        profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.role = role.isEmpty ? nil : role
        profile.location = place?.displayName
        if LocationParts.isRemote(place?.displayName) || place == nil {
            profile.latitude = nil
            profile.longitude = nil
        } else {
            profile.latitude = place?.latitude
            profile.longitude = place?.longitude
        }
        // Save what was actually picked, not what the current role offers: an
        // off-taxonomy role falls back to Builder and would strip valid answers.
        profile.stages = StartupStage.allCases.filter(stages.contains).map(\.rawValue) + unrecognizedStages
        profile.goal = goal?.rawValue
        profile.industry = industry?.rawValue
        let looking = lookingFor.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.lookingFor = looking.isEmpty ? nil : looking
        let help = canHelpWith.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.canHelpWith = help.isEmpty ? nil : help
        profile.bio = bio.isEmpty ? nil : bio
        let idea = buildingIdea.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.buildingIdea = idea.isEmpty ? nil : idea
        let linkedIn = Self.normalizedLinkedInURL(linkedInURL)
        profile.linkedInURL = linkedIn
        profile.skills = Skill.allCases.filter(skills.contains).map(\.rawValue) + unrecognizedSkills
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

    private func deleteAccount() async {
        isDeletingAccount = true
        statusMessage = ""
        defer { isDeletingAccount = false }
        do {
            try await authManager.deleteAccount()
            dismiss()
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

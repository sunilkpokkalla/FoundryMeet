import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject private var repository: AppRepository
    @State private var showProfile = false
    @State private var showAvailability = false
    @State private var showInviteShare = false
    @State private var errorMessage = ""
    @State private var statusMessage = ""
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppColors.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    AppHeader(
                        showProfile: $showProfile,
                        profileInitials: repository.profile?.initials ?? "",
                        profilePhotoURL: repository.profile?.photoURL
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Curated for you")
                                    .font(.system(size: 28, weight: .semibold))
                                    .tracking(-0.6)
                                    .foregroundColor(AppColors.onSurface)
                                Text(homeSubtitle)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(AppColors.onSurfaceVariant)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 12)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if let goal = myGoal {
                                        FilterChip(
                                            text: "Can help me \(goal.title.lowercased())",
                                            icon: "target",
                                            isSelected: repository.filters.complementaryGoalsOnly
                                        ) {
                                            var next = repository.filters
                                            next.complementaryGoalsOnly.toggle()
                                            repository.setFilters(next)
                                        }
                                    }
                                    if myLocation != nil || hasCoordinates {
                                        FilterChip(
                                            text: "Nearby",
                                            icon: "mappin.and.ellipse",
                                            isSelected: repository.filters.nearbyOnly
                                        ) {
                                            var next = repository.filters
                                            next.nearbyOnly.toggle()
                                            repository.setFilters(next)
                                        }
                                    }
                                    if let stage = myStage {
                                        FilterChip(
                                            text: "Stage: \(stage)",
                                            icon: "slider.horizontal.3",
                                            isSelected: repository.filters.stage == stage
                                        ) {
                                            toggleFilter(stage: stage)
                                        }
                                    }
                                    if let industry = myIndustry {
                                        FilterChip(
                                            text: "Industry: \(industry)",
                                            isSelected: repository.filters.industry == industry
                                        ) {
                                            toggleFilter(industry: industry)
                                        }
                                    }
                                    if !repository.filters.isDefault {
                                        FilterChip(text: "Reset", isSelected: false) {
                                            repository.setFilters(.default)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }

                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 24)
                            }

                            if !statusMessage.isEmpty {
                                Text(statusMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.secondary)
                                    .padding(.horizontal, 24)
                            }

                            if !earlyMemberSteps.isEmpty {
                                earlyMemberChecklist
                                    .padding(.horizontal, 20)
                            }

                            if repository.discoveryFeed.isEmpty {
                                emptyNetworkState
                            } else {
                                VStack(spacing: 20) {
                                    ForEach(repository.discoveryFeed) { profile in
                                        DiscoveryProfileCard(
                                            profile: profile,
                                            isDisabled: isWorking,
                                            onDismiss: { handleDismiss(profile) },
                                            onConnect: { handleRequest(profile) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 4)
                                .padding(.bottom, 40)
                            }
                        }
                    }
                }
            }
            .hideSystemNavBar()
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showAvailability) {
                AvailabilityEditorView()
                    .environmentObject(repository)
            }
            .background {
                ActivitySharePresenter(isPresented: $showInviteShare, items: [inviteMessage])
            }
            .task {
                try? await repository.refreshAll()
            }
        }
    }

    private enum EarlyMemberStep: String, Identifiable {
        case photo
        case linkedIn
        case building
        case availability
        case invite

        var id: String { rawValue }

        var title: String {
            switch self {
            case .photo: return "Add a profile photo"
            case .linkedIn: return "Add LinkedIn"
            case .building: return "Say what you’re building"
            case .availability: return "Confirm coffee-chat hours"
            case .invite: return "Invite someone in your city"
            }
        }

        var icon: String {
            switch self {
            case .photo: return "camera"
            case .linkedIn: return "link"
            case .building: return "lightbulb"
            case .availability: return "calendar"
            case .invite: return "square.and.arrow.up"
            }
        }
    }

    private var earlyMemberSteps: [EarlyMemberStep] {
        guard let profile = repository.profile else { return [] }
        var steps: [EarlyMemberStep] = []
        if profile.photoURL == nil || profile.photoURL?.isEmpty == true {
            steps.append(.photo)
        }
        if profile.linkedInURL == nil || profile.linkedInURL?.isEmpty == true {
            steps.append(.linkedIn)
        }
        if profile.buildingIdea == nil || profile.buildingIdea?.isEmpty == true {
            steps.append(.building)
        }
        if profile.availability == AvailabilityWindow.defaultWorkWeek {
            steps.append(.availability)
        }
        if repository.networkProfiles.count < 3 {
            steps.append(.invite)
        }
        return steps
    }

    private var earlyMemberChecklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Early member checklist")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.onSurface)

            Text("A complete profile helps reviewers and new members see a real network, not an empty shell.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(earlyMemberSteps) { step in
                Button {
                    handleEarlyMemberStep(step)
                } label: {
                    earlyMemberRow(step)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppColors.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.hairline, lineWidth: 1)
        )
    }

    private func earlyMemberRow(_ step: EarlyMemberStep) -> some View {
        HStack(spacing: 12) {
            Image(systemName: step.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.secondary)
                .frame(width: 22)
            Text(step.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.onSurface)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.onSurfaceVariant)
        }
        .padding(.vertical, 10)
    }

    private func handleEarlyMemberStep(_ step: EarlyMemberStep) {
        switch step {
        case .photo, .linkedIn, .building:
            showProfile = true
        case .availability:
            showAvailability = true
        case .invite:
            showInviteShare = true
        }
    }

    private func handleDismiss(_ profile: DiscoveryCandidate) {
        isWorking = true
        errorMessage = ""
        Task {
            do {
                try await repository.dismissCandidate(profile)
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func handleRequest(_ profile: DiscoveryCandidate) {
        isWorking = true
        errorMessage = ""
        statusMessage = ""
        Task {
            do {
                try await repository.requestMatch(with: profile)
                statusMessage = "Request sent to \(profile.name)."
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    /// Filters describe you, not an arbitrary segment, so they are built from
    /// your own profile rather than hardcoded here.
    private var myGoal: NetworkingGoal? {
        repository.profile?.goal.flatMap(NetworkingGoal.init(rawValue:))
    }

    private var myStage: String? {
        repository.profile?.stages.first
    }

    private var myIndustry: String? {
        repository.profile?.industry
    }

    private var myLocation: String? {
        repository.profile?.location
    }

    private var hasCoordinates: Bool {
        repository.profile?.latitude != nil && repository.profile?.longitude != nil
    }

    private var homeSubtitle: String {
        if let goal = myGoal {
            return "People who can help you \(goal.title.lowercased()), closer ones first."
        }
        return "High-signal coffee chats with people building nearby."
    }

    private var inviteMessage: String {
        if let city = myLocation, !city.isEmpty, city.lowercased() != "remote" {
            return "I'm on FoundryMeet — high-signal coffee chats for founders and builders in \(city). Join me and grow the local network."
        }
        return "I'm on FoundryMeet — high-signal coffee chats for founders, builders, and investors. Join me."
    }

    private var emptyNetworkState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 56)

            ZStack {
                Circle()
                    .fill(AppColors.accentSoft.opacity(0.55))
                    .frame(width: 72, height: 72)
                Image(systemName: repository.filters.nearbyOnly ? "mappin.and.ellipse" : "person.2")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(AppColors.secondary)
            }

            Text(emptyTitle)
                .font(.system(size: 20, weight: .semibold))
                .tracking(-0.3)
                .foregroundColor(AppColors.onSurface)

            Text(emptyBody)
                .font(.system(size: 15))
                .foregroundColor(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showInviteShare = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(inviteButtonTitle)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(AppColors.onPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(AppColors.primary)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            if !repository.filters.isDefault {
                Button("Reset filters") {
                    repository.setFilters(.default)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
    }

    private var emptyTitle: String {
        if repository.filters.nearbyOnly {
            return myLocation.map { "No one in \($0) yet" } ?? "No one nearby yet"
        }
        if repository.networkProfiles.isEmpty {
            return "Your city is still quiet"
        }
        return "You're all caught up"
    }

    private var emptyBody: String {
        if repository.filters.nearbyOnly || repository.networkProfiles.isEmpty {
            return "Invite founders you already trust. Density is what makes coffee chats possible."
        }
        return "Widen filters or invite someone — new matches show up as the network grows."
    }

    private var inviteButtonTitle: String {
        if let city = myLocation, !city.isEmpty, city.lowercased() != "remote" {
            return "Invite founders in \(city)"
        }
        return "Invite founders"
    }

    private func toggleFilter(stage: String? = nil, industry: String? = nil) {
        var next = repository.filters
        if let stage {
            next.stage = next.stage == stage ? nil : stage
        }
        if let industry {
            next.industry = next.industry == industry ? nil : industry
        }
        repository.setFilters(next)
    }
}

struct FilterChip: View {
    var text: String
    var icon: String? = nil
    var isSelected: Bool
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(text)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? AppColors.accentSoft : AppColors.surfaceContainerLowest)
            .foregroundColor(isSelected ? AppColors.secondary : AppColors.onSurfaceVariant)
            .overlay(
                Capsule()
                    .stroke(isSelected ? AppColors.secondary.opacity(0.18) : AppColors.hairline, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct DiscoveryProfileCard: View {
    var profile: DiscoveryCandidate
    var isDisabled: Bool = false
    var onDismiss: () -> Void
    var onConnect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let url = URL(string: profile.imgUrl), !profile.imgUrl.isEmpty {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                    } else {
                        profile.accentColor.opacity(0.2)
                            .overlay(
                                Text(profile.initials)
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(profile.accentColor)
                            )
                    }
                }
                .frame(height: 192)
                .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.7), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 120)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if profile.isSeed {
                            Text("SAMPLE")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.6)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Text(profile.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text(profile.role)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                        if let location = profile.location, !location.isEmpty {
                            Label(location, systemImage: "mappin")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    Spacer()
                    if let urlString = profile.linkedInURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Image(systemName: "link")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.28))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Open LinkedIn")
                    }
                }
                .padding(24)
            }

            VStack(alignment: .leading, spacing: 20) {
                if !profile.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TOP EXPERTISE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.onSurfaceVariant)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(profile.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppColors.surfaceContainer)
                                        .foregroundColor(AppColors.onSurfaceVariant)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.buildingIdea == nil ? "LOOKING FOR" : "BUILDING")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: 0x5a4309))

                    Text(profile.desc)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.onSurface)

                    if let goal = profile.goal, profile.buildingIdea != nil {
                        Text("Looking for: \(goal)")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.onSurfaceVariant)
                    }
                }
                .padding(16)
                .background(AppColors.surfaceContainerLow)
                .cornerRadius(12)

                HStack(spacing: 12) {
                    Button(action: onConnect) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("Request Coffee Chat")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.primary)
                        .cornerRadius(12)
                    }
                    .disabled(isDisabled)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.onSurface)
                            .frame(width: 56, height: 56)
                            .background(AppColors.surfaceContainerHighest)
                            .cornerRadius(12)
                    }
                    .disabled(isDisabled)
                }
            }
            .padding(24)
            .background(AppColors.surfaceContainerLowest)
        }
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 4)
    }
}

struct DiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoveryView()
            .environmentObject(AppRepository.shared)
    }
}

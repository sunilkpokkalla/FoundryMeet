import SwiftUI

struct NetworkingHubView: View {
    @EnvironmentObject private var repository: AppRepository
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedBuilder: DiscoveryCandidate? = nil
    @State private var statusMessage = ""
    @State private var showProfile = false
    @State private var activeThread: MessageThread? = nil
    /// Holds a thread while the profile sheet dismisses — avoids SwiftUI double-sheet races.
    @State private var pendingThread: MessageThread? = nil
    @State private var locationFilter = HubLocationFilter.default
    @State private var showCountryPicker = false
    @State private var showCityPicker = false
    @StateObject private var currentLocation = CurrentLocationService()

    private var allBuilders: [DiscoveryCandidate] {
        let myId = authManager.userId ?? repository.profile?.id
        let live = repository.networkProfiles
            .filter { $0.id != myId }
            .map(DiscoveryCandidate.init(profile:))
        if live.isEmpty && repository.usesLocalStore {
            return SeedCatalog.candidates.filter { $0.id != myId }
        }
        return live
    }

    private var placeOptions: HubPlaceOptions {
        HubPlaceOptions.from(builders: allBuilders)
    }

    private var builders: [DiscoveryCandidate] {
        allBuilders.filtered(
            by: locationFilter,
            myLocation: repository.profile?.location,
            myLatitude: repository.profile?.latitude,
            myLongitude: repository.profile?.longitude
        )
    }

    /// Near me needs coordinates for distance matching; a typed city alone is not enough.
    private var hasNearMeCoordinates: Bool {
        repository.profile?.latitude != nil && repository.profile?.longitude != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    AppHeader(
                        showProfile: $showProfile,
                        profileInitials: repository.profile?.initials ?? "",
                        profilePhotoURL: repository.profile?.photoURL
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Foundry Hub")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(AppColors.onSurface)
                                Text("Browse builders across the network.")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.onSurfaceVariant)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                            locationFilterBar
                                .padding(.top, 2)

                            if !statusMessage.isEmpty {
                                Text(statusMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.secondary)
                                    .padding(.horizontal, 20)
                            }

                            if allBuilders.isEmpty {
                                emptyNetworkState
                            } else if builders.isEmpty {
                                emptyFilterState
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                    ForEach(builders) { builder in
                                        Button {
                                            selectedBuilder = builder
                                        } label: {
                                            HubBuilderCard(builder: builder)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
            }
            .hideSystemNavBar()
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(authManager)
            }
            .task {
                applyFilter(initialFilter())
                try? await repository.refreshAll()
            }
            .refreshable {
                try? await repository.refreshAll()
            }
            .sheet(item: $selectedBuilder, onDismiss: {
                guard let thread = pendingThread else { return }
                pendingThread = nil
                // Present after the detail sheet finishes dismissing.
                DispatchQueue.main.async {
                    activeThread = thread
                }
            }) { builder in
                BuilderDetailView(builder: builder) { action in
                    do {
                        switch action {
                        case .connect:
                            try await repository.requestMatch(with: builder)
                            statusMessage = "Request sent to \(builder.name). You can pick a time once they accept."
                            selectedBuilder = nil
                        case .message:
                            let thread = try await repository.openOrCreateThread(with: builder)
                            pendingThread = thread
                            selectedBuilder = nil
                        }
                    } catch {
                        statusMessage = error.localizedDescription
                    }
                }
                .environmentObject(authManager)
                .environmentObject(repository)
            }
            .sheet(item: $activeThread) { thread in
                NavigationStack {
                    ConversationView(thread: thread)
                }
                .environmentObject(authManager)
            }
            .sheet(isPresented: $showCountryPicker) {
                HubPlacePickerSheet(
                    title: "Select country",
                    subtitle: "Only countries with builders in the Hub.",
                    options: placeOptions.countries.map { HubPlacePickerOption(id: $0, title: $0) },
                    selectedId: locationFilter.country
                ) { country in
                    applyFilter(HubLocationFilter(scope: .country, country: country, city: nil))
                }
            }
            .sheet(isPresented: $showCityPicker) {
                HubPlacePickerSheet(
                    title: "Select city",
                    subtitle: "Only cities with builders in the Hub.",
                    options: placeOptions.cities.map {
                        HubPlacePickerOption(
                            id: $0.label,
                            title: $0.label,
                            subtitle: $0.country
                        )
                    },
                    selectedId: locationFilter.city
                ) { city in
                    let country = placeOptions.cities.first(where: { $0.label == city })?.country
                    applyFilter(HubLocationFilter(scope: .city, country: country, city: city))
                }
            }
        }
    }

    private var locationFilterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        text: currentLocation.isLocating
                            ? "Locating…"
                            : HubLocationScope.nearMe.title,
                        icon: HubLocationScope.nearMe.icon,
                        isSelected: locationFilter.scope == .nearMe
                    ) {
                        Task { await selectNearMe() }
                    }

                    FilterChip(
                        text: locationFilter.scope == .city
                            ? (locationFilter.city ?? HubLocationScope.city.title)
                            : HubLocationScope.city.title,
                        icon: HubLocationScope.city.icon,
                        isSelected: locationFilter.scope == .city
                    ) {
                        if placeOptions.cities.isEmpty {
                            statusMessage = "No cities in the Hub yet. Try All or Remote."
                        } else {
                            showCityPicker = true
                        }
                    }

                    FilterChip(
                        text: locationFilter.scope == .country
                            ? (locationFilter.country ?? HubLocationScope.country.title)
                            : HubLocationScope.country.title,
                        icon: HubLocationScope.country.icon,
                        isSelected: locationFilter.scope == .country
                    ) {
                        if placeOptions.countries.isEmpty {
                            statusMessage = "No countries in the Hub yet. Try All or Remote."
                        } else {
                            showCountryPicker = true
                        }
                    }

                    FilterChip(
                        text: HubLocationScope.remote.title,
                        icon: HubLocationScope.remote.icon,
                        isSelected: locationFilter.scope == .remote
                    ) {
                        applyFilter(HubLocationFilter(scope: .remote))
                    }

                    FilterChip(
                        text: HubLocationScope.all.title,
                        icon: HubLocationScope.all.icon,
                        isSelected: locationFilter.scope == .all
                    ) {
                        applyFilter(HubLocationFilter(scope: .all))
                    }
                }
                .padding(.horizontal, 20)
            }

            if let label = locationFilter.selectionLabel {
                Text("Showing builders in \(label)")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.onSurfaceVariant)
                    .padding(.horizontal, 20)
            } else if locationFilter.scope == .nearMe {
                Text("Within coffee-chat distance of you")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.onSurfaceVariant)
                    .padding(.horizontal, 20)
            }
        }
    }

    private var emptyNetworkState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Image(systemName: "globe")
                .font(.system(size: 36))
                .foregroundColor(AppColors.secondary)
            Text("No builders yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.onSurface)
            Text("As founders join and turn on discovery, they'll show up here.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
    }

    private var emptyFilterState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 48)
            Image(systemName: "mappin.slash")
                .font(.system(size: 34))
                .foregroundColor(AppColors.secondary)
            Text(emptyFilterTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.onSurface)
                .multilineTextAlignment(.center)
            Text(emptyFilterSubtitle)
                .font(.system(size: 15))
                .foregroundColor(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            HStack(spacing: 10) {
                if locationFilter.scope == .city, let country = locationFilter.country {
                    Button("Widen to \(country)") {
                        applyFilter(HubLocationFilter(scope: .country, country: country, city: nil))
                    }
                    .buttonStyle(HubSecondaryButtonStyle())
                }
                Button("Show all") {
                    applyFilter(HubLocationFilter(scope: .all))
                }
                .buttonStyle(HubPrimaryButtonStyle())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
    }

    private var emptyFilterTitle: String {
        switch locationFilter.scope {
        case .nearMe:
            if let city = repository.profile?.location, !city.isEmpty {
                return "No one in \(city) yet"
            }
            return "No one nearby yet"
        case .city:
            return "No one in \(locationFilter.city ?? "this city") yet"
        case .country:
            return "No one in \(locationFilter.country ?? "this country") yet"
        case .remote:
            return "No remote builders yet"
        case .all:
            return "No builders yet"
        }
    }

    private var emptyFilterSubtitle: String {
        switch locationFilter.scope {
        case .nearMe:
            return "Widen to your country, try Remote, or browse All."
        case .city:
            if let country = locationFilter.country {
                return "Widen to \(country), try Remote, or browse All."
            }
            return "Widen to a country, try Remote, or browse All."
        case .country:
            return "Try Remote, another country, or browse All."
        case .remote:
            return "Browse All to see in-person builders too."
        case .all:
            return "As founders join and turn on discovery, they'll show up here."
        }
    }

    private func initialFilter() -> HubLocationFilter {
        let saved = HubLocationFilterStore.load(userId: authManager.userId)
        // Near me is opt-in — defaulting to it made early networks look empty.
        if saved.scope == .nearMe && !hasNearMeCoordinates {
            return .default
        }
        return saved
    }

    private func applyFilter(_ filter: HubLocationFilter) {
        locationFilter = filter
        HubLocationFilterStore.save(filter, userId: authManager.userId)
        statusMessage = ""
    }

    /// Uses saved GPS coordinates when present; otherwise asks native location once
    /// and saves the reverse-geocoded city so Near me can work.
    private func selectNearMe() async {
        if hasNearMeCoordinates {
            applyFilter(HubLocationFilter(scope: .nearMe))
            return
        }
        do {
            let place = try await currentLocation.fetchCurrentPlace()
            guard var profile = repository.profile else {
                statusMessage = "Sign in to use Near me."
                return
            }
            profile.location = place.displayName
            profile.latitude = place.latitude
            profile.longitude = place.longitude
            try await repository.updateProfile(profile)
            applyFilter(HubLocationFilter(scope: .nearMe))
            statusMessage = "Using \(place.displayName) for Near me."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private struct HubPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(AppColors.onPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppColors.primary.opacity(configuration.isPressed ? 0.85 : 1))
            .cornerRadius(10)
    }
}

private struct HubSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(AppColors.onSurface)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppColors.surfaceContainerHigh.opacity(configuration.isPressed ? 0.85 : 1))
            .cornerRadius(10)
    }
}

struct HubPlacePickerOption: Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String? = nil
}

struct HubPlacePickerSheet: View {
    var title: String
    var subtitle: String
    var options: [HubPlacePickerOption]
    var selectedId: String?
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(options) { option in
                        Button {
                            onSelect(option.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(AppColors.onSurface)
                                    if let subtitle = option.subtitle, !subtitle.isEmpty {
                                        Text(subtitle)
                                            .font(.system(size: 13))
                                            .foregroundColor(AppColors.onSurfaceVariant)
                                    }
                                }
                                Spacer()
                                if option.id == selectedId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.primary)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                        }
                    }
                } footer: {
                    Text(subtitle)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Compact browse card: photo, identity, location, and what they want from a chat.
private struct HubBuilderCard: View {
    var builder: DiscoveryCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileAvatarView(
                photoURL: builder.imgUrl.isEmpty ? nil : builder.imgUrl,
                initials: builder.initials,
                size: 72,
                fallbackFill: builder.accentColor.opacity(0.15),
                fallbackForeground: builder.accentColor
            )
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(builder.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.onSurface)
                    .lineLimit(1)

                Text(builder.role)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(1)

                if let location = builder.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.onSurfaceVariant)
                        .lineLimit(1)
                        .labelStyle(.titleAndIcon)
                }

                if let goal = builder.goal, !goal.isEmpty {
                    Text("Looking for: \(goal)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 196, alignment: .top)
        .background(AppColors.surfaceContainerLowest)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

enum BuilderAction {
    case connect
    case message
}

struct BuilderDetailView: View {
    var builder: DiscoveryCandidate
    var onAction: (BuilderAction) async -> Void
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var repository: AppRepository
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false

    private var isSelf: Bool {
        guard let myId = authManager.userId else { return false }
        return builder.id == myId
    }

    private var canMessage: Bool {
        repository.hasAcceptedMatch(with: builder.id)
    }

    private var matchStatus: MatchRequest.Status? {
        repository.matchStatus(with: builder.id)
    }

    private var aboutText: String? {
        if let bio = builder.bio?.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty {
            return bio
        }
        if builder.buildingIdea == nil,
           !builder.desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return builder.desc
        }
        return nil
    }

    /// Public before accept — helps people decide whether to request a chat.
    private var linkedInURL: URL? {
        guard let raw = builder.linkedInURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return nil }
        if let url = URL(string: raw), url.scheme != nil { return url }
        return URL(string: "https://\(raw)")
    }

    private var matchStatusPendingCopy: String {
        guard let userId = authManager.userId,
              let match = repository.matchRequests.first(where: {
                  Set($0.participantIds) == Set([userId, builder.id])
              })
        else {
            return "Coffee chat request pending. Messaging unlocks after they accept."
        }
        if match.isIncoming(for: userId) {
            return "They requested a coffee chat. Accept it in Schedule to unlock messaging."
        }
        return "Request sent. Messaging unlocks after they accept."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            ProfileAvatarView(
                                photoURL: builder.imgUrl.isEmpty ? nil : builder.imgUrl,
                                initials: builder.initials,
                                size: 112,
                                fallbackFill: builder.accentColor.opacity(0.15),
                                fallbackForeground: builder.accentColor
                            )
                            .padding(.top, 28)

                            VStack(spacing: 6) {
                                Text(builder.name)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(AppColors.onSurface)
                                    .multilineTextAlignment(.center)

                                Text(builder.role)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(AppColors.secondary)

                                Text(builder.industry)
                                    .font(.system(size: 15))
                                    .foregroundColor(AppColors.onSurfaceVariant)

                                if let location = builder.location, !location.isEmpty {
                                    Label(location, systemImage: "mappin")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppColors.onSurfaceVariant)
                                        .padding(.top, 2)
                                }

                                if let linkedInURL = linkedInURL {
                                    Link(destination: linkedInURL) {
                                        Label("View LinkedIn", systemImage: "link")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(AppColors.primary)
                                            .padding(.top, 6)
                                    }
                                    .accessibilityLabel("Open LinkedIn profile")
                                }
                            }
                            .padding(.horizontal, 24)

                            VStack(spacing: 12) {
                                if let goal = builder.goal, !goal.isEmpty {
                                    detailBlock(
                                        title: "LOOKING TO CONNECT",
                                        accent: AppColors.primary
                                    ) {
                                        Text(goal)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppColors.onSurface)
                                    }
                                }

                                if let idea = builder.buildingIdea, !idea.isEmpty {
                                    detailBlock(title: "BUILDING") {
                                        Text(idea)
                                            .font(.system(size: 16))
                                            .foregroundColor(AppColors.onSurface)
                                            .lineSpacing(4)
                                    }
                                }

                                if let about = aboutText {
                                    detailBlock(title: "ABOUT") {
                                        Text(about)
                                            .font(.system(size: 16))
                                            .foregroundColor(AppColors.onSurface)
                                            .lineSpacing(4)
                                    }
                                }

                                if !builder.tags.isEmpty {
                                    detailBlock(title: "EXPERTISE") {
                                        FlexibleChipWrap(tags: builder.tags)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                        }
                    }

                    if isSelf {
                        Text("This is your profile.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                    } else {
                        VStack(spacing: 10) {
                            if canMessage {
                                Button {
                                    Task {
                                        isWorking = true
                                        defer { isWorking = false }
                                        await onAction(.message)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "message.fill")
                                        Text("Message")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppColors.primary)
                                    .foregroundColor(AppColors.onPrimary)
                                    .cornerRadius(12)
                                }
                                .disabled(isWorking)
                            } else if matchStatus == .pending {
                                Text(
                                    matchStatusPendingCopy
                                )
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.onSurfaceVariant)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            } else {
                                Button {
                                    Task {
                                        isWorking = true
                                        defer { isWorking = false }
                                        await onAction(.connect)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "cup.and.saucer.fill")
                                        Text("Request Chat")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppColors.primary)
                                    .foregroundColor(AppColors.onPrimary)
                                    .cornerRadius(12)
                                }
                                .disabled(isWorking)

                                Text("Messaging unlocks after they accept.")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.onSurfaceVariant)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                        .background(AppColors.surface)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .font(.system(size: 24))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailBlock<Content: View>(
        title: String,
        accent: Color = AppColors.onSurfaceVariant,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accent)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceContainerLow)
        .cornerRadius(16)
    }
}

private struct FlexibleChipWrap: View {
    var tags: [String]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.surfaceContainer)
                    .foregroundColor(AppColors.onSurfaceVariant)
                    .cornerRadius(16)
                    .lineLimit(1)
            }
        }
    }
}

struct NetworkingHubView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkingHubView()
            .environmentObject(AppRepository.shared)
            .environmentObject(AuthManager())
    }
}

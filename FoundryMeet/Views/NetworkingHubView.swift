import SwiftUI

struct NetworkingHubView: View {
    @EnvironmentObject private var repository: AppRepository
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedBuilder: DiscoveryCandidate? = nil
    @State private var statusMessage = ""
    @State private var showProfile = false
    @State private var activeThread: MessageThread? = nil

    private var builders: [DiscoveryCandidate] {
        let live = repository.networkProfiles.map(DiscoveryCandidate.init(profile:))
        // Sample profiles have no account behind them, so they only fill an
        // empty directory in the local debug store.
        if live.isEmpty && repository.usesLocalStore {
            return SeedCatalog.candidates
        }
        return live
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

                            if !statusMessage.isEmpty {
                                Text(statusMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.secondary)
                                    .padding(.horizontal, 20)
                            }

                            if builders.isEmpty {
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
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(builders) { builder in
                                    Button(action: {
                                        selectedBuilder = builder
                                    }) {
                                        VStack(spacing: 12) {
                                            Circle()
                                                .fill(builder.accentColor.opacity(0.15))
                                                .frame(width: 80, height: 80)
                                                .overlay(
                                                    Text(builder.initials)
                                                        .font(.system(size: 28, weight: .bold))
                                                        .foregroundColor(builder.accentColor)
                                                )

                                            VStack(spacing: 4) {
                                                Text(builder.name)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(AppColors.onSurface)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)

                                                Text(builder.role)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(AppColors.secondary)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)

                                                Text(builder.industry)
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(AppColors.onSurfaceVariant)
                                            }
                                        }
                                        .padding(20)
                                        .frame(maxWidth: .infinity)
                                        .background(AppColors.surfaceContainerLowest)
                                        .cornerRadius(16)
                                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .hideSystemNavBar()
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(item: $selectedBuilder) { builder in
                BuilderDetailView(builder: builder) { action in
                    Task {
                        do {
                            switch action {
                            case .connect:
                                try await repository.requestMatch(with: builder)
                                statusMessage = "Request sent to \(builder.name). You can pick a time once they accept."
                                selectedBuilder = nil
                            case .message:
                                let thread = try await repository.openOrCreateThread(with: builder)
                                selectedBuilder = nil
                                activeThread = thread
                            }
                        } catch {
                            statusMessage = error.localizedDescription
                        }
                    }
                }
            }
            .sheet(item: $activeThread) { thread in
                NavigationStack {
                    ConversationView(thread: thread)
                }
                .environmentObject(authManager)
            }
        }
    }
}

enum BuilderAction {
    case connect
    case message
}

struct BuilderDetailView: View {
    var builder: DiscoveryCandidate
    var onAction: (BuilderAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()

                VStack(spacing: 24) {
                    Circle()
                        .fill(builder.accentColor.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text(builder.initials)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(builder.accentColor)
                        )
                        .padding(.top, 40)

                    VStack(spacing: 8) {
                        Text(builder.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColors.onSurface)

                        Text(builder.role)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.secondary)

                        Text(builder.industry)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(AppColors.onSurfaceVariant)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("ABOUT")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.onSurfaceVariant)

                        Text(builder.desc)
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.onSurface)
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.surfaceContainerLow)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)

                    Spacer()

                    HStack(spacing: 16) {
                        Button(action: {
                            isWorking = true
                            onAction(.message)
                        }) {
                            HStack {
                                Image(systemName: "message.fill")
                                Text("Message")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.surfaceContainerHigh)
                            .foregroundColor(AppColors.onSurface)
                            .cornerRadius(12)
                        }
                        .disabled(isWorking)

                        Button(action: {
                            isWorking = true
                            onAction(.connect)
                        }) {
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
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .font(.system(size: 24))
                    }
                }
            }
        }
    }
}

struct NetworkingHubView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkingHubView()
            .environmentObject(AppRepository.shared)
    }
}

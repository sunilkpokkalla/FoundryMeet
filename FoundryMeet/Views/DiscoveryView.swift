import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject private var repository: AppRepository
    @State private var showProfile = false
    @State private var errorMessage = ""
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppColors.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    AppHeader(
                        showProfile: $showProfile,
                        profileInitials: repository.profile?.initials ?? ""
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Curated for you")
                                    .font(.system(size: 28, weight: .semibold))
                                    .tracking(-0.6)
                                    .foregroundColor(AppColors.onSurface)
                                Text("High-signal matches based on your recent activity.")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(AppColors.onSurfaceVariant)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 12)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FilterChip(text: "Stage: Seed+", icon: "slider.horizontal.3", isSelected: true)
                                    FilterChip(text: "Goal: Fundraising", isSelected: false)
                                    FilterChip(text: "Industry: AI/ML", isSelected: false)
                                    FilterChip(text: "Location", isSelected: false)
                                }
                                .padding(.horizontal, 24)
                            }

                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 24)
                            }

                            if repository.discoveryFeed.isEmpty {
                                VStack(spacing: 14) {
                                    Spacer().frame(height: 72)

                                    ZStack {
                                        Circle()
                                            .fill(AppColors.accentSoft.opacity(0.55))
                                            .frame(width: 72, height: 72)
                                        Image(systemName: "sparkle")
                                            .font(.system(size: 28, weight: .medium))
                                            .foregroundColor(AppColors.secondary)
                                    }

                                    Text("You're all caught up")
                                        .font(.system(size: 20, weight: .semibold))
                                        .tracking(-0.3)
                                        .foregroundColor(AppColors.onSurface)

                                    Text("New high-signal matches will appear here as your network evolves.")
                                        .font(.system(size: 15))
                                        .foregroundColor(AppColors.onSurfaceVariant)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 48)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 40)
                            } else {
                                VStack(spacing: 20) {
                                    ForEach(repository.discoveryFeed) { profile in
                                        DiscoveryProfileCard(
                                            profile: profile,
                                            isDisabled: isWorking,
                                            onDismiss: { handleDismiss(profile) },
                                            onConnect: { handleConnect(profile) }
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
            .task {
                try? await repository.refreshAll()
            }
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

    private func handleConnect(_ profile: DiscoveryCandidate) {
        isWorking = true
        errorMessage = ""
        Task {
            do {
                try await repository.connectCandidate(profile)
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

struct FilterChip: View {
    var text: String
    var icon: String? = nil
    var isSelected: Bool

    var body: some View {
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

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text(profile.role)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: 0xc86c00))
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: 0x010000).opacity(0.2))
                    .cornerRadius(12)
                }
                .padding(24)
            }

            VStack(alignment: .leading, spacing: 20) {
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("LOOKING FOR")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: 0x5a4309))

                    Text(profile.desc)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.onSurface)
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

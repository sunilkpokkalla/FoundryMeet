import SwiftUI

struct MatchHistoryView: View {
    @EnvironmentObject private var repository: AppRepository
    @State private var showProfile = false

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

                    if repository.chats.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "clock")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.secondary)
                            Text("No chats yet")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Accept a match and confirm a coffee chat to see history here.")
                                .font(.system(size: 15))
                                .foregroundColor(AppColors.onSurfaceVariant)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Match History")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(AppColors.onSurface)
                                    Text("Notes and past coffee chats.")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppColors.onSurfaceVariant)
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 8)

                                ForEach(repository.chats) { chat in
                                    NavigationLink(destination: MatchNotesView(chat: chat)) {
                                        HStack(spacing: 16) {
                                            Circle()
                                                .fill(AppColors.secondary.opacity(0.1))
                                                .frame(width: 56, height: 56)
                                                .overlay(
                                                    Text(String(chat.otherPartyName(for: repository.profile?.id ?? "").prefix(1)))
                                                        .font(.system(size: 20, weight: .bold))
                                                        .foregroundColor(AppColors.secondary)
                                                )

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(chat.otherPartyName(for: repository.profile?.id ?? ""))
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(AppColors.onSurface)
                                                Text("\(chat.dayLabel) · \(chat.timeLabel)")
                                                    .font(.system(size: 14, weight: .regular))
                                                    .foregroundColor(AppColors.onSurfaceVariant)
                                                ChatStatusBadge(
                                                    chat: chat,
                                                    userId: repository.profile?.id ?? ""
                                                )
                                                if !chat.notes.isEmpty {
                                                    Text(chat.notes)
                                                        .font(.system(size: 13))
                                                        .foregroundColor(AppColors.onSurfaceVariant)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AppColors.onSurfaceVariant.opacity(0.5))
                                        }
                                        .padding(16)
                                        .background(AppColors.surfaceContainerLowest)
                                        .cornerRadius(16)
                                        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 2)
                                    }
                                }
                            }
                            .padding(20)
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
}

struct MatchHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        MatchHistoryView()
            .environmentObject(AppRepository.shared)
    }
}

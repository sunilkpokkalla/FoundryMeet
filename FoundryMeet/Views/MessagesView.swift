import SwiftUI

struct MessagesView: View {
    /// When true, Messages is a main tab (header + no Done). When false, sheet/cover.
    var isTabRoot: Bool = false

    @ObservedObject private var repository = AppRepository.shared
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    if isTabRoot {
                        AppHeader(
                            showProfile: $showProfile,
                            profileInitials: repository.profile?.initials ?? "",
                            profilePhotoURL: repository.profile?.photoURL
                        )
                    }

                    if repository.threads.isEmpty {
                        emptyState
                    } else {
                        threadList
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isTabRoot {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .toolbar(isTabRoot ? .hidden : .automatic, for: .navigationBar)
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(authManager)
            }
            .task {
                try? await repository.refreshAll()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundColor(AppColors.secondary)
            Text("No messages yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.onSurface)
            Text("Start a conversation from Hub or Discover.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var threadList: some View {
        List(repository.threads) { thread in
            NavigationLink {
                ConversationView(thread: thread)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title(for: thread))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.onSurface)
                    Text(thread.lastMessage.isEmpty ? "Say hello" : thread.lastMessage)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.onSurfaceVariant)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    private func title(for thread: MessageThread) -> String {
        let myId = authManager.userId ?? ""
        let other = thread.participantIds.first { $0 != myId } ?? myId
        return thread.participantNames[other] ?? "Conversation"
    }
}

struct ConversationView: View {
    let thread: MessageThread
    @ObservedObject private var repository = AppRepository.shared
    @EnvironmentObject private var authManager: AuthManager
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var errorMessage = ""
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            let isMine = message.senderId == authManager.userId
                            HStack {
                                if isMine { Spacer(minLength: 40) }
                                Text(message.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isMine ? AppColors.primary : AppColors.surfaceContainerLow)
                                    .foregroundColor(isMine ? AppColors.onPrimary : AppColors.onSurface)
                                    .cornerRadius(14)
                                if !isMine { Spacer(minLength: 40) }
                            }
                            .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            HStack(spacing: 10) {
                TextField("Message", text: $draft)
                    .padding(12)
                    .background(AppColors.surfaceContainerLowest)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.hairline, lineWidth: 1)
                    )

                Button(action: send) {
                    if isSending {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(AppColors.onPrimary)
                            .frame(width: 44, height: 44)
                            .background(AppColors.primary)
                            .clipShape(Circle())
                    }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(16)
            .background(AppColors.surface)
        }
        .background(AppColors.surface.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            repository.observeMessages(threadId: thread.id) { latest in
                messages = latest
            }
        }
        .onDisappear {
            repository.stopObservingMessages(threadId: thread.id)
        }
    }

    private var title: String {
        let myId = authManager.userId ?? ""
        let other = thread.participantIds.first { $0 != myId } ?? myId
        return thread.participantNames[other] ?? "Chat"
    }

    private func send() {
        let text = draft
        draft = ""
        isSending = true
        errorMessage = ""
        Task {
            do {
                _ = try await repository.sendMessage(threadId: thread.id, text: text)
                if repository.usesLocalStore {
                    messages = try await repository.loadMessages(threadId: thread.id)
                }
            } catch {
                errorMessage = error.localizedDescription
                draft = text
            }
            isSending = false
        }
    }
}

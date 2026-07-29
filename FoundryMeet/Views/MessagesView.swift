import SwiftUI

struct MessagesView: View {
    @ObservedObject private var repository = AppRepository.shared
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if repository.threads.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 36))
                            .foregroundColor(AppColors.secondary)
                        Text("No messages yet")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Start a conversation from Hub or Discover.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.surface)
                } else {
                    List(repository.threads) { thread in
                        NavigationLink {
                            ConversationView(thread: thread)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title(for: thread))
                                    .font(.system(size: 16, weight: .semibold))
                                Text(thread.lastMessage.isEmpty ? "Say hello" : thread.lastMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.onSurfaceVariant)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                try? await repository.refreshAll()
            }
        }
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
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(AppColors.onPrimary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.primary)
                        .clipShape(Circle())
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .background(AppColors.surface)
        }
        .background(AppColors.surface.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    private var title: String {
        let myId = authManager.userId ?? ""
        let other = thread.participantIds.first { $0 != myId } ?? myId
        return thread.participantNames[other] ?? "Chat"
    }

    private func reload() async {
        do {
            messages = try await repository.loadMessages(threadId: thread.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func send() {
        let text = draft
        draft = ""
        Task {
            do {
                let message = try await repository.sendMessage(threadId: thread.id, text: text)
                messages.append(message)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

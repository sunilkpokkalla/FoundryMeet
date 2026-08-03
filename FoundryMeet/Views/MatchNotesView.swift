import SwiftUI

struct MatchNotesView: View {
    let chat: CoffeeChat
    @ObservedObject private var repository = AppRepository.shared
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var statusMessage = ""
    @State private var errorMessage = ""
    @State private var showReschedule = false
    @State private var showCancelPrompt = false
    @State private var cancellationReason = ""
    @Environment(\.dismiss) private var dismiss

    private var myId: String { repository.profile?.id ?? "" }

    /// Prefer the repository copy so the view reflects an answer or cancellation
    /// made from here without waiting for a refresh.
    private var liveChat: CoffeeChat {
        repository.chats.first { $0.id == chat.id } ?? chat
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                if !liveChat.talkingPoints.isEmpty {
                    labelledBox("TALKING POINTS", text: liveChat.talkingPoints)
                }

                if let reason = liveChat.cancellationReason, liveChat.isCancelled {
                    labelledBox("CANCELLATION REASON", text: reason)
                }

                actionsSection

                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTES")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    TextEditor(text: $notes)
                        .frame(minHeight: 180)
                        .padding(12)
                        .background(AppColors.surfaceContainerLowest)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.secondary)
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }

                Button(action: saveNotes) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(AppColors.onPrimary)
                        } else {
                            Text("Save Notes")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.primary)
                    .foregroundColor(AppColors.onPrimary)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
            .padding(24)
        }
        .background(AppColors.surface.ignoresSafeArea())
        .navigationTitle("Match Notes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReschedule) {
            SlotPickerSheet(
                title: "New time",
                subtitle: "Pick another slot for your chat with \(liveChat.otherPartyName(for: myId)). They'll be asked to confirm it.",
                confirmTitle: "Propose new time"
            ) { slot in
                try await repository.rescheduleChat(
                    liveChat,
                    startsAt: slot.startsAt,
                    endsAt: slot.endsAt,
                    dayLabel: slot.dayLabel,
                    timeLabel: slot.timeLabel
                )
                statusMessage = "New time sent."
            }
        }
        .alert("Cancel this chat?", isPresented: $showCancelPrompt) {
            TextField("Reason (optional)", text: $cancellationReason)
            Button("Keep it", role: .cancel) {}
            Button("Cancel chat", role: .destructive) {
                perform("Chat cancelled.") {
                    try await repository.cancelChat(liveChat, reason: cancellationReason)
                }
            }
        } message: {
            Text("Both of you lose the calendar entry and the reminder.")
        }
        .onAppear {
            notes = chat.notes
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(liveChat.otherPartyName(for: myId))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.onSurface)
            Text(liveChat.candidateRole)
                .font(.system(size: 15))
                .foregroundColor(AppColors.onSurfaceVariant)
            Text("\(liveChat.dayLabel) · \(liveChat.timeLabel) · \(liveChat.setting)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.secondary)
            ChatStatusBadge(chat: liveChat, userId: myId)
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        let chat = liveChat
        if chat.awaitsResponse(from: myId) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    actionButton("Decline", isPrimary: false) {
                        perform("Time declined.") {
                            try await repository.respondToChat(chat, accept: false)
                        }
                    }
                    actionButton("Confirm", isPrimary: true) {
                        perform("Confirmed and added to your calendar.") {
                            try await repository.respondToChat(chat, accept: true)
                        }
                    }
                }
                actionButton("Suggest another time", isPrimary: false) {
                    showReschedule = true
                }
            }
        } else if chat.isActive {
            HStack(spacing: 12) {
                actionButton("Cancel chat", isPrimary: false) {
                    showCancelPrompt = true
                }
                actionButton("Reschedule", isPrimary: false) {
                    showReschedule = true
                }
            }
        }
    }

    private func labelledBox(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.onSurfaceVariant)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(AppColors.onSurface)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceContainerLow)
        .cornerRadius(12)
    }

    private func actionButton(_ title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isPrimary ? .semibold : .medium))
                .foregroundColor(isPrimary ? AppColors.onPrimary : AppColors.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isPrimary ? AppColors.primary : AppColors.surfaceContainerHigh)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func perform(_ successMessage: String, _ work: @escaping () async throws -> Void) {
        statusMessage = ""
        errorMessage = ""
        Task {
            do {
                try await work()
                statusMessage = successMessage
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveNotes() {
        isSaving = true
        statusMessage = ""
        errorMessage = ""
        Task {
            do {
                try await repository.updateChatNotes(chatId: chat.id, notes: notes)
                statusMessage = "Notes saved."
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

struct ChatStatusBadge: View {
    let chat: CoffeeChat
    let userId: String

    private var tint: Color {
        if chat.isCancelled || chat.isDeclined { return Color(hex: 0xB42318) }
        if chat.isProposed { return Color(hex: 0x8A6100) }
        return Color(hex: 0x2F6B3A)
    }

    var body: some View {
        Text(chat.statusLabel(for: userId))
            .font(.system(size: 11, weight: .bold))
            .kerning(0.4)
            .foregroundColor(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
            .accessibilityLabel("Status: \(chat.statusLabel(for: userId))")
    }
}

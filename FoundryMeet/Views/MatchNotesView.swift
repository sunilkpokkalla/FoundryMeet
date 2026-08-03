import SwiftUI

/// Detail for one coffee chat: status, confirm/cancel, private reminders, outcome.
struct MatchNotesView: View {
    let chat: CoffeeChat
    @ObservedObject private var repository = AppRepository.shared
    @State private var privateNotes: String = ""
    @State private var isSaving = false
    @State private var statusMessage = ""
    @State private var errorMessage = ""
    @State private var showReschedule = false
    @State private var showCancelPrompt = false
    @State private var cancellationReason = ""
    @FocusState private var notesFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var myId: String { repository.profile?.id ?? "" }

    /// Prefer the repository copy so the view reflects an answer or cancellation
    /// made from here without waiting for a refresh.
    private var liveChat: CoffeeChat {
        repository.chats.first { $0.id == chat.id } ?? chat
    }

    private var otherName: String {
        liveChat.otherPartyName(for: myId)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                if !liveChat.talkingPoints.isEmpty {
                    infoCard(
                        title: "What you planned to talk about",
                        body: liveChat.talkingPoints
                    )
                }

                if let reason = liveChat.cancellationReason, liveChat.isCancelled {
                    infoCard(title: "Why it was cancelled", body: reason)
                }

                actionsSection

                if liveChat.needsOutcome {
                    outcomeSection
                }

                privateNotesSection

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.secondary)
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: 0xB42318))
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(AppColors.surface.ignoresSafeArea())
        .navigationTitle(otherName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReschedule) {
            SlotPickerSheet(
                title: "New time",
                subtitle: "Pick another slot with \(otherName). They’ll be asked to confirm.",
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
        .sheet(isPresented: $showCancelPrompt) {
            AppFormSheet(
                title: "Cancel this coffee chat?",
                message: "This removes the calendar entry for both of you.",
                fields: [
                    AppFormField(
                        label: "Reason (optional)",
                        placeholder: "e.g. Schedule conflict",
                        text: $cancellationReason
                    )
                ],
                cancelTitle: "Keep chat",
                confirmTitle: "Cancel chat",
                isDestructive: true,
                onCancel: { cancellationReason = "" },
                onConfirm: {
                    perform("Chat cancelled.") {
                        try await repository.cancelChat(liveChat, reason: cancellationReason)
                    }
                }
            )
        }
        .onAppear {
            privateNotes = chat.notes
        }
        .onTapGesture {
            notesFocused = false
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChatStatusBadge(chat: liveChat, userId: myId)

            Text(otherName)
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.4)
                .foregroundColor(AppColors.onSurface)

            if !liveChat.candidateRole.isEmpty {
                Text(liveChat.candidateRole)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.onSurfaceVariant)
            }

            Label("\(liveChat.dayLabel) · \(liveChat.timeLabel)", systemImage: "calendar")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.secondary)

            Label(liveChat.setting, systemImage: "cup.and.saucer.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColors.onSurfaceVariant)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.hairline, lineWidth: 1)
        )
    }

    private var privateNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your private notes")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.onSurface)

            Text("Only you see these — reminders, intros, or follow-ups after the coffee.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .topLeading) {
                if privateNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("e.g. Introduced to their CTO. Follow up next week.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.onSurfaceVariant.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $privateNotes)
                    .focused($notesFocused)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.onSurface)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 140)
            }
            .background(AppColors.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(notesFocused ? AppColors.secondary.opacity(0.45) : AppColors.hairline, lineWidth: 1)
            )

            Button(action: saveNotes) {
                HStack {
                    if isSaving {
                        ProgressView().tint(AppColors.onPrimary)
                    } else {
                        Text(privateNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? "Save"
                             : "Save notes")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(AppColors.primary)
                .foregroundColor(AppColors.onPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var outcomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How did the coffee go?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.onSurface)

            if let existing = liveChat.outcome(for: myId) {
                Text("You marked this \(existing.title.lowercased()).")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.onSurfaceVariant)
            } else {
                Text("Optional — helps you remember who was worth meeting.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.onSurfaceVariant)

                HStack(spacing: 8) {
                    ForEach(CoffeeChat.MeetingOutcome.allCases) { outcome in
                        Button {
                            perform("Thanks — noted.") {
                                try await repository.submitChatOutcome(liveChat, outcome: outcome)
                            }
                        } label: {
                            Text(outcome.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.onSurface)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppColors.surfaceContainerLowest)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(AppColors.hairline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.hairline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionsSection: some View {
        let chat = liveChat
        if chat.awaitsResponse(from: myId) {
            VStack(spacing: 10) {
                Text("They suggested this time")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    actionButton("Decline", isPrimary: false) {
                        perform("Time declined.") {
                            try await repository.respondToChat(chat, accept: false)
                        }
                    }
                    actionButton("Confirm", isPrimary: true) {
                        perform("Confirmed — added to your calendar.") {
                            try await repository.respondToChat(chat, accept: true)
                        }
                    }
                }
                actionButton("Suggest another time", isPrimary: false) {
                    showReschedule = true
                }
            }
        } else if chat.isActive {
            HStack(spacing: 10) {
                actionButton("Cancel", isPrimary: false) {
                    showCancelPrompt = true
                }
                actionButton("Reschedule", isPrimary: false) {
                    showReschedule = true
                }
            }
        }
    }

    private func infoCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.onSurfaceVariant)
            Text(body)
                .font(.system(size: 15))
                .foregroundColor(AppColors.onSurface)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.hairline, lineWidth: 1)
        )
    }

    private func actionButton(_ title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isPrimary ? .semibold : .medium))
                .foregroundColor(isPrimary ? AppColors.onPrimary : AppColors.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isPrimary ? AppColors.primary : AppColors.surfaceContainerLowest)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isPrimary ? Color.clear : AppColors.hairline, lineWidth: 1)
                )
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
        notesFocused = false
        isSaving = true
        statusMessage = ""
        errorMessage = ""
        Task {
            do {
                try await repository.updateChatNotes(chatId: chat.id, notes: privateNotes)
                statusMessage = "Notes saved — only you can see them."
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

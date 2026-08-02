import SwiftUI

struct MatchNotesView: View {
    let chat: CoffeeChat
    @ObservedObject private var repository = AppRepository.shared
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var statusMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(chat.otherPartyName(for: repository.profile?.id ?? ""))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.onSurface)
                    Text(chat.candidateRole)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.onSurfaceVariant)
                    Text("\(chat.dayLabel) · \(chat.timeLabel) · \(chat.setting)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.secondary)
                }

                if !chat.talkingPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TALKING POINTS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.onSurfaceVariant)
                        Text(chat.talkingPoints)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.onSurface)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.surfaceContainerLow)
                    .cornerRadius(12)
                }

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
                .disabled(isSaving)
            }
            .padding(24)
        }
        .background(AppColors.surface.ignoresSafeArea())
        .navigationTitle("Match Notes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notes = chat.notes
        }
    }

    private func saveNotes() {
        isSaving = true
        statusMessage = ""
        Task {
            do {
                try await repository.updateChatNotes(chatId: chat.id, notes: notes)
                statusMessage = "Notes saved."
            } catch {
                statusMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

import SwiftUI
import PhotosUI

struct AvailabilityEditorView: View {
    @EnvironmentObject private var repository: AppRepository
    @Environment(\.dismiss) private var dismiss

    @State private var windows: [AvailabilityWindow] = AvailabilityWindow.defaultWorkWeek
    @State private var statusMessage = ""
    @State private var isSaving = false

    private let weekdays: [(Int, String)] = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()
                List {
                    Section {
                        Text("Open times are generated from these windows, minus events already on your calendar.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .listRowBackground(AppColors.surface)
                    }

                    ForEach(weekdays, id: \.0) { day in
                        Section(day.1) {
                            Toggle("Available", isOn: bindingEnabled(for: day.0))
                                .tint(AppColors.secondary)

                            if windows.contains(where: { $0.weekday == day.0 }) {
                                Stepper(
                                    "Start \(timeLabel(minutes(for: day.0, start: true)))",
                                    value: bindingMinutes(for: day.0, start: true),
                                    in: 6 * 60...20 * 60,
                                    step: 30
                                )
                                Stepper(
                                    "End \(timeLabel(minutes(for: day.0, start: false)))",
                                    value: bindingMinutes(for: day.0, start: false),
                                    in: 7 * 60...22 * 60,
                                    step: 30
                                )
                            }
                        }
                        .listRowBackground(AppColors.surfaceContainerLowest)
                    }

                    if !statusMessage.isEmpty {
                        Section {
                            Text(statusMessage)
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Availability")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
            .onAppear {
                windows = repository.profile?.availability ?? AvailabilityWindow.defaultWorkWeek
            }
        }
    }

    private func bindingEnabled(for weekday: Int) -> Binding<Bool> {
        Binding(
            get: { windows.contains { $0.weekday == weekday } },
            set: { enabled in
                if enabled {
                    if !windows.contains(where: { $0.weekday == weekday }) {
                        windows.append(AvailabilityWindow(weekday: weekday, startMinutes: 9 * 60, endMinutes: 17 * 60))
                    }
                } else {
                    windows.removeAll { $0.weekday == weekday }
                }
            }
        )
    }

    private func minutes(for weekday: Int, start: Bool) -> Int {
        guard let window = windows.first(where: { $0.weekday == weekday }) else {
            return start ? 9 * 60 : 17 * 60
        }
        return start ? window.startMinutes : window.endMinutes
    }

    private func bindingMinutes(for weekday: Int, start: Bool) -> Binding<Int> {
        Binding(
            get: { minutes(for: weekday, start: start) },
            set: { value in
                guard let index = windows.firstIndex(where: { $0.weekday == weekday }) else { return }
                if start {
                    windows[index].startMinutes = min(value, windows[index].endMinutes - 30)
                } else {
                    windows[index].endMinutes = max(value, windows[index].startMinutes + 30)
                }
            }
        )
    }

    private func timeLabel(_ minutes: Int) -> String {
        let hour = minutes / 60
        let min = minutes % 60
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = min
        let date = Calendar.current.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func save() {
        isSaving = true
        statusMessage = ""
        Task {
            do {
                try await repository.updateAvailability(windows)
                statusMessage = "Availability saved."
                dismiss()
            } catch {
                statusMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

struct CredentialReviewQueueView: View {
    @EnvironmentObject private var repository: AppRepository
    @Environment(\.dismiss) private var dismiss
    @State private var reviews: [CredentialReview] = []
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()
                if reviews.isEmpty {
                    Text("No pending credentials.")
                        .foregroundColor(AppColors.onSurfaceVariant)
                } else {
                    List(reviews) { review in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(review.title)
                                .font(.system(size: 16, weight: .semibold))
                            Text("\(review.issuer) · \(review.userName)")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.onSurfaceVariant)
                            if let url = URL(string: review.url) {
                                Link(review.url, destination: url)
                                    .font(.system(size: 13))
                            }
                            HStack {
                                Button("Verify") {
                                    Task { await decide(review, approve: true) }
                                }
                                .tint(Color(hex: 0x2F6B3A))
                                Button("Reject", role: .destructive) {
                                    Task { await decide(review, approve: false) }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .listRowBackground(AppColors.surfaceContainerLowest)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Review queue")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await reload() }
            .overlay {
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
        }
    }

    private func reload() async {
        do {
            reviews = try await repository.loadPendingCredentialReviews()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func decide(_ review: CredentialReview, approve: Bool) async {
        do {
            try await repository.reviewCredential(
                credentialOwnerId: review.userId,
                credentialId: review.credentialId,
                approve: approve,
                reason: approve ? nil : "Needs a clearer public verification link."
            )
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

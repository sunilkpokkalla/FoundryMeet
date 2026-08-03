import SwiftUI

/// Day and time chooser driven by the signed-in user's availability minus their
/// busy calendar events.
struct SlotPicker: View {
    let dayGroups: [(dayLabel: String, slots: [AvailableSlot])]
    let isLoading: Bool
    @Binding var selection: AvailableSlot?
    @State private var selectedDayIndex = 0

    private var slotsForSelectedDay: [AvailableSlot] {
        guard dayGroups.indices.contains(selectedDayIndex) else { return [] }
        return dayGroups[selectedDayIndex].slots
    }

    var body: some View {
        if isLoading {
            ProgressView("Loading open times…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if dayGroups.isEmpty {
            Text("No open slots in the next two weeks. Update your availability in Account.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.onSurfaceVariant)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(dayGroups.indices, id: \.self) { index in
                            let parts = dayGroups[index].dayLabel.split(separator: " ")
                            Button {
                                selectedDayIndex = index
                                selection = nil
                            } label: {
                                VStack(spacing: 4) {
                                    Text(parts.first.map(String.init) ?? "")
                                        .font(.system(size: 12, weight: .medium))
                                    Text(parts.dropFirst().first.map(String.init) ?? "")
                                        .font(.system(size: 20, weight: .bold))
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 24)
                                .background(selectedDayIndex == index ? AppColors.primary : AppColors.secondary.opacity(0.15))
                                .foregroundColor(selectedDayIndex == index ? AppColors.onPrimary : AppColors.onSurface)
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(dayGroups[index].dayLabel)
                            .accessibilityAddTraits(selectedDayIndex == index ? [.isSelected] : [])
                        }
                    }
                }

                Text("OPEN SLOTS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.onSurfaceVariant)
                    .kerning(1.2)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(slotsForSelectedDay) { slot in
                        Button {
                            selection = slot
                        } label: {
                            VStack(spacing: 4) {
                                Text("45 min")
                                    .font(.system(size: 12, weight: .medium))
                                Text(slot.timeLabel)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selection == slot ? AppColors.primary : AppColors.surfaceContainerLowest)
                            .foregroundColor(selection == slot ? AppColors.onPrimary : AppColors.onSurface)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection == slot ? [.isSelected] : [])
                    }
                }
            }
        }
    }
}

/// Modal wrapper used when moving an existing coffee chat to a new time.
struct SlotPickerSheet: View {
    let title: String
    let subtitle: String
    let confirmTitle: String
    var onConfirm: (AvailableSlot) async throws -> Void

    @ObservedObject private var repository = AppRepository.shared
    @Environment(\.dismiss) private var dismiss
    @State private var dayGroups: [(dayLabel: String, slots: [AvailableSlot])] = []
    @State private var selection: AvailableSlot?
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(subtitle)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.onSurfaceVariant)

                        SlotPicker(dayGroups: dayGroups, isLoading: isLoading, selection: $selection)

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }

                        Button(action: confirm) {
                            HStack {
                                if isWorking {
                                    ProgressView().tint(AppColors.onPrimary)
                                } else {
                                    Text(confirmTitle)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selection != nil ? AppColors.primary : AppColors.primary.opacity(0.5))
                            .foregroundColor(AppColors.onPrimary)
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                        .disabled(selection == nil || isWorking)
                    }
                    .padding(24)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                let slots = await repository.availableSlots()
                dayGroups = AvailabilityEngine.groupByDay(slots)
                isLoading = false
            }
        }
    }

    private func confirm() {
        guard let selection else { return }
        isWorking = true
        errorMessage = ""
        Task {
            do {
                try await onConfirm(selection)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

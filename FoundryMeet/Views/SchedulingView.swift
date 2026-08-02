import SwiftUI

struct SchedulingView: View {
    @EnvironmentObject private var repository: AppRepository
    @State private var dayGroups: [(dayLabel: String, slots: [AvailableSlot])] = []
    @State private var selectedDayIndex = 0
    @State private var selectedSlot: AvailableSlot?
    @State private var selectedSetting: SettingType = .virtual
    @State private var talkingPoints: String = ""
    @State private var isConfirming = false
    @State private var isLoadingSlots = false
    @State private var statusMessage = ""
    @State private var showProfile = false
    @State private var confirmedChatName: String?

    enum SettingType: String {
        case inPerson = "In-Person"
        case virtual = "Virtual"
        case office = "Office"
    }

    private var activeMatch: PendingMatch? {
        repository.pendingMatches.first
    }

    private var slotsForSelectedDay: [AvailableSlot] {
        guard dayGroups.indices.contains(selectedDayIndex) else { return [] }
        return dayGroups[selectedDayIndex].slots
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    AppHeader(
                        showProfile: $showProfile,
                        profileInitials: repository.profile?.initials ?? ""
                    )

                    if let match = activeMatch {
                        scheduleForm(for: match)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Schedule")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(AppColors.onSurface)
                                Text("Confirm a time once you have an accepted match.")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.onSurfaceVariant)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                            Spacer()
                            emptyState
                            Spacer()
                        }
                    }
                }
            }
            .hideSystemNavBar()
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .alert("Chat confirmed", isPresented: Binding(
                get: { confirmedChatName != nil },
                set: { if !$0 { confirmedChatName = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Coffee chat with \(confirmedChatName ?? "your match") was saved, added to your calendar, and queued for email invite.")
            }
            .task(id: activeMatch?.id) {
                await reloadSlots()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(AppColors.secondary)
            Text("No accepted matches yet")
                .font(.system(size: 20, weight: .semibold))
            Text("Request a coffee chat from Discover or Hub, then come back here to pick a time.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func scheduleForm(for match: PendingMatch) -> some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 16) {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(AppColors.secondary.opacity(0.15))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Text(String(match.candidateName.prefix(1)))
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(AppColors.secondary)
                                    )

                                ZStack {
                                    Circle().fill(AppColors.surface).frame(width: 18, height: 18)
                                    Image(systemName: "checkmark.circle.fill")
                                        .resizable()
                                        .frame(width: 14, height: 14)
                                        .foregroundColor(AppColors.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("ACCEPTED MATCH")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AppColors.secondary)
                                    .kerning(1.2)

                                Text("Coffee with \(match.candidateName.components(separatedBy: " ").first ?? match.candidateName)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(AppColors.onSurface)

                                Text(match.candidateRole)
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.onSurfaceVariant)
                            }
                        }

                        Text("Slots come from your weekly availability, minus busy events on your calendar.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .lineSpacing(4)
                    }

                    if isLoadingSlots {
                        ProgressView("Loading open times…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else if dayGroups.isEmpty {
                        Text("No open slots in the next two weeks. Update your availability in Account.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.onSurfaceVariant)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(dayGroups.indices, id: \.self) { index in
                                    Button {
                                        selectedDayIndex = index
                                        selectedSlot = nil
                                    } label: {
                                        let parts = dayGroups[index].dayLabel.split(separator: " ")
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
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("OPEN SLOTS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppColors.onSurfaceVariant)
                                .kerning(1.2)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(slotsForSelectedDay) { slot in
                                    Button {
                                        selectedSlot = slot
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text("45 min")
                                                .font(.system(size: 12, weight: .medium))
                                            Text(slot.timeLabel)
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(selectedSlot == slot ? AppColors.primary : AppColors.surfaceContainerLowest)
                                        .foregroundColor(selectedSlot == slot ? AppColors.onPrimary : AppColors.onSurface)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("SETTING")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .kerning(1.2)

                        HStack(spacing: 12) {
                            SettingButton(title: "In-Person", icon: "cup.and.saucer.fill", isSelected: selectedSetting == .inPerson) {
                                selectedSetting = .inPerson
                            }
                            SettingButton(title: "Virtual", icon: "video.fill", isSelected: selectedSetting == .virtual) {
                                selectedSetting = .virtual
                            }
                            SettingButton(title: "Office", icon: "building.2.fill", isSelected: selectedSetting == .office) {
                                selectedSetting = .office
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("TALKING POINTS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .kerning(1.2)

                        TextField("What do you want to cover?", text: $talkingPoints, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(16)
                            .background(AppColors.surfaceContainerLowest)
                            .cornerRadius(12)
                    }

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }

                    Spacer().frame(height: 100)
                }
                .padding(24)
            }

            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Button(action: { confirmChat(for: match) }) {
                        HStack {
                            if isConfirming {
                                ProgressView().tint(AppColors.onPrimary)
                            } else {
                                Text("Confirm Chat")
                                Image(systemName: "paperplane")
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedSlot != nil ? AppColors.primary : AppColors.primary.opacity(0.5))
                        .cornerRadius(16)
                    }
                    .disabled(selectedSlot == nil || isConfirming)

                    Text("Saves to History, adds a calendar event, and emails an .ics invite.")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(AppColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .background(AppColors.surface)
            }
        }
    }

    private func reloadSlots() async {
        guard activeMatch != nil else {
            dayGroups = []
            return
        }
        isLoadingSlots = true
        selectedSlot = nil
        selectedDayIndex = 0
        let slots = await repository.availableSlots()
        dayGroups = AvailabilityEngine.groupByDay(slots)
        isLoadingSlots = false
    }

    private func confirmChat(for match: PendingMatch) {
        guard let selectedSlot else { return }
        isConfirming = true
        statusMessage = ""

        Task {
            do {
                let chat = try await repository.scheduleChat(
                    for: match,
                    startsAt: selectedSlot.startsAt,
                    endsAt: selectedSlot.endsAt,
                    dayLabel: selectedSlot.dayLabel,
                    timeLabel: selectedSlot.timeLabel,
                    setting: selectedSetting.rawValue,
                    talkingPoints: talkingPoints
                )
                confirmedChatName = chat.candidateName
                self.selectedSlot = nil
                talkingPoints = ""
                await reloadSlots()
            } catch {
                statusMessage = error.localizedDescription
            }
            isConfirming = false
        }
    }
}

struct SettingButton: View {
    var title: String
    var icon: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color(hex: 0xffdb94).opacity(0.7) : AppColors.surfaceContainerLowest)
            .foregroundColor(isSelected ? AppColors.onSurface : AppColors.onSurfaceVariant)
            .cornerRadius(12)
        }
    }
}

import SwiftUI

struct SchedulingView: View {
    @EnvironmentObject private var repository: AppRepository
    @State private var selectedDay = 0
    @State private var selectedTime: Int? = nil
    @State private var selectedSetting: SettingType = .virtual
    @State private var talkingPoints: String = ""
    @State private var isConfirming = false
    @State private var statusMessage = ""
    @State private var showProfile = false
    @State private var confirmedChatName: String?

    let days = [
        ("Tue", "14"), ("Wed", "15"), ("Thu", "16"), ("Fri", "17")
    ]

    let slots = [
        ("Morning", "9:00 AM"),
        ("Lunch", "12:30 PM"),
        ("Afternoon", "3:45 PM")
    ]

    enum SettingType: String {
        case inPerson = "In-Person"
        case virtual = "Virtual"
        case office = "Office"
    }

    private var activeMatch: PendingMatch? {
        repository.pendingMatches.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()

                if let match = activeMatch {
                    scheduleForm(for: match)
                } else {
                    emptyState
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .padding(.leading, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text("Schedule")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.onSurface)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showProfile = true }) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .alert("Chat confirmed", isPresented: Binding(
                get: { confirmedChatName != nil },
                set: { if !$0 { confirmedChatName = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Coffee chat with \(confirmedChatName ?? "your match") is saved in History.")
            }
            .task {
                try? await repository.refreshAll()
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

                        Text("You both have overlapping gaps this week. Pick a time that feels effortless.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .lineSpacing(4)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<days.count, id: \.self) { index in
                                Button(action: { selectedDay = index }) {
                                    VStack(spacing: 4) {
                                        Text(days[index].0)
                                            .font(.system(size: 12, weight: .medium))
                                        Text(days[index].1)
                                            .font(.system(size: 20, weight: .bold))
                                    }
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 24)
                                    .background(selectedDay == index ? AppColors.primary : AppColors.secondary.opacity(0.15))
                                    .foregroundColor(selectedDay == index ? AppColors.onPrimary : AppColors.onSurface)
                                    .cornerRadius(16)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("SUGGESTED SLOTS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .kerning(1.2)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(0..<slots.count, id: \.self) { index in
                                Button(action: { selectedTime = index }) {
                                    VStack(spacing: 4) {
                                        Text(slots[index].0)
                                            .font(.system(size: 12, weight: .medium))
                                        Text(slots[index].1)
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(selectedTime == index ? AppColors.primary : AppColors.surfaceContainerLowest)
                                    .foregroundColor(selectedTime == index ? AppColors.onPrimary : AppColors.onSurface)
                                    .cornerRadius(12)
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
                        .background(selectedTime != nil ? AppColors.primary : AppColors.primary.opacity(0.5))
                        .cornerRadius(16)
                    }
                    .disabled(selectedTime == nil || isConfirming)

                    Text("Confirming saves this chat to your Match History.")
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

    private func confirmChat(for match: PendingMatch) {
        guard let selectedTime else { return }
        isConfirming = true
        statusMessage = ""
        let dayLabel = "\(days[selectedDay].0) \(days[selectedDay].1)"
        let timeLabel = slots[selectedTime].1

        Task {
            do {
                let chat = try await repository.scheduleChat(
                    for: match,
                    dayLabel: dayLabel,
                    timeLabel: timeLabel,
                    setting: selectedSetting.rawValue,
                    talkingPoints: talkingPoints
                )
                confirmedChatName = chat.candidateName
                self.selectedTime = nil
                talkingPoints = ""
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

struct SchedulingView_Previews: PreviewProvider {
    static var previews: some View {
        SchedulingView()
            .environmentObject(AppRepository.shared)
    }
}

import SwiftUI

struct SchedulingView: View {
    @EnvironmentObject private var repository: AppRepository
    @EnvironmentObject private var authManager: AuthManager
    @State private var showProfile = false
    @State private var statusMessage = ""
    @State private var errorMessage = ""
    @State private var matchToSchedule: MatchRequest?
    @State private var chatToReschedule: CoffeeChat?
    @State private var chatToCancel: CoffeeChat?
    @State private var cancellationReason = ""

    private var myId: String { authManager.userId ?? repository.profile?.id ?? "" }

    private var awaitingReply: [CoffeeChat] {
        repository.chats.filter { $0.awaitsOtherParty(for: myId) }
    }

    private var upcoming: [CoffeeChat] {
        repository.chats.filter { $0.isConfirmed && !$0.isPast }
    }

    private var isEmpty: Bool {
        repository.incomingRequests.isEmpty
            && repository.outgoingRequests.isEmpty
            && repository.schedulableMatches.isEmpty
            && repository.chatsAwaitingMyResponse.isEmpty
            && awaitingReply.isEmpty
            && upcoming.isEmpty
    }

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

                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            header

                            if !statusMessage.isEmpty {
                                banner(statusMessage, color: AppColors.secondary)
                            }
                            if !errorMessage.isEmpty {
                                banner(errorMessage, color: .red)
                            }

                            if isEmpty {
                                emptyState
                            } else {
                                requestsToAnswer
                                timesToAnswer
                                readyToSchedule
                                waitingOnThem
                                upcomingChats
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .hideSystemNavBar()
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(authManager)
            }
            .sheet(item: $matchToSchedule) { match in
                ProposeTimeSheet(match: match) { message in
                    statusMessage = message
                }
            }
            .sheet(item: $chatToReschedule) { chat in
                SlotPickerSheet(
                    title: "New time",
                    subtitle: "Pick another slot for your chat with \(chat.otherPartyName(for: myId)). They'll be asked to confirm it.",
                    confirmTitle: "Propose new time"
                ) { slot in
                    try await repository.rescheduleChat(
                        chat,
                        startsAt: slot.startsAt,
                        endsAt: slot.endsAt,
                        dayLabel: slot.dayLabel,
                        timeLabel: slot.timeLabel
                    )
                    statusMessage = "New time sent to \(chat.otherPartyName(for: myId))."
                }
            }
            .sheet(isPresented: Binding(
                get: { chatToCancel != nil },
                set: { if !$0 { chatToCancel = nil; cancellationReason = "" } }
            )) {
                AppFormSheet(
                    title: "Cancel this coffee chat?",
                    message: "Both of you lose the calendar entry and the reminder.",
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
                    onCancel: {
                        chatToCancel = nil
                        cancellationReason = ""
                    },
                    onConfirm: {
                        if let chat = chatToCancel {
                            perform("Chat cancelled.") {
                                try await repository.cancelChat(chat, reason: cancellationReason)
                            }
                        }
                        chatToCancel = nil
                        cancellationReason = ""
                    }
                )
            }
            .task {
                try? await repository.refreshAll()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Schedule")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(AppColors.onSurface)
            Text("Requests, proposed times, and what's on the books.")
                .font(.system(size: 16))
                .foregroundColor(AppColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(AppColors.secondary)
            Text("Nothing to schedule yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.onSurface)
            Text("Request a coffee chat from Discover or Hub. Once someone accepts, pick a time here.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    @ViewBuilder
    private var requestsToAnswer: some View {
        let requests = repository.incomingRequests
        if !requests.isEmpty {
            section("Requests for you", count: requests.count) {
                ForEach(requests) { request in
                    Card {
                        personRow(
                            name: request.otherPartyName(for: myId),
                            role: request.otherPartyRole(for: myId),
                            detail: request.note.isEmpty ? "Wants to grab coffee." : request.note
                        )

                        HStack(spacing: 12) {
                            secondaryButton("Decline") {
                                perform("Request declined.") {
                                    try await repository.respondToRequest(request, accept: false)
                                }
                            }
                            primaryButton("Accept") {
                                perform("Accepted. Pick a time below.") {
                                    try await repository.respondToRequest(request, accept: true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var timesToAnswer: some View {
        let chats = repository.chatsAwaitingMyResponse
        if !chats.isEmpty {
            section("Times to confirm", count: chats.count) {
                ForEach(chats) { chat in
                    Card {
                        personRow(
                            name: chat.otherPartyName(for: myId),
                            role: chat.candidateRole,
                            detail: "\(chat.dayLabel) · \(chat.timeLabel) · \(chat.setting)"
                        )

                        if !chat.talkingPoints.isEmpty {
                            Text(chat.talkingPoints)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.onSurfaceVariant)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        HStack(spacing: 12) {
                            secondaryButton("Decline") {
                                perform("Time declined.") {
                                    try await repository.respondToChat(chat, accept: false)
                                }
                            }
                            primaryButton("Confirm") {
                                perform("Confirmed and added to your calendar.") {
                                    try await repository.respondToChat(chat, accept: true)
                                }
                            }
                        }

                        Button("Suggest another time") {
                            chatToReschedule = chat
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.secondary)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var readyToSchedule: some View {
        let matches = repository.schedulableMatches
        if !matches.isEmpty {
            section("Ready to schedule", count: matches.count) {
                ForEach(matches) { match in
                    Card {
                        personRow(
                            name: match.otherPartyName(for: myId),
                            role: match.otherPartyRole(for: myId),
                            detail: "Accepted — pick a time that works for you."
                        )

                        primaryButton("Pick a time") {
                            matchToSchedule = match
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var waitingOnThem: some View {
        let requests = repository.outgoingRequests
        let chats = awaitingReply
        if !requests.isEmpty || !chats.isEmpty {
            section("Waiting on them", count: requests.count + chats.count) {
                ForEach(requests) { request in
                    Card {
                        personRow(
                            name: request.otherPartyName(for: myId),
                            role: request.otherPartyRole(for: myId),
                            detail: "Request sent — no answer yet."
                        )
                        secondaryButton("Withdraw request") {
                            perform("Request withdrawn.") {
                                try await repository.withdrawRequest(request)
                            }
                        }
                    }
                }

                ForEach(chats) { chat in
                    Card {
                        personRow(
                            name: chat.otherPartyName(for: myId),
                            role: chat.candidateRole,
                            detail: "\(chat.dayLabel) · \(chat.timeLabel) — waiting for them to confirm."
                        )
                        HStack(spacing: 12) {
                            secondaryButton("Cancel") { chatToCancel = chat }
                            secondaryButton("Change time") { chatToReschedule = chat }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var upcomingChats: some View {
        let chats = upcoming
        if !chats.isEmpty {
            section("Confirmed", count: chats.count) {
                ForEach(chats) { chat in
                    Card {
                        personRow(
                            name: chat.otherPartyName(for: myId),
                            role: chat.candidateRole,
                            detail: "\(chat.dayLabel) · \(chat.timeLabel) · \(chat.setting)"
                        )
                        HStack(spacing: 12) {
                            secondaryButton("Cancel") { chatToCancel = chat }
                            secondaryButton("Reschedule") { chatToReschedule = chat }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Building blocks

    private func section<Content: View>(
        _ title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1.2)
                    .foregroundColor(AppColors.onSurfaceVariant)
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.accentSoft))
            }
            content()
        }
    }

    private func personRow(name: String, role: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(AppColors.secondary.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(AppColors.secondary)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.onSurface)
                if !role.isEmpty {
                    Text(role)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.onSurfaceVariant)
                }
                Text(detail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppColors.primary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppColors.surfaceContainerHigh)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func banner(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
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
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
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
}

/// Compose sheet for the first time proposal on an accepted match.
struct ProposeTimeSheet: View {
    let match: MatchRequest
    var onSent: (String) -> Void

    @ObservedObject private var repository = AppRepository.shared
    @Environment(\.dismiss) private var dismiss
    @State private var dayGroups: [(dayLabel: String, slots: [AvailableSlot])] = []
    @State private var selection: AvailableSlot?
    @State private var setting: SettingType = .virtual
    @State private var talkingPoints = ""
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage = ""

    enum SettingType: String, CaseIterable {
        case inPerson = "In-Person"
        case virtual = "Virtual"
        case office = "Office"

        var icon: String {
            switch self {
            case .inPerson: return "cup.and.saucer.fill"
            case .virtual: return "video.fill"
            case .office: return "building.2.fill"
            }
        }
    }

    private var otherName: String {
        match.otherPartyName(for: repository.profile?.id ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Text("Pick a slot from your availability. \(otherName) confirms before anything lands on a calendar.")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)

                        SlotPicker(dayGroups: dayGroups, isLoading: isLoading, selection: $selection)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("SETTING")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppColors.onSurfaceVariant)
                                .kerning(1.2)

                            HStack(spacing: 12) {
                                ForEach(SettingType.allCases, id: \.self) { option in
                                    SettingButton(
                                        title: option.rawValue,
                                        icon: option.icon,
                                        isSelected: setting == option
                                    ) {
                                        setting = option
                                    }
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

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }

                        Button(action: send) {
                            HStack {
                                if isWorking {
                                    ProgressView().tint(AppColors.onPrimary)
                                } else {
                                    Text("Send time proposal")
                                    Image(systemName: "paperplane")
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selection != nil ? AppColors.primary : AppColors.primary.opacity(0.5))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                        .disabled(selection == nil || isWorking)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Coffee with \(otherName.components(separatedBy: " ").first ?? otherName)")
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

    private func send() {
        guard let selection else { return }
        isWorking = true
        errorMessage = ""
        Task {
            do {
                _ = try await repository.proposeChat(
                    for: match,
                    startsAt: selection.startsAt,
                    endsAt: selection.endsAt,
                    dayLabel: selection.dayLabel,
                    timeLabel: selection.timeLabel,
                    setting: setting.rawValue,
                    talkingPoints: talkingPoints
                )
                onSent("Time sent to \(otherName). You'll be notified when they confirm.")
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
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
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

import Foundation
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

@MainActor
final class AppRepository: ObservableObject {
    static let shared = AppRepository()

    @Published private(set) var profile: UserProfile?
    @Published private(set) var matchRequests: [MatchRequest] = []
    @Published private(set) var chats: [CoffeeChat] = []
    @Published private(set) var discoveryFeed: [DiscoveryCandidate] = []
    @Published private(set) var networkProfiles: [UserProfile] = []
    @Published private(set) var threads: [MessageThread] = []
    @Published var filters = DiscoveryFilters()
    @Published var lastError: String?

    private let db = Firestore.firestore()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var userId: String?
    private(set) var usesLocalStore = false
    private var excludedCandidateIds: Set<String> = []
    private var listeners: [ListenerRegistration] = []
    private var messageListeners: [String: ListenerRegistration] = [:]

    private init() {}

    // MARK: - Derived match state

    /// Requests waiting on me to accept or decline.
    var incomingRequests: [MatchRequest] {
        guard let userId else { return [] }
        return matchRequests
            .filter { $0.isPending && $0.isIncoming(for: userId) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Requests I sent that have not been answered yet.
    var outgoingRequests: [MatchRequest] {
        guard let userId else { return [] }
        return matchRequests
            .filter { $0.isPending && !$0.isIncoming(for: userId) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Accepted matches with no live chat, so a time still needs proposing.
    var schedulableMatches: [MatchRequest] {
        matchRequests
            .filter { request in
                request.isAccepted && !chats.contains { chat in
                    chat.isActive && Set(chat.participantIds) == Set(request.participantIds)
                }
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Proposed times I need to confirm or turn down.
    var chatsAwaitingMyResponse: [CoffeeChat] {
        guard let userId else { return [] }
        return chats
            .filter { $0.awaitsResponse(from: userId) }
            .sorted { ($0.startsAt ?? $0.createdAt) < ($1.startsAt ?? $1.createdAt) }
    }

    func configure(userId: String, email: String, displayName: String, useLocalStore: Bool) async {
        self.userId = userId
        self.usesLocalStore = useLocalStore
        lastError = nil

        do {
            if useLocalStore {
                try ensureLocalNetworkSeed()
            }
            if var existing = try await loadProfile(userId: userId) {
                if existing.email.isEmpty { existing.email = email }
                if existing.displayName.isEmpty {
                    existing.displayName = displayName.isEmpty
                        ? (email.components(separatedBy: "@").first ?? "Founder")
                        : displayName
                }
                profile = existing
            } else {
                let created = UserProfile(
                    id: userId,
                    email: email,
                    displayName: displayName.isEmpty
                        ? (email.components(separatedBy: "@").first ?? "Founder")
                        : displayName
                )
                try await saveProfile(created)
                profile = created
            }
            try await refreshAll()
            startRealtimeSync()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearSession() {
        stopRealtimeSync()
        userId = nil
        profile = nil
        matchRequests = []
        chats = []
        discoveryFeed = []
        networkProfiles = []
        threads = []
        filters = DiscoveryFilters()
        excludedCandidateIds = []
        lastError = nil
    }

    /// Keeps matches / chats / threads live so the other person's accept shows
    /// without manually switching tabs.
    func startRealtimeSync() {
        stopRealtimeSync()
        guard let userId, !usesLocalStore else { return }

        listeners.append(
            db.collection("matches")
                .whereField("participantIds", arrayContains: userId)
                .addSnapshotListener { [weak self] snapshot, _ in
                    Task { @MainActor in
                        guard let self else { return }
                        self.matchRequests = (snapshot?.documents ?? [])
                            .compactMap { MatchRequest(id: $0.documentID, firestoreData: $0.data()) }
                            .sorted { $0.updatedAt > $1.updatedAt }
                        let interactions = (try? await self.loadInteractions(userId: userId)) ?? []
                        self.excludedCandidateIds = Set(interactions.map(\.candidateId))
                            .union(self.matchRequests.filter { !$0.isDeclined }.map { $0.otherPartyId(for: userId) })
                        await self.rebuildDiscoveryFeed()
                    }
                }
        )

        listeners.append(
            db.collection("chats")
                .whereField("participantIds", arrayContains: userId)
                .addSnapshotListener { [weak self] snapshot, _ in
                    Task { @MainActor in
                        guard let self else { return }
                        self.chats = (snapshot?.documents ?? [])
                            .compactMap { CoffeeChat(id: $0.documentID, firestoreData: $0.data()) }
                            .sorted { ($0.startsAt ?? $0.createdAt) > ($1.startsAt ?? $1.createdAt) }
                        await self.syncCalendarState()
                    }
                }
        )

        listeners.append(
            db.collection("threads")
                .whereField("participantIds", arrayContains: userId)
                .addSnapshotListener { [weak self] snapshot, _ in
                    Task { @MainActor in
                        guard let self else { return }
                        self.threads = (snapshot?.documents ?? [])
                            .compactMap { MessageThread(id: $0.documentID, firestoreData: $0.data()) }
                            .sorted { $0.updatedAt > $1.updatedAt }
                    }
                }
        )
    }

    func stopRealtimeSync() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        messageListeners.values.forEach { $0.remove() }
        messageListeners.removeAll()
    }

    /// Live updates while a conversation is open.
    func observeMessages(
        threadId: String,
        onChange: @escaping @MainActor ([ChatMessage]) -> Void
    ) {
        messageListeners[threadId]?.remove()
        messageListeners[threadId] = nil

        if usesLocalStore {
            Task {
                let messages = (try? await loadMessages(threadId: threadId)) ?? []
                onChange(messages)
            }
            return
        }

        messageListeners[threadId] = db.collection("threads").document(threadId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, _ in
                let messages = (snapshot?.documents ?? [])
                    .compactMap { ChatMessage(id: $0.documentID, firestoreData: $0.data()) }
                Task { @MainActor in
                    onChange(messages)
                }
            }
    }

    func stopObservingMessages(threadId: String) {
        messageListeners[threadId]?.remove()
        messageListeners[threadId] = nil
    }

    /// Wipes this user's stored profile data before Auth deletion. Shared chats
    /// with other people are left for the other participant's history.
    func deleteAccountData() async throws {
        guard let userId else { throw RepositoryError.notSignedIn }

        stopRealtimeSync()
        await PhotoStorageService.deleteAvatar(userId: userId, useLocalStore: usesLocalStore)

        if usesLocalStore {
            let profileURL = try? localURL(key: "profile_\(userId)")
            if let profileURL { try? FileManager.default.removeItem(at: profileURL) }
            let interactionsURL = try? localURL(key: "interactions_\(userId)")
            if let interactionsURL { try? FileManager.default.removeItem(at: interactionsURL) }
            var network = (try? readLocal(key: "network_directory", as: [UserProfile].self)) ?? []
            network.removeAll { $0.id == userId }
            try? writeLocal(network, key: "network_directory")
            UserDefaults.standard.removeObject(forKey: onboardingKey(for: userId))
            return
        }

        // Leave the network immediately, then remove personal data.
        if var current = profile {
            current.isDiscoverable = false
            current.displayName = "Deleted user"
            current.bio = nil
            current.buildingIdea = nil
            current.linkedInURL = nil
            current.photoURL = nil
            current.fcmTokens = []
            current.email = ""
            try? await saveProfile(current)
        }

        let interactions = try await db.collection("users").document(userId)
            .collection("interactions")
            .getDocuments()
        for doc in interactions.documents {
            try await doc.reference.delete()
        }
        try await db.collection("users").document(userId).delete()
        UserDefaults.standard.removeObject(forKey: onboardingKey(for: userId))
    }

    func saveOnboarding(
        role: String?,
        place: ResolvedPlace?,
        stages: [StartupStage],
        industry: Industry?,
        skills: [String],
        goal: String?
    ) async throws {
        guard var current = profile, let userId else {
            throw RepositoryError.notSignedIn
        }
        current.role = role
        current.location = place?.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        current.latitude = place?.latitude
        current.longitude = place?.longitude
        current.stages = stages.map(\.rawValue)
        current.skills = skills
        current.goal = goal
        current.industry = industry?.rawValue
        current.onboardingCompleted = true
        current.updatedAt = Date()
        try await saveProfile(current)
        profile = current
        UserDefaults.standard.set(true, forKey: onboardingKey(for: userId))
        try await refreshAll()
    }

    func updateProfile(_ updated: UserProfile) async throws {
        var next = updated
        next.updatedAt = Date()
        try await saveProfile(next)
        profile = next
        // A failed feed refresh must not look like the save itself failed —
        // availability and profile edits already landed.
        do {
            try await refreshAll()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addCredential(title: String, issuer: String, url: String) async throws {
        guard var current = profile, let userId else { throw RepositoryError.notSignedIn }
        let credential = VerifiedCredential(title: title, issuer: issuer, url: url, status: "pending")
        current.credentials.append(credential)
        try await updateProfile(current)

        let review = CredentialReview(
            userId: userId,
            userName: current.displayName,
            userEmail: current.email,
            credentialId: credential.id,
            title: credential.title,
            issuer: credential.issuer,
            url: credential.url
        )
        try await saveCredentialReview(review)
    }

    func removeCredential(id: String) async throws {
        guard var current = profile else { throw RepositoryError.notSignedIn }
        current.credentials.removeAll { $0.id == id }
        try await updateProfile(current)
    }

    func verifyCredential(id: String) async throws {
        guard let ownerId = userId ?? profile?.id else { throw RepositoryError.notSignedIn }
        try await reviewCredential(credentialOwnerId: ownerId, credentialId: id, approve: true, reason: nil)
    }

    func loadPendingCredentialReviews() async throws -> [CredentialReview] {
        if usesLocalStore {
            let all = (try? readLocal(key: "credential_reviews", as: [CredentialReview].self)) ?? []
            return all.filter { $0.status == "pending" }.sorted { $0.createdAt > $1.createdAt }
        }
        let snapshot = try await db.collection("credentialReviews")
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        return snapshot.documents
            .compactMap { CredentialReview(id: $0.documentID, firestoreData: $0.data()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func reviewCredential(
        credentialOwnerId: String,
        credentialId: String,
        approve: Bool,
        reason: String?
    ) async throws {
        guard let reviewerId = userId else { throw RepositoryError.notSignedIn }

        if usesLocalStore {
            var reviews = (try? readLocal(key: "credential_reviews", as: [CredentialReview].self)) ?? []
            if let index = reviews.firstIndex(where: { $0.userId == credentialOwnerId && $0.credentialId == credentialId }) {
                reviews[index].status = approve ? "verified" : "rejected"
                reviews[index].rejectionReason = reason
                reviews[index].reviewedBy = reviewerId
                reviews[index].updatedAt = Date()
                try writeLocal(reviews, key: "credential_reviews")
            }
        } else {
            let snapshot = try await db.collection("credentialReviews")
                .whereField("userId", isEqualTo: credentialOwnerId)
                .whereField("credentialId", isEqualTo: credentialId)
                .getDocuments()
            for doc in snapshot.documents {
                try await doc.reference.setData([
                    "status": approve ? "verified" : "rejected",
                    "rejectionReason": reason as Any,
                    "reviewedBy": reviewerId,
                    "updatedAt": Timestamp(date: Date())
                ], merge: true)
            }
        }

        // Update owner profile credentials
        if var owner = try await loadProfile(userId: credentialOwnerId) {
            if let index = owner.credentials.firstIndex(where: { $0.id == credentialId }) {
                owner.credentials[index].status = approve ? "verified" : "rejected"
                owner.credentials[index].rejectionReason = reason
                owner.credentials[index].reviewedAt = Date()
                owner.credentials[index].reviewedBy = reviewerId
                owner.updatedAt = Date()
                try await saveProfile(owner)
                if owner.id == userId {
                    profile = owner
                }
                try await enqueuePush(
                    recipientIds: [owner.id],
                    title: approve ? "Credential verified" : "Credential update",
                    body: approve
                        ? "\(owner.credentials[index].title) was verified."
                        : "\(owner.credentials[index].title) was not verified."
                )
            }
        }
    }

    func updateAvailability(_ windows: [AvailabilityWindow]) async throws {
        guard var current = profile else { throw RepositoryError.notSignedIn }
        current.availability = windows
        try await updateProfile(current)
    }

    func uploadProfilePhoto(_ imageData: Data) async throws {
        guard var current = profile, let userId else { throw RepositoryError.notSignedIn }
        let url = try await PhotoStorageService.uploadAvatar(
            userId: userId,
            imageData: imageData,
            useLocalStore: usesLocalStore
        )
        current.photoURL = url
        try await updateProfile(current)
    }

    func availableSlots(meetingMinutes: Int = 45) async -> [AvailableSlot] {
        let windows = profile?.availability.isEmpty == false
            ? (profile?.availability ?? AvailabilityWindow.defaultWorkWeek)
            : AvailabilityWindow.defaultWorkWeek

        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 14, to: start) ?? start.addingTimeInterval(14 * 86400)
        let busy = await CalendarInviteService.shared.busyIntervals(from: start, to: end)

        return AvailabilityEngine.generateSlots(
            windows: windows,
            from: start,
            dayCount: 14,
            meetingMinutes: meetingMinutes,
            stepMinutes: 30,
            busyIntervals: busy
        )
    }

    // MARK: - Coffee chat scheduling

    /// Puts a time on the table for an accepted match. Nothing lands on either
    /// calendar until the other person confirms.
    func proposeChat(
        for match: MatchRequest,
        startsAt: Date,
        endsAt: Date,
        dayLabel: String,
        timeLabel: String,
        setting: String,
        talkingPoints: String
    ) async throws -> CoffeeChat {
        guard let userId, let me = profile else { throw RepositoryError.notSignedIn }
        guard match.isAccepted else { throw RepositoryError.matchNotAccepted }

        let otherId = match.otherPartyId(for: userId)
        let chat = CoffeeChat(
            id: UUID().uuidString,
            userId: userId,
            candidateId: otherId,
            candidateName: match.otherPartyName(for: userId),
            candidateRole: match.otherPartyRole(for: userId),
            organizerName: me.displayName.isEmpty ? "Founder" : me.displayName,
            participantIds: match.participantIds,
            dayLabel: dayLabel,
            timeLabel: timeLabel,
            setting: setting,
            talkingPoints: talkingPoints,
            notes: "",
            status: CoffeeChat.Status.proposed.rawValue,
            proposedById: userId,
            respondedAt: nil,
            cancelledById: nil,
            cancellationReason: nil,
            startsAt: startsAt,
            endsAt: endsAt,
            calendarEventId: nil,
            inviteStatus: "none",
            outcomes: [:],
            createdAt: Date(),
            updatedAt: Date()
        )
        try await saveChat(chat)
        upsertChat(chat)

        // Demo partner confirms immediately so calendar + outcome flows are testable.
        if DemoPartner.isDemo(otherId) {
            var confirmed = chat
            confirmed.status = CoffeeChat.Status.confirmed.rawValue
            confirmed.respondedAt = Date()
            confirmed.updatedAt = Date()
            try await saveChat(confirmed)
            upsertChat(confirmed)
            await syncCalendarState()
            return confirmed
        }

        try await enqueuePush(
            recipientIds: [otherId],
            title: "New time proposed",
            body: "\(chat.organizerName) suggested \(dayLabel) · \(timeLabel)",
            chatId: chat.id
        )

        return chat
    }

    /// Confirms or turns down a time the other person proposed.
    func respondToChat(_ chat: CoffeeChat, accept: Bool) async throws {
        guard let userId else { throw RepositoryError.notSignedIn }
        guard chat.awaitsResponse(from: userId) else { throw RepositoryError.notAllowed }

        var updated = chat
        updated.status = accept
            ? CoffeeChat.Status.confirmed.rawValue
            : CoffeeChat.Status.declined.rawValue
        updated.respondedAt = Date()
        updated.updatedAt = Date()
        try await saveChat(updated)
        upsertChat(updated)
        await syncCalendarState()

        let responderName = profile?.displayName.isEmpty == false
            ? (profile?.displayName ?? "Your match")
            : "Your match"
        try await enqueuePush(
            recipientIds: [chat.otherPartyId(for: userId)],
            title: accept ? "Coffee chat confirmed" : "Time declined",
            body: accept
                ? "\(responderName) confirmed \(chat.dayLabel) · \(chat.timeLabel)"
                : "\(responderName) can't make \(chat.dayLabel) · \(chat.timeLabel). Try another time.",
            chatId: chat.id
        )
    }

    /// Moves an existing chat to a new time. The other person has to confirm again.
    func rescheduleChat(
        _ chat: CoffeeChat,
        startsAt: Date,
        endsAt: Date,
        dayLabel: String,
        timeLabel: String
    ) async throws {
        guard let userId else { throw RepositoryError.notSignedIn }
        guard chat.participantIds.contains(userId) else { throw RepositoryError.notAllowed }
        guard chat.isActive else { throw RepositoryError.chatNotActive }

        var updated = chat
        updated.startsAt = startsAt
        updated.endsAt = endsAt
        updated.dayLabel = dayLabel
        updated.timeLabel = timeLabel
        updated.status = CoffeeChat.Status.proposed.rawValue
        updated.proposedById = userId
        updated.respondedAt = nil
        updated.updatedAt = Date()
        try await saveChat(updated)
        upsertChat(updated)
        await syncCalendarState()

        let myName = profile?.displayName.isEmpty == false
            ? (profile?.displayName ?? "Your match")
            : "Your match"
        try await enqueuePush(
            recipientIds: [chat.otherPartyId(for: userId)],
            title: "New time proposed",
            body: "\(myName) moved your coffee chat to \(dayLabel) · \(timeLabel)",
            chatId: chat.id
        )
    }

    /// Calls off a chat for both people and clears the local calendar entry.
    func cancelChat(_ chat: CoffeeChat, reason: String?) async throws {
        guard let userId else { throw RepositoryError.notSignedIn }
        guard chat.participantIds.contains(userId) else { throw RepositoryError.notAllowed }
        guard chat.isActive else { throw RepositoryError.chatNotActive }

        let trimmedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = chat
        updated.status = CoffeeChat.Status.cancelled.rawValue
        updated.cancelledById = userId
        updated.cancellationReason = trimmedReason?.isEmpty == false ? trimmedReason : nil
        updated.updatedAt = Date()
        try await saveChat(updated)
        upsertChat(updated)
        await syncCalendarState()

        let myName = profile?.displayName.isEmpty == false
            ? (profile?.displayName ?? "Your match")
            : "Your match"
        let detail = updated.cancellationReason.map { " — \($0)" } ?? ""
        try await enqueuePush(
            recipientIds: [chat.otherPartyId(for: userId)],
            title: "Coffee chat cancelled",
            body: "\(myName) cancelled \(chat.dayLabel) · \(chat.timeLabel)\(detail)",
            chatId: chat.id
        )
    }

    /// Brings this device's calendar and reminders in line with the shared chat
    /// state, in both directions: confirmed chats get an entry, and anything the
    /// other person cancelled, declined, or moved has its entry taken back out.
    func syncCalendarState() async {
        guard let userId else { return }

        for chat in chats {
            let existingEventId = calendarEventId(for: chat.id)
            let shouldBeOnCalendar = chat.isConfirmed
                && (chat.startsAt.map { $0 > Date() } ?? false)

            if shouldBeOnCalendar {
                guard existingEventId == nil, let startsAt = chat.startsAt else { continue }
                let other = chat.otherPartyName(for: userId)
                let endsAt = chat.endsAt ?? startsAt.addingTimeInterval(45 * 60)

                if let eventId = try? await CalendarInviteService.shared.createEvent(
                    title: "FoundryMeet coffee with \(other)",
                    notes: chat.talkingPoints.isEmpty ? "Coffee chat via FoundryMeet" : chat.talkingPoints,
                    location: chat.setting,
                    startsAt: startsAt,
                    endsAt: endsAt
                ) {
                    setCalendarEventId(eventId, for: chat.id)
                } else {
                    // Calendar access denied — the in-app reminder still stands.
                    setCalendarEventId("", for: chat.id)
                }

                PushNotificationService.shared.scheduleChatReminder(
                    chatId: chat.id,
                    title: "Coffee with \(other) in 15 minutes",
                    startsAt: startsAt
                )
            } else if let existingEventId {
                if !existingEventId.isEmpty {
                    await CalendarInviteService.shared.removeEvent(identifier: existingEventId)
                }
                PushNotificationService.shared.cancelChatReminder(chatId: chat.id)
                setCalendarEventId(nil, for: chat.id)
            }
        }
    }

    func enqueuePush(
        recipientIds: [String],
        title: String,
        body: String,
        chatId: String? = nil,
        threadId: String? = nil
    ) async throws {
        let recipients = recipientIds.filter { !$0.isEmpty }
        guard !recipients.isEmpty else { return }

        if usesLocalStore {
            // Debug: surface as a local banner-style notification for the current user when testing alone.
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "local-push-\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
            return
        }

        var data: [String: Any] = [
            "recipientIds": recipients,
            "title": title,
            "body": body,
            "status": "pending",
            "createdAt": Timestamp(date: Date())
        ]
        if let chatId { data["chatId"] = chatId }
        if let threadId { data["threadId"] = threadId }
        try await db.collection("pushOutbox").document(UUID().uuidString).setData(data, merge: true)
    }

    /// Each device creates its own calendar event, so the identifier is kept
    /// locally rather than in the shared chat document.
    private func calendarEventsKey() -> String {
        "calendarEventIds_\(userId ?? "none")"
    }

    private func calendarEventId(for chatId: String) -> String? {
        let map = UserDefaults.standard.dictionary(forKey: calendarEventsKey()) as? [String: String]
        return map?[chatId]
    }

    private func setCalendarEventId(_ eventId: String?, for chatId: String) {
        var map = (UserDefaults.standard.dictionary(forKey: calendarEventsKey()) as? [String: String]) ?? [:]
        if let eventId {
            map[chatId] = eventId
        } else {
            map.removeValue(forKey: chatId)
        }
        UserDefaults.standard.set(map, forKey: calendarEventsKey())
    }

    private func upsertChat(_ chat: CoffeeChat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[index] = chat
        } else {
            chats.insert(chat, at: 0)
        }
        chats.sort { $0.createdAt > $1.createdAt }
    }

    private func upsertMatchRequest(_ request: MatchRequest) {
        if let index = matchRequests.firstIndex(where: { $0.id == request.id }) {
            matchRequests[index] = request
        } else {
            matchRequests.insert(request, at: 0)
        }
    }

    private func saveCredentialReview(_ review: CredentialReview) async throws {
        if usesLocalStore {
            var all = (try? readLocal(key: "credential_reviews", as: [CredentialReview].self)) ?? []
            all.removeAll { $0.id == review.id }
            all.insert(review, at: 0)
            try writeLocal(all, key: "credential_reviews")
            return
        }
        try await db.collection("credentialReviews").document(review.id).setData(review.firestoreData, merge: true)
    }

    func hasCompletedOnboarding(for userId: String) -> Bool {
        if let profile, profile.id == userId {
            return profile.onboardingCompleted
        }
        return UserDefaults.standard.bool(forKey: onboardingKey(for: userId))
    }

    func setFilters(_ filters: DiscoveryFilters) {
        self.filters = filters
        Task { await rebuildDiscoveryFeed() }
    }

    func refreshAll() async throws {
        guard let userId else { return }
        async let interactionsTask = loadInteractions(userId: userId)
        async let matchesTask = loadMatchRequests(userId: userId)
        async let chatsTask = loadChats(userId: userId)
        async let networkTask = loadNetworkProfiles(excluding: userId)
        async let threadsTask = loadThreads(userId: userId)

        let interactions = try await interactionsTask
        matchRequests = try await matchesTask
        chats = try await chatsTask
        networkProfiles = try await networkTask
        threads = try await threadsTask
        // Keep live sync attached after every refresh (covers first launch races).
        if listeners.isEmpty {
            startRealtimeSync()
        }
        excludedCandidateIds = Set(interactions.map(\.candidateId))
            .union(matchRequests.filter { !$0.isDeclined }.map { $0.otherPartyId(for: userId) })
        await rebuildDiscoveryFeed()
        await syncCalendarState()
    }

    private func rebuildDiscoveryFeed() async {
        guard let userId else { return }
        var candidates = networkProfiles
            .filter { $0.isDiscoverable && $0.onboardingCompleted && $0.id != userId }
            .map(DiscoveryCandidate.init(profile:))
        // Sample profiles have no account behind them, so they only stand in for
        // an empty directory in the local debug store.
        if candidates.isEmpty && usesLocalStore {
            candidates = SeedCatalog.candidates.filter { $0.id != userId }
        }
        candidates = candidates.filter { !excludedCandidateIds.contains($0.id) }

        if let stage = filters.stage, !stage.isEmpty {
            candidates = candidates.filter { StartupStage.stages($0.stages, match: stage) }
        }
        if let industry = filters.industry, !industry.isEmpty {
            candidates = candidates.filter {
                $0.industry.localizedCaseInsensitiveContains(industry)
                    || $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(industry) })
            }
        }

        // Without a goal of your own there is nothing to complement, so the
        // filter becomes a no-op rather than blanking the feed.
        let myGoal = profile?.goal.flatMap(NetworkingGoal.init(rawValue:))?.rawValue
        let myLocation = profile?.location
        let myLat = profile?.latitude
        let myLon = profile?.longitude

        if filters.complementaryGoalsOnly, myGoal != nil {
            candidates = candidates.filter { NetworkingGoal.areComplementary(myGoal, $0.goal) }
        }
        if filters.nearbyOnly {
            candidates = candidates.filter {
                GeoDistance.isNearby(
                    myLocation: myLocation,
                    myLatitude: myLat,
                    myLongitude: myLon,
                    theirLocation: $0.location,
                    theirLatitude: $0.latitude,
                    theirLongitude: $0.longitude
                )
            }
        }

        // Complementary goals first, then closer people, then original order.
        var ranked = candidates.enumerated()
            .sorted { lhs, rhs in
                let lhsFits = NetworkingGoal.areComplementary(myGoal, lhs.element.goal)
                let rhsFits = NetworkingGoal.areComplementary(myGoal, rhs.element.goal)
                if lhsFits != rhsFits { return lhsFits }

                let lhsDistance = GeoDistance.sortKeyKilometers(
                    myLatitude: myLat,
                    myLongitude: myLon,
                    theirLatitude: lhs.element.latitude,
                    theirLongitude: lhs.element.longitude,
                    myLocation: myLocation,
                    theirLocation: lhs.element.location
                )
                let rhsDistance = GeoDistance.sortKeyKilometers(
                    myLatitude: myLat,
                    myLongitude: myLon,
                    theirLatitude: rhs.element.latitude,
                    theirLongitude: rhs.element.longitude,
                    myLocation: myLocation,
                    theirLocation: rhs.element.location
                )
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        // Pin the interactive demo partner so testers can always run the full loop.
        let demo = DemoPartner.candidate(for: profile)
        if !excludedCandidateIds.contains(demo.id) {
            ranked.removeAll { $0.id == demo.id }
            ranked.insert(demo, at: 0)
        }
        discoveryFeed = ranked
    }

    func dismissCandidate(_ candidate: DiscoveryCandidate) async throws {
        try await recordInteraction(
            candidateId: candidate.id,
            candidateName: candidate.name,
            candidateRole: candidate.role,
            action: .dismissed
        )
        excludedCandidateIds.insert(candidate.id)
        discoveryFeed.removeAll { $0.id == candidate.id }
    }

    // MARK: - Match requests

    /// Sends a coffee chat request. If that person already asked me, this counts
    /// as accepting theirs instead of opening a second request.
    func requestMatch(with candidate: DiscoveryCandidate, note: String = "") async throws {
        guard let userId, let me = profile else { throw RepositoryError.notSignedIn }
        guard candidate.id != userId else { throw RepositoryError.invalidInput }
        if DemoPartner.isDemo(candidate.id) {
            try await connectWithDemoPartner(candidate, note: note)
            return
        }
        guard !candidate.isSeed || usesLocalStore else { throw RepositoryError.sampleProfile }

        if let existing = matchRequests.first(where: { $0.id == MatchRequest.pairId(userId, candidate.id) }) {
            if existing.isPending && existing.isIncoming(for: userId) {
                try await respondToRequest(existing, accept: true)
                return
            }
            if existing.isPending || existing.isAccepted {
                throw RepositoryError.duplicateRequest
            }
        }

        let request = MatchRequest(
            requesterId: userId,
            requesterName: me.displayName.isEmpty ? "Founder" : me.displayName,
            requesterRole: me.role ?? "Founder",
            recipientId: candidate.id,
            recipientName: candidate.name,
            recipientRole: candidate.role,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try await saveMatchRequest(request)
        upsertMatchRequest(request)

        try await recordInteraction(
            candidateId: candidate.id,
            candidateName: candidate.name,
            candidateRole: candidate.role,
            action: .connected
        )
        excludedCandidateIds.insert(candidate.id)
        discoveryFeed.removeAll { $0.id == candidate.id }

        try await enqueuePush(
            recipientIds: [candidate.id],
            title: "New coffee chat request",
            body: "\(request.requesterName) would like to grab coffee."
        )
    }

    /// Demo partner auto-accepts, opens chat, and drops a welcome message so the
    /// full coffee-chat loop can be tested without a second device.
    private func connectWithDemoPartner(_ candidate: DiscoveryCandidate, note: String) async throws {
        guard let userId, let me = profile else { throw RepositoryError.notSignedIn }

        if let existing = matchRequests.first(where: { $0.id == MatchRequest.pairId(userId, candidate.id) }),
           existing.isAccepted {
            throw RepositoryError.duplicateRequest
        }

        let request = MatchRequest(
            requesterId: userId,
            requesterName: me.displayName.isEmpty ? "Founder" : me.displayName,
            requesterRole: me.role ?? "Founder",
            recipientId: candidate.id,
            recipientName: candidate.name,
            recipientRole: candidate.role,
            status: .accepted,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try await saveMatchRequest(request)
        upsertMatchRequest(request)

        try await recordInteraction(
            candidateId: candidate.id,
            candidateName: candidate.name,
            candidateRole: candidate.role,
            action: .connected
        )
        excludedCandidateIds.insert(candidate.id)
        discoveryFeed.removeAll { $0.id == candidate.id }

        let thread = try await openOrCreateThread(with: candidate)
        let welcome = ChatMessage(
            id: UUID().uuidString,
            threadId: thread.id,
            senderId: DemoPartner.id,
            text: DemoPartner.welcomeMessage,
            createdAt: Date()
        )
        try await saveMessage(welcome)
        if var updated = threads.first(where: { $0.id == thread.id }) {
            updated.lastMessage = welcome.text
            updated.updatedAt = Date()
            try await saveThread(updated)
            if let index = threads.firstIndex(where: { $0.id == updated.id }) {
                threads[index] = updated
            }
        }
    }

    /// Accepts or declines a request addressed to me.
    func respondToRequest(_ request: MatchRequest, accept: Bool) async throws {
        guard let userId else { throw RepositoryError.notSignedIn }
        guard request.isIncoming(for: userId) else { throw RepositoryError.notAllowed }
        guard request.isPending else { throw RepositoryError.requestAlreadyAnswered }

        var updated = request
        updated.status = accept
            ? MatchRequest.Status.accepted.rawValue
            : MatchRequest.Status.declined.rawValue
        updated.updatedAt = Date()
        try await saveMatchRequest(updated)
        upsertMatchRequest(updated)

        // Keep them out of my feed either way; a decline still leaves the door
        // open for me to reach out later.
        try await recordInteraction(
            candidateId: request.requesterId,
            candidateName: request.requesterName,
            candidateRole: request.requesterRole,
            action: accept ? .connected : .dismissed
        )
        excludedCandidateIds.insert(request.requesterId)
        discoveryFeed.removeAll { $0.id == request.requesterId }

        // A decline stays silent; the requester sees it in their own list.
        guard accept else { return }
        try await enqueuePush(
            recipientIds: [request.requesterId],
            title: "Request accepted",
            body: "\(updated.recipientName) accepted your coffee chat request. Pick a time."
        )
    }

    /// Pulls back a request I sent before it was answered.
    func withdrawRequest(_ request: MatchRequest) async throws {
        guard let userId else { throw RepositoryError.notSignedIn }
        guard request.requesterId == userId else { throw RepositoryError.notAllowed }
        guard request.isPending else { throw RepositoryError.requestAlreadyAnswered }

        var updated = request
        updated.status = MatchRequest.Status.withdrawn.rawValue
        updated.updatedAt = Date()
        try await saveMatchRequest(updated)
        upsertMatchRequest(updated)
    }

    func updateChatNotes(chatId: String, notes: String) async throws {
        guard let userId else { throw RepositoryError.notSignedIn }
        guard var chat = chats.first(where: { $0.id == chatId }) else {
            throw RepositoryError.notFound
        }
        guard chat.participantIds.contains(userId) else { throw RepositoryError.notAllowed }
        chat.privateNotes[userId] = notes
        // Clear legacy shared notes once per-user storage is in use.
        chat.notes = ""
        chat.updatedAt = Date()
        try await saveChat(chat)
        upsertChat(chat)
    }

    /// Records how the coffee went for this user. Each participant keeps their
    /// own answer on the shared chat document.
    func submitChatOutcome(_ chat: CoffeeChat, outcome: CoffeeChat.MeetingOutcome) async throws {
        guard let userId else { throw RepositoryError.notSignedIn }
        guard chat.participantIds.contains(userId) else { throw RepositoryError.notAllowed }
        guard chat.needsOutcome else { throw RepositoryError.chatNotActive }
        var updated = chats.first(where: { $0.id == chat.id }) ?? chat
        updated.outcomes[userId] = outcome.rawValue
        updated.updatedAt = Date()
        try await saveChat(updated)
        upsertChat(updated)
    }

    // MARK: - Messaging

    func openOrCreateThread(with candidate: DiscoveryCandidate) async throws -> MessageThread {
        guard let userId, let me = profile else { throw RepositoryError.notSignedIn }
        let sortedIds = [userId, candidate.id].sorted()
        let threadId = sortedIds.joined(separator: "_")

        if let existing = threads.first(where: { $0.id == threadId }) {
            return existing
        }

        let thread = MessageThread(
            id: threadId,
            participantIds: sortedIds,
            participantNames: [
                userId: me.displayName,
                candidate.id: candidate.name
            ],
            lastMessage: "",
            updatedAt: Date()
        )
        try await saveThread(thread)
        threads.insert(thread, at: 0)
        return thread
    }

    func loadMessages(threadId: String) async throws -> [ChatMessage] {
        if usesLocalStore {
            let all = (try? readLocal(key: "messages_\(threadId)", as: [ChatMessage].self)) ?? []
            return all.sorted { $0.createdAt < $1.createdAt }
        }
        let snapshot = try await db.collection("threads").document(threadId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { ChatMessage(id: $0.documentID, firestoreData: $0.data()) }
    }

    func sendMessage(threadId: String, text: String) async throws -> ChatMessage {
        guard let userId else { throw RepositoryError.notSignedIn }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RepositoryError.invalidInput }

        let message = ChatMessage(
            id: UUID().uuidString,
            threadId: threadId,
            senderId: userId,
            text: trimmed,
            createdAt: Date()
        )
        try await saveMessage(message)

        if var thread = threads.first(where: { $0.id == threadId }) {
            thread.lastMessage = trimmed
            thread.updatedAt = Date()
            try await saveThread(thread)
            if let index = threads.firstIndex(where: { $0.id == threadId }) {
                threads[index] = thread
                threads.sort { $0.updatedAt > $1.updatedAt }
            }

            // Queue push for other participants (Cloud Function delivers via FCM).
            let recipients = thread.participantIds.filter { $0 != userId }
            if !usesLocalStore, !recipients.isEmpty, !recipients.contains(where: DemoPartner.isDemo) {
                let title = profile?.displayName.isEmpty == false ? (profile?.displayName ?? "New message") : "New message"
                try? await db.collection("pushOutbox").document(UUID().uuidString).setData([
                    "recipientIds": recipients,
                    "title": title,
                    "body": trimmed,
                    "threadId": threadId,
                    "status": "pending",
                    "createdAt": Timestamp(date: Date())
                ], merge: true)
            }

            if recipients.contains(where: DemoPartner.isDemo) {
                let reply = ChatMessage(
                    id: UUID().uuidString,
                    threadId: threadId,
                    senderId: DemoPartner.id,
                    text: DemoPartner.autoReply(to: trimmed),
                    createdAt: Date().addingTimeInterval(0.5)
                )
                try await saveMessage(reply)
                thread.lastMessage = reply.text
                thread.updatedAt = reply.createdAt
                try await saveThread(thread)
                if let index = threads.firstIndex(where: { $0.id == threadId }) {
                    threads[index] = thread
                    threads.sort { $0.updatedAt > $1.updatedAt }
                }
            }
        }
        return message
    }

    // MARK: - Persistence

    private func saveProfile(_ profile: UserProfile) async throws {
        if usesLocalStore {
            try writeLocal(profile, key: "profile_\(profile.id)")
            // Keep discoverable users in the shared network directory.
            var network = (try? readLocal(key: "network_directory", as: [UserProfile].self)) ?? []
            network.removeAll { $0.id == profile.id }
            if profile.isDiscoverable && profile.onboardingCompleted {
                network.append(profile)
            }
            try writeLocal(network, key: "network_directory")
            return
        }
        try await db.collection("users").document(profile.id).setData(profile.firestoreData, merge: true)
    }

    private func loadProfile(userId: String) async throws -> UserProfile? {
        if usesLocalStore {
            return try readLocal(key: "profile_\(userId)", as: UserProfile.self)
        }
        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let data = snapshot.data() else { return nil }
        return UserProfile(id: userId, firestoreData: data)
    }

    private func loadNetworkProfiles(excluding userId: String) async throws -> [UserProfile] {
        if usesLocalStore {
            let network = (try? readLocal(key: "network_directory", as: [UserProfile].self)) ?? []
            return network.filter { $0.id != userId }
        }
        let snapshot = try await db.collection("users")
            .whereField("onboardingCompleted", isEqualTo: true)
            .getDocuments()
        return snapshot.documents
            .compactMap { UserProfile(id: $0.documentID, firestoreData: $0.data()) }
            .filter { $0.id != userId && $0.isDiscoverable }
    }

    private func recordInteraction(
        candidateId: String,
        candidateName: String,
        candidateRole: String,
        action: InteractionAction
    ) async throws {
        guard let userId else { throw RepositoryError.notSignedIn }
        let interaction = ProfileInteraction(
            id: candidateId,
            candidateId: candidateId,
            candidateName: candidateName,
            candidateRole: candidateRole,
            action: action,
            createdAt: Date()
        )
        if usesLocalStore {
            var all = (try? readLocal(key: "interactions_\(userId)", as: [ProfileInteraction].self)) ?? []
            all.removeAll { $0.id == interaction.id }
            all.append(interaction)
            try writeLocal(all, key: "interactions_\(userId)")
            return
        }
        try await db.collection("users").document(userId)
            .collection("interactions").document(candidateId)
            .setData(interaction.firestoreData, merge: true)
    }

    private func loadInteractions(userId: String) async throws -> [ProfileInteraction] {
        if usesLocalStore {
            return (try? readLocal(key: "interactions_\(userId)", as: [ProfileInteraction].self)) ?? []
        }
        let snapshot = try await db.collection("users").document(userId)
            .collection("interactions").getDocuments()
        return snapshot.documents.compactMap { ProfileInteraction(id: $0.documentID, firestoreData: $0.data()) }
    }

    private func saveMatchRequest(_ request: MatchRequest) async throws {
        if usesLocalStore {
            var all = (try? readLocal(key: "match_requests_shared", as: [MatchRequest].self)) ?? []
            all.removeAll { $0.id == request.id }
            all.insert(request, at: 0)
            try writeLocal(all, key: "match_requests_shared")
            return
        }
        try await db.collection("matches").document(request.id).setData(request.firestoreData, merge: true)
    }

    private func loadMatchRequests(userId: String) async throws -> [MatchRequest] {
        if usesLocalStore {
            let all = (try? readLocal(key: "match_requests_shared", as: [MatchRequest].self)) ?? []
            return all
                .filter { $0.participantIds.contains(userId) }
                .sorted { $0.updatedAt > $1.updatedAt }
        }
        let snapshot = try await db.collection("matches")
            .whereField("participantIds", arrayContains: userId)
            .getDocuments()
        return snapshot.documents
            .compactMap { MatchRequest(id: $0.documentID, firestoreData: $0.data()) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func saveChat(_ chat: CoffeeChat) async throws {
        if usesLocalStore {
            var all = (try? readLocal(key: "chats_shared", as: [CoffeeChat].self)) ?? []
            all.removeAll { $0.id == chat.id }
            all.insert(chat, at: 0)
            try writeLocal(all, key: "chats_shared")
            return
        }
        try await db.collection("chats").document(chat.id).setData(chat.firestoreData, merge: true)
    }

    private func loadChats(userId: String) async throws -> [CoffeeChat] {
        if usesLocalStore {
            let all = (try? readLocal(key: "chats_shared", as: [CoffeeChat].self)) ?? []
            return all
                .filter { $0.participantIds.contains(userId) || $0.userId == userId || $0.candidateId == userId }
                .sorted { $0.createdAt > $1.createdAt }
        }
        let snapshot = try await db.collection("chats")
            .whereField("participantIds", arrayContains: userId)
            .getDocuments()
        return snapshot.documents
            .compactMap { CoffeeChat(id: $0.documentID, firestoreData: $0.data()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func saveThread(_ thread: MessageThread) async throws {
        if usesLocalStore {
            var all = (try? readLocal(key: "threads", as: [MessageThread].self)) ?? []
            all.removeAll { $0.id == thread.id }
            all.insert(thread, at: 0)
            try writeLocal(all, key: "threads")
            return
        }
        try await db.collection("threads").document(thread.id).setData(thread.firestoreData, merge: true)
    }

    private func loadThreads(userId: String) async throws -> [MessageThread] {
        if usesLocalStore {
            let all = (try? readLocal(key: "threads", as: [MessageThread].self)) ?? []
            return all
                .filter { $0.participantIds.contains(userId) }
                .sorted { $0.updatedAt > $1.updatedAt }
        }
        let snapshot = try await db.collection("threads")
            .whereField("participantIds", arrayContains: userId)
            .getDocuments()
        return snapshot.documents
            .compactMap { MessageThread(id: $0.documentID, firestoreData: $0.data()) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func saveMessage(_ message: ChatMessage) async throws {
        if usesLocalStore {
            var all = (try? readLocal(key: "messages_\(message.threadId)", as: [ChatMessage].self)) ?? []
            all.append(message)
            try writeLocal(all, key: "messages_\(message.threadId)")
            return
        }
        try await db.collection("threads").document(message.threadId)
            .collection("messages").document(message.id)
            .setData(message.firestoreData, merge: true)
    }

    private func ensureLocalNetworkSeed() throws {
        let existing = (try? readLocal(key: "network_directory", as: [UserProfile].self)) ?? []
        guard existing.isEmpty else { return }
        let seeded = SeedCatalog.candidates.map { candidate -> UserProfile in
            UserProfile(
                id: candidate.id,
                email: "\(candidate.id)@foundrymeet.demo",
                displayName: candidate.name,
                role: candidate.role,
                location: "Remote",
                stages: candidate.stages.isEmpty ? [StartupStage.seed.rawValue] : candidate.stages,
                skills: candidate.tags,
                goal: candidate.goal ?? "Get Advice",
                bio: candidate.desc,
                industry: candidate.industry,
                credentials: [
                    VerifiedCredential(
                        title: "Founder credential",
                        issuer: "FoundryMeet",
                        url: "https://foundrymeet.com",
                        status: "verified"
                    )
                ],
                isDiscoverable: true,
                onboardingCompleted: true
            )
        }
        try writeLocal(seeded, key: "network_directory")
    }

    // MARK: - Local JSON helpers

    private func localURL(key: String) throws -> URL {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("FoundryMeetData", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(key).json")
    }

    private func writeLocal<T: Encodable>(_ value: T, key: String) throws {
        let data = try encoder.encode(value)
        try data.write(to: try localURL(key: key), options: .atomic)
    }

    private func readLocal<T: Decodable>(key: String, as type: T.Type) throws -> T? {
        let url = try localURL(key: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private func onboardingKey(for userId: String) -> String {
        "hasSeenOnboarding_\(userId)"
    }
}

enum RepositoryError: LocalizedError {
    case notSignedIn
    case notFound
    case invalidInput
    case notAllowed
    case duplicateRequest
    case requestAlreadyAnswered
    case matchNotAccepted
    case chatNotActive
    case sampleProfile
    case reauthenticationRequired

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You need to be signed in."
        case .notFound: return "Item not found."
        case .invalidInput: return "Please enter a valid value."
        case .notAllowed: return "You can't do that on this request."
        case .duplicateRequest: return "You already have a request open with this person."
        case .requestAlreadyAnswered: return "This request was already answered."
        case .matchNotAccepted: return "Wait for the request to be accepted before picking a time."
        case .chatNotActive: return "This coffee chat is no longer active."
        case .sampleProfile: return "This is a sample profile and can't receive requests."
        case .reauthenticationRequired:
            return "For security, sign out, sign back in, then delete your account again."
        }
    }
}

// MARK: - Firestore mapping

extension UserProfile {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "email": email,
            "displayName": displayName,
            "skills": skills,
            "credentials": credentials.map(\.firestoreData),
            "availability": availability.map(\.firestoreData),
            // fcmTokens are written only by PushNotificationService via arrayUnion —
            // never overwrite them from a profile save (that was wiping push).
            "isReviewer": isReviewer,
            "isDiscoverable": isDiscoverable,
            "onboardingCompleted": onboardingCompleted,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
        if let role { data["role"] = role }
        if let location { data["location"] = location }
        if let latitude { data["latitude"] = latitude }
        if let longitude { data["longitude"] = longitude }
        if !stages.isEmpty {
            data["stages"] = stages
            data["stage"] = stages[0]
        }
        if let goal { data["goal"] = goal }
        if let bio { data["bio"] = bio }
        if let buildingIdea { data["buildingIdea"] = buildingIdea }
        if let linkedInURL { data["linkedInURL"] = linkedInURL }
        if let industry { data["industry"] = industry }
        if let photoURL { data["photoURL"] = photoURL }
        return data
    }

    init(id: String, firestoreData data: [String: Any]) {
        let credentialMaps = data["credentials"] as? [[String: Any]] ?? []
        let availabilityMaps = data["availability"] as? [[String: Any]] ?? []
        let windows = availabilityMaps.compactMap(AvailabilityWindow.init(firestoreData:))
        self.init(
            id: id,
            email: data["email"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "",
            role: data["role"] as? String,
            location: data["location"] as? String,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            // Documents written before multi-stage support only carry `stage`.
            stages: UserProfile.normalizedStages(
                data["stages"] as? [String] ?? [data["stage"] as? String].compactMap { $0 }
            ),
            skills: data["skills"] as? [String] ?? [],
            goal: data["goal"] as? String,
            bio: data["bio"] as? String,
            buildingIdea: data["buildingIdea"] as? String,
            linkedInURL: data["linkedInURL"] as? String,
            industry: UserProfile.normalizedIndustry(data["industry"] as? String),
            credentials: credentialMaps.compactMap(VerifiedCredential.init(firestoreData:)),
            availability: windows.isEmpty ? AvailabilityWindow.defaultWorkWeek : windows,
            photoURL: data["photoURL"] as? String,
            fcmTokens: data["fcmTokens"] as? [String] ?? [],
            isReviewer: data["isReviewer"] as? Bool ?? false,
            isDiscoverable: data["isDiscoverable"] as? Bool ?? true,
            onboardingCompleted: data["onboardingCompleted"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

extension AvailabilityWindow {
    var firestoreData: [String: Any] {
        [
            "id": id,
            "weekday": weekday,
            "startMinutes": startMinutes,
            "endMinutes": endMinutes
        ]
    }

    init?(firestoreData data: [String: Any]) {
        guard
            let weekday = data["weekday"] as? Int,
            let startMinutes = data["startMinutes"] as? Int,
            let endMinutes = data["endMinutes"] as? Int
        else { return nil }
        self.init(
            id: data["id"] as? String ?? UUID().uuidString,
            weekday: weekday,
            startMinutes: startMinutes,
            endMinutes: endMinutes
        )
    }
}

extension VerifiedCredential {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "title": title,
            "issuer": issuer,
            "url": url,
            "status": status,
            "createdAt": Timestamp(date: createdAt)
        ]
        if let rejectionReason { data["rejectionReason"] = rejectionReason }
        if let reviewedAt { data["reviewedAt"] = Timestamp(date: reviewedAt) }
        if let reviewedBy { data["reviewedBy"] = reviewedBy }
        return data
    }

    init?(firestoreData data: [String: Any]) {
        guard
            let id = data["id"] as? String,
            let title = data["title"] as? String,
            let issuer = data["issuer"] as? String,
            let url = data["url"] as? String,
            let status = data["status"] as? String
        else { return nil }
        self.init(
            id: id,
            title: title,
            issuer: issuer,
            url: url,
            status: status,
            rejectionReason: data["rejectionReason"] as? String,
            reviewedAt: (data["reviewedAt"] as? Timestamp)?.dateValue(),
            reviewedBy: data["reviewedBy"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

private extension ProfileInteraction {
    var firestoreData: [String: Any] {
        [
            "candidateId": candidateId,
            "candidateName": candidateName,
            "candidateRole": candidateRole,
            "action": action.rawValue,
            "createdAt": Timestamp(date: createdAt)
        ]
    }

    init?(id: String, firestoreData data: [String: Any]) {
        guard
            let candidateId = data["candidateId"] as? String,
            let candidateName = data["candidateName"] as? String,
            let candidateRole = data["candidateRole"] as? String,
            let actionRaw = data["action"] as? String,
            let action = InteractionAction(rawValue: actionRaw)
        else { return nil }
        self.init(
            id: id,
            candidateId: candidateId,
            candidateName: candidateName,
            candidateRole: candidateRole,
            action: action,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

extension MatchRequest {
    var firestoreData: [String: Any] {
        [
            "requesterId": requesterId,
            "requesterName": requesterName,
            "requesterRole": requesterRole,
            "recipientId": recipientId,
            "recipientName": recipientName,
            "recipientRole": recipientRole,
            "participantIds": participantIds,
            "status": status,
            "note": note,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }

    init?(id: String, firestoreData data: [String: Any]) {
        guard
            let requesterId = data["requesterId"] as? String,
            let recipientId = data["recipientId"] as? String,
            let status = data["status"] as? String
        else { return nil }
        self.init(
            requesterId: requesterId,
            requesterName: data["requesterName"] as? String ?? "",
            requesterRole: data["requesterRole"] as? String ?? "Founder",
            recipientId: recipientId,
            recipientName: data["recipientName"] as? String ?? "",
            recipientRole: data["recipientRole"] as? String ?? "Founder",
            status: Status(rawValue: status) ?? .pending,
            note: data["note"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
        self.id = id
    }
}

private extension CoffeeChat {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "candidateId": candidateId,
            "candidateName": candidateName,
            "candidateRole": candidateRole,
            "organizerName": organizerName,
            "participantIds": participantIds,
            "dayLabel": dayLabel,
            "timeLabel": timeLabel,
            "setting": setting,
            "talkingPoints": talkingPoints,
            "notes": notes,
            "privateNotes": privateNotes,
            "status": status,
            "proposedById": proposedById,
            "inviteStatus": inviteStatus,
            "outcomes": outcomes,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
        if let startsAt { data["startsAt"] = Timestamp(date: startsAt) }
        if let endsAt { data["endsAt"] = Timestamp(date: endsAt) }
        if let calendarEventId { data["calendarEventId"] = calendarEventId }
        if let respondedAt { data["respondedAt"] = Timestamp(date: respondedAt) }
        if let cancelledById { data["cancelledById"] = cancelledById }
        if let cancellationReason { data["cancellationReason"] = cancellationReason }
        return data
    }

    init?(id: String, firestoreData data: [String: Any]) {
        guard
            let userId = data["userId"] as? String,
            let candidateId = data["candidateId"] as? String,
            let candidateName = data["candidateName"] as? String,
            let candidateRole = data["candidateRole"] as? String
        else { return nil }
        let participants = data["participantIds"] as? [String]
            ?? Array(Set([userId, candidateId])).sorted()
        self.init(
            id: id,
            userId: userId,
            candidateId: candidateId,
            candidateName: candidateName,
            candidateRole: candidateRole,
            organizerName: data["organizerName"] as? String ?? "",
            participantIds: participants,
            dayLabel: data["dayLabel"] as? String ?? "",
            timeLabel: data["timeLabel"] as? String ?? "",
            setting: data["setting"] as? String ?? "Virtual",
            talkingPoints: data["talkingPoints"] as? String ?? "",
            notes: data["notes"] as? String ?? "",
            privateNotes: data["privateNotes"] as? [String: String] ?? [:],
            status: data["status"] as? String ?? CoffeeChat.legacyConfirmedStatus,
            proposedById: data["proposedById"] as? String ?? userId,
            respondedAt: (data["respondedAt"] as? Timestamp)?.dateValue(),
            cancelledById: data["cancelledById"] as? String,
            cancellationReason: data["cancellationReason"] as? String,
            startsAt: (data["startsAt"] as? Timestamp)?.dateValue(),
            endsAt: (data["endsAt"] as? Timestamp)?.dateValue(),
            calendarEventId: data["calendarEventId"] as? String,
            inviteStatus: data["inviteStatus"] as? String ?? "none",
            outcomes: data["outcomes"] as? [String: String] ?? [:],
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

extension CredentialReview {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "userName": userName,
            "userEmail": userEmail,
            "credentialId": credentialId,
            "title": title,
            "issuer": issuer,
            "url": url,
            "status": status,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
        if let rejectionReason { data["rejectionReason"] = rejectionReason }
        if let reviewedBy { data["reviewedBy"] = reviewedBy }
        return data
    }

    init?(id: String, firestoreData data: [String: Any]) {
        guard
            let userId = data["userId"] as? String,
            let credentialId = data["credentialId"] as? String,
            let title = data["title"] as? String,
            let issuer = data["issuer"] as? String,
            let url = data["url"] as? String,
            let status = data["status"] as? String
        else { return nil }
        self.init(
            id: id,
            userId: userId,
            userName: data["userName"] as? String ?? "",
            userEmail: data["userEmail"] as? String ?? "",
            credentialId: credentialId,
            title: title,
            issuer: issuer,
            url: url,
            status: status,
            rejectionReason: data["rejectionReason"] as? String,
            reviewedBy: data["reviewedBy"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

extension MessageThread {
    var firestoreData: [String: Any] {
        [
            "participantIds": participantIds,
            "participantNames": participantNames,
            "lastMessage": lastMessage,
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }

    init?(id: String, firestoreData data: [String: Any]) {
        guard
            let participantIds = data["participantIds"] as? [String],
            let participantNames = data["participantNames"] as? [String: String]
        else { return nil }
        self.init(
            id: id,
            participantIds: participantIds,
            participantNames: participantNames,
            lastMessage: data["lastMessage"] as? String ?? "",
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

extension ChatMessage {
    var firestoreData: [String: Any] {
        [
            "threadId": threadId,
            "senderId": senderId,
            "text": text,
            "createdAt": Timestamp(date: createdAt)
        ]
    }

    init?(id: String, firestoreData data: [String: Any]) {
        guard
            let threadId = data["threadId"] as? String,
            let senderId = data["senderId"] as? String,
            let text = data["text"] as? String
        else { return nil }
        self.init(
            id: id,
            threadId: threadId,
            senderId: senderId,
            text: text,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AppRepository: ObservableObject {
    static let shared = AppRepository()

    @Published private(set) var profile: UserProfile?
    @Published private(set) var pendingMatches: [PendingMatch] = []
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

    private init() {}

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
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearSession() {
        userId = nil
        profile = nil
        pendingMatches = []
        chats = []
        discoveryFeed = []
        networkProfiles = []
        threads = []
        filters = DiscoveryFilters()
        excludedCandidateIds = []
        lastError = nil
    }

    func saveOnboarding(
        role: String?,
        location: String,
        stage: String?,
        skills: [String],
        goal: String?
    ) async throws {
        guard var current = profile, let userId else {
            throw RepositoryError.notSignedIn
        }
        current.role = role
        current.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        current.stage = stage
        current.skills = skills
        current.goal = goal
        current.industry = stage
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
        try await refreshAll()
    }

    func addCredential(title: String, issuer: String, url: String) async throws {
        guard var current = profile else { throw RepositoryError.notSignedIn }
        let credential = VerifiedCredential(title: title, issuer: issuer, url: url, status: "pending")
        current.credentials.append(credential)
        try await updateProfile(current)
    }

    func removeCredential(id: String) async throws {
        guard var current = profile else { throw RepositoryError.notSignedIn }
        current.credentials.removeAll { $0.id == id }
        try await updateProfile(current)
    }

    /// Demo helper: mark a pending credential as verified (admin flow later).
    func verifyCredential(id: String) async throws {
        guard var current = profile else { throw RepositoryError.notSignedIn }
        guard let index = current.credentials.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        current.credentials[index].status = "verified"
        try await updateProfile(current)
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
        async let matchesTask = loadPendingMatches(userId: userId)
        async let chatsTask = loadChats(userId: userId)
        async let networkTask = loadNetworkProfiles(excluding: userId)
        async let threadsTask = loadThreads(userId: userId)

        let interactions = try await interactionsTask
        pendingMatches = try await matchesTask
        chats = try await chatsTask
        networkProfiles = try await networkTask
        threads = try await threadsTask
        excludedCandidateIds = Set(interactions.map(\.candidateId))
        await rebuildDiscoveryFeed()
    }

    private func rebuildDiscoveryFeed() async {
        guard let userId else { return }
        var candidates = networkProfiles
            .filter { $0.isDiscoverable && $0.onboardingCompleted && $0.id != userId }
            .map(DiscoveryCandidate.init(profile:))
        if candidates.isEmpty {
            candidates = SeedCatalog.candidates.filter { $0.id != userId }
        }
        candidates = candidates.filter { !excludedCandidateIds.contains($0.id) }

        if let stage = filters.stage, !stage.isEmpty {
            let token = stage.replacingOccurrences(of: "+", with: "")
            candidates = candidates.filter {
                $0.stage?.localizedCaseInsensitiveContains(token) == true
                    || $0.industry.localizedCaseInsensitiveContains(token)
                    || stage == "Seed+"
            }
        }
        if let goal = filters.goal, !goal.isEmpty {
            candidates = candidates.filter {
                $0.goal?.localizedCaseInsensitiveContains(goal) == true
                    || $0.desc.localizedCaseInsensitiveContains(goal)
                    || $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(goal) })
            }
        }
        if let industry = filters.industry, !industry.isEmpty {
            candidates = candidates.filter {
                $0.industry.localizedCaseInsensitiveContains(industry)
                    || $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(industry) })
            }
        }
        discoveryFeed = candidates
    }

    func dismissCandidate(_ candidate: DiscoveryCandidate) async throws {
        try await recordInteraction(candidate, action: .dismissed)
        excludedCandidateIds.insert(candidate.id)
        discoveryFeed.removeAll { $0.id == candidate.id }
    }

    func connectCandidate(_ candidate: DiscoveryCandidate) async throws {
        guard let userId else { throw RepositoryError.notSignedIn }
        try await recordInteraction(candidate, action: .connected)
        excludedCandidateIds.insert(candidate.id)

        let match = PendingMatch(
            id: "\(userId)_\(candidate.id)",
            userId: userId,
            candidateId: candidate.id,
            candidateName: candidate.name,
            candidateRole: candidate.role,
            status: "accepted",
            createdAt: Date()
        )
        try await savePendingMatch(match)
        if !pendingMatches.contains(where: { $0.id == match.id }) {
            pendingMatches.insert(match, at: 0)
        }
        discoveryFeed.removeAll { $0.id == candidate.id }
    }

    func scheduleChat(
        for match: PendingMatch,
        dayLabel: String,
        timeLabel: String,
        setting: String,
        talkingPoints: String
    ) async throws -> CoffeeChat {
        guard let userId else { throw RepositoryError.notSignedIn }

        let chat = CoffeeChat(
            id: UUID().uuidString,
            userId: userId,
            candidateId: match.candidateId,
            candidateName: match.candidateName,
            candidateRole: match.candidateRole,
            dayLabel: dayLabel,
            timeLabel: timeLabel,
            setting: setting,
            talkingPoints: talkingPoints,
            notes: "",
            status: "scheduled",
            createdAt: Date(),
            updatedAt: Date()
        )
        try await saveChat(chat)

        var updated = match
        updated.status = "scheduled"
        try await savePendingMatch(updated)

        chats.insert(chat, at: 0)
        pendingMatches.removeAll { $0.id == match.id }
        return chat
    }

    func updateChatNotes(chatId: String, notes: String) async throws {
        guard var chat = chats.first(where: { $0.id == chatId }) else {
            throw RepositoryError.notFound
        }
        chat.notes = notes
        chat.updatedAt = Date()
        try await saveChat(chat)
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            chats[index] = chat
        }
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

    private func recordInteraction(_ candidate: DiscoveryCandidate, action: InteractionAction) async throws {
        guard let userId else { throw RepositoryError.notSignedIn }
        let interaction = ProfileInteraction(
            id: candidate.id,
            candidateId: candidate.id,
            candidateName: candidate.name,
            candidateRole: candidate.role,
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
            .collection("interactions").document(candidate.id)
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

    private func savePendingMatch(_ match: PendingMatch) async throws {
        if usesLocalStore {
            var all = (try? readLocal(key: "matches_\(match.userId)", as: [PendingMatch].self)) ?? []
            all.removeAll { $0.id == match.id }
            if match.status != "scheduled" {
                all.append(match)
            }
            try writeLocal(all, key: "matches_\(match.userId)")
            return
        }
        try await db.collection("matches").document(match.id).setData(match.firestoreData, merge: true)
    }

    private func loadPendingMatches(userId: String) async throws -> [PendingMatch] {
        if usesLocalStore {
            let all = (try? readLocal(key: "matches_\(userId)", as: [PendingMatch].self)) ?? []
            return all.filter { $0.status == "accepted" }.sorted { $0.createdAt > $1.createdAt }
        }
        let snapshot = try await db.collection("matches")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        return snapshot.documents
            .compactMap { PendingMatch(id: $0.documentID, firestoreData: $0.data()) }
            .filter { $0.status == "accepted" }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func saveChat(_ chat: CoffeeChat) async throws {
        if usesLocalStore {
            var all = (try? readLocal(key: "chats_\(chat.userId)", as: [CoffeeChat].self)) ?? []
            all.removeAll { $0.id == chat.id }
            all.insert(chat, at: 0)
            try writeLocal(all, key: "chats_\(chat.userId)")
            return
        }
        try await db.collection("chats").document(chat.id).setData(chat.firestoreData, merge: true)
    }

    private func loadChats(userId: String) async throws -> [CoffeeChat] {
        if usesLocalStore {
            let all = (try? readLocal(key: "chats_\(userId)", as: [CoffeeChat].self)) ?? []
            return all.sorted { $0.createdAt > $1.createdAt }
        }
        let snapshot = try await db.collection("chats")
            .whereField("userId", isEqualTo: userId)
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
                stage: candidate.stage ?? "Seed",
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

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You need to be signed in."
        case .notFound: return "Item not found."
        case .invalidInput: return "Please enter a valid value."
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
            "isDiscoverable": isDiscoverable,
            "onboardingCompleted": onboardingCompleted,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
        if let role { data["role"] = role }
        if let location { data["location"] = location }
        if let stage { data["stage"] = stage }
        if let goal { data["goal"] = goal }
        if let bio { data["bio"] = bio }
        if let industry { data["industry"] = industry }
        return data
    }

    init(id: String, firestoreData data: [String: Any]) {
        let credentialMaps = data["credentials"] as? [[String: Any]] ?? []
        self.init(
            id: id,
            email: data["email"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "",
            role: data["role"] as? String,
            location: data["location"] as? String,
            stage: data["stage"] as? String,
            skills: data["skills"] as? [String] ?? [],
            goal: data["goal"] as? String,
            bio: data["bio"] as? String,
            industry: data["industry"] as? String,
            credentials: credentialMaps.compactMap(VerifiedCredential.init(firestoreData:)),
            isDiscoverable: data["isDiscoverable"] as? Bool ?? true,
            onboardingCompleted: data["onboardingCompleted"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

extension VerifiedCredential {
    var firestoreData: [String: Any] {
        [
            "id": id,
            "title": title,
            "issuer": issuer,
            "url": url,
            "status": status,
            "createdAt": Timestamp(date: createdAt)
        ]
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

private extension PendingMatch {
    var firestoreData: [String: Any] {
        [
            "userId": userId,
            "candidateId": candidateId,
            "candidateName": candidateName,
            "candidateRole": candidateRole,
            "status": status,
            "createdAt": Timestamp(date: createdAt)
        ]
    }

    init?(id: String, firestoreData data: [String: Any]) {
        guard
            let userId = data["userId"] as? String,
            let candidateId = data["candidateId"] as? String,
            let candidateName = data["candidateName"] as? String,
            let candidateRole = data["candidateRole"] as? String,
            let status = data["status"] as? String
        else { return nil }
        self.init(
            id: id,
            userId: userId,
            candidateId: candidateId,
            candidateName: candidateName,
            candidateRole: candidateRole,
            status: status,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

private extension CoffeeChat {
    var firestoreData: [String: Any] {
        [
            "userId": userId,
            "candidateId": candidateId,
            "candidateName": candidateName,
            "candidateRole": candidateRole,
            "dayLabel": dayLabel,
            "timeLabel": timeLabel,
            "setting": setting,
            "talkingPoints": talkingPoints,
            "notes": notes,
            "status": status,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }

    init?(id: String, firestoreData data: [String: Any]) {
        guard
            let userId = data["userId"] as? String,
            let candidateId = data["candidateId"] as? String,
            let candidateName = data["candidateName"] as? String,
            let candidateRole = data["candidateRole"] as? String
        else { return nil }
        self.init(
            id: id,
            userId: userId,
            candidateId: candidateId,
            candidateName: candidateName,
            candidateRole: candidateRole,
            dayLabel: data["dayLabel"] as? String ?? "",
            timeLabel: data["timeLabel"] as? String ?? "",
            setting: data["setting"] as? String ?? "Virtual",
            talkingPoints: data["talkingPoints"] as? String ?? "",
            notes: data["notes"] as? String ?? "",
            status: data["status"] as? String ?? "scheduled",
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

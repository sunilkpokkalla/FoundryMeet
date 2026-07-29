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
    private var usesLocalStore = false

    private init() {}

    func configure(userId: String, email: String, displayName: String, useLocalStore: Bool) async {
        self.userId = userId
        self.usesLocalStore = useLocalStore
        lastError = nil

        do {
            if var existing = try await loadProfile(userId: userId) {
                if existing.email.isEmpty {
                    existing.email = email
                }
                if existing.displayName.isEmpty {
                    existing.displayName = displayName.isEmpty ? email.components(separatedBy: "@").first ?? "Founder" : displayName
                }
                profile = existing
            } else {
                let created = UserProfile(
                    id: userId,
                    email: email,
                    displayName: displayName.isEmpty ? (email.components(separatedBy: "@").first ?? "Founder") : displayName
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
        current.onboardingCompleted = true
        current.updatedAt = Date()
        try await saveProfile(current)
        profile = current
        UserDefaults.standard.set(true, forKey: onboardingKey(for: userId))
    }

    func hasCompletedOnboarding(for userId: String) -> Bool {
        if let profile, profile.id == userId {
            return profile.onboardingCompleted
        }
        return UserDefaults.standard.bool(forKey: onboardingKey(for: userId))
    }

    func refreshAll() async throws {
        guard let userId else { return }
        async let interactionsTask = loadInteractions(userId: userId)
        async let matchesTask = loadPendingMatches(userId: userId)
        async let chatsTask = loadChats(userId: userId)

        let interactions = try await interactionsTask
        pendingMatches = try await matchesTask
        chats = try await chatsTask

        let actedOn = Set(interactions.map(\.candidateId))
        discoveryFeed = SeedCatalog.candidates.filter { !actedOn.contains($0.id) }
    }

    func dismissCandidate(_ candidate: DiscoveryCandidate) async throws {
        try await recordInteraction(candidate, action: .dismissed)
        discoveryFeed.removeAll { $0.id == candidate.id }
    }

    func connectCandidate(_ candidate: DiscoveryCandidate) async throws {
        guard let userId else { throw RepositoryError.notSignedIn }
        try await recordInteraction(candidate, action: .connected)

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

    // MARK: - Persistence

    private func saveProfile(_ profile: UserProfile) async throws {
        if usesLocalStore {
            try writeLocal(profile, key: "profile_\(profile.id)")
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

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You need to be signed in."
        case .notFound: return "Item not found."
        }
    }
}

// MARK: - Firestore mapping

private extension UserProfile {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "email": email,
            "displayName": displayName,
            "skills": skills,
            "onboardingCompleted": onboardingCompleted,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
        if let role { data["role"] = role }
        if let location { data["location"] = location }
        if let stage { data["stage"] = stage }
        if let goal { data["goal"] = goal }
        return data
    }

    init(id: String, firestoreData data: [String: Any]) {
        self.init(
            id: id,
            email: data["email"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "",
            role: data["role"] as? String,
            location: data["location"] as? String,
            stage: data["stage"] as? String,
            skills: data["skills"] as? [String] ?? [],
            goal: data["goal"] as? String,
            onboardingCompleted: data["onboardingCompleted"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
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

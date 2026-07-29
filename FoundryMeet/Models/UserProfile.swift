import Foundation

struct VerifiedCredential: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var issuer: String
    var url: String
    /// pending | verified | rejected
    var status: String
    var createdAt: Date

    var isVerified: Bool { status == "verified" }

    init(
        id: String = UUID().uuidString,
        title: String,
        issuer: String,
        url: String,
        status: String = "pending",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.issuer = issuer
        self.url = url
        self.status = status
        self.createdAt = createdAt
    }
}

struct UserProfile: Codable, Equatable {
    var id: String
    var email: String
    var displayName: String
    var role: String?
    var location: String?
    var stage: String?
    var skills: [String]
    var goal: String?
    var bio: String?
    var industry: String?
    var credentials: [VerifiedCredential]
    var isDiscoverable: Bool
    var onboardingCompleted: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        email: String,
        displayName: String = "",
        role: String? = nil,
        location: String? = nil,
        stage: String? = nil,
        skills: [String] = [],
        goal: String? = nil,
        bio: String? = nil,
        industry: String? = nil,
        credentials: [VerifiedCredential] = [],
        isDiscoverable: Bool = true,
        onboardingCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.role = role
        self.location = location
        self.stage = stage
        self.skills = skills
        self.goal = goal
        self.bio = bio
        self.industry = industry
        self.credentials = credentials
        self.isDiscoverable = isDiscoverable
        self.onboardingCompleted = onboardingCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        if let first = displayName.first {
            return String(first).uppercased()
        }
        return String(email.prefix(1)).uppercased()
    }
}

struct MessageThread: Codable, Identifiable, Equatable {
    var id: String
    var participantIds: [String]
    var participantNames: [String: String]
    var lastMessage: String
    var updatedAt: Date
}

struct ChatMessage: Codable, Identifiable, Equatable {
    var id: String
    var threadId: String
    var senderId: String
    var text: String
    var createdAt: Date
}

struct DiscoveryFilters: Equatable {
    var stage: String? = nil
    var goal: String? = nil
    var industry: String? = nil
}

import Foundation

struct UserProfile: Codable, Equatable {
    var id: String
    var email: String
    var displayName: String
    var role: String?
    var location: String?
    var stage: String?
    var skills: [String]
    var goal: String?
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

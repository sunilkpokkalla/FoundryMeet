import Foundation

struct VerifiedCredential: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var issuer: String
    var url: String
    /// pending | verified | rejected
    var status: String
    var rejectionReason: String?
    var reviewedAt: Date?
    var reviewedBy: String?
    var createdAt: Date

    var isVerified: Bool { status == "verified" }
    var isRejected: Bool { status == "rejected" }

    init(
        id: String = UUID().uuidString,
        title: String,
        issuer: String,
        url: String,
        status: String = "pending",
        rejectionReason: String? = nil,
        reviewedAt: Date? = nil,
        reviewedBy: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.issuer = issuer
        self.url = url
        self.status = status
        self.rejectionReason = rejectionReason
        self.reviewedAt = reviewedAt
        self.reviewedBy = reviewedBy
        self.createdAt = createdAt
    }
}

struct UserProfile: Codable, Equatable {
    var id: String
    var email: String
    var displayName: String
    var role: String?
    var location: String?
    /// Set only when the location came from a picked place, so distance-based
    /// matching can use it later.
    var latitude: Double?
    var longitude: Double?
    /// Advisors and investors span several stages, so this is the real answer.
    /// `stage` stays as the first entry for older clients and existing documents.
    var stages: [String]
    var skills: [String]
    var goal: String?
    /// Free-text: who / what they want to meet (complements structured `goal`).
    var lookingFor: String?
    /// Free-text: how they can help others in a coffee chat.
    var canHelpWith: String?
    var bio: String?
    /// One-line product or idea — what someone is actually building.
    var buildingIdea: String?
    var linkedInURL: String?
    var industry: String?
    var credentials: [VerifiedCredential]
    var availability: [AvailabilityWindow]
    var photoURL: String?
    var fcmTokens: [String]
    var isReviewer: Bool
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
        latitude: Double? = nil,
        longitude: Double? = nil,
        stages: [String] = [],
        skills: [String] = [],
        goal: String? = nil,
        lookingFor: String? = nil,
        canHelpWith: String? = nil,
        bio: String? = nil,
        buildingIdea: String? = nil,
        linkedInURL: String? = nil,
        industry: String? = nil,
        credentials: [VerifiedCredential] = [],
        availability: [AvailabilityWindow] = AvailabilityWindow.defaultWorkWeek,
        photoURL: String? = nil,
        fcmTokens: [String] = [],
        isReviewer: Bool = false,
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
        self.latitude = latitude
        self.longitude = longitude
        self.stages = stages
        self.skills = skills
        self.goal = goal
        self.lookingFor = lookingFor
        self.canHelpWith = canHelpWith
        self.bio = bio
        self.buildingIdea = buildingIdea
        self.linkedInURL = linkedInURL
        self.industry = industry
        self.credentials = credentials
        self.availability = availability
        self.photoURL = photoURL
        self.fcmTokens = fcmTokens
        self.isReviewer = isReviewer
        self.isDiscoverable = isDiscoverable
        self.onboardingCompleted = onboardingCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// The headline stage, for anywhere that can only show one.
    var stage: String? { stages.first }

    var stageSummary: String {
        stages.isEmpty ? "—" : stages.joined(separator: ", ")
    }

    var place: ResolvedPlace? {
        guard let location, !location.isEmpty else { return nil }
        return ResolvedPlace(displayName: location, latitude: latitude, longitude: longitude)
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

extension UserProfile {
    /// The first onboarding wrote a stage value that no longer exists, and it
    /// also copied that value into `industry`. Both are repaired on read.
    static func normalizedStages(_ stored: [String]) -> [String] {
        stored.map { StartupStage.parse($0)?.rawValue ?? $0 }
    }

    static func normalizedIndustry(_ stored: String?) -> String? {
        guard let stored, !stored.isEmpty else { return nil }
        return StartupStage.parse(stored) == nil ? stored : nil
    }
}

struct DiscoveryFilters: Equatable {
    var stage: String? = nil
    var industry: String? = nil
    /// Narrow to people whose goal is the other side of your own.
    /// On by default — that pairing is the product.
    var complementaryGoalsOnly: Bool = true
    /// Same city, or within coffee-chat distance when coordinates exist.
    var nearbyOnly: Bool = false
    /// Hiring / fundraising / co-founder / advisor / customer intent chip.
    var intent: NetworkingIntent? = nil

    static let `default` = DiscoveryFilters()

    var isDefault: Bool {
        stage == nil && industry == nil && complementaryGoalsOnly && !nearbyOnly && intent == nil
    }

    var isEmpty: Bool { isDefault }
}

import Foundation

/// Weekly availability window in the user's local timezone.
struct AvailabilityWindow: Codable, Identifiable, Equatable {
    var id: String
    /// 1 = Sunday … 7 = Saturday (Calendar.Component.weekday)
    var weekday: Int
    /// Minutes from midnight, inclusive start.
    var startMinutes: Int
    /// Minutes from midnight, exclusive end.
    var endMinutes: Int

    init(
        id: String = UUID().uuidString,
        weekday: Int,
        startMinutes: Int,
        endMinutes: Int
    ) {
        self.id = id
        self.weekday = weekday
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }

    static let defaultWorkWeek: [AvailabilityWindow] = (2...6).map { day in
        AvailabilityWindow(weekday: day, startMinutes: 9 * 60, endMinutes: 17 * 60)
    }
}

struct MailOutboxItem: Codable, Identifiable, Equatable {
    var id: String
    var to: [String]
    var subject: String
    var htmlBody: String
    var textBody: String
    var icsContent: String?
    var template: String
    var relatedChatId: String?
    var relatedCredentialId: String?
    /// pending | sent | failed | skipped
    var status: String
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String

    init(
        id: String = UUID().uuidString,
        to: [String],
        subject: String,
        htmlBody: String,
        textBody: String,
        icsContent: String? = nil,
        template: String,
        relatedChatId: String? = nil,
        relatedCredentialId: String? = nil,
        status: String = "pending",
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String
    ) {
        self.id = id
        self.to = to
        self.subject = subject
        self.htmlBody = htmlBody
        self.textBody = textBody
        self.icsContent = icsContent
        self.template = template
        self.relatedChatId = relatedChatId
        self.relatedCredentialId = relatedCredentialId
        self.status = status
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
    }
}

struct CredentialReview: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    var userName: String
    var userEmail: String
    var credentialId: String
    var title: String
    var issuer: String
    var url: String
    /// pending | verified | rejected
    var status: String
    var rejectionReason: String?
    var reviewedBy: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        userName: String,
        userEmail: String,
        credentialId: String,
        title: String,
        issuer: String,
        url: String,
        status: String = "pending",
        rejectionReason: String? = nil,
        reviewedBy: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userEmail = userEmail
        self.credentialId = credentialId
        self.title = title
        self.issuer = issuer
        self.url = url
        self.status = status
        self.rejectionReason = rejectionReason
        self.reviewedBy = reviewedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct AvailableSlot: Identifiable, Equatable {
    var id: String { "\(startsAt.timeIntervalSince1970)" }
    var startsAt: Date
    var endsAt: Date
    var dayLabel: String
    var timeLabel: String
}

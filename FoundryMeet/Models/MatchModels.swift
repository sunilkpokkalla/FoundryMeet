import Foundation
import SwiftUI

enum InteractionAction: String, Codable {
    case connected
    case dismissed
}

struct ProfileInteraction: Codable, Identifiable, Equatable {
    var id: String
    var candidateId: String
    var candidateName: String
    var candidateRole: String
    var action: InteractionAction
    var createdAt: Date
}

/// A coffee chat request. One document is shared by both people, so either side
/// can see it and act on it.
struct MatchRequest: Codable, Identifiable, Equatable {
    /// pending → the recipient has not answered yet
    /// accepted → both agreed to meet, a time can now be proposed
    /// declined → the recipient passed
    /// withdrawn → the requester pulled it back before an answer
    enum Status: String, Codable {
        case pending
        case accepted
        case declined
        case withdrawn
    }

    var id: String
    var requesterId: String
    var requesterName: String
    var requesterRole: String
    var recipientId: String
    var recipientName: String
    var recipientRole: String
    var participantIds: [String]
    var status: String
    var note: String
    var createdAt: Date
    var updatedAt: Date

    /// Both directions collapse to the same document, so A→B and B→A can never
    /// produce two competing requests.
    static func pairId(_ first: String, _ second: String) -> String {
        [first, second].sorted().joined(separator: "_")
    }

    init(
        requesterId: String,
        requesterName: String,
        requesterRole: String,
        recipientId: String,
        recipientName: String,
        recipientRole: String,
        status: Status = .pending,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = MatchRequest.pairId(requesterId, recipientId)
        self.requesterId = requesterId
        self.requesterName = requesterName
        self.requesterRole = requesterRole
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.recipientRole = recipientRole
        self.participantIds = [requesterId, recipientId].sorted()
        self.status = status.rawValue
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isPending: Bool { status == Status.pending.rawValue }
    var isAccepted: Bool { status == Status.accepted.rawValue }
    var isDeclined: Bool { status == Status.declined.rawValue }

    func isIncoming(for userId: String) -> Bool { recipientId == userId }

    func otherPartyId(for userId: String) -> String {
        requesterId == userId ? recipientId : requesterId
    }

    func otherPartyName(for userId: String) -> String {
        let name = requesterId == userId ? recipientName : requesterName
        return name.isEmpty ? "Founder" : name
    }

    func otherPartyRole(for userId: String) -> String {
        requesterId == userId ? recipientRole : requesterRole
    }
}

struct CoffeeChat: Codable, Identifiable, Equatable {
    /// proposed → one side picked a time, the other has not answered
    /// confirmed → both agreed, calendar entries and reminders are live
    /// declined → the invitee turned down the proposed time
    /// cancelled → called off after being confirmed or proposed
    enum Status: String, Codable {
        case proposed
        case confirmed
        case declined
        case cancelled
    }

    /// Written by builds before the two-sided flow existed; treated as confirmed.
    static let legacyConfirmedStatus = "scheduled"

    var id: String
    var userId: String
    var candidateId: String
    var candidateName: String
    var candidateRole: String
    var organizerName: String
    var participantIds: [String]
    var dayLabel: String
    var timeLabel: String
    var setting: String
    var talkingPoints: String
    var notes: String
    var status: String
    /// Who put the current time on the table. Changes on every reschedule.
    var proposedById: String
    var respondedAt: Date?
    var cancelledById: String?
    var cancellationReason: String?
    var startsAt: Date?
    var endsAt: Date?
    var calendarEventId: String?
    /// none | local | synced | failed
    var inviteStatus: String
    /// Per-participant post-chat outcome: useful | not_a_fit | no_show
    var outcomes: [String: String]
    var createdAt: Date
    var updatedAt: Date

    enum MeetingOutcome: String, CaseIterable, Identifiable {
        case useful = "useful"
        case notAFit = "not_a_fit"
        case noShow = "no_show"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .useful: return "Useful"
            case .notAFit: return "Not a fit"
            case .noShow: return "No-show"
            }
        }
    }

    var metOnLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: startsAt ?? createdAt)
    }

    var isProposed: Bool { status == Status.proposed.rawValue }
    var isConfirmed: Bool {
        status == Status.confirmed.rawValue || status == CoffeeChat.legacyConfirmedStatus
    }
    var isDeclined: Bool { status == Status.declined.rawValue }
    var isCancelled: Bool { status == Status.cancelled.rawValue }
    var isActive: Bool { isProposed || isConfirmed }

    var isPast: Bool {
        guard let startsAt else { return false }
        return startsAt < Date()
    }

    func awaitsResponse(from userId: String) -> Bool {
        isProposed && proposedById != userId
    }

    func awaitsOtherParty(for userId: String) -> Bool {
        isProposed && proposedById == userId
    }

    func statusLabel(for userId: String) -> String {
        if isCancelled { return "Cancelled" }
        if isDeclined { return "Time declined" }
        if awaitsResponse(from: userId) { return "Needs your answer" }
        if awaitsOtherParty(for: userId) { return "Awaiting reply" }
        if isPast { return "Completed" }
        return "Confirmed"
    }

    func otherPartyId(for userId: String) -> String {
        userId == self.userId ? candidateId : self.userId
    }

    func otherPartyName(for userId: String) -> String {
        if userId == self.userId {
            return candidateName
        }
        return organizerName.isEmpty ? "Founder" : organizerName
    }

    func outcome(for userId: String) -> MeetingOutcome? {
        outcomes[userId].flatMap(MeetingOutcome.init(rawValue:))
    }

    var needsOutcome: Bool {
        isConfirmed && isPast
    }
}

struct DiscoveryCandidate: Identifiable, Equatable {
    let id: String
    let name: String
    let role: String
    let imgUrl: String
    let desc: String
    let tags: [String]
    let industry: String
    var stages: [String] = []
    var goal: String? = nil
    var location: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var buildingIdea: String? = nil
    var linkedInURL: String? = nil
    var credentials: [VerifiedCredential] = []
    /// Sample profile with no account behind it, so it cannot receive a request.
    var isSeed: Bool = false

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }

    var accentColor: Color {
        let palette: [Color] = [
            Color(hex: 0x4a90e2),
            Color(hex: 0xe24a4a),
            Color(hex: 0x4ae290),
            Color(hex: 0x904ae2),
            Color(hex: 0xe2904a),
            Color(hex: 0x4ae2d9),
            Color(hex: 0xe24a90),
            Color(hex: 0xa9e24a)
        ]
        let hash = abs(id.hashValue)
        return palette[hash % palette.count]
    }

    init(
        id: String,
        name: String,
        role: String,
        imgUrl: String,
        desc: String,
        tags: [String],
        industry: String,
        stages: [String] = [],
        goal: String? = nil,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        buildingIdea: String? = nil,
        linkedInURL: String? = nil,
        credentials: [VerifiedCredential] = [],
        isSeed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.imgUrl = imgUrl
        self.desc = desc
        self.tags = tags
        self.industry = industry
        self.stages = stages
        self.goal = goal
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.buildingIdea = buildingIdea
        self.linkedInURL = linkedInURL
        self.credentials = credentials
        self.isSeed = isSeed
    }

    init(profile: UserProfile) {
        let idea = profile.buildingIdea?.trimmingCharacters(in: .whitespacesAndNewlines)
        let blurb: String
        if let idea, !idea.isEmpty {
            blurb = idea
        } else if let bio = profile.bio, !bio.isEmpty {
            blurb = bio
        } else if let goal = profile.goal {
            blurb = "Looking for: \(goal)"
        } else {
            blurb = "Open to high-signal coffee chats."
        }
        self.init(
            id: profile.id,
            name: profile.displayName.isEmpty ? "Founder" : profile.displayName,
            role: profile.role ?? "Founder",
            imgUrl: profile.photoURL ?? "",
            desc: blurb,
            tags: profile.skills,
            industry: profile.industry ?? "Startup",
            stages: profile.stages,
            goal: profile.goal,
            location: profile.location,
            latitude: profile.latitude,
            longitude: profile.longitude,
            buildingIdea: idea?.isEmpty == false ? idea : nil,
            linkedInURL: profile.linkedInURL,
            credentials: profile.credentials
        )
    }
}

enum SeedCatalog {
    /// Sample profiles for the local debug store. They have no account behind
    /// them, so they are never mixed into a live directory.
    static let candidates: [DiscoveryCandidate] = rawCandidates.map { candidate in
        var seed = candidate
        seed.isSeed = true
        return seed
    }

    private static let rawCandidates: [DiscoveryCandidate] = [
        DiscoveryCandidate(
            id: "sarah-chen",
            name: "Sarah Chen",
            role: "CTO @ Stealth AI",
            imgUrl: "https://lh3.googleusercontent.com/aida-public/AB6AXuA0QfBeBm1DioWiMlUSwaNwhkst_KPXGv2hscKZ2WCivesiC-ZRg8rn7JQFo1RjP_A9hbX26eOk7mEfxWofkPWxOji9sb8uLBOhotCKhc_rSfmXtqMhdrSxgVJkINqhpUT9dEYXN4r0iSz6ThAj72IKacQNHzUg_n-QsoKhhmFdFyhnKE7cZpOmD1WXAkKByP6UttP7z8BFt6BBTIyvpa3qmuB8_C4BY3BCoDvveSHfXMKYefVvbZfp1D-kqG0sq5xTW4JT0Z2QsNg",
            desc: "Potential GTM partners and Series A insights from founders who've scaled to $10M ARR.",
            tags: ["Natural Language Processing", "Cloud Infrastructure", "Scaling Teams"],
            industry: "AI / Fintech"
        ),
        DiscoveryCandidate(
            id: "marcus-aris",
            name: "Marcus Aris",
            role: "CEO @ Bloom Logistics",
            imgUrl: "https://lh3.googleusercontent.com/aida-public/AB6AXuBCtE5qu2rf2QU80DNGHCzWZ-AUgsifbN4BMvaOdZSLRFmeki7ZYM0JROldW9HKvoS1GPaoFUTwgYmTrDBWCv716Stg_0q8kl7EyI8MhjlzzOrxQ8a8YUfsbdkTeXDPhTD5bxusQN7mQcm0gZAkKIfP4bntsMxF21ixvM_CUU_ipbTMtXy4I87Bo78BUGpmJnKMPrBmIHjd-JDVgqIqJ2unLKKdSOkIfBbjbzaW216WKUxWJPBT24Vvgddbap3hKPkPMOBY9rQJo7U",
            desc: "Mentoring early-stage founders in the logistics space and exploring sustainable packaging tech.",
            tags: ["Operations", "Supply Chain AI", "Series B Prep"],
            industry: "Logistics"
        ),
        DiscoveryCandidate(
            id: "elena-rodriguez",
            name: "Elena Rodriguez",
            role: "Product Designer",
            imgUrl: "",
            desc: "Looking for technical co-founders building patient-first health products.",
            tags: ["Design Systems", "Healthtech", "User Research"],
            industry: "Healthtech"
        ),
        DiscoveryCandidate(
            id: "david-kim",
            name: "David Kim",
            role: "Data Scientist",
            imgUrl: "",
            desc: "Open to advising seed teams on ML infra and hiring their first applied scientists.",
            tags: ["Machine Learning", "Hiring", "Infra"],
            industry: "Machine Learning"
        ),
        DiscoveryCandidate(
            id: "priya-patel",
            name: "Priya Patel",
            role: "CEO @ Learnly",
            imgUrl: "",
            desc: "Raising Series A and looking for operators who've scaled EdTech GTM.",
            tags: ["EdTech", "Fundraising", "GTM"],
            industry: "EdTech"
        ),
        DiscoveryCandidate(
            id: "alex-thompson",
            name: "Alex Thompson",
            role: "Backend Engineer",
            imgUrl: "",
            desc: "Exploring cofounder fits for a developer tools company in web3 infra.",
            tags: ["Web3", "Backend", "DevTools"],
            industry: "Web3 / Crypto"
        ),
        DiscoveryCandidate(
            id: "james-wilson",
            name: "James Wilson",
            role: "Marketing VP",
            imgUrl: "",
            desc: "Happy to mentor early growth leads and swap channel experiments.",
            tags: ["Growth", "Brand", "Performance"],
            industry: "E-commerce"
        ),
        DiscoveryCandidate(
            id: "nina-simone",
            name: "Nina Simone",
            role: "Head of Operations",
            imgUrl: "",
            desc: "Looking for founders building logistics tooling for mid-market brands.",
            tags: ["Operations", "Logistics", "Ops Hire"],
            industry: "Logistics"
        )
    ]

    static func candidate(id: String) -> DiscoveryCandidate? {
        candidates.first { $0.id == id }
    }
}

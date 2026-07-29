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

struct CoffeeChat: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    var candidateId: String
    var candidateName: String
    var candidateRole: String
    var dayLabel: String
    var timeLabel: String
    var setting: String
    var talkingPoints: String
    var notes: String
    var status: String
    var createdAt: Date
    var updatedAt: Date

    var metOnLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt)
    }
}

struct PendingMatch: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    var candidateId: String
    var candidateName: String
    var candidateRole: String
    var status: String
    var createdAt: Date
}

struct DiscoveryCandidate: Identifiable, Equatable {
    let id: String
    let name: String
    let role: String
    let imgUrl: String
    let desc: String
    let tags: [String]
    let industry: String

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
}

enum SeedCatalog {
    static let candidates: [DiscoveryCandidate] = [
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

import Foundation

/// Public URLs for App Store Connect and in-app links. Hosted via Firebase Hosting.
enum LegalURLs {
    static let privacy = URL(string: "https://foundrymeet.web.app/privacy.html")!
    static let terms = URL(string: "https://foundrymeet.web.app/terms.html")!
    static let support = URL(string: "https://foundrymeet.web.app/support.html")!
}

enum LegalDocument: String, Identifiable, CaseIterable {
    case privacy
    case terms
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return "Privacy Policy"
        case .terms: return "Terms of Use"
        case .support: return "Support"
        }
    }

    var url: URL {
        switch self {
        case .privacy: return LegalURLs.privacy
        case .terms: return LegalURLs.terms
        case .support: return LegalURLs.support
        }
    }

    /// Shown in-app so reviewers and users can read the policy even offline.
    var body: String {
        switch self {
        case .privacy: return Self.privacyBody
        case .terms: return Self.termsBody
        case .support: return Self.supportBody
        }
    }

    private static let privacyBody = """
    Last updated: August 2, 2026

    FoundryMeet (“we”, “us”) provides a networking app that helps founders, builders, operators, advisors, and investors arrange high-signal coffee chats.

    Information we collect
    • Account information: email address, display name, and sign-in provider (Apple, Google, or email).
    • Profile information you provide: role, location (including approximate coordinates when you pick a place), stages, industry, skills, goals, bio, what you are building, LinkedIn URL, photo, availability windows, and verified-credential links.
    • Usage data needed to operate matching and messaging: match requests, coffee chat proposals and outcomes, messages you send, and device push tokens.
    • Device permissions you grant: photo library (profile photo), calendar (coffee chat events and busy times). We do not access your precise GPS location; city coordinates come from place search when you select a location.

    How we use information
    • To create and maintain your account and profile.
    • To suggest people to meet, propose times, send reminders, and deliver in-app or push notifications you opt into.
    • To improve safety and prevent abuse (for example credential review).
    • We do not sell your personal information.

    Sharing
    • Other signed-in members can see profile fields you make discoverable (name, photo, role, location, skills, goals, building idea, LinkedIn, and similar public profile fields).
    • Service providers that power the app (for example Firebase Auth, Firestore, Storage, and Cloud Messaging) process data on our behalf.
    • We may disclose information if required by law.

    Retention and deletion
    • We keep your account data while your account is active.
    • You can delete your account in Account → Delete Account. That removes your authentication account and profile data we store. Some residual records (for example chat history visible to another participant) may remain in anonymized or limited form where needed for the other person’s records.

    Your choices
    • Edit or clear profile fields at any time.
    • Turn off Discover visibility.
    • Revoke photo or calendar access in iOS Settings.
    • Request account deletion in the app.

    Children
    FoundryMeet is not directed to children under 13, and we do not knowingly collect their data.

    Contact
    Questions about privacy: support@foundrymeet.app
    """

    private static let termsBody = """
    Last updated: August 2, 2026

    By using FoundryMeet you agree to these Terms of Use.

    The service
    FoundryMeet helps members discover people and schedule coffee chats. We do not guarantee introductions, funding, jobs, or outcomes from any meeting.

    Accounts
    You must provide accurate profile information and keep your login secure. You are responsible for activity under your account. You must be at least 13 years old (or the minimum age in your country).

    Acceptable use
    You agree not to harass others, spam requests, misrepresent who you are, scrape the directory, or use the app for unlawful purposes. We may suspend or terminate accounts that violate these terms.

    Content you submit
    You retain rights to your profile content. You grant us a license to host and display it so the service can operate (for example showing your profile to other members).

    Meetings
    Coffee chats are arranged between members. You are responsible for your own safety when meeting in person. Cancel or decline anytime.

    Disclaimers
    The app is provided “as is.” To the fullest extent permitted by law, we disclaim warranties of merchantability, fitness for a particular purpose, and non-infringement.

    Limitation of liability
    To the fullest extent permitted by law, FoundryMeet and its operators are not liable for indirect, incidental, or consequential damages arising from your use of the app or from meetings arranged through it.

    Changes
    We may update these terms. Continued use after changes means you accept the updated terms.

    Contact
    support@foundrymeet.app
    """

    private static let supportBody = """
    Need help with FoundryMeet?

    Email: support@foundrymeet.app

    Common requests
    • Account or sign-in issues
    • Profile or photo problems
    • Matching and scheduling questions
    • Privacy or data deletion requests

    App Review / demo
    If you are reviewing the app for the App Store, create an account with Sign in with Apple or email, complete onboarding, and use Account to reach Support, Privacy, and Delete Account.
    """
}

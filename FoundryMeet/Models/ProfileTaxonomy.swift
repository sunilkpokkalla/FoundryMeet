import Foundation

/// A person's relationship to the startup world. One axis only — what you can
/// *do* lives in skills, and when you joined a company is not an identity.
enum FounderRole: String, CaseIterable, Identifiable {
    case founder = "Founder"
    case aspiringFounder = "Aspiring Founder"
    case builder = "Builder"
    case operator_ = "Operator"
    case advisor = "Advisor"
    case investor = "Investor"

    var id: String { rawValue }
    var title: String { rawValue }

    var icon: String {
        switch self {
        case .founder: return "flame"
        case .aspiringFounder: return "lightbulb"
        case .builder: return "wrench.and.screwdriver"
        case .operator_: return "gearshape.2"
        case .advisor: return "graduationcap"
        case .investor: return "chart.line.uptrend.xyaxis"
        }
    }

    var subtitle: String {
        switch self {
        case .founder: return "Running a company today"
        case .aspiringFounder: return "Have an idea, looking for a partner"
        case .builder: return "Engineering, design, or product"
        case .operator_: return "Growth, sales, ops, or finance"
        case .advisor: return "Experience to share"
        case .investor: return "Angel or fund"
        }
    }

    var goals: [NetworkingGoal] {
        NetworkingGoal.allCases.filter { $0.roles.contains(self) }
    }

    /// Stage means something different depending on who is answering: the stage
    /// you are at, the stage you want to join, or the stage you invest in.
    var stages: [StartupStage] {
        switch self {
        case .founder:
            return [.idea, .preSeed, .seed, .seriesA, .seriesB, .bootstrapped]
        case .aspiringFounder:
            return [.idea, .preSeed]
        case .builder, .operator_:
            return [.idea, .preSeed, .seed, .seriesA, .seriesB, .bootstrapped, .any]
        case .advisor:
            return [.idea, .preSeed, .seed, .seriesA, .seriesB, .bootstrapped, .any]
        case .investor:
            return [.idea, .preSeed, .seed, .seriesA, .seriesB, .any]
        }
    }

    var stageQuestion: String {
        switch self {
        case .founder, .aspiringFounder: return "What stage are you at?"
        case .builder, .operator_: return "What stage do you want to join?"
        case .advisor, .investor: return "What stages do you work with?"
        }
    }

    var stageLabel: String {
        switch self {
        case .founder, .aspiringFounder: return "Your Stage"
        case .builder, .operator_: return "Target Stage"
        case .advisor, .investor: return "Stages You Work With"
        }
    }

    /// Investors and advisors rarely cover a single stage, so they get to say so.
    var allowsMultipleStages: Bool {
        self == .advisor || self == .investor
    }

    /// Tapping a stage chip. Single-choice roles just replace their answer;
    /// multi-choice roles accumulate, except that "Any stage" stands alone.
    func toggling(_ stage: StartupStage, in current: Set<StartupStage>) -> Set<StartupStage> {
        guard allowsMultipleStages else { return [stage] }
        if current.contains(stage) {
            return current.subtracting([stage])
        }
        return stage == .any ? [.any] : current.subtracting([.any]).union([stage])
    }

    /// Answers that no longer make sense after a role change.
    func retainingValidStages(from current: Set<StartupStage>) -> Set<StartupStage> {
        let kept = current.filter(stages.contains)
        if !allowsMultipleStages && kept.count > 1 { return [] }
        return kept
    }

    var industryQuestion: String {
        switch self {
        case .founder, .aspiringFounder: return "What space are you building in?"
        case .builder, .operator_: return "What space do you want to work in?"
        case .advisor, .investor: return "What space do you focus on?"
        }
    }

    /// What this person brings. An investor's contribution is capital and
    /// network, not engineering, so the lists barely overlap at the edges.
    var skills: [Skill] {
        switch self {
        case .founder, .aspiringFounder:
            return [.engineering, .mlEngineering, .product, .design, .sales, .marketing,
                    .growth, .operations, .finance, .fundraising, .recruiting, .legal]
        case .builder:
            return [.engineering, .mlEngineering, .data, .infrastructure, .security,
                    .mobile, .product, .design, .userResearch]
        case .operator_:
            return [.sales, .marketing, .growth, .partnerships, .community,
                    .operations, .finance, .recruiting, .customerSuccess, .legal]
        case .advisor:
            return [.fundraising, .network, .governance, .marketExpertise, .product,
                    .engineering, .sales, .marketing, .growth, .operations, .recruiting, .legal]
        case .investor:
            return [.fundraising, .network, .governance, .marketExpertise,
                    .recruiting, .growth, .marketing]
        }
    }

    var skillQuestion: String {
        switch self {
        case .founder, .aspiringFounder: return "What do you personally bring to the table?"
        case .builder, .operator_: return "What do you do best?"
        case .advisor, .investor: return "What do you help founders with?"
        }
    }

    func retainingValidSkills(from current: Set<Skill>) -> Set<Skill> {
        current.filter(skills.contains)
    }
}

/// What a person contributes. Kept to a fixed list because these become the
/// tags Discover searches, and a long tail of one-off answers would sink that.
enum Skill: String, CaseIterable, Identifiable {
    case engineering = "Engineering"
    case mlEngineering = "ML Engineering"
    case data = "Data"
    case infrastructure = "Infrastructure"
    case security = "Security"
    case mobile = "Mobile"
    case product = "Product"
    case design = "Design"
    case userResearch = "User Research"
    case sales = "Sales"
    case marketing = "Marketing"
    case growth = "Growth"
    case partnerships = "Partnerships"
    case community = "Community"
    case operations = "Operations"
    case finance = "Finance"
    case legal = "Legal"
    case recruiting = "Recruiting"
    case customerSuccess = "Customer Success"
    case fundraising = "Fundraising"
    case network = "Intros & Network"
    case governance = "Board & Governance"
    case marketExpertise = "Market Expertise"

    var id: String { rawValue }
    var title: String { rawValue }

    /// Without a ceiling the rational move is to tick everything, which makes
    /// the tags worth nothing.
    static let selectionLimit = 5

    var icon: String {
        switch self {
        case .engineering: return "curlybraces"
        case .mlEngineering: return "brain"
        case .data: return "chart.bar"
        case .infrastructure: return "server.rack"
        case .security: return "lock.shield"
        case .mobile: return "iphone"
        case .product: return "cube.box"
        case .design: return "paintpalette"
        case .userResearch: return "magnifyingglass.circle"
        case .sales: return "banknote"
        case .marketing: return "megaphone"
        case .growth: return "chart.line.uptrend.xyaxis"
        case .partnerships: return "link"
        case .community: return "person.3"
        case .operations: return "gearshape.2"
        case .finance: return "dollarsign.circle"
        case .legal: return "briefcase"
        case .recruiting: return "person.badge.plus"
        case .customerSuccess: return "hand.thumbsup"
        case .fundraising: return "chart.pie"
        case .network: return "person.2.wave.2"
        case .governance: return "building.columns"
        case .marketExpertise: return "globe"
        }
    }

    /// Tolerates values written before this list existed.
    static func parse(_ stored: String) -> Skill? {
        if let exact = Skill(rawValue: stored) { return exact }
        return stored == "AI/ML" ? .mlEngineering : nil
    }

    static func toggling(_ skill: Skill, in current: Set<Skill>) -> Set<Skill> {
        if current.contains(skill) { return current.subtracting([skill]) }
        guard current.count < selectionLimit else { return current }
        return current.union([skill])
    }
}

/// Where a company sits on the funding path, plus the two answers that are not
/// points on that path at all.
enum StartupStage: String, CaseIterable, Identifiable {
    case idea = "Idea"
    case preSeed = "Pre-seed"
    case seed = "Seed"
    case seriesA = "Series A"
    case seriesB = "Series B+"
    case bootstrapped = "Bootstrapped"
    case any = "Any stage"

    var id: String { rawValue }
    var title: String { rawValue }

    /// Position on the funding ladder. Bootstrapped is deliberately off it, and
    /// `any` is a wildcard rather than a rung.
    var fundingRank: Int? {
        switch self {
        case .idea: return 0
        case .preSeed: return 1
        case .seed: return 2
        case .seriesA: return 3
        case .seriesB: return 4
        case .bootstrapped, .any: return nil
        }
    }

    /// Does a person's stages satisfy a Discover filter such as "Seed" or "Seed+"?
    static func stages(_ stored: [String], match filter: String) -> Bool {
        let trimmed = filter.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }

        let picked = stored.compactMap(StartupStage.init(rawValue:))
        guard !picked.isEmpty else { return false }
        if picked.contains(.any) { return true }

        let isOpenEnded = trimmed.hasSuffix("+")
        let name = isOpenEnded ? String(trimmed.dropLast()) : trimmed
        guard let floor = StartupStage(rawValue: name) else { return false }

        guard isOpenEnded, let floorRank = floor.fundingRank else {
            return picked.contains(floor)
        }
        return picked.contains { ($0.fundingRank ?? -1) >= floorRank }
    }
}

/// A coarse sector list. Coarse on purpose — it only has to be good enough to
/// filter on, and a long tail of one-off answers would defeat that.
enum Industry: String, CaseIterable, Identifiable {
    case ai = "AI & ML"
    case saas = "B2B SaaS"
    case fintech = "Fintech"
    case health = "Health"
    case consumer = "Consumer"
    case marketplace = "Marketplace"
    case devTools = "Developer Tools"
    case climate = "Climate"
    case crypto = "Crypto"
    case hardware = "Hardware"
    case education = "Education"
    case other = "Something else"

    var id: String { rawValue }
    var title: String { rawValue }
}

/// What someone wants out of the network right now. Every goal is scoped to the
/// roles it makes sense for, so a builder is never asked who they want to hire.
enum NetworkingGoal: String, CaseIterable, Identifiable {
    case findCofounder = "Find a Cofounder"
    case hireEarlyTeam = "Hire Early Team"
    case raiseFunding = "Raise Funding"
    case joinStartup = "Join a Startup"
    case getAdvice = "Get Advice"
    case adviseAndMentor = "Advise & Mentor"
    case meetFounders = "Meet Founders"

    var id: String { rawValue }
    var title: String { rawValue }

    var icon: String {
        switch self {
        case .findCofounder: return "person.2"
        case .hireEarlyTeam: return "person.badge.plus"
        case .raiseFunding: return "dollarsign.circle"
        case .joinStartup: return "building.2"
        case .getAdvice: return "questionmark.circle"
        case .adviseAndMentor: return "graduationcap"
        case .meetFounders: return "binoculars"
        }
    }

    var detail: String {
        switch self {
        case .findCofounder: return "Partners with complementary skills and shared values."
        case .hireEarlyTeam: return "The builders who will help you lay the first bricks."
        case .raiseFunding: return "Angels and funds who back teams at your stage."
        case .joinStartup: return "Early teams looking for someone with your skills."
        case .getAdvice: return "Experienced operators and domain experts."
        case .adviseAndMentor: return "Founders who need what you've already learned."
        case .meetFounders: return "Teams building in the areas you care about."
        }
    }

    var roles: [FounderRole] {
        switch self {
        case .findCofounder: return [.founder, .aspiringFounder, .builder, .operator_]
        case .hireEarlyTeam: return [.founder]
        case .raiseFunding: return [.founder, .aspiringFounder]
        case .joinStartup: return [.builder, .operator_]
        case .getAdvice: return [.founder, .aspiringFounder, .builder, .operator_]
        case .adviseAndMentor: return [.advisor, .investor]
        case .meetFounders: return [.advisor, .investor]
        }
    }
}

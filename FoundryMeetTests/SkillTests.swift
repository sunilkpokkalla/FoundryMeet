import XCTest
import UIKit
@testable import FoundryMeet

final class SkillTaxonomyTests: XCTestCase {
    /// A misspelled SF Symbol renders as nothing at all, with no build error.
    func testEverySkillIconResolves() {
        for skill in Skill.allCases {
            XCTAssertNotNil(
                UIImage(systemName: skill.icon),
                "\(skill.title) uses an unknown symbol: \(skill.icon)"
            )
        }
    }

    /// Nobody should face a list shorter than what they are allowed to pick.
    func testEveryRoleOffersMoreSkillsThanTheLimit() {
        for role in FounderRole.allCases {
            XCTAssertGreaterThan(
                role.skills.count, Skill.selectionLimit,
                "\(role.title) has too few skills to choose from"
            )
        }
    }

    func testEverySkillIsReachableFromSomeRole() {
        let offered = Set(FounderRole.allCases.flatMap(\.skills))
        for skill in Skill.allCases {
            XCTAssertTrue(offered.contains(skill), "\(skill.title) is offered to nobody")
        }
    }

    func testNoRoleListsTheSameSkillTwice() {
        for role in FounderRole.allCases {
            XCTAssertEqual(
                role.skills.count, Set(role.skills).count,
                "\(role.title) repeats a skill"
            )
        }
    }

    /// Capital and network are what advisors and investors actually bring, and
    /// they are not something a builder can claim.
    func testCapitalSkillsBelongToAdvisorsAndInvestorsOnly() {
        for skill in [Skill.fundraising, .network, .governance, .marketExpertise] {
            XCTAssertTrue(FounderRole.investor.skills.contains(skill))
            XCTAssertTrue(FounderRole.advisor.skills.contains(skill))
            XCTAssertFalse(FounderRole.builder.skills.contains(skill), "A builder cannot offer \(skill.title)")
        }
    }

    func testInvestorsAreNotAskedToClaimEngineering() {
        XCTAssertFalse(FounderRole.investor.skills.contains(.engineering))
        XCTAssertFalse(FounderRole.investor.skills.contains(.design))
    }

    func testBuildersGetTechnicalDepth() {
        for skill in [Skill.data, .infrastructure, .security, .mobile] {
            XCTAssertTrue(FounderRole.builder.skills.contains(skill))
        }
    }

    func testOperatorsGetGoToMarketDepth() {
        for skill in [Skill.partnerships, .community, .customerSuccess] {
            XCTAssertTrue(FounderRole.operator_.skills.contains(skill))
        }
    }

    /// The industry list and the skill list must not use the same words for
    /// different things.
    func testNoSkillSharesAWordingWithAnIndustry() {
        let industries = Set(Industry.allCases.map { $0.rawValue.lowercased() })
        for skill in Skill.allCases {
            XCTAssertFalse(
                industries.contains(skill.rawValue.lowercased()),
                "\(skill.title) reads as both a skill and an industry"
            )
        }
    }

    func testSkillsRoundTripThroughStoredValue() {
        for skill in Skill.allCases {
            XCTAssertEqual(Skill.parse(skill.rawValue), skill)
        }
    }

    /// Profiles saved before this list existed used "AI/ML".
    func testLegacySkillValueStillParses() {
        XCTAssertEqual(Skill.parse("AI/ML"), .mlEngineering)
        XCTAssertNil(Skill.parse("Supply Chain AI"))
    }
}

final class SkillSelectionTests: XCTestCase {
    func testSelectingAndDeselecting() {
        var picked = Skill.toggling(.engineering, in: [])
        XCTAssertEqual(picked, [.engineering])

        picked = Skill.toggling(.engineering, in: picked)
        XCTAssertTrue(picked.isEmpty)
    }

    func testTheLimitBlocksFurtherPicks() {
        var picked: Set<Skill> = [.engineering, .design, .product, .sales, .growth]
        XCTAssertEqual(picked.count, Skill.selectionLimit)

        picked = Skill.toggling(.marketing, in: picked)
        XCTAssertFalse(picked.contains(.marketing), "The sixth pick should be refused")
        XCTAssertEqual(picked.count, Skill.selectionLimit)
    }

    /// Being at the limit must not trap someone into their current answers.
    func testDeselectingStillWorksAtTheLimit() {
        let full: Set<Skill> = [.engineering, .design, .product, .sales, .growth]
        let after = Skill.toggling(.design, in: full)
        XCTAssertEqual(after.count, Skill.selectionLimit - 1)
        XCTAssertFalse(after.contains(.design))
    }

    func testChangingRoleDropsSkillsThatNoLongerApply() {
        let kept = FounderRole.investor.retainingValidSkills(from: [.fundraising, .engineering])
        XCTAssertEqual(kept, [.fundraising], "Engineering is not on offer to investors")
    }

    func testChangingRoleKeepsOverlappingSkills() {
        let kept = FounderRole.builder.retainingValidSkills(from: [.engineering, .product])
        XCTAssertEqual(kept, [.engineering, .product])
    }
}

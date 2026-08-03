import XCTest
import UIKit
@testable import FoundryMeet

final class ProfileTaxonomyTests: XCTestCase {
    /// A misspelled SF Symbol renders as nothing at all, with no build error.
    func testEveryRoleIconResolves() {
        for role in FounderRole.allCases {
            XCTAssertNotNil(
                UIImage(systemName: role.icon),
                "\(role.title) uses an unknown symbol: \(role.icon)"
            )
        }
    }

    func testEveryGoalIconResolves() {
        for goal in NetworkingGoal.allCases {
            XCTAssertNotNil(
                UIImage(systemName: goal.icon),
                "\(goal.title) uses an unknown symbol: \(goal.icon)"
            )
        }
    }

    /// Step 4 is unskippable, so a role with no goals would trap the user.
    func testEveryRoleHasAtLeastTwoGoals() {
        for role in FounderRole.allCases {
            XCTAssertGreaterThanOrEqual(
                role.goals.count, 2,
                "\(role.title) has too few goals to choose from"
            )
        }
    }

    func testEveryGoalBelongsToSomeRole() {
        for goal in NetworkingGoal.allCases {
            XCTAssertFalse(goal.roles.isEmpty, "\(goal.title) is unreachable")
        }
    }

    func testGoalsAndRolesAgreeWithEachOther() {
        for role in FounderRole.allCases {
            for goal in role.goals {
                XCTAssertTrue(
                    goal.roles.contains(role),
                    "\(goal.title) is offered to \(role.title) but doesn't list it"
                )
            }
        }
    }

    func testHiringAndJobHuntingNeverOverlap() {
        XCTAssertEqual(NetworkingGoal.hireEarlyTeam.roles, [.founder])
        XCTAssertFalse(NetworkingGoal.joinStartup.roles.contains(.founder))
        XCTAssertFalse(FounderRole.builder.goals.contains(.hireEarlyTeam))
        XCTAssertFalse(FounderRole.investor.goals.contains(.raiseFunding))
    }

    func testRolesRoundTripThroughStoredValue() {
        for role in FounderRole.allCases {
            XCTAssertEqual(FounderRole(rawValue: role.rawValue), role)
        }
        for goal in NetworkingGoal.allCases {
            XCTAssertEqual(NetworkingGoal(rawValue: goal.rawValue), goal)
        }
    }
}

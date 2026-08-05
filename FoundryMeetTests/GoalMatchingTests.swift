import XCTest
@testable import FoundryMeet

final class GoalReciprocityTests: XCTestCase {
    func testEveryGoalHasSomeoneOnTheOtherSide() {
        for goal in NetworkingGoal.allCases {
            XCTAssertFalse(
                goal.counterparts.isEmpty,
                "\(goal.title) matches nobody"
            )
        }
    }

    /// If A is useful to B then B must be useful to A, or the feed would show
    /// people a match that only works in one direction.
    func testPairingsAreMutual() {
        for goal in NetworkingGoal.allCases {
            for counterpart in goal.counterparts {
                XCTAssertTrue(
                    counterpart.counterparts.contains(goal),
                    "\(goal.title) points at \(counterpart.title), but not the other way round"
                )
            }
        }
    }

    /// The bug this whole change exists to fix.
    func testFundraisingMatchesInvestorsNotOtherFounders() {
        XCTAssertTrue(NetworkingGoal.areComplementary("Raise Funding", "Meet Founders"))
        XCTAssertFalse(
            NetworkingGoal.areComplementary("Raise Funding", "Raise Funding"),
            "Two founders chasing the same cheques are not a match"
        )
    }

    func testHiringMatchesJobHunting() {
        XCTAssertTrue(NetworkingGoal.areComplementary("Hire Early Team", "Join a Startup"))
        XCTAssertTrue(NetworkingGoal.areComplementary("Join a Startup", "Hire Early Team"))
        XCTAssertFalse(NetworkingGoal.areComplementary("Hire Early Team", "Hire Early Team"))
        XCTAssertFalse(NetworkingGoal.areComplementary("Join a Startup", "Join a Startup"))
    }

    func testAdviceMatchesMentoring() {
        XCTAssertTrue(NetworkingGoal.areComplementary("Get Advice", "Advise & Mentor"))
        XCTAssertFalse(NetworkingGoal.areComplementary("Get Advice", "Get Advice"))
    }

    /// Cofounder hunting is the one goal that genuinely matches itself.
    func testCofounderHuntingIsSymmetric() {
        XCTAssertTrue(NetworkingGoal.areComplementary("Find a Cofounder", "Find a Cofounder"))
    }

    func testUnknownOrMissingGoalsNeverMatch() {
        XCTAssertFalse(NetworkingGoal.areComplementary(nil, "Meet Founders"))
        XCTAssertFalse(NetworkingGoal.areComplementary("Raise Funding", nil))
        XCTAssertFalse(NetworkingGoal.areComplementary("raise a seed round", "Meet Founders"))
    }

    /// A pairing is worthless if the two roles can never both be on the network.
    func testEveryPairingIsReachableByRealRoles() {
        for goal in NetworkingGoal.allCases {
            for counterpart in goal.counterparts {
                XCTAssertFalse(
                    counterpart.roles.isEmpty,
                    "\(counterpart.title) belongs to no role, so \(goal.title) can never match"
                )
            }
        }
    }
}

final class DiscoveryFilterStateTests: XCTestCase {
    func testDefaultIncludesComplementaryMatching() {
        XCTAssertTrue(DiscoveryFilters.default.complementaryGoalsOnly)
        XCTAssertTrue(DiscoveryFilters().isDefault)
        XCTAssertTrue(DiscoveryFilters().isEmpty)
    }

    func testNarrowingLeavesTheDefault() {
        var filters = DiscoveryFilters.default
        filters.complementaryGoalsOnly = false
        XCTAssertFalse(filters.isDefault)

        filters = DiscoveryFilters.default
        filters.nearbyOnly = true
        XCTAssertFalse(filters.isDefault)

        filters = DiscoveryFilters.default
        filters.stage = "Seed"
        XCTAssertFalse(filters.isDefault)

        filters = DiscoveryFilters.default
        filters.industry = "Fintech"
        XCTAssertFalse(filters.isDefault)

        filters = DiscoveryFilters.default
        filters.intent = .hiring
        XCTAssertFalse(filters.isDefault)
    }
}

final class NetworkingIntentTests: XCTestCase {
    func testHiringMatchesHireGoal() {
        let candidate = DiscoveryCandidate(
            id: "1",
            name: "A",
            role: "Founder",
            imgUrl: "",
            desc: "",
            tags: [],
            industry: "SaaS",
            goal: NetworkingGoal.hireEarlyTeam.rawValue
        )
        XCTAssertTrue(NetworkingIntent.hiring.matches(candidate: candidate))
        XCTAssertFalse(NetworkingIntent.customer.matches(candidate: candidate))
    }

    func testCustomerMatchesLookingForText() {
        let candidate = DiscoveryCandidate(
            id: "2",
            name: "B",
            role: "Founder",
            imgUrl: "",
            desc: "",
            tags: [],
            industry: "SaaS",
            lookingFor: "Design partners and early customers"
        )
        XCTAssertTrue(NetworkingIntent.customer.matches(candidate: candidate))
    }
}

final class MeetingPrepTests: XCTestCase {
    func testNeedsPrepWithin24Hours() {
        var chat = CoffeeChat(
            id: "c1",
            userId: "a",
            candidateId: "b",
            candidateName: "Sam",
            candidateRole: "Founder",
            organizerName: "Alex",
            participantIds: ["a", "b"],
            dayLabel: "Mon",
            timeLabel: "10:00 AM",
            setting: "Virtual",
            talkingPoints: "Roadmap",
            notes: "",
            status: CoffeeChat.Status.confirmed.rawValue,
            proposedById: "a",
            inviteStatus: "none",
            outcomes: [:],
            createdAt: Date(),
            updatedAt: Date()
        )
        chat.startsAt = Date().addingTimeInterval(2 * 3600)
        XCTAssertTrue(chat.needsPrep())
        chat.startsAt = Date().addingTimeInterval(48 * 3600)
        XCTAssertFalse(chat.needsPrep())
    }
}

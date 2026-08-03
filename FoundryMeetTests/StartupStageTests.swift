import XCTest
@testable import FoundryMeet

final class StartupStageTaxonomyTests: XCTestCase {
    func testEveryRoleOffersAtLeastTwoStages() {
        for role in FounderRole.allCases {
            XCTAssertGreaterThanOrEqual(
                role.stages.count, 2,
                "\(role.title) cannot answer the stage question"
            )
        }
    }

    func testOnlyAdvisorsAndInvestorsPickSeveralStages() {
        XCTAssertTrue(FounderRole.advisor.allowsMultipleStages)
        XCTAssertTrue(FounderRole.investor.allowsMultipleStages)
        for role in [FounderRole.founder, .aspiringFounder, .builder, .operator_] {
            XCTAssertFalse(role.allowsMultipleStages, "\(role.title) should pick one stage")
        }
    }

    /// "Any stage" is an answer about other people's companies, so it makes no
    /// sense for someone describing their own.
    func testOnlyRolesLookingOutwardCanSayAnyStage() {
        for role in [FounderRole.founder, .aspiringFounder] {
            XCTAssertFalse(role.stages.contains(.any), "\(role.title) has a stage of its own")
        }
        for role in [FounderRole.builder, .operator_, .advisor, .investor] {
            XCTAssertTrue(role.stages.contains(.any), "\(role.title) should be able to be open")
        }
    }

    func testInvestorsAreNotOfferedBootstrapped() {
        XCTAssertFalse(FounderRole.investor.stages.contains(.bootstrapped))
        XCTAssertTrue(FounderRole.founder.stages.contains(.bootstrapped))
    }

    func testEveryRoleAsksAStageQuestionThatFitsIt() {
        XCTAssertEqual(FounderRole.founder.stageQuestion, "What stage are you at?")
        XCTAssertEqual(FounderRole.builder.stageQuestion, "What stage do you want to join?")
        XCTAssertEqual(FounderRole.investor.stageQuestion, "What stages do you work with?")
    }

    func testStagesRoundTripThroughStoredValue() {
        for stage in StartupStage.allCases {
            XCTAssertEqual(StartupStage(rawValue: stage.rawValue), stage)
        }
        for industry in Industry.allCases {
            XCTAssertEqual(Industry(rawValue: industry.rawValue), industry)
        }
    }
}

final class StageSelectionTests: XCTestCase {
    func testSingleChoiceRolesReplaceTheirAnswer() {
        let founder = FounderRole.founder
        var picked = founder.toggling(.seed, in: [])
        XCTAssertEqual(picked, [.seed])

        picked = founder.toggling(.seriesA, in: picked)
        XCTAssertEqual(picked, [.seriesA], "A founder is at one stage at a time")
    }

    func testMultiChoiceRolesAccumulate() {
        let investor = FounderRole.investor
        var picked = investor.toggling(.preSeed, in: [])
        picked = investor.toggling(.seed, in: picked)
        XCTAssertEqual(picked, [.preSeed, .seed])

        picked = investor.toggling(.preSeed, in: picked)
        XCTAssertEqual(picked, [.seed], "Tapping again removes it")
    }

    func testAnyStageStandsAlone() {
        let investor = FounderRole.investor
        var picked = investor.toggling(.seed, in: [])
        picked = investor.toggling(.any, in: picked)
        XCTAssertEqual(picked, [.any], "Any stage replaces specific picks")

        picked = investor.toggling(.seriesA, in: picked)
        XCTAssertEqual(picked, [.seriesA], "A specific pick replaces Any stage")
    }

    func testChangingRoleDropsStagesThatNoLongerApply() {
        let kept = FounderRole.founder.retainingValidStages(from: [.seed, .any])
        XCTAssertEqual(kept, [.seed], "Any stage is not on offer to founders")
    }

    func testChangingToASingleChoiceRoleClearsAnAmbiguousAnswer() {
        let kept = FounderRole.founder.retainingValidStages(from: [.seed, .seriesA])
        XCTAssertTrue(kept.isEmpty, "Two stages cannot collapse into one honestly")
    }
}

final class StageFilterTests: XCTestCase {
    func testOpenEndedFilterMatchesThatStageAndLater() {
        XCTAssertTrue(StartupStage.stages(["Seed"], match: "Seed+"))
        XCTAssertTrue(StartupStage.stages(["Series A"], match: "Seed+"))
        XCTAssertTrue(StartupStage.stages(["Series B+"], match: "Seed+"))
    }

    func testOpenEndedFilterExcludesEarlierStages() {
        XCTAssertFalse(StartupStage.stages(["Idea"], match: "Seed+"))
        XCTAssertFalse(StartupStage.stages(["Pre-seed"], match: "Seed+"))
    }

    /// Bootstrapped is not a rung on the funding ladder, so it never satisfies
    /// a funding-stage filter.
    func testBootstrappedIsOffTheLadder() {
        XCTAssertFalse(StartupStage.stages(["Bootstrapped"], match: "Seed+"))
        XCTAssertTrue(StartupStage.stages(["Bootstrapped"], match: "Bootstrapped"))
    }

    func testAnyStageMatchesEveryFilter() {
        XCTAssertTrue(StartupStage.stages(["Any stage"], match: "Seed+"))
        XCTAssertTrue(StartupStage.stages(["Any stage"], match: "Idea"))
    }

    func testAnyOfSeveralStagesIsEnough() {
        XCTAssertTrue(StartupStage.stages(["Pre-seed", "Seed"], match: "Seed+"))
        XCTAssertFalse(StartupStage.stages(["Idea", "Pre-seed"], match: "Seed+"))
    }

    func testExactFilterDoesNotMatchNeighbours() {
        XCTAssertTrue(StartupStage.stages(["Seed"], match: "Seed"))
        XCTAssertFalse(StartupStage.stages(["Series A"], match: "Seed"))
    }

    func testPeopleWithNoStageAreFilteredOut() {
        XCTAssertFalse(StartupStage.stages([], match: "Seed+"))
    }

    func testAnEmptyFilterKeepsEveryone() {
        XCTAssertTrue(StartupStage.stages([], match: ""))
        XCTAssertTrue(StartupStage.stages(["Idea"], match: "  "))
    }

    func testUnknownStoredValuesAreIgnored() {
        XCTAssertFalse(StartupStage.stages(["CTO @ Stealth"], match: "Seed+"))
    }
}

final class ProfileStageStorageTests: XCTestCase {
    func testStagesSurviveTheFirestoreRoundTrip() {
        var profile = UserProfile(id: "u1", email: "a@b.com")
        profile.stages = ["Pre-seed", "Seed"]

        let restored = UserProfile(id: "u1", firestoreData: profile.firestoreData)
        XCTAssertEqual(restored.stages, ["Pre-seed", "Seed"])
    }

    /// Older documents only carry a single `stage` string.
    func testLegacyDocumentsMigrateIntoTheStagesList() {
        let restored = UserProfile(id: "u1", firestoreData: ["email": "a@b.com", "stage": "Seed"])
        XCTAssertEqual(restored.stages, ["Seed"])
        XCTAssertEqual(restored.stage, "Seed")
    }

    /// Older clients still read `stage`, so it has to keep being written.
    func testTheHeadlineStageIsWrittenForOlderClients() {
        var profile = UserProfile(id: "u1", email: "a@b.com")
        profile.stages = ["Seed", "Series A"]
        XCTAssertEqual(profile.firestoreData["stage"] as? String, "Seed")
    }

    func testStageSummaryReadsAsASentence() {
        var profile = UserProfile(id: "u1", email: "a@b.com")
        XCTAssertEqual(profile.stageSummary, "—")

        profile.stages = ["Pre-seed", "Seed"]
        XCTAssertEqual(profile.stageSummary, "Pre-seed, Seed")
    }
}

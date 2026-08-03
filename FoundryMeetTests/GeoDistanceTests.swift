import XCTest
@testable import FoundryMeet

final class GeoDistanceTests: XCTestCase {
    func testSameMetroIsNearby() {
        // SF Ferry Building → Oakland (~12 km)
        XCTAssertTrue(
            GeoDistance.isNearby(
                myLocation: "San Francisco, CA",
                myLatitude: 37.7955,
                myLongitude: -122.3937,
                theirLocation: "Oakland, CA",
                theirLatitude: 37.8044,
                theirLongitude: -122.2712
            )
        )
    }

    func testCrossCoastIsNotNearby() {
        XCTAssertFalse(
            GeoDistance.isNearby(
                myLocation: "San Francisco, CA",
                myLatitude: 37.7749,
                myLongitude: -122.4194,
                theirLocation: "New York, NY",
                theirLatitude: 40.7128,
                theirLongitude: -74.0060
            )
        )
    }

    func testSameCityNameFallsBackWithoutCoordinates() {
        XCTAssertTrue(
            GeoDistance.isNearby(
                myLocation: "Berlin, Germany",
                myLatitude: nil,
                myLongitude: nil,
                theirLocation: "Berlin, Germany",
                theirLatitude: nil,
                theirLongitude: nil
            )
        )
        XCTAssertFalse(
            GeoDistance.isNearby(
                myLocation: "Berlin, Germany",
                myLatitude: nil,
                myLongitude: nil,
                theirLocation: "Munich, Germany",
                theirLatitude: nil,
                theirLongitude: nil
            )
        )
    }

    func testRemoteNeverCountsAsACity() {
        XCTAssertNil(GeoDistance.normalizedCity("Remote"))
        XCTAssertFalse(GeoDistance.isSameCity("Remote", "Remote"))
    }

    func testSortKeyPutsKnownCloserFirst() {
        let near = GeoDistance.sortKeyKilometers(
            myLatitude: 37.7749,
            myLongitude: -122.4194,
            theirLatitude: 37.8044,
            theirLongitude: -122.2712,
            myLocation: "San Francisco, CA",
            theirLocation: "Oakland, CA"
        )
        let far = GeoDistance.sortKeyKilometers(
            myLatitude: 37.7749,
            myLongitude: -122.4194,
            theirLatitude: 40.7128,
            theirLongitude: -74.0060,
            myLocation: "San Francisco, CA",
            theirLocation: "New York, NY"
        )
        XCTAssertLessThan(near, far)
    }

    func testComplementaryFilterDefaultsOn() {
        XCTAssertTrue(DiscoveryFilters.default.complementaryGoalsOnly)
        XCTAssertTrue(DiscoveryFilters().isDefault)
        var narrowed = DiscoveryFilters.default
        narrowed.nearbyOnly = true
        XCTAssertFalse(narrowed.isDefault)
    }
}

final class ChatOutcomeTests: XCTestCase {
    func testPastConfirmedChatNeedsOutcome() {
        var chat = sampleChat(status: .confirmed, startsAt: Date().addingTimeInterval(-3600))
        XCTAssertTrue(chat.needsOutcome)
        chat.outcomes["u1"] = CoffeeChat.MeetingOutcome.useful.rawValue
        XCTAssertEqual(chat.outcome(for: "u1"), .useful)
    }

    func testFutureChatDoesNotNeedOutcome() {
        let chat = sampleChat(status: .confirmed, startsAt: Date().addingTimeInterval(3600))
        XCTAssertFalse(chat.needsOutcome)
    }

    private func sampleChat(status: CoffeeChat.Status, startsAt: Date) -> CoffeeChat {
        CoffeeChat(
            id: "c1",
            userId: "u1",
            candidateId: "u2",
            candidateName: "Other",
            candidateRole: "Founder",
            organizerName: "Me",
            participantIds: ["u1", "u2"],
            dayLabel: "Mon",
            timeLabel: "10:00 AM",
            setting: "Cafe",
            talkingPoints: "",
            notes: "",
            status: status.rawValue,
            proposedById: "u1",
            respondedAt: nil,
            cancelledById: nil,
            cancellationReason: nil,
            startsAt: startsAt,
            endsAt: startsAt.addingTimeInterval(2700),
            calendarEventId: nil,
            inviteStatus: "none",
            outcomes: [:],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

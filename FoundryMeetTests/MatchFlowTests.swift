import XCTest
@testable import FoundryMeet

final class MatchRequestTests: XCTestCase {
    private func request(
        requester: String = "alice",
        recipient: String = "bob",
        status: MatchRequest.Status = .pending
    ) -> MatchRequest {
        MatchRequest(
            requesterId: requester,
            requesterName: "Alice",
            requesterRole: "CEO",
            recipientId: recipient,
            recipientName: "Bob",
            recipientRole: "CTO",
            status: status
        )
    }

    func testPairIdIsIndependentOfDirection() {
        XCTAssertEqual(
            MatchRequest.pairId("alice", "bob"),
            MatchRequest.pairId("bob", "alice")
        )
    }

    func testBothDirectionsCollapseToOneDocument() {
        XCTAssertEqual(
            request(requester: "alice", recipient: "bob").id,
            request(requester: "bob", recipient: "alice").id
        )
    }

    func testParticipantsAlwaysIncludeBothSides() {
        let sent = request()
        XCTAssertEqual(sent.participantIds, ["alice", "bob"])
        XCTAssertTrue(sent.participantIds.contains(sent.requesterId))
        XCTAssertTrue(sent.participantIds.contains(sent.recipientId))
    }

    func testOnlyRecipientSeesRequestAsIncoming() {
        let sent = request()
        XCTAssertTrue(sent.isIncoming(for: "bob"))
        XCTAssertFalse(sent.isIncoming(for: "alice"))
    }

    func testOtherPartyResolvesFromEitherSide() {
        let sent = request()
        XCTAssertEqual(sent.otherPartyId(for: "alice"), "bob")
        XCTAssertEqual(sent.otherPartyName(for: "alice"), "Bob")
        XCTAssertEqual(sent.otherPartyRole(for: "alice"), "CTO")
        XCTAssertEqual(sent.otherPartyId(for: "bob"), "alice")
        XCTAssertEqual(sent.otherPartyName(for: "bob"), "Alice")
    }

    func testStatusFlags() {
        XCTAssertTrue(request(status: .pending).isPending)
        XCTAssertTrue(request(status: .accepted).isAccepted)
        XCTAssertTrue(request(status: .declined).isDeclined)
        XCTAssertFalse(request(status: .withdrawn).isPending)
    }
}

final class CoffeeChatStateTests: XCTestCase {
    private func chat(
        status: String,
        proposedBy: String = "alice",
        startsAt: Date? = Date().addingTimeInterval(3600)
    ) -> CoffeeChat {
        CoffeeChat(
            id: "chat-1",
            userId: "alice",
            candidateId: "bob",
            candidateName: "Bob",
            candidateRole: "CTO",
            organizerName: "Alice",
            participantIds: ["alice", "bob"],
            dayLabel: "Mon 3",
            timeLabel: "9:00 AM",
            setting: "Virtual",
            talkingPoints: "",
            notes: "",
            privateNotes: [:],
            status: status,
            proposedById: proposedBy,
            respondedAt: nil,
            cancelledById: nil,
            cancellationReason: nil,
            startsAt: startsAt,
            endsAt: startsAt?.addingTimeInterval(45 * 60),
            calendarEventId: nil,
            inviteStatus: "none",
            outcomes: [:],
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func testProposalAwaitsOnlyTheOtherSide() {
        let proposed = chat(status: CoffeeChat.Status.proposed.rawValue, proposedBy: "alice")
        XCTAssertTrue(proposed.awaitsResponse(from: "bob"))
        XCTAssertFalse(proposed.awaitsResponse(from: "alice"))
        XCTAssertTrue(proposed.awaitsOtherParty(for: "alice"))
        XCTAssertFalse(proposed.awaitsOtherParty(for: "bob"))
    }

    func testLegacyScheduledStatusCountsAsConfirmed() {
        XCTAssertTrue(chat(status: CoffeeChat.legacyConfirmedStatus).isConfirmed)
        XCTAssertTrue(chat(status: CoffeeChat.Status.confirmed.rawValue).isConfirmed)
    }

    func testCancelledAndDeclinedAreNotActive() {
        XCTAssertFalse(chat(status: CoffeeChat.Status.cancelled.rawValue).isActive)
        XCTAssertFalse(chat(status: CoffeeChat.Status.declined.rawValue).isActive)
        XCTAssertTrue(chat(status: CoffeeChat.Status.proposed.rawValue).isActive)
        XCTAssertTrue(chat(status: CoffeeChat.Status.confirmed.rawValue).isActive)
    }

    func testOtherPartyResolvesFromEitherSide() {
        let confirmed = chat(status: CoffeeChat.Status.confirmed.rawValue)
        XCTAssertEqual(confirmed.otherPartyId(for: "alice"), "bob")
        XCTAssertEqual(confirmed.otherPartyName(for: "alice"), "Bob")
        XCTAssertEqual(confirmed.otherPartyId(for: "bob"), "alice")
        XCTAssertEqual(confirmed.otherPartyName(for: "bob"), "Alice")
    }

    func testStatusLabelReflectsWhoOwesAnAnswer() {
        let proposed = chat(status: CoffeeChat.Status.proposed.rawValue, proposedBy: "alice")
        XCTAssertEqual(proposed.statusLabel(for: "bob"), "Needs your answer")
        XCTAssertEqual(proposed.statusLabel(for: "alice"), "Awaiting reply")

        let cancelled = chat(status: CoffeeChat.Status.cancelled.rawValue)
        XCTAssertEqual(cancelled.statusLabel(for: "alice"), "Cancelled")

        let past = chat(
            status: CoffeeChat.Status.confirmed.rawValue,
            startsAt: Date().addingTimeInterval(-7200)
        )
        XCTAssertEqual(past.statusLabel(for: "alice"), "Completed")
    }
}

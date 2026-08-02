import XCTest
@testable import FoundryMeet

final class AvailabilityEngineTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func testGeneratesSlotsInsideWindows() {
        // Monday 2026-08-03
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 3
        comps.hour = 8
        let now = calendar.date(from: comps)!

        let windows = [AvailabilityWindow(weekday: 2, startMinutes: 9 * 60, endMinutes: 11 * 60)]
        let slots = AvailabilityEngine.generateSlots(
            windows: windows,
            from: now,
            dayCount: 1,
            meetingMinutes: 45,
            stepMinutes: 30,
            busyIntervals: [],
            calendar: calendar,
            now: now
        )

        XCTAssertFalse(slots.isEmpty)
        XCTAssertEqual(calendar.component(.hour, from: slots[0].startsAt), 9)
        for slot in slots {
            XCTAssertEqual(calendar.component(.weekday, from: slot.startsAt), 2)
            XCTAssertEqual(Int(slot.endsAt.timeIntervalSince(slot.startsAt)), 45 * 60)
        }
    }

    func testExcludesBusyIntervals() {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 3
        comps.hour = 8
        let now = calendar.date(from: comps)!

        comps.hour = 9
        comps.minute = 0
        let busyStart = calendar.date(from: comps)!
        comps.hour = 10
        let busyEnd = calendar.date(from: comps)!

        let windows = [AvailabilityWindow(weekday: 2, startMinutes: 9 * 60, endMinutes: 12 * 60)]
        let slots = AvailabilityEngine.generateSlots(
            windows: windows,
            from: now,
            dayCount: 1,
            meetingMinutes: 45,
            stepMinutes: 30,
            busyIntervals: [(busyStart, busyEnd)],
            calendar: calendar,
            now: now
        )

        for slot in slots {
            let overlaps = slot.startsAt < busyEnd && slot.endsAt > busyStart
            XCTAssertFalse(overlaps, "Slot \(slot.timeLabel) overlapped busy block")
        }
    }

    func testGroupByDayPreservesOrder() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let a = AvailableSlot(
            startsAt: formatter.date(from: "2026-08-03 09:00")!,
            endsAt: formatter.date(from: "2026-08-03 09:45")!,
            dayLabel: "Mon 3",
            timeLabel: "9:00 AM"
        )
        let b = AvailableSlot(
            startsAt: formatter.date(from: "2026-08-04 09:00")!,
            endsAt: formatter.date(from: "2026-08-04 09:45")!,
            dayLabel: "Tue 4",
            timeLabel: "9:00 AM"
        )
        let grouped = AvailabilityEngine.groupByDay([a, b, a])
        XCTAssertEqual(grouped.map(\.dayLabel), ["Mon 3", "Tue 4"])
        XCTAssertEqual(grouped[0].slots.count, 2)
    }
}

final class ICSBuilderTests: XCTestCase {
    func testBuildsValidICSEnvelope() {
        let start = Date(timeIntervalSince1970: 1_775_174_400) // fixed
        let end = start.addingTimeInterval(45 * 60)
        let ics = ICSBuilder.event(
            uid: "test-chat",
            summary: "Coffee with Sam",
            description: "Talk fundraising",
            startsAt: start,
            endsAt: end,
            location: "Virtual",
            organizerEmail: "host@foundrymeet.com"
        )

        XCTAssertTrue(ics.contains("BEGIN:VCALENDAR"))
        XCTAssertTrue(ics.contains("BEGIN:VEVENT"))
        XCTAssertTrue(ics.contains("SUMMARY:Coffee with Sam"))
        XCTAssertTrue(ics.contains("LOCATION:Virtual"))
        XCTAssertTrue(ics.contains("ORGANIZER:mailto:host@foundrymeet.com"))
        XCTAssertTrue(ics.contains("END:VCALENDAR"))
    }
}

final class CredentialModelTests: XCTestCase {
    func testVerifiedFlags() {
        var credential = VerifiedCredential(title: "MBA", issuer: "Stanford", url: "https://example.com")
        XCTAssertFalse(credential.isVerified)
        XCTAssertFalse(credential.isRejected)

        credential.status = "verified"
        XCTAssertTrue(credential.isVerified)

        credential.status = "rejected"
        XCTAssertTrue(credential.isRejected)
    }
}

import Foundation

enum AvailabilityEngine {
    /// Generates bookable slots from weekly windows, excluding busy intervals.
    static func generateSlots(
        windows: [AvailabilityWindow],
        from startDate: Date,
        dayCount: Int = 14,
        meetingMinutes: Int = 45,
        stepMinutes: Int = 30,
        busyIntervals: [(start: Date, end: Date)] = [],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [AvailableSlot] {
        guard meetingMinutes > 0, stepMinutes > 0, dayCount > 0 else { return [] }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        var slots: [AvailableSlot] = []
        let startOfToday = calendar.startOfDay(for: startDate)

        for dayOffset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let dayWindows = windows.filter { $0.weekday == weekday && $0.endMinutes > $0.startMinutes }

            for window in dayWindows {
                var cursor = window.startMinutes
                while cursor + meetingMinutes <= window.endMinutes {
                    guard
                        let startsAt = calendar.date(byAdding: .minute, value: cursor, to: day),
                        let endsAt = calendar.date(byAdding: .minute, value: meetingMinutes, to: startsAt)
                    else { break }

                    cursor += stepMinutes

                    // Skip past slots
                    if endsAt <= now { continue }

                    let overlapsBusy = busyIntervals.contains { busy in
                        startsAt < busy.end && endsAt > busy.start
                    }
                    if overlapsBusy { continue }

                    slots.append(
                        AvailableSlot(
                            startsAt: startsAt,
                            endsAt: endsAt,
                            dayLabel: dayFormatter.string(from: startsAt),
                            timeLabel: timeFormatter.string(from: startsAt)
                        )
                    )
                }
            }
        }

        return slots
    }

    static func groupByDay(_ slots: [AvailableSlot]) -> [(dayLabel: String, slots: [AvailableSlot])] {
        var order: [String] = []
        var map: [String: [AvailableSlot]] = [:]
        for slot in slots {
            if map[slot.dayLabel] == nil {
                order.append(slot.dayLabel)
                map[slot.dayLabel] = []
            }
            map[slot.dayLabel, default: []].append(slot)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    /// Slots that fit both people's weekly windows (uses the proposer's busy calendar).
    static func overlappingSlots(
        myWindows: [AvailabilityWindow],
        theirWindows: [AvailabilityWindow],
        from startDate: Date,
        dayCount: Int = 14,
        meetingMinutes: Int = 45,
        stepMinutes: Int = 30,
        myBusyIntervals: [(start: Date, end: Date)] = [],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [AvailableSlot] {
        let mine = generateSlots(
            windows: myWindows,
            from: startDate,
            dayCount: dayCount,
            meetingMinutes: meetingMinutes,
            stepMinutes: stepMinutes,
            busyIntervals: myBusyIntervals,
            calendar: calendar,
            now: now
        )
        let theirs = generateSlots(
            windows: theirWindows,
            from: startDate,
            dayCount: dayCount,
            meetingMinutes: meetingMinutes,
            stepMinutes: stepMinutes,
            busyIntervals: [],
            calendar: calendar,
            now: now
        )
        let theirStarts = Set(theirs.map(\.startsAt))
        return mine.filter { theirStarts.contains($0.startsAt) }
    }

    static func overlapSummary(slotCount: Int) -> String? {
        guard slotCount > 0 else { return nil }
        if slotCount == 1 { return "1 overlapping time in the next 2 weeks" }
        return "\(slotCount) overlapping times in the next 2 weeks"
    }
}

enum ICSBuilder {
    static func event(
        uid: String,
        summary: String,
        description: String,
        startsAt: Date,
        endsAt: Date,
        location: String,
        organizerEmail: String
    ) -> String {
        let stamp = icsDate(Date())
        let start = icsDate(startsAt)
        let end = icsDate(endsAt)
        let escapedSummary = escape(summary)
        let escapedDescription = escape(description)
        let escapedLocation = escape(location)

        return """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//FoundryMeet//EN
        CALSCALE:GREGORIAN
        METHOD:REQUEST
        BEGIN:VEVENT
        UID:\(uid)@foundrymeet.com
        DTSTAMP:\(stamp)
        DTSTART:\(start)
        DTEND:\(end)
        SUMMARY:\(escapedSummary)
        DESCRIPTION:\(escapedDescription)
        LOCATION:\(escapedLocation)
        ORGANIZER:mailto:\(organizerEmail)
        STATUS:CONFIRMED
        END:VEVENT
        END:VCALENDAR
        """.replacingOccurrences(of: "\n", with: "\r\n")
    }

    private static func icsDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

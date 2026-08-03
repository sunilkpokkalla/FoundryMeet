import Foundation
import EventKit

@MainActor
final class CalendarInviteService {
    static let shared = CalendarInviteService()

    private let store = EKEventStore()

    private init() {}

    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }

    func createEvent(
        title: String,
        notes: String,
        location: String,
        startsAt: Date,
        endsAt: Date
    ) async throws -> String {
        let granted = await requestAccess()
        guard granted else {
            throw CalendarInviteError.accessDenied
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = notes
        event.location = location
        event.startDate = startsAt
        event.endDate = endsAt
        event.calendar = store.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -15 * 60))

        try store.save(event, span: .thisEvent, commit: true)
        guard let eventId = event.eventIdentifier else {
            throw CalendarInviteError.saveFailed
        }
        return eventId
    }

    /// Removes a previously created event. Missing events are treated as removed
    /// so a cancellation never fails because the user already deleted it.
    func removeEvent(identifier: String) async {
        let granted = await requestAccess()
        guard granted, let event = store.event(withIdentifier: identifier) else { return }
        try? store.remove(event, span: .thisEvent, commit: true)
    }

    func busyIntervals(from start: Date, to end: Date) async -> [(start: Date, end: Date)] {
        let granted = await requestAccess()
        guard granted else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
        return events
            .filter { !$0.isAllDay }
            .map { ($0.startDate, $0.endDate) }
    }
}

enum CalendarInviteError: LocalizedError {
    case accessDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Calendar access was denied. Enable it in Settings to add invites."
        case .saveFailed: return "Could not save the calendar event."
        }
    }
}

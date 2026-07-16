import EventKit
import Foundation

enum CalendarMonitor {
    private static let store = EKEventStore()

    static func requestAccess(completion: @escaping (Bool) -> Void) {
        store.requestFullAccessToEvents { granted, error in
            if let error { AppLog.write("Calendar access error: \(error.localizedDescription)") }
            completion(granted)
        }
    }

    private static var hasEventAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// True when there is an event happening now that looks like a meeting.
    static func isInMeeting(now: Date = Date()) -> Bool {
        guard hasEventAccess else { return false }

        let windowEnd = now.addingTimeInterval(60)
        let predicate = store.predicateForEvents(withStart: now, end: windowEnd, calendars: nil)
        let events = store.events(matching: predicate)

        return events.contains { event in
            if event.isAllDay { return false }
            if event.availability == .free { return false }
            let attendees = event.attendees?.count ?? 0
            if attendees > 0 { return true }
            let haystack = ((event.title ?? "") + " " + (event.notes ?? "") + " " + (event.location ?? "")).lowercased()
            let keywords = ["zoom", "meet.google", "teams.microsoft", "webex", "call", "standup", "stand-up", "sync", "interview"]
            return keywords.contains { haystack.contains($0) }
        }
    }
}

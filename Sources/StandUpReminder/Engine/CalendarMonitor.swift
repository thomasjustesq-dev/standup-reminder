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

    static func isInMeeting(now: Date = Date()) -> Bool {
        guard hasEventAccess else { return false }
        let windowEnd = now.addingTimeInterval(60)
        let predicate = store.predicateForEvents(withStart: now, end: windowEnd, calendars: nil)
        return store.events(matching: predicate).contains { looksLikeMeeting($0) }
    }

    /// Current meeting event ending soonest, if any.
    static func currentMeetingEnd(now: Date = Date()) -> Date? {
        guard hasEventAccess else { return nil }
        let windowEnd = now.addingTimeInterval(60)
        let predicate = store.predicateForEvents(withStart: now, end: windowEnd, calendars: nil)
        return store.events(matching: predicate)
            .filter(looksLikeMeeting)
            .compactMap(\.endDate)
            .sorted()
            .first
    }

    /// Count of meeting-like events that start today (for auto pack switch).
    static func meetingEventCountToday(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard hasEventAccess else { return 0 }
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).filter(looksLikeMeeting).count
    }

    /// All-day or titled events that look like PTO / OOO / holiday.
    static func isOutOfOffice(now: Date = Date(), keywords: [String], calendar: Calendar = .current) -> Bool {
        guard hasEventAccess else { return false }
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
        let keys = keywords.map { $0.lowercased() }
        return events.contains { event in
            let haystack = ((event.title ?? "") + " " + (event.notes ?? "")).lowercased()
            if keys.contains(where: { haystack.contains($0) }) { return true }
            // Availability busy + all-day with "ooo" style is covered by keywords; also treat calendar type holidays lightly
            if event.isAllDay, keys.contains(where: { haystack.contains($0) }) { return true }
            return false
        }
    }

    private static func looksLikeMeeting(_ event: EKEvent) -> Bool {
        if event.isAllDay { return false }
        if event.availability == .free { return false }
        let attendees = event.attendees?.count ?? 0
        if attendees > 0 { return true }
        let haystack = ((event.title ?? "") + " " + (event.notes ?? "") + " " + (event.location ?? "")).lowercased()
        let keywords = ["zoom", "meet.google", "teams.microsoft", "webex", "call", "standup", "stand-up", "sync", "interview"]
        return keywords.contains { haystack.contains($0) }
    }
}

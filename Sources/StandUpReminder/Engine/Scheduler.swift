import Foundation

/// Pure scheduling core: given the current state, computes the next reminder —
/// what kind and when. AppState fires when `Date()` reaches `Next.date`.
///
/// Break cadence is anchored to the last reminder/acknowledgement, so "every
/// 30 minutes" means 30 minutes after your last break — not "when the wall
/// clock minute is divisible by 30", which produced uneven gaps and reminders
/// moments after a completed break in v4.0.
enum Scheduler {
    enum Kind: String, Equatable {
        case breakPrompt
        case sitStand
        case lunch
        case windDown
    }

    struct Next: Equatable {
        var date: Date
        var kind: Kind
    }

    struct Input {
        var config: AppConfig
        var intervalMinutes: Int
        var now: Date
        var paused: Bool
        var snoozeUntil: Date?
        var lastReminderAt: Date?
        var lastAcknowledgedAt: Date?
        var deskPhaseStartedAt: Date?
        var lunchFiredDayKey: String?
        var windDownFiredDayKey: String?
    }

    static func next(_ input: Input) -> Next? {
        guard !input.paused else { return nil }
        var candidates: [Next] = []

        if let due = breakDue(input) {
            candidates.append(Next(date: due, kind: .breakPrompt))
        }
        if let due = sitStandDue(input) {
            candidates.append(Next(date: due, kind: .sitStand))
        }
        if input.config.lunch.enabled, let due = nextScheduledOccurrence(
            hour: input.config.lunch.hour,
            minute: input.config.lunch.minute,
            graceMinutes: input.config.lunch.windowMinutes,
            firedDayKey: input.lunchFiredDayKey,
            config: input.config,
            now: input.now
        ) {
            candidates.append(Next(date: due, kind: .lunch))
        }
        if input.config.windDown.enabled, let due = nextScheduledOccurrence(
            hour: input.config.windDown.hour,
            minute: input.config.windDown.minute,
            graceMinutes: input.config.windDown.windowMinutes,
            firedDayKey: input.windDownFiredDayKey,
            config: input.config,
            now: input.now
        ) {
            candidates.append(Next(date: due, kind: .windDown))
        }

        // Earliest wins; on a tie, scheduled events beat the rolling cadence.
        let priority: [Kind: Int] = [.windDown: 0, .lunch: 1, .sitStand: 2, .breakPrompt: 3]
        return candidates.min { a, b in
            if a.date != b.date { return a.date < b.date }
            return (priority[a.kind] ?? 9) < (priority[b.kind] ?? 9)
        }
    }

    /// Latest break-related event; the cadence counts from here.
    static func cadenceAnchor(lastReminderAt: Date?, lastAcknowledgedAt: Date?) -> Date? {
        [lastReminderAt, lastAcknowledgedAt].compactMap { $0 }.max()
    }

    private static func breakDue(_ input: Input) -> Date? {
        let interval = TimeInterval(max(1, input.intervalMinutes) * 60)
        let anchor = cadenceAnchor(
            lastReminderAt: input.lastReminderAt,
            lastAcknowledgedAt: input.lastAcknowledgedAt
        ) ?? input.now
        var due = anchor.addingTimeInterval(interval)
        if let snooze = input.snoozeUntil, snooze > due { due = snooze }
        return nextWithinWorkHours(due, config: input.config)
    }

    private static func sitStandDue(_ input: Input) -> Date? {
        guard input.config.sitStandModeEnabled else { return nil }
        let phase = TimeInterval(max(1, input.config.sitStandPhaseMinutes) * 60)
        let anchor = input.deskPhaseStartedAt
            ?? cadenceAnchor(lastReminderAt: input.lastReminderAt, lastAcknowledgedAt: input.lastAcknowledgedAt)
            ?? input.now
        var due = anchor.addingTimeInterval(phase)
        if let snooze = input.snoozeUntil, snooze > due { due = snooze }
        return nextWithinWorkHours(due, config: input.config)
    }

    /// Next lunch/wind-down occurrence on a scheduled workday. An occurrence
    /// stays eligible for `graceMinutes` past its time (so a reminder that was
    /// suppressed at the exact minute can still fire), then is skipped for the
    /// day. Occurrences whose day key matches `firedDayKey` already fired.
    private static func nextScheduledOccurrence(
        hour: Int,
        minute: Int,
        graceMinutes: Int,
        firedDayKey: String?,
        config: AppConfig,
        now: Date
    ) -> Date? {
        let calendar = config.scheduleCalendar
        let grace = TimeInterval(max(1, graceMinutes) * 60)
        for dayOffset in 0..<15 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  config.schedule(for: day) != nil else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            guard let occurrence = calendar.date(from: comps) else { continue }
            if occurrence.addingTimeInterval(grace) < now { continue }
            if StatsSnapshot.dayKey(occurrence, calendar: calendar) == firedDayKey { continue }
            return occurrence
        }
        return nil
    }

    /// The given moment if it falls inside work hours, otherwise the start of
    /// the next scheduled workday.
    static func nextWithinWorkHours(_ date: Date, config: AppConfig) -> Date? {
        if config.isWithinWorkHours(at: date) { return date }
        let calendar = config.scheduleCalendar
        for dayOffset in 0..<15 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date),
                  let schedule = config.schedule(for: day) else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = schedule.startHour
            comps.minute = 0
            comps.second = 0
            guard let startOfWork = calendar.date(from: comps), startOfWork >= date else { continue }
            return startOfWork
        }
        return nil
    }
}

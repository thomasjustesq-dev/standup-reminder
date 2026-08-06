import Foundation

/// Deterministic day simulator: pure config + presence timeline → scheduled fires.
/// Used by tests and the debug/timeline UI — no AppKit, no clocks outside inputs.
enum DaySimulation {
    struct PresenceSample: Equatable {
        var at: Date
        /// Presence at this instant; held until the next sample.
        var presence: PresenceState
    }

    struct FiredEvent: Equatable {
        var at: Date
        var kind: Scheduler.Kind
        var presence: PresenceState
    }

    struct Input {
        var config: AppConfig
        var intervalMinutes: Int
        var dayStart: Date
        /// Wall clock samples of presence across the day (sorted).
        var presenceTimeline: [PresenceSample]
        var lastAcknowledgedAt: Date?
        /// If true, a full fire auto-acks after `ackDelay` (simulates Done).
        var autoAck: Bool = true
        var ackDelay: TimeInterval = 60
    }

    /// Walk the day minute-by-minute (or sample boundaries) and emit fires that
    /// would land when presence is `atDesk` (or env-allowed for wind-down/lunch).
    static func run(_ input: Input) -> [FiredEvent] {
        var events: [FiredEvent] = []
        var lastReminder = input.lastAcknowledgedAt
        var lastAck = input.lastAcknowledgedAt
        var lunchKey: String?
        var windKey: String?
        var deskStart = input.lastAcknowledgedAt
        let calendar = input.config.scheduleCalendar
        let end = calendar.date(byAdding: .hour, value: 14, to: input.dayStart) ?? input.dayStart
        var t = input.dayStart
        let step: TimeInterval = 60

        while t <= end {
            let presence = presence(at: t, timeline: input.presenceTimeline)
            let sched = Scheduler.next(Scheduler.Input(
                config: input.config,
                intervalMinutes: input.intervalMinutes,
                now: t,
                paused: presence == .paused || presence == .disabled || presence == .skippedToday,
                snoozeUntil: presence == .snoozing ? t.addingTimeInterval(600) : nil,
                lastReminderAt: lastReminder,
                lastAcknowledgedAt: lastAck,
                deskPhaseStartedAt: deskStart,
                lunchFiredDayKey: lunchKey,
                windDownFiredDayKey: windKey
            ))
            if let next = sched, next.date <= t {
                let canFull = presence == .atDesk
                let canEnv = presence == .atDesk || presence == .focus || presence == .deepWork
                    || presence == .quietApp || presence == .warmingUp || presence == .meeting
                let allowed: Bool = {
                    switch next.kind {
                    case .breakPrompt, .sitStand, .lunch: return canFull
                    case .windDown: return canEnv && presence != .away && presence != .locked
                    }
                }()
                if allowed {
                    events.append(FiredEvent(at: t, kind: next.kind, presence: presence))
                    lastReminder = t
                    if input.autoAck {
                        lastAck = t.addingTimeInterval(input.ackDelay)
                    }
                    if next.kind == .sitStand { deskStart = t }
                    if next.kind == .lunch {
                        lunchKey = StatsSnapshot.dayKey(t, calendar: calendar)
                    }
                    if next.kind == .windDown {
                        windKey = StatsSnapshot.dayKey(t, calendar: calendar)
                    }
                }
            }
            t = t.addingTimeInterval(step)
        }
        return events
    }

    private static func presence(at date: Date, timeline: [PresenceSample]) -> PresenceState {
        guard !timeline.isEmpty else { return .atDesk }
        var current = timeline[0].presence
        for sample in timeline where sample.at <= date {
            current = sample.presence
        }
        return current
    }

    /// Human-readable timeline for debug / Day view.
    static func describe(_ events: [FiredEvent], calendar: Calendar) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "HH:mm"
        if events.isEmpty { return "No fires simulated." }
        return events.map { "\(f.string(from: $0.at)) \($0.kind.rawValue) @ \($0.presence.rawValue)" }
            .joined(separator: "\n")
    }
}

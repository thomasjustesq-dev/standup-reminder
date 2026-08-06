import Foundation

/// Pure policy: which pre-scheduled slots a **follower** device (iPhone) may
/// keep when the cadence **authority** (usually Mac) has published presence
/// and a next-fire gate.
enum FollowerSchedulePolicy {
    /// Presence values that mean "don't deliver a full break banner now."
    static func blocksFullFire(_ presence: PresenceState) -> Bool {
        switch presence {
        case .atDesk:
            return false
        case .warmingUp:
            // Warm-up is local Mac state; followers may still deliver on schedule.
            return false
        case .disabled, .paused, .skippedToday, .snoozing, .pto, .teamQuiet,
             .offHours, .displayAsleep, .locked, .away, .meeting, .focus,
             .quietApp, .deepWork, .onBreak:
            return true
        }
    }

    /// Whether a scheduled slot should become a local notification.
    ///
    /// - Lunch / wind-down are wall-clock social events → always kept.
    /// - Break / sit-stand: drop if before the authority's `nextFireAt`, or if
    ///   they fall in the near window while authority presence is blocking.
    static func shouldSchedule(
        _ next: Scheduler.Next,
        authorityPresence: PresenceState?,
        authorityNextFireAt: Date?,
        now: Date = Date(),
        nearWindow: TimeInterval = 2 * 3600
    ) -> Bool {
        switch next.kind {
        case .lunch, .windDown:
            return true
        case .breakPrompt, .sitStand:
            break
        }

        if let gate = authorityNextFireAt, next.date < gate {
            return false
        }

        if let presence = authorityPresence, blocksFullFire(presence) {
            // No gate yet: suppress breaks that would land while we still
            // believe authority is blocked (near window only — far future
            // presence is unknown).
            if authorityNextFireAt == nil, next.date.timeIntervalSince(now) <= nearWindow {
                return false
            }
        }

        return true
    }

    /// Align the first break to the authority gate when the pure schedule is earlier.
    static func clampFirstBreak(
        chain: [Scheduler.Next],
        authorityNextFireAt: Date?
    ) -> [Scheduler.Next] {
        guard let gate = authorityNextFireAt else { return chain }
        return chain.map { next in
            guard next.kind == .breakPrompt || next.kind == .sitStand else { return next }
            if next.date < gate {
                return Scheduler.Next(date: gate, kind: next.kind)
            }
            return next
        }
    }
}

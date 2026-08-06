import Foundation

/// Pure newest-wins merge of a remote runtime document into local cadence state.
/// Used by Mac AppState and iOS PhoneModel so clear-snooze / clear-skip / pause
/// behave identically. Adaptive interval is newest-doc-wins (no local override).
enum RuntimeMerge {
    struct Local: Equatable {
        var lastReminderAt: Date? = nil
        var lastAcknowledgedAt: Date? = nil
        var snoozeUntil: Date? = nil
        var skipRestOfDayDate: Date? = nil
        var effectiveIntervalMinutes: Int? = nil
        var isPaused: Bool = false
        var lastRuntimeMutationAt: Date? = nil
    }

    struct Outcome: Equatable {
        var local: Local
        var changed: Bool
    }

    /// Apply `remote` when it is strictly newer than this device's last mutation.
    /// Forward-in-time only for anchors; snooze and skip are authoritative clears
    /// when the remote doc is newer and has no active value. Pause is a bool
    /// field: remote wins entirely when the doc is newer.
    static func apply(
        local: Local,
        remote: CloudSync.RuntimeDoc,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Outcome {
        if let stamp = local.lastRuntimeMutationAt, remote.updatedAt <= stamp {
            return Outcome(local: local, changed: false)
        }

        var next = local
        var changed = false

        if let remoteAck = remote.lastAcknowledgedAt,
           (next.lastAcknowledgedAt ?? .distantPast) < remoteAck {
            next.lastAcknowledgedAt = remoteAck
            changed = true
        }
        if let remoteReminder = remote.lastReminderAt,
           (next.lastReminderAt ?? .distantPast) < remoteReminder {
            next.lastReminderAt = remoteReminder
            changed = true
        }

        // Snooze: future remote extends; nil/past remote clears when doc is newer.
        if let remoteSnooze = remote.snoozeUntil, remoteSnooze > now {
            if (next.snoozeUntil ?? .distantPast) < remoteSnooze {
                next.snoozeUntil = remoteSnooze
                changed = true
            }
        } else if next.snoozeUntil != nil {
            next.snoozeUntil = nil
            changed = true
        }

        // Skip-today: active remote sets; inactive remote clears.
        let remoteSkipActive = remote.skipRestOfDayDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        let localSkipActive = next.skipRestOfDayDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        if remoteSkipActive {
            if !localSkipActive || next.skipRestOfDayDate != remote.skipRestOfDayDate {
                next.skipRestOfDayDate = remote.skipRestOfDayDate
                changed = true
            }
        } else if localSkipActive {
            next.skipRestOfDayDate = nil
            changed = true
        }

        // Adaptive interval: newest remote doc wins (hysteresis applied by callers
        // when *computing* a new local value, not when applying a peer).
        if let minutes = remote.effectiveIntervalMinutes, minutes > 0,
           next.effectiveIntervalMinutes != minutes {
            next.effectiveIntervalMinutes = minutes
            changed = true
        }

        // Pause: authoritative bool when present on a newer doc.
        if let remotePaused = remote.isPaused, next.isPaused != remotePaused {
            next.isPaused = remotePaused
            changed = true
        }

        return Outcome(local: next, changed: changed)
    }

    /// Only accept a newly computed adaptive interval if it moved enough to
    /// matter — avoids multi-Mac thrash from 1-minute sample noise.
    static func shouldPublishAdaptiveChange(from current: Int, to candidate: Int, minimumDelta: Int = 5) -> Bool {
        abs(candidate - current) >= minimumDelta
    }
}

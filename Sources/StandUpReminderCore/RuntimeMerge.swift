import Foundation

/// Pure newest-wins merge of a remote runtime document into local cadence state.
/// Used by Mac AppState and iOS PhoneModel so clear-snooze / clear-skip behave identically.
enum RuntimeMerge {
    struct Local: Equatable {
        var lastReminderAt: Date? = nil
        var lastAcknowledgedAt: Date? = nil
        var snoozeUntil: Date? = nil
        var skipRestOfDayDate: Date? = nil
        var effectiveIntervalMinutes: Int? = nil
        var lastRuntimeMutationAt: Date? = nil
    }

    struct Outcome: Equatable {
        var local: Local
        var changed: Bool
    }

    /// Apply `remote` when it is strictly newer than this device's last mutation.
    /// Forward-in-time only for anchors; snooze and skip are authoritative clears
    /// when the remote doc is newer and has no active value.
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
        // Use `now` (not Calendar.isDateInToday) so tests and delayed merges
        // evaluate the same day as the runtime stamp.
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

        if let minutes = remote.effectiveIntervalMinutes, minutes > 0,
           next.effectiveIntervalMinutes != minutes {
            next.effectiveIntervalMinutes = minutes
            changed = true
        }

        return Outcome(local: next, changed: changed)
    }
}

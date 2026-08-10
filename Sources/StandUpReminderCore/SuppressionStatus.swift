import Foundation

/// Pure formatters for glanceable “why didn’t it fire?” UI.
enum SuppressionStatus {
    /// Status strings that mean “not a quiet-rule hold” — don’t show as Held.
    static let nonHoldStatuses: Set<String> = [
        "Armed", "Disabled", "Paused", "Skipped today", "Snoozing", "Outside work hours"
    ]

    static func isHoldStatus(_ status: String) -> Bool {
        !nonHoldStatuses.contains(status)
    }

    /// Menu line while currently held, e.g. `Held: Meeting · 2m ago`.
    static func heldLine(
        currentStatus: String,
        lastReason: String?,
        lastAt: Date?,
        now: Date = Date()
    ) -> String? {
        if isHoldStatus(currentStatus) {
            let age = lastAt.map { relativeAge($0, now: now) } ?? "now"
            // Prefer live status (may match lastReason).
            return "Held: \(currentStatus) · \(age)"
        }
        if let lastReason, isHoldStatus(lastReason), let lastAt {
            // Recently held but now armed — still useful briefly within 30m.
            let ageSec = now.timeIntervalSince(lastAt)
            if ageSec <= 30 * 60 {
                return "Last held: \(lastReason) · \(relativeAge(lastAt, now: now))"
            }
        }
        return nil
    }

    /// Top counter line, e.g. `Top block today: Meeting (4)`.
    static func topBlockLine(dayKey: String, byReason: [String: Int]) -> String? {
        guard let top = byReason.max(by: { $0.value < $1.value }) else { return nil }
        return "Top block today: \(top.key) (\(top.value))"
    }

    /// Follower lease glance: `lease 3m · iMac` / `expired 18m · iMac`.
    static func leaseLine(
        authorityUpdatedAt: Date?,
        authorityName: String?,
        now: Date = Date(),
        ttl: TimeInterval = AuthorityLease.defaultTTL
    ) -> String? {
        guard let stamp = authorityUpdatedAt else {
            return "lease: never seen"
        }
        let mins = max(0, Int(now.timeIntervalSince(stamp) / 60))
        let who = authorityName.map { " · \($0)" } ?? ""
        if AuthorityLease.isAlive(updatedAt: stamp, now: now, ttl: ttl) {
            return "lease \(mins)m\(who)"
        }
        return "expired \(mins)m\(who)"
    }

    static func relativeAge(_ date: Date, now: Date = Date()) -> String {
        let s = Int(now.timeIntervalSince(date))
        if s < 60 { return "just now" }
        if s < 3600 { return "\(s / 60)m ago" }
        if s < 86400 { return "\(s / 3600)h ago" }
        return "\(s / 86400)d ago"
    }
}

/// Why the iOS upcoming list is empty while reminders are “on.”
enum EmptyQueueReason: String, Equatable {
    case notificationsDenied
    case disabled
    case paused
    case skippedToday
    case snoozing
    case authorityBlocking
    case outsideHoursOrEmpty
    case notEmpty

    static func classify(
        configEnabled: Bool,
        isPaused: Bool,
        isSkipToday: Bool,
        isSnoozing: Bool,
        notificationsAuthorized: Bool,
        upcomingEmpty: Bool,
        honorsAuthority: Bool,
        authorityPresence: PresenceState?
    ) -> EmptyQueueReason {
        if !notificationsAuthorized { return .notificationsDenied }
        if !configEnabled { return .disabled }
        if isPaused { return .paused }
        if isSkipToday { return .skippedToday }
        if isSnoozing { return .snoozing }
        guard upcomingEmpty else { return .notEmpty }
        if honorsAuthority,
           let p = authorityPresence,
           FollowerSchedulePolicy.blocksFullFire(p) {
            return .authorityBlocking
        }
        return .outsideHoursOrEmpty
    }

    var displayLine: String? {
        switch self {
        case .notEmpty: return nil
        case .notificationsDenied: return "Notifications denied — enable in Settings"
        case .disabled: return "Reminders disabled"
        case .paused: return "Paused"
        case .skippedToday: return "Skipped today"
        case .snoozing: return "Snoozing"
        case .authorityBlocking: return nil // presence line already covers
        case .outsideHoursOrEmpty: return "No upcoming slots (outside hours or filtered)"
        }
    }
}

/// Pure policy: when auto-open of guided break may activate the app.
/// The guided window is always presented; only *activation* is gated so
/// Zoom/Keynote are not yanked to the background.
enum GuidedBreakOpenPolicy {
    /// User tapped banner/action → always activate.
    /// Auto fire → respect denylist/fullscreen unless stealFocus is on.
    static func shouldActivateApp(
        userInitiated: Bool,
        stealFocus: Bool,
        frontmostIsDenylisted: Bool,
        isFullscreenDeepWork: Bool
    ) -> Bool {
        if userInitiated { return true }
        if stealFocus { return true }
        if frontmostIsDenylisted { return false }
        if isFullscreenDeepWork { return false }
        return true
    }
}

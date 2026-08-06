import Foundation

/// Inputs for presence resolution and fire gates. AppState builds this from
/// live monitors; unit tests inject fixtures.
struct FireGateContext: Equatable {
    var enabled: Bool = true
    var paused: Bool = false
    var skipToday: Bool = false
    var snoozing: Bool = false
    var onPTO: Bool = false
    var teamQuiet: Bool = false
    var withinWorkHoursOrWindDown: Bool = true
    var displayAsleep: Bool = false
    var skipWhenDisplayAsleep: Bool = true
    var screenLocked: Bool = false
    var skipWhenLocked: Bool = true
    var focused: Bool = false
    var skipWhenFocused: Bool = true
    var inMeeting: Bool = false
    var skipWhenInMeeting: Bool = true
    var denylisted: Bool = false
    var deepWork: Bool = false
    var deepWorkEnabled: Bool = true
    /// Seconds since last break anchor; deep work is ignored past overdueLimit.
    var sinceAnchor: TimeInterval = 0
    var overdueLimit: TimeInterval = 60 * 60
    var idle: Bool = false
    var activeFor: TimeInterval = 0
    var minActiveSeconds: TimeInterval = 0
    /// Lunch/wind-down skip the min-active warm-up.
    var isLunchOrWindDown: Bool = false
    /// Guided break UI open.
    var onBreak: Bool = false
}

struct FireGateResult: Equatable {
    var allowed: Bool
    var status: String
    var presence: PresenceState
}

enum FireGateEvaluator {
    /// Presence-first evaluation: one state, then fire permission.
    static func evaluate(_ ctx: FireGateContext) -> FireGateResult {
        let presence = PresenceResolver.resolve(ctx)
        if presence == .warmingUp {
            return FireGateResult(
                allowed: false,
                status: "Warming up (active \(Int(ctx.activeFor / 60))m)",
                presence: presence
            )
        }
        if presence == .atDesk {
            return FireGateResult(allowed: true, status: "Armed", presence: .atDesk)
        }
        return FireGateResult(allowed: false, status: presence.displayName, presence: presence)
    }

    /// Environment-only gate used by wind-down and meeting catch-up.
    /// Ignores meeting/focus/deep-work/denylist/warm-up; still blocks
    /// locked, asleep, away, off-hours, pause, disabled.
    static func environmentAllows(_ ctx: FireGateContext) -> Bool {
        var env = ctx
        env.inMeeting = false
        env.focused = false
        env.deepWork = false
        env.denylisted = false
        env.minActiveSeconds = 0
        env.onBreak = false
        let presence = PresenceResolver.resolve(env)
        switch presence {
        case .atDesk, .warmingUp:
            return true
        case .disabled, .paused, .skippedToday, .snoozing, .pto, .teamQuiet,
             .offHours, .displayAsleep, .locked, .away, .onBreak:
            return false
        case .meeting, .focus, .quietApp, .deepWork:
            // Cleared above — should not appear.
            return true
        }
    }
}

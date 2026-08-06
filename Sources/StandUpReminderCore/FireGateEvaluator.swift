import Foundation

/// Pure quiet-rule evaluation for the full fire gate. AppState builds the
/// context from live monitors; unit tests inject fixtures.
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
}

enum FireGateEvaluator {
    /// Returns whether a full-gated fire may proceed, and a status string for the menu bar.
    static func evaluate(_ ctx: FireGateContext) -> (allowed: Bool, status: String) {
        if !ctx.enabled { return (false, "Disabled") }
        if ctx.paused { return (false, "Paused") }
        if ctx.skipToday { return (false, "Skipped today") }
        if ctx.snoozing { return (false, "Snoozing") }
        if ctx.onPTO { return (false, "PTO / OOO") }
        if ctx.teamQuiet { return (false, "Team quiet hours") }
        if !ctx.withinWorkHoursOrWindDown { return (false, "Outside work hours") }
        if ctx.skipWhenDisplayAsleep && ctx.displayAsleep { return (false, "Display asleep") }
        if ctx.skipWhenLocked && ctx.screenLocked { return (false, "Screen locked") }
        if ctx.skipWhenFocused && ctx.focused { return (false, "Focus mode on") }
        if ctx.skipWhenInMeeting && ctx.inMeeting { return (false, "In a meeting") }
        if ctx.denylisted { return (false, "Quiet app (denylist)") }
        if ctx.deepWorkEnabled && ctx.deepWork && ctx.sinceAnchor < ctx.overdueLimit {
            return (false, "Deep work")
        }
        if ctx.idle { return (false, "Idle — skipped") }
        if !ctx.isLunchOrWindDown, ctx.minActiveSeconds > 0, ctx.activeFor < ctx.minActiveSeconds {
            return (false, "Warming up (active \(Int(ctx.activeFor / 60))m)")
        }
        return (true, "Armed")
    }

    /// Environment-only gate used by wind-down and meeting catch-up.
    static func environmentAllows(_ ctx: FireGateContext) -> Bool {
        guard ctx.enabled, !ctx.paused, !ctx.skipToday else { return false }
        guard ctx.withinWorkHoursOrWindDown else { return false }
        if ctx.skipWhenDisplayAsleep && ctx.displayAsleep { return false }
        if ctx.skipWhenLocked && ctx.screenLocked { return false }
        if ctx.idle { return false }
        return true
    }
}

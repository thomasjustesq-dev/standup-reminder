import Foundation

/// Single presence state for the Mac (and any authority device). Quiet rules
/// resolve to exactly one state; full-gated reminders only fire from `atDesk`.
enum PresenceState: String, Codable, CaseIterable, Equatable {
    case disabled
    case paused
    case skippedToday
    case snoozing
    case pto
    case teamQuiet
    case offHours
    case displayAsleep
    case locked
    case away
    case meeting
    case focus
    case quietApp
    case deepWork
    case warmingUp
    case onBreak
    case atDesk

    var displayName: String {
        switch self {
        case .disabled: return "Disabled"
        case .paused: return "Paused"
        case .skippedToday: return "Skipped today"
        case .snoozing: return "Snoozing"
        case .pto: return "PTO / OOO"
        case .teamQuiet: return "Team quiet hours"
        case .offHours: return "Outside work hours"
        case .displayAsleep: return "Display asleep"
        case .locked: return "Screen locked"
        case .away: return "Away"
        case .meeting: return "In a meeting"
        case .focus: return "Focus mode on"
        case .quietApp: return "Quiet app (denylist)"
        case .deepWork: return "Deep work"
        case .warmingUp: return "Warming up"
        case .onBreak: return "On break"
        case .atDesk: return "At desk"
        }
    }

    var symbolName: String {
        switch self {
        case .atDesk: return "figure.stand"
        case .away: return "figure.walk"
        case .meeting: return "person.3"
        case .focus, .deepWork: return "brain.head.profile"
        case .snoozing, .paused, .disabled: return "pause.circle"
        case .onBreak: return "figure.cooldown"
        default: return "moon.zzz"
        }
    }
}

/// Cadence ownership across devices. Authority evaluates presence; followers
/// schedule from shared anchors without inventing quiet rules.
enum CadenceRole: String, Codable, CaseIterable, Identifiable {
    case authority
    case follower
    case automatic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .authority: return "Authority (quiet rules here)"
        case .follower: return "Follower (cadence only)"
        case .automatic: return "Automatic (Mac = authority)"
        }
    }

    /// Resolve automatic based on platform.
    static func resolved(configRole: CadenceRole, isMac: Bool) -> CadenceRole {
        switch configRole {
        case .authority, .follower: return configRole
        case .automatic: return isMac ? .authority : .follower
        }
    }
}

enum PresenceResolver {
    /// Priority order ends at `atDesk` when nothing suppresses.
    static func resolve(_ ctx: FireGateContext) -> PresenceState {
        if !ctx.enabled { return .disabled }
        if ctx.paused { return .paused }
        if ctx.skipToday { return .skippedToday }
        if ctx.snoozing { return .snoozing }
        if ctx.onPTO { return .pto }
        if ctx.teamQuiet { return .teamQuiet }
        if !ctx.withinWorkHoursOrWindDown { return .offHours }
        if ctx.skipWhenDisplayAsleep && ctx.displayAsleep { return .displayAsleep }
        if ctx.skipWhenLocked && ctx.screenLocked { return .locked }
        if ctx.idle { return .away }
        if ctx.onBreak { return .onBreak }
        if ctx.skipWhenInMeeting && ctx.inMeeting { return .meeting }
        if ctx.skipWhenFocused && ctx.focused { return .focus }
        if ctx.denylisted { return .quietApp }
        if ctx.deepWorkEnabled && ctx.deepWork && ctx.sinceAnchor < ctx.overdueLimit {
            return .deepWork
        }
        if !ctx.isLunchOrWindDown, ctx.minActiveSeconds > 0, ctx.activeFor < ctx.minActiveSeconds {
            return .warmingUp
        }
        return .atDesk
    }
}

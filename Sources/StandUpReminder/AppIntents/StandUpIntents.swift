import AppIntents
import Foundation

/// Shortcuts / Siri entry points for the menu bar app (macOS 14+).
struct LogBreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Log movement break"
    static var description = IntentDescription("Marks a break as done and re-anchors the schedule.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppState.shared.acknowledgeDone()
        return .result(dialog: "Break logged.")
    }
}

struct SnoozeBreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Snooze stand-up reminder"
    static var description = IntentDescription("Snoozes the next movement reminder.")

    @Parameter(title: "Minutes", default: 15)
    var minutes: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let m = max(5, min(minutes, 120))
        AppState.shared.snooze(minutes: m)
        return .result(dialog: "Snoozed \(m) minutes.")
    }
}

struct PauseUntilIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause stand-up reminders"
    static var description = IntentDescription("Pauses reminders until you resume.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppState.shared.pause()
        return .result(dialog: "Reminders paused.")
    }
}

struct ResumeRemindersIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume stand-up reminders"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppState.shared.resume()
        return .result(dialog: "Reminders resumed.")
    }
}

struct StandUpShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogBreakIntent(),
            phrases: ["Log a break in \(.applicationName)", "I stood up in \(.applicationName)"],
            shortTitle: "Log break",
            systemImageName: "figure.stand"
        )
        AppShortcut(
            intent: SnoozeBreakIntent(),
            phrases: [
                "Snooze \(.applicationName)",
                "Snooze stand up reminder in \(.applicationName)"
            ],
            shortTitle: "Snooze",
            systemImageName: "zzz"
        )
        AppShortcut(
            intent: PauseUntilIntent(),
            phrases: ["Pause \(.applicationName)"],
            shortTitle: "Pause",
            systemImageName: "pause.circle"
        )
        AppShortcut(
            intent: ResumeRemindersIntent(),
            phrases: ["Resume \(.applicationName)"],
            shortTitle: "Resume",
            systemImageName: "play.circle"
        )
    }
}

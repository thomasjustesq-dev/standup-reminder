import Foundation

enum CLI {
    /// Returns true if the process should exit after handling CLI (caller exits).
    @MainActor
    static func runIfNeeded() -> Bool {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else { return false }

        let state = AppState.shared

        switch command {
        case "status":
            state.refreshNextFire()
            _ = state.shouldFireNow(force: false)
            print(state.statusReport())
            return true
        case "pause":
            state.pause()
            print("Paused.")
            return true
        case "resume":
            state.resume()
            print("Resumed.")
            return true
        case "enable":
            state.setEnabled(true)
            print("Enabled.")
            return true
        case "disable":
            state.setEnabled(false)
            print("Disabled.")
            return true
        case "snooze":
            let minutes = Int(args.dropFirst().first ?? "10") ?? 10
            state.snooze(minutes: minutes)
            print("Snoozed \(minutes) minutes.")
            return true
        case "skip-today":
            state.skipToday()
            print("Skipping remaining reminders today.")
            return true
        case "test":
            state.testStandUp()
            // Allow notification delivery to enqueue
            Thread.sleep(forTimeInterval: 0.5)
            print("Test stand-up notification sent.")
            return true
        case "test-lunch":
            state.testLunch()
            Thread.sleep(forTimeInterval: 0.5)
            print("Test lunch notification sent.")
            return true
        case "help", "-h", "--help":
            print(helpText)
            return true
        default:
            if command.hasPrefix("-") {
                return false
            }
            fputs("Unknown command: \(command)\n\n\(helpText)\n", stderr)
            exit(2)
        }
    }

    static let helpText = """
    Stand Up Reminder CLI

    Usage:
      StandUpReminder                 Launch menu bar app
      StandUpReminder status          Show status and weekly stats
      StandUpReminder pause           Pause reminders
      StandUpReminder resume          Resume reminders
      StandUpReminder enable          Turn reminders on
      StandUpReminder disable         Turn reminders off
      StandUpReminder snooze [min]    Snooze (default 10)
      StandUpReminder skip-today      Skip the rest of today
      StandUpReminder test            Fire a stand-up notification
      StandUpReminder test-lunch      Fire a lunch notification
      StandUpReminder help            Show this help
    """
}

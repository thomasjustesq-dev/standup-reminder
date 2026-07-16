import Foundation

enum CLI {
    /// The CLI runs as a second instance of the app binary and mutates the
    /// shared JSON stores on disk. After any mutation it posts a distributed
    /// notification so the running menu bar app reloads immediately instead
    /// of waiting for its next tick.
    @MainActor
    private static func notifyRunningApp() {
        DistributedNotificationCenter.default().postNotificationName(
            .standUpExternalStateChanged,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    @MainActor
    static func runIfNeeded() async -> Bool {
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
            state.pause(); notifyRunningApp(); print("Paused."); return true
        case "resume":
            state.resume(); notifyRunningApp(); print("Resumed."); return true
        case "enable":
            state.setEnabled(true); notifyRunningApp(); print("Enabled."); return true
        case "disable":
            state.setEnabled(false); notifyRunningApp(); print("Disabled."); return true
        case "snooze":
            let minutes = Int(args.dropFirst().first ?? "10") ?? 10
            state.snooze(minutes: minutes)
            notifyRunningApp()
            print("Snoozed \(minutes) minutes.")
            return true
        case "skip-today":
            state.skipToday(); notifyRunningApp(); print("Skipping remaining reminders today."); return true
        case "profile":
            guard let idOrName = args.dropFirst().first else {
                for p in state.profiles.profiles {
                    let mark = p.id == state.profiles.activeProfileId ? "*" : " "
                    print("\(mark) \(p.id)  \(p.name)")
                }
                return true
            }
            if let byId = state.profiles.profiles.first(where: { $0.id == idOrName }) {
                state.switchProfile(id: byId.id)
            } else if let byName = state.profiles.profiles.first(where: { $0.name.lowercased() == idOrName.lowercased() }) {
                state.switchProfile(id: byName.id)
            } else {
                fputs("Profile not found: \(idOrName)\n", stderr)
                exit(2)
            }
            notifyRunningApp()
            print("Switched to \(state.activeProfileName)")
            return true
        case "pack":
            guard let name = args.dropFirst().first else {
                print("Packs: " + ReminderPack.allCases.map(\.rawValue).joined(separator: ", "))
                return true
            }
            guard let pack = ReminderPack(rawValue: name)
                    ?? ReminderPack.allCases.first(where: { $0.displayName.lowercased() == name.lowercased() }) else {
                print("Packs: " + ReminderPack.allCases.map(\.rawValue).joined(separator: ", "))
                return true
            }
            state.applyReminderPack(pack)
            notifyRunningApp()
            print("Applied pack: \(pack.displayName)")
            return true
        case "export":
            let path = args.dropFirst().first ?? "standup-reminder-settings.json"
            do {
                let data = try state.exportSettings()
                try data.write(to: URL(fileURLWithPath: path))
                print("Exported \(path)")
            } catch {
                fputs("Export failed: \(error)\n", stderr)
                exit(1)
            }
            return true
        case "import":
            guard let path = args.dropFirst().first else {
                fputs("Usage: standup-reminder import <file.json>\n", stderr)
                exit(2)
            }
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                try state.importSettings(data)
                notifyRunningApp()
                print("Imported \(path)")
            } catch {
                fputs("Import failed: \(error)\n", stderr)
                exit(1)
            }
            return true
        case "test":
            state.testStandUp()
            try? await Task.sleep(nanoseconds: 500_000_000)
            print("Test stand-up sent.")
            return true
        case "test-lunch":
            state.testLunch()
            try? await Task.sleep(nanoseconds: 500_000_000)
            print("Test lunch sent.")
            return true
        case "test-wind-down":
            state.testWindDown()
            try? await Task.sleep(nanoseconds: 500_000_000)
            print("Test wind-down sent.")
            return true
        case "test-guided":
            state.testGuided()
            try? await Task.sleep(nanoseconds: 500_000_000)
            print("Guided break opened.")
            return true
        case "icloud-push":
            state.pushToiCloud(); print("Pushed."); return true
        case "icloud-pull":
            state.pullFromiCloud(); notifyRunningApp(); print(state.statusMessage); return true
        case "weather":
            await state.refreshWeather()
            if let w = state.weather {
                print(String(format: "%.0f°C code=%d nice=%@ — %@", w.temperatureC, w.weatherCode, w.isNiceForWalk ? "yes" : "no", w.summary))
            } else {
                print("No weather (disabled or fetch failed).")
            }
            return true
        case "learn-apply":
            state.refreshLearnedSuggestion()
            state.applyLearnedSchedule()
            notifyRunningApp()
            print(state.statusMessage)
            return true
        case "help", "-h", "--help":
            print(helpText); return true
        default:
            if command.hasPrefix("-") { return false }
            fputs("Unknown command: \(command)\n\n\(helpText)\n", stderr)
            exit(2)
        }
    }

    static let helpText = """
    Stand Up Reminder CLI

      StandUpReminder                      Launch menu bar app
      standup-reminder status              Status + weekly stats
      standup-reminder pause|resume
      standup-reminder enable|disable
      standup-reminder snooze [min]
      standup-reminder skip-today
      standup-reminder profile [id|name]   List or switch profiles
      standup-reminder pack [name]         Apply reminder pack
      standup-reminder export [file.json]
      standup-reminder import <file.json>
      standup-reminder test|test-lunch|test-wind-down|test-guided
      standup-reminder icloud-push|icloud-pull
      standup-reminder weather
      standup-reminder learn-apply
      standup-reminder help
    """
}

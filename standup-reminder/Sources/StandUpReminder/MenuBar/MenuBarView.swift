import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private var nextFireText: String {
        guard let next = appState.nextFireAt else { return "No upcoming reminder" }
        let formatter = DateFormatter()
        formatter.timeZone = appState.config.scheduleTimeZone
        formatter.dateFormat = "EEE h:mm a"
        return "Next: \(formatter.string(from: next)) · every \(appState.effectiveIntervalMinutes)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(appState.statusMessage)
                .font(.headline)
            Text("Profile: \(appState.activeProfileName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(nextFireText)
                .font(.caption)
                .foregroundStyle(.secondary)
            if appState.config.sitStandModeEnabled {
                Text("Desk: \(appState.deskPhase.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(appState.weekStatsText())
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            if let update = appState.updateInfo, update.isNewer {
                Text("Update available: \(update.tagName)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            if appState.showOnboarding {
                openWindow(id: "onboarding")
            }
            if appState.showGuidedBreak {
                openWindow(id: "guided-break")
            }
        }
        .onChange(of: appState.showGuidedBreak) { _, shouldOpen in
            if shouldOpen { openWindow(id: "guided-break") }
        }

        Divider()

        Toggle("Reminders enabled", isOn: Binding(
            get: { appState.config.enabled },
            set: { appState.setEnabled($0) }
        ))

        if appState.isPaused {
            Button("Resume") { appState.resume() }
        } else {
            Button("Pause") { appState.pause() }
                .disabled(!appState.config.enabled)
        }

        Button("Snooze 10 minutes") { appState.snooze(minutes: 10) }
            .disabled(!appState.config.enabled)
        Button("Skip rest of today") { appState.skipToday() }
            .disabled(!appState.config.enabled)

        Menu("Profile") {
            ForEach(appState.profiles.profiles) { profile in
                Button(profile.name) { appState.switchProfile(id: profile.id) }
            }
        }

        Divider()

        Button("Start guided break") { appState.testGuided() }
        Button("Test stand-up reminder") { appState.testStandUp() }
        Button("Test lunch reminder") { appState.testLunch() }
        Button("Test end-of-day") { appState.testWindDown() }

        Divider()

        Button("Settings…") { openSettings() }
            .keyboardShortcut(",", modifiers: .command)
        Button("Welcome / permissions…") { openWindow(id: "onboarding") }

        if let update = appState.updateInfo, update.isNewer, let url = URL(string: update.htmlURL) {
            Button("Download update…") { NSWorkspace.shared.open(url) }
        }

        Divider()

        Button("Quit Stand Up Reminder") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

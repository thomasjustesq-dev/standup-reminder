import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private var nextFireText: String {
        guard let next = appState.nextFireAt else { return "No upcoming reminder" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return "Next: \(formatter.string(from: next))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(appState.statusMessage)
                .font(.headline)
            Text(nextFireText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(appState.weekStatsText())
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            if appState.showOnboarding {
                openWindow(id: "onboarding")
            }
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

        Divider()

        Button("Test stand-up reminder") { appState.testStandUp() }
        Button("Test lunch reminder") { appState.testLunch() }

        Divider()

        Button("Settings…") {
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Welcome / permissions…") {
            openWindow(id: "onboarding")
        }

        Divider()

        Button("Quit Stand Up Reminder") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

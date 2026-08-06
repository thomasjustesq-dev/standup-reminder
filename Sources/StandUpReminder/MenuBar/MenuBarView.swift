import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
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
            if appState.notificationsAuthorized == false {
                Text("⚠ Notifications are off — reminders can't appear")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text("Mac · primary quiet-rule suppressor")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Profile: \(appState.activeProfileName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(nextFireText)
                .font(.caption)
                .foregroundStyle(.secondary)
            if appState.config.features.iCloudSyncEnabled {
                Text(appState.syncHealth.summary(iCloudEnabled: true))
                    .font(.caption2)
                    .foregroundStyle(appState.syncHealth.lastPullWasStale ? .orange : .secondary)
            }
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
        // All window opens go through the AppDelegate presenter so its
        // dedup applies — mixing openWindow here with the fallback windows
        // could show two live copies of the same UI.
        .onAppear {
            if appState.showOnboarding {
                NotificationCenter.default.post(name: .openOnboardingWindow, object: nil)
            }
            if appState.showGuidedBreak {
                NotificationCenter.default.post(name: .openGuidedBreakWindow, object: nil)
            }
        }
        .onChange(of: appState.showGuidedBreak) { _, shouldOpen in
            if shouldOpen { NotificationCenter.default.post(name: .openGuidedBreakWindow, object: nil) }
        }
        .onChange(of: appState.showSampleDayTour) { _, shouldOpen in
            if shouldOpen { NotificationCenter.default.post(name: .openSampleDayTour, object: nil) }
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

        if appState.notificationsAuthorized == false {
            Button("Enable notifications…") {
                // macOS 13+ Notifications pane; fall back to legacy pref pane id.
                let candidates = [
                    "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
                    "x-apple.systempreferences:com.apple.preference.notifications"
                ]
                for target in candidates {
                    if let url = URL(string: target) {
                        NSWorkspace.shared.open(url)
                        break
                    }
                }
            }
        }

        if appState.config.features.iCloudSyncEnabled, appState.syncHealth.lastPullWasStale {
            Button("Push local settings to iCloud") { _ = appState.pushToiCloud() }
            Button("Force pull (overwrite local)") { _ = appState.pullFromiCloud(force: true) }
        }

        Button("Settings…") { openSettings() }
            .keyboardShortcut(",", modifiers: .command)
        Button("Welcome / permissions…") { NotificationCenter.default.post(name: .openOnboardingWindow, object: nil) }
        Button("Sample day tour…") { NotificationCenter.default.post(name: .openSampleDayTour, object: nil) }

        if let update = appState.updateInfo, update.isNewer, let url = URL(string: update.htmlURL) {
            Button("Download update…") { NSWorkspace.shared.open(url) }
        }

        Divider()

        Button("Quit Stand Up Reminder") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)

        #if DEBUG
        if DebugEnvironment.isDebugMode {
            Divider()
            Button("Debug Panel…") {
                NotificationCenter.default.post(name: .openDebugPanel, object: nil)
            }
        }
        #endif
    }
}

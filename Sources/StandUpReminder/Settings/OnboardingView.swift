import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fallbackWindowClose) private var fallbackWindowClose

    /// DismissAction is inert inside an AppDelegate fallback window.
    private func closeWindow() {
        if let fallbackWindowClose { fallbackWindowClose() } else { dismiss() }
    }

    @State private var enableCalendar = true
    @State private var enableFocus = true
    @State private var enableHealth = false
    @State private var enableiCloud = false
    @State private var enableVoice = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Stand Up Reminder")
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text("Breaks that respect meetings, Focus, team quiet hours, and optionally sync across your Macs.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Label("Notifications + guided breaks", systemImage: "bell.badge")
                Label("Optional Calendar, Focus, Health, Camera (stillness)", systemImage: "lock.shield")
                Label("iCloud sync, Watch Done button, voice chimes", systemImage: "applewatch")
                Label("Sample-day tour so you see 9→5 in a minute", systemImage: "map")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Toggle("Calendar (meetings + OOO)", isOn: $enableCalendar)
            Toggle("Focus / Do Not Disturb", isOn: $enableFocus)
            Toggle("Apple Health mindful minutes on Done", isOn: $enableHealth)
            Toggle("iCloud settings sync", isOn: $enableiCloud)
            Toggle("Voice announcements", isOn: $enableVoice)

            HStack {
                Spacer()
                Button("Not now") {
                    appState.config.hasCompletedOnboarding = true
                    appState.showOnboarding = false
                    closeWindow()
                }
                Button("Enable & start") {
                    var c = appState.config
                    c.features.iCloudSyncEnabled = enableiCloud
                    c.features.voiceAnnouncementsEnabled = enableVoice
                    appState.config = c
                    appState.completeOnboarding(
                        enableCalendar: enableCalendar,
                        enableFocus: enableFocus,
                        enableHealth: enableHealth
                    )
                    closeWindow()
                    if appState.config.features.showSampleDayTour {
                        appState.showSampleDayTour = true
                        NotificationCenter.default.post(name: .openSampleDayTour, object: nil)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560)
    }
}

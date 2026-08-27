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
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AeroColor.volt.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "figure.stand")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AeroColor.volt)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stand Up Reminder")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AeroColor.titaniumWhite)
                        .accessibilityAddTraits(.isHeader)
                    Text("Smart ergonomic breaks respecting meetings, Focus, and quiet hours.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(AeroColor.vaporGray)
                }
            }

            // Feature Pillars
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "bell.badge", title: "Smart Notifications & Guided Breaks", detail: "Timed stretching routines and posture cues")
                featureRow(icon: "lock.shield", title: "Meeting & Focus Guard", detail: "Automatic suppression during calls or screen lock")
                featureRow(icon: "applewatch", title: "iCloud Sync & Apple Watch", detail: "Unified schedule and haptic alerts across all devices")
            }
            .padding(14)
            .aeroGlassCard(cornerRadius: 14)

            // Permissions / Integrations Toggle Card
            VStack(alignment: .leading, spacing: 10) {
                Text("INTEGRATIONS & PREFERENCES")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(AeroColor.vaporGray)
                
                Toggle("Calendar (meetings + OOO)", isOn: $enableCalendar)
                Toggle("Focus / Do Not Disturb state", isOn: $enableFocus)
                Toggle("Apple Health mindful minutes on Done", isOn: $enableHealth)
                Toggle("iCloud multi-device cadence sync", isOn: $enableiCloud)
                Toggle("Voice chime announcements", isOn: $enableVoice)
            }
            .font(.system(size: 12.5))
            .padding(14)
            .aeroGlassCard(cornerRadius: 14)

            // Bottom Buttons
            HStack(spacing: 12) {
                Button("Not now") {
                    appState.config.hasCompletedOnboarding = true
                    appState.showOnboarding = false
                    closeWindow()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AeroColor.vaporGray)
                
                Spacer()
                
                AeroGlassButton(title: "Enable & Start Using", isProminent: true) {
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
                .frame(width: 180)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 540)
        .background(AeroColor.void)
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AeroColor.volt)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AeroColor.titaniumWhite)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(AeroColor.vaporGray)
            }
        }
    }
}

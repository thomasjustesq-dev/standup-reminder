import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var enableCalendar = true
    @State private var enableFocus = true
    @State private var enableHealth = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Stand Up Reminder")
                .font(.largeTitle.weight(.bold))
            Text("Break nudges for real workdays — stand/sit desk cues, lunch, wind-down, guided stretches, and quiet rules for meetings & deep work.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Label("Notifications with Done / Snooze / Guided break", systemImage: "bell.badge")
                Label("Optional Focus, Calendar (meetings + PTO), and Health", systemImage: "heart.text.square")
                Label("Profiles for Office Mac vs Laptop", systemImage: "laptopcomputer")
                Label("Menu bar countdown to your next break", systemImage: "timer")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Toggle("Calendar (meetings + OOO)", isOn: $enableCalendar)
            Toggle("Focus / Do Not Disturb", isOn: $enableFocus)
            Toggle("Apple Health mindful minutes on Done", isOn: $enableHealth)

            HStack {
                Spacer()
                Button("Not now") {
                    appState.config.hasCompletedOnboarding = true
                    appState.showOnboarding = false
                    dismiss()
                }
                Button("Enable & start") {
                    appState.completeOnboarding(
                        enableCalendar: enableCalendar,
                        enableFocus: enableFocus,
                        enableHealth: enableHealth
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 540)
    }
}

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var enableCalendar = true
    @State private var enableFocus = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Stand Up Reminder")
                .font(.largeTitle.weight(.bold))
            Text("Gentle break nudges while you work — stand/move, stretches, water, eye rest, and lunch at noon.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Label("Notification permission so alerts can appear", systemImage: "bell.badge")
                Label("Optional Focus status to avoid interrupting deep work", systemImage: "moon.fill")
                Label("Optional Calendar access to skip during meetings", systemImage: "calendar")
                Label("Menu bar controls for pause, snooze, and skip today", systemImage: "menubar.arrow.up.rectangle")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Toggle("Check Calendar for meetings", isOn: $enableCalendar)
            Toggle("Respect Focus / Do Not Disturb", isOn: $enableFocus)

            Text("You can change hours, prompts, and quiet rules anytime in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Not now") {
                    appState.config.hasCompletedOnboarding = true
                    appState.showOnboarding = false
                    dismiss()
                }
                Button("Enable permissions & start") {
                    appState.completeOnboarding(enableCalendar: enableCalendar, enableFocus: enableFocus)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
    }
}

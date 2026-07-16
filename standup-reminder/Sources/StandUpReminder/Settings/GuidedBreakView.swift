import SwiftUI

struct GuidedBreakView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var secondsRemaining: Int = 45
    @State private var stepIndex = 0
    @State private var timer: Timer?

    private var payload: ReminderPayload {
        appState.pendingGuidedPayload ?? ReminderPayload(
            kind: .breakPrompt,
            title: "Guided Break",
            body: "Move for a minute.",
            promptId: "guided",
            guidedSteps: ["Stand up", "Move", "Reset posture"]
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(payload.title)
                .font(.title.weight(.bold))
            Text(payload.body)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(max(appState.config.guidedBreakSeconds - secondsRemaining, 0)),
                         total: Double(max(appState.config.guidedBreakSeconds, 1)))

            Text("\(secondsRemaining)s")
                .font(.system(.largeTitle, design: .rounded).monospacedDigit())

            if payload.guidedSteps.indices.contains(stepIndex) {
                Label(payload.guidedSteps[stepIndex], systemImage: "figure.walk")
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Button("Skip step") { advanceStep() }
                Spacer()
                Button("Done") {
                    appState.acknowledgeDone()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear(perform: start)
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        secondsRemaining = max(15, appState.config.guidedBreakSeconds)
        stepIndex = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if secondsRemaining > 0 {
                    secondsRemaining -= 1
                    let total = max(appState.config.guidedBreakSeconds, 1)
                    let elapsed = total - secondsRemaining
                    let stepDuration = max(total / max(payload.guidedSteps.count, 1), 1)
                    stepIndex = min(elapsed / stepDuration, payload.guidedSteps.count - 1)
                } else {
                    timer?.invalidate()
                }
            }
        }
    }

    private func advanceStep() {
        if stepIndex < payload.guidedSteps.count - 1 {
            stepIndex += 1
        }
    }
}

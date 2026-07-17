import SwiftUI

struct GuidedBreakView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private var demo: BreakDemo {
        BreakDemoLibrary.demo(forPromptId: payload.promptId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(payload.title)
                .font(.title.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text(payload.body)
                .foregroundStyle(.secondary)

            if appState.config.features.breakDemoSymbolsEnabled {
                HStack(spacing: 14) {
                    Image(systemName: demo.systemImage)
                        .font(.system(size: 40))
                        .accessibilityHidden(true)
                    Text(demo.caption)
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Break demo: \(demo.caption)")
            }

            ProgressView(
                value: Double(max(appState.config.guidedBreakSeconds - secondsRemaining, 0)),
                total: Double(max(appState.config.guidedBreakSeconds, 1))
            )
            .accessibilityLabel("Break timer")

            Text("\(secondsRemaining)s")
                .font(.system(.largeTitle, design: .rounded).monospacedDigit())
                .accessibilityLabel("\(secondsRemaining) seconds remaining")

            if payload.guidedSteps.indices.contains(stepIndex) {
                Label(payload.guidedSteps[stepIndex], systemImage: "figure.walk")
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Step \(stepIndex + 1): \(payload.guidedSteps[stepIndex])")
            }

            if let weather = appState.weather, appState.config.features.weatherBreaksEnabled {
                Text(weather.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(weather.summary)
            }

            HStack {
                Button("Skip step") { advanceStep() }
                    .accessibilityHint("Advances to the next stretch instruction")
                Spacer()
                Button("Done") {
                    appState.acknowledgeDone()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityHint("Marks the break complete")
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear(perform: start)
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        secondsRemaining = max(15, appState.config.guidedBreakSeconds)
        stepIndex = 0
        timer?.invalidate()
        let animate = !(reduceMotion || appState.config.features.reduceMotionOverrides)
        _ = animate
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

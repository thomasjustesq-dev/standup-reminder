import SwiftUI

struct GuidedBreakView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fallbackWindowClose) private var fallbackWindowClose

    /// DismissAction is inert inside an AppDelegate fallback window.
    private func closeWindow() {
        if let fallbackWindowClose { fallbackWindowClose() } else { dismiss() }
    }
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

    private var progressFraction: Double {
        let total = max(appState.config.guidedBreakSeconds, 1)
        let elapsed = max(0, total - secondsRemaining)
        return min(1.0, Double(elapsed) / Double(total))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(payload.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AeroColor.titaniumWhite)
                        .accessibilityAddTraits(.isHeader)
                    Text(payload.body)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AeroColor.vaporGray)
                }
                Spacer()
                AeroTelemetryBadge(text: "ACTIVE BREAK", statusColor: AeroColor.volt)
            }

            // Demo Graphic Card
            if appState.config.features.breakDemoSymbolsEnabled {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AeroColor.volt.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: demo.systemImage)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AeroColor.volt)
                            .accessibilityHidden(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EXERCISE FOCUS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(AeroColor.vaporGray)
                        Text(demo.caption)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AeroColor.titaniumWhite)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .aeroGlassCard(cornerRadius: 14)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Break demo: \(demo.caption)")
            }

            // Timer & Progress Gauge Card
            VStack(spacing: 10) {
                HStack {
                    Text("TIME REMAINING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(AeroColor.vaporGray)
                    Spacer()
                    Text("\(secondsRemaining)s")
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(AeroColor.volt)
                }
                
                // Custom Glowing Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AeroColor.volt.opacity(0.8), AeroColor.volt],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * progressFraction), height: 8)
                            .aeroGlow(color: AeroColor.volt, radius: 6)
                            .animation(.linear(duration: 1.0), value: progressFraction)
                    }
                }
                .frame(height: 8)
            }
            .padding(14)
            .aeroGlassCard(cornerRadius: 14)

            // Current Step Callout
            if payload.guidedSteps.indices.contains(stepIndex) {
                HStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AeroColor.ionBlue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("STEP \(stepIndex + 1) OF \(payload.guidedSteps.count)")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(AeroColor.vaporGray)
                        Text(payload.guidedSteps[stepIndex])
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AeroColor.titaniumWhite)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .aeroGlassCard(cornerRadius: 12, strokeColor: AeroColor.ionBlue.opacity(0.4))
                .accessibilityLabel("Step \(stepIndex + 1): \(payload.guidedSteps[stepIndex])")
            }

            if let weather = appState.weather, appState.config.features.weatherBreaksEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AeroColor.volt)
                    Text(weather.summary)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AeroColor.vaporGray)
                }
                .accessibilityLabel(weather.summary)
            }

            // Action Buttons
            HStack(spacing: 10) {
                AeroGlassButton(title: "Skip Step", systemImage: "forward.fill") {
                    advanceStep()
                }
                .accessibilityHint("Advances to the next stretch instruction")
                
                AeroGlassButton(title: "Done Complete", systemImage: "checkmark", isProminent: true) {
                    appState.acknowledgeDone()
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityHint("Marks the break complete")
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 440)
        .background(AeroColor.void)
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

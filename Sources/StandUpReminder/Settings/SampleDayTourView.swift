import SwiftUI

struct SampleDayTourView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let beats: [(time: String, title: String, detail: String, symbol: String)] = [
        ("9:00", "Workday starts", "Reminders arm for your schedule.", "sun.max"),
        ("9:30", "First stand cue", "A gentle nudge after you settle in.", "figure.stand"),
        ("12:00", "Lunch", "Step away and eat.", "fork.knife"),
        ("2:30", "Meeting catch-up", "If a call ran long, you get one break after.", "phone.down"),
        ("5:00", "Wind-down", "Stretch, tidy, log off.", "sunset.fill")
    ]

    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("A sample workday")
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            Text("Here’s how Stand Up Reminder behaves from 9 to 5 — no waiting required.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Image(systemName: beats[index].symbol)
                    .font(.system(size: 44))
                    .opacity(reduceMotion || appState.config.features.reduceMotionOverrides ? 1 : 0.95)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(beats[index].time)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(beats[index].title)
                        .font(.title2.weight(.semibold))
                    Text(beats[index].detail)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(beats[index].time), \(beats[index].title). \(beats[index].detail)")

            ProgressView(value: Double(index + 1), total: Double(beats.count))
                .accessibilityLabel("Tour progress")

            HStack {
                Button("Back") { index = max(0, index - 1) }
                    .disabled(index == 0)
                Spacer()
                if index < beats.count - 1 {
                    Button("Next") { index += 1 }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Start using it") {
                        appState.showSampleDayTour = false
                        var c = appState.config
                        c.features.showSampleDayTour = false
                        appState.config = c
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(28)
        .frame(width: 520)
    }
}

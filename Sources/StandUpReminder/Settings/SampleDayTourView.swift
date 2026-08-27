import SwiftUI

struct SampleDayTourView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fallbackWindowClose) private var fallbackWindowClose

    /// DismissAction is inert inside an AppDelegate fallback window.
    private func closeWindow() {
        if let fallbackWindowClose { fallbackWindowClose() } else { dismiss() }
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let beats: [(time: String, title: String, detail: String, symbol: String)] = [
        ("9:00 AM", "Workday starts", "Reminders arm automatically according to your profile schedule.", "sun.max.fill"),
        ("9:30 AM", "First stand cue", "A gentle, unobtrusive reminder after you settle in to focus.", "figure.stand"),
        ("12:00 PM", "Lunch break", "Step away, nourish, and move freely.", "fork.knife"),
        ("2:30 PM", "Meeting catch-up", "If a call ran long, you receive one clean break catch-up after.", "phone.down.fill"),
        ("5:00 PM", "Wind-down", "Stretch, decompress, log off, and rest.", "sunset.fill")
    ]

    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("A Sample Workday")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AeroColor.titaniumWhite)
                    .accessibilityAddTraits(.isHeader)

                Text("How Stand Up Reminder works quietly in the background from 9 to 5.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(AeroColor.vaporGray)
            }

            // Interactive Beat Card
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AeroColor.volt.opacity(0.12))
                        .frame(width: 60, height: 60)
                    Image(systemName: beats[index].symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AeroColor.volt)
                        .aeroGlow(color: AeroColor.volt, radius: 6)
                        .accessibilityHidden(true)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(beats[index].time.uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(AeroColor.volt)
                    Text(beats[index].title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AeroColor.titaniumWhite)
                    Text(beats[index].detail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AeroColor.vaporGray)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .aeroGlassCard(cornerRadius: 16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(beats[index].time), \(beats[index].title). \(beats[index].detail)")

            // Step Progress
            HStack(spacing: 6) {
                ForEach(0..<beats.count, id: \.self) { i in
                    Capsule()
                        .fill(i <= index ? AeroColor.volt : Color.white.opacity(0.15))
                        .frame(height: 4)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: index)
                }
            }
            .accessibilityLabel("Tour step \(index + 1) of \(beats.count)")

            // Navigation Buttons
            HStack(spacing: 12) {
                Button("Back") { index = max(0, index - 1) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(index == 0 ? AeroColor.vaporGray.opacity(0.4) : AeroColor.vaporGray)
                    .disabled(index == 0)
                
                Spacer()
                
                if index < beats.count - 1 {
                    AeroGlassButton(title: "Next Step", systemImage: "arrow.right", isProminent: true) {
                        index += 1
                    }
                    .frame(width: 120)
                    .keyboardShortcut(.defaultAction)
                } else {
                    AeroGlassButton(title: "Start Using Now", systemImage: "checkmark", isProminent: true) {
                        appState.showSampleDayTour = false
                        var c = appState.config
                        c.features.showSampleDayTour = false
                        appState.config = c
                        closeWindow()
                    }
                    .frame(width: 150)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 500)
        .background(AeroColor.void)
    }
}

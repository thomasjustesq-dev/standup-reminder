import SwiftUI

/// Today strip: presence, why suppressed, upcoming schedule, adaptive coach.
struct DayTimelineView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.fallbackWindowClose) private var fallbackClose
    @Environment(\.dismiss) private var dismiss

    private var upcoming: [Scheduler.Next] {
        Scheduler.upcoming(appState.makeSchedulerInput(), count: 12)
    }

    private var simulated: [DaySimulation.FiredEvent] {
        let cal = appState.config.scheduleCalendar
        let start = cal.startOfDay(for: Date())
        let samples: [DaySimulation.PresenceSample] = [
            .init(at: start, presence: .offHours),
            .init(at: start.addingTimeInterval(9 * 3600), presence: appState.presence),
            .init(at: start.addingTimeInterval(12 * 3600), presence: .meeting),
            .init(at: start.addingTimeInterval(13 * 3600), presence: .atDesk),
            .init(at: start.addingTimeInterval(17 * 3600), presence: .offHours)
        ]
        return DaySimulation.run(DaySimulation.Input(
            config: appState.config,
            intervalMinutes: appState.effectiveIntervalMinutes,
            dayStart: start.addingTimeInterval(8 * 3600),
            presenceTimeline: samples,
            lastAcknowledgedAt: appState.lastAcknowledgedAt
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: appState.presence.symbolName)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.presence.displayName)
                        .font(.title3.weight(.semibold))
                    Text(appState.isCadenceAuthority
                         ? "Cadence authority · quiet rules on this Mac"
                         : "Follower · quiet rules on \(appState.remoteAuthorityName ?? "another device")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { fallbackClose?() ?? dismiss() }
            }

            GroupBox("Why this state") {
                Text(appState.statusMessage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Next up") {
                if upcoming.isEmpty {
                    Text("Nothing scheduled (outside hours or paused).")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(upcoming.prefix(6).enumerated()), id: \.offset) { _, next in
                        HStack {
                            Text(label(next.kind))
                            Spacer()
                            Text(next.date, style: .time)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }
            }

            if let suggestion = appState.adaptiveSuggestion {
                GroupBox("Adaptive coach") {
                    Text("Suggested interval: \(suggestion.recommendedMinutes)m")
                        .font(.headline)
                    Text(suggestion.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Apply suggestion") { appState.applyAdaptiveSuggestion() }
                }
            }

            GroupBox("Evidence") {
                Text(appState.evidenceStats.summaryLine())
                    .font(.caption)
            }

            GroupBox("Simulated day (illustrative)") {
                Text(DaySimulation.describe(simulated, calendar: appState.config.scheduleCalendar))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Done — log break") { appState.acknowledgeDone() }
                    .keyboardShortcut(.defaultAction)
                Button("Snooze 10m") { appState.snooze(minutes: 10) }
            }
        }
        .padding(20)
        .frame(width: 420, height: 560)
    }

    private func label(_ kind: Scheduler.Kind) -> String {
        switch kind {
        case .breakPrompt: return "Movement break"
        case .sitStand: return "Sit/stand"
        case .lunch: return "Lunch"
        case .windDown: return "Wind-down"
        }
    }
}

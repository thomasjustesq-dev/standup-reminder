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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: appState.presence.symbolName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AeroColor.volt)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(appState.presence.displayName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AeroColor.titaniumWhite)
                            Text(appState.isCadenceAuthority
                                 ? "Cadence authority · local Mac rules"
                                 : "Follower · quiet rules on \(appState.remoteAuthorityName ?? "another device")")
                                .font(.system(size: 10.5))
                                .foregroundStyle(AeroColor.vaporGray)
                        }
                    }
                    Spacer()
                    Button("Close") { fallbackClose?() ?? dismiss() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AeroColor.vaporGray)
                }
                .padding(.bottom, 2)

                // Current State
                VStack(alignment: .leading, spacing: 6) {
                    Text("CURRENT STATUS")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(AeroColor.vaporGray)
                    Text(appState.statusMessage)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(AeroColor.titaniumWhite)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .aeroGlassCard(cornerRadius: 12)

                // Posture / Stillness Radar
                AeroPostureRadar(
                    facePresent: WebcamStillnessMonitor.shared.facePresent,
                    isStillTooLong: WebcamStillnessMonitor.shared.isStillTooLong
                )

                // Next Up Schedule
                VStack(alignment: .leading, spacing: 8) {
                    Text("UPCOMING SCHEDULE")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(AeroColor.vaporGray)
                    
                    if upcoming.isEmpty {
                        Text("Nothing scheduled (outside hours or paused).")
                            .font(.system(size: 11.5))
                            .foregroundStyle(AeroColor.vaporGray)
                    } else {
                        ForEach(Array(upcoming.prefix(5).enumerated()), id: \.offset) { index, next in
                            HStack {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(index == 0 ? AeroColor.volt : AeroColor.ionBlue)
                                        .frame(width: 5, height: 5)
                                    Text(label(next.kind))
                                        .font(.system(size: 12, weight: index == 0 ? .semibold : .regular))
                                        .foregroundStyle(AeroColor.titaniumWhite)
                                }
                                Spacer()
                                Text(next.date, style: .time)
                                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                    .monospacedDigit()
                                    .foregroundStyle(index == 0 ? AeroColor.volt : AeroColor.vaporGray)
                            }
                            if index < min(upcoming.count - 1, 4) {
                                Divider().overlay(AeroColor.hairline)
                            }
                        }
                    }
                }
                .padding(12)
                .aeroGlassCard(cornerRadius: 12)

                // Adaptive Coach
                if let suggestion = appState.adaptiveSuggestion {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("ADAPTIVE COACH")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(AeroColor.volt)
                            Spacer()
                            Text("Suggested: \(suggestion.recommendedMinutes)m")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AeroColor.volt)
                        }
                        Text(suggestion.explanation)
                            .font(.system(size: 11.5))
                            .foregroundStyle(AeroColor.vaporGray)
                        
                        AeroGlassButton(title: "Apply Suggestion", isProminent: true) {
                            appState.applyAdaptiveSuggestion()
                        }
                        .padding(.top, 2)
                    }
                    .padding(12)
                    .aeroGlassCard(cornerRadius: 12, glowColor: AeroColor.volt)
                }

                // Evidence Stats
                VStack(alignment: .leading, spacing: 4) {
                    Text("EVIDENCE TELEMETRY")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(AeroColor.vaporGray)
                    Text(appState.evidenceStats.summaryLine())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AeroColor.titaniumWhite)
                }
                .padding(12)
                .aeroGlassCard(cornerRadius: 12)

                // Simulated Day
                VStack(alignment: .leading, spacing: 4) {
                    Text("SIMULATED DAY TIMELINE")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(AeroColor.vaporGray)
                    Text(DaySimulation.describe(simulated, calendar: appState.config.scheduleCalendar))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AeroColor.vaporGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .aeroGlassCard(cornerRadius: 12)

                // Bottom Action Row
                HStack(spacing: 10) {
                    AeroGlassButton(title: "Log Break Done", systemImage: "checkmark", isProminent: true) {
                        appState.acknowledgeDone()
                    }
                    .keyboardShortcut(.defaultAction)
                    
                    AeroGlassButton(title: "Snooze 10m", systemImage: "clock.arrow.circlepath") {
                        appState.snooze(minutes: 10)
                    }
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
        .frame(width: 440, height: 580)
        .background(AeroColor.void)
    }

    private func label(_ kind: Scheduler.Kind) -> String {
        switch kind {
        case .breakPrompt: return "Movement break"
        case .sitStand: return "Sit/stand transition"
        case .lunch: return "Lunch break"
        case .windDown: return "Wind-down"
        }
    }
}

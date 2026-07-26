#if os(iOS)
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: PhoneModel
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .center, spacing: 6) {
                        if let minutes = model.countdownMinutes {
                            Text("\(minutes)m")
                                .font(.system(size: 54, weight: .semibold, design: .rounded).monospacedDigit())
                            Text("until your next break")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(model.statusText)
                                .font(.title2)
                        }
                        Text(model.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    Button("Done — I took a break") { model.acknowledgeDone() }
                    Button("Snooze 10 minutes") { model.snooze(minutes: 10) }
                    Button("Skip rest of today", role: .destructive) { model.skipToday() }
                    if model.isPaused {
                        Button("Resume reminders") { model.resume() }
                    } else {
                        Button("Pause reminders") { model.pause() }
                    }
                }

                if !model.upcoming.isEmpty {
                    Section("Coming up") {
                        ForEach(Array(model.upcoming.prefix(5).enumerated()), id: \.offset) { _, next in
                            HStack {
                                Text(label(for: next.kind))
                                Spacer()
                                Text(next.date, style: .time)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("This week") {
                    Text(model.weekStatsText())
                        .font(.footnote)
                }

                if !model.notificationsAuthorized {
                    Section {
                        Label(
                            "Notifications are off — reminders can't be delivered. Enable them in Settings → Notifications.",
                            systemImage: "bell.slash"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Stand Up")
            .toolbar {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    .environmentObject(model)
            }
        }
    }

    private func label(for kind: Scheduler.Kind) -> String {
        switch kind {
        case .breakPrompt: return "Movement break"
        case .sitStand: return "Sit/stand switch"
        case .lunch: return "Lunch"
        case .windDown: return "Wind down"
        }
    }
}

struct SettingsSheet: View {
    @EnvironmentObject private var model: PhoneModel
    @Environment(\.dismiss) private var dismiss
    @State private var cloudMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Cadence") {
                    Toggle("Reminders enabled", isOn: binding(\.enabled))
                    Stepper("Every \(model.config.intervalMinutes) min",
                            value: binding(\.intervalMinutes), in: 10...120, step: 5)
                }

                Section("Work hours (all workdays)") {
                    Stepper("Start: \(workStart):00", value: workStartBinding, in: 4...12)
                    Stepper("End: \(workEnd):00", value: workEndBinding, in: 13...23)
                    Toggle("Weekdays only", isOn: binding(\.weekdaysOnly))
                }

                Section("Lunch") {
                    Toggle("Lunch reminder", isOn: binding(\.lunch.enabled))
                    if model.config.lunch.enabled {
                        Stepper("At \(model.config.lunch.hour):\(String(format: "%02d", model.config.lunch.minute))",
                                value: binding(\.lunch.hour), in: 10...15)
                    }
                }

                Section("End of day") {
                    Toggle("Wind-down reminder", isOn: binding(\.windDown.enabled))
                    if model.config.windDown.enabled {
                        Stepper("At \(model.config.windDown.hour):\(String(format: "%02d", model.config.windDown.minute))",
                                value: binding(\.windDown.hour), in: 14...22)
                    }
                }

                Section("Sit / stand desk") {
                    Toggle("Sit/stand phases", isOn: binding(\.sitStandModeEnabled))
                    if model.config.sitStandModeEnabled {
                        Stepper("Switch every \(model.config.sitStandPhaseMinutes) min",
                                value: binding(\.sitStandPhaseMinutes), in: 15...90, step: 5)
                    }
                }

                Section("iCloud sync") {
                    Button("Push settings to iCloud") {
                        model.pushToiCloud()
                        cloudMessage = "Pushed."
                    }
                    Button("Pull settings from iCloud") {
                        cloudMessage = model.pullFromiCloud() ? "Pulled." : "Nothing to pull (is iCloud Drive on?)"
                    }
                    if let cloudMessage {
                        Text(cloudMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }

    private var workStart: Int {
        model.config.scheduleByWeekday.values.map(\.startHour).min() ?? 9
    }

    private var workEnd: Int {
        model.config.scheduleByWeekday.values.map(\.endHour).max() ?? 17
    }

    private var workStartBinding: Binding<Int> {
        Binding(get: { workStart }, set: { newValue in
            var config = model.config
            for key in config.scheduleByWeekday.keys {
                config.scheduleByWeekday[key]?.startHour = newValue
            }
            model.config = config
        })
    }

    private var workEndBinding: Binding<Int> {
        Binding(get: { workEnd }, set: { newValue in
            var config = model.config
            for key in config.scheduleByWeekday.keys {
                config.scheduleByWeekday[key]?.endHour = newValue
            }
            model.config = config
        })
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppConfig, T>) -> Binding<T> {
        Binding(
            get: { model.config[keyPath: keyPath] },
            set: { model.config[keyPath: keyPath] = $0 }
        )
    }
}
#endif

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .environmentObject(appState)
                .tabItem { Label("General", systemImage: "gearshape") }

            ScheduleSettingsTab()
                .environmentObject(appState)
                .tabItem { Label("Schedule", systemImage: "calendar") }

            PromptsSettingsTab()
                .environmentObject(appState)
                .tabItem { Label("Prompts", systemImage: "text.bubble") }

            StatsSettingsTab()
                .environmentObject(appState)
                .tabItem { Label("Stats", systemImage: "chart.bar") }
        }
        .frame(width: 540, height: 440)
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Skip when screen is locked", isOn: binding(\.skipWhenLocked))
                Toggle("Skip when display is asleep", isOn: binding(\.skipWhenDisplayAsleep))
                Toggle("Skip during Focus / Do Not Disturb", isOn: binding(\.skipWhenFocused))
                Toggle("Skip during calendar meetings", isOn: binding(\.skipWhenInMeeting))
            }
            Section("Presence") {
                Stepper(
                    "Idle skip after \(appState.config.idleSkipMinutes) min",
                    value: intBinding(\.idleSkipMinutes),
                    in: 0...120
                )
                Stepper(
                    "Require \(appState.config.minActiveMinutes) min active before reminding",
                    value: intBinding(\.minActiveMinutes),
                    in: 0...120
                )
                Text("Idle skip avoids nagging when you step away. Active warm-up avoids reminding the moment you sit down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Sound") {
                TextField("Alert sound name", text: stringBinding(\.soundName))
                Text("Uses macOS sound names such as Glass, Ping, Purr, Submarine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func binding(_ keyPath: WritableKeyPath<AppConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.config[keyPath: keyPath] },
            set: {
                var c = appState.config
                c[keyPath: keyPath] = $0
                appState.config = c
                appState.refreshNextFire()
            }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<AppConfig, Int>) -> Binding<Int> {
        Binding(
            get: { appState.config[keyPath: keyPath] },
            set: {
                var c = appState.config
                c[keyPath: keyPath] = $0
                appState.config = c
                appState.refreshNextFire()
            }
        )
    }

    private func stringBinding(_ keyPath: WritableKeyPath<AppConfig, String>) -> Binding<String> {
        Binding(
            get: { appState.config[keyPath: keyPath] },
            set: {
                var c = appState.config
                c[keyPath: keyPath] = $0
                appState.config = c
            }
        )
    }
}

private struct ScheduleSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    private let dayNames = [
        ("1", "Monday"),
        ("2", "Tuesday"),
        ("3", "Wednesday"),
        ("4", "Thursday"),
        ("5", "Friday"),
        ("6", "Saturday"),
        ("7", "Sunday")
    ]

    var body: some View {
        Form {
            Section("Cadence") {
                Stepper(
                    "Every \(appState.config.intervalMinutes) minutes",
                    value: Binding(
                        get: { appState.config.intervalMinutes },
                        set: {
                            var c = appState.config
                            c.intervalMinutes = $0
                            appState.config = c
                            appState.refreshNextFire()
                        }
                    ),
                    in: 5...120,
                    step: 5
                )
                Toggle("Prefer weekdays (disable Sat/Sun unless enabled below)", isOn: Binding(
                    get: { appState.config.weekdaysOnly },
                    set: {
                        var c = appState.config
                        c.weekdaysOnly = $0
                        appState.config = c
                        appState.refreshNextFire()
                    }
                ))
            }
            Section("Lunch") {
                Toggle("Lunch reminder", isOn: lunchBool(\.enabled))
                Stepper("Hour: \(appState.config.lunch.hour)", value: lunchInt(\.hour), in: 0...23)
                Stepper("Minute: \(appState.config.lunch.minute)", value: lunchInt(\.minute), in: 0...59)
                Stepper("Match window ±\(appState.config.lunch.windowMinutes) min", value: lunchInt(\.windowMinutes), in: 0...15)
                TextField("Title", text: lunchString(\.title))
                TextField("Message", text: lunchString(\.body))
            }
            Section("Hours by day") {
                ForEach(dayNames, id: \.0) { key, name in
                    HStack {
                        Toggle(name, isOn: Binding(
                            get: { appState.config.scheduleByWeekday[key] != nil },
                            set: { enabled in
                                var c = appState.config
                                if enabled {
                                    c.scheduleByWeekday[key] = c.scheduleByWeekday[key] ?? .standard
                                } else {
                                    c.scheduleByWeekday[key] = nil
                                }
                                appState.config = c
                                appState.refreshNextFire()
                            }
                        ))
                        if appState.config.scheduleByWeekday[key] != nil {
                            Stepper(
                                "\(appState.config.scheduleByWeekday[key]!.startHour):00",
                                value: Binding(
                                    get: { appState.config.scheduleByWeekday[key]?.startHour ?? 9 },
                                    set: { newValue in
                                        var c = appState.config
                                        c.scheduleByWeekday[key]?.startHour = newValue
                                        appState.config = c
                                        appState.refreshNextFire()
                                    }
                                ),
                                in: 0...23
                            )
                            Text("–")
                            Stepper(
                                "\(appState.config.scheduleByWeekday[key]!.endHour):00",
                                value: Binding(
                                    get: { appState.config.scheduleByWeekday[key]?.endHour ?? 17 },
                                    set: { newValue in
                                        var c = appState.config
                                        c.scheduleByWeekday[key]?.endHour = newValue
                                        appState.config = c
                                        appState.refreshNextFire()
                                    }
                                ),
                                in: 1...24
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func lunchBool(_ keyPath: WritableKeyPath<LunchConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.config.lunch[keyPath: keyPath] },
            set: {
                var c = appState.config
                c.lunch[keyPath: keyPath] = $0
                appState.config = c
                appState.refreshNextFire()
            }
        )
    }

    private func lunchInt(_ keyPath: WritableKeyPath<LunchConfig, Int>) -> Binding<Int> {
        Binding(
            get: { appState.config.lunch[keyPath: keyPath] },
            set: {
                var c = appState.config
                c.lunch[keyPath: keyPath] = $0
                appState.config = c
                appState.refreshNextFire()
            }
        )
    }

    private func lunchString(_ keyPath: WritableKeyPath<LunchConfig, String>) -> Binding<String> {
        Binding(
            get: { appState.config.lunch[keyPath: keyPath] },
            set: {
                var c = appState.config
                c.lunch[keyPath: keyPath] = $0
                appState.config = c
            }
        )
    }
}

private struct PromptsSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Rotating break prompts") {
                Text("Stand-up reminders cycle through these (lunch uses its own message).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(appState.config.prompts.indices), id: \.self) { index in
                    VStack(alignment: .leading) {
                        TextField("Title", text: Binding(
                            get: { appState.config.prompts[index].title },
                            set: {
                                var c = appState.config
                                c.prompts[index].title = $0
                                appState.config = c
                            }
                        ))
                        TextField("Body", text: Binding(
                            get: { appState.config.prompts[index].body },
                            set: {
                                var c = appState.config
                                c.prompts[index].body = $0
                                appState.config = c
                            }
                        ))
                    }
                    .padding(.vertical, 4)
                }
                Button("Reset to defaults") {
                    var c = appState.config
                    c.prompts = BreakPrompt.defaults
                    appState.config = c
                }
            }
        }
        .padding()
    }
}

private struct StatsSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local stats")
                .font(.headline)
            Text(appState.weekStatsText())
            let s = appState.stats
            LabeledContent("All-time shown", value: "\(s.shownTotal)")
            LabeledContent("All-time done", value: "\(s.acknowledgedTotal)")
            LabeledContent("All-time snoozed", value: "\(s.snoozedTotal)")
            LabeledContent("All-time skipped", value: "\(s.skippedTotal)")
            Text("Stored at \(Paths.statsFile.path)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button("Reset stats") {
                appState.stats = StatsSnapshot()
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

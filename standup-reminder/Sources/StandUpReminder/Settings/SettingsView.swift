import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsTab().environmentObject(appState)
                .tabItem { Label("General", systemImage: "gearshape") }
            ScheduleSettingsTab().environmentObject(appState)
                .tabItem { Label("Schedule", systemImage: "calendar") }
            ModesSettingsTab().environmentObject(appState)
                .tabItem { Label("Modes", systemImage: "figure.stand") }
            QuietSettingsTab().environmentObject(appState)
                .tabItem { Label("Quiet", systemImage: "moon.zzz") }
            PromptsSettingsTab().environmentObject(appState)
                .tabItem { Label("Prompts", systemImage: "text.bubble") }
            ProfilesSettingsTab().environmentObject(appState)
                .tabItem { Label("Profiles", systemImage: "person.2") }
            StatsSettingsTab().environmentObject(appState)
                .tabItem { Label("Stats", systemImage: "chart.bar") }
        }
        .frame(width: 580, height: 480)
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Presence") {
                Stepper("Idle skip after \(appState.config.idleSkipMinutes) min",
                        value: intBinding(\.idleSkipMinutes), in: 0...120)
                Stepper("Require \(appState.config.minActiveMinutes) min active before reminding",
                        value: intBinding(\.minActiveMinutes), in: 0...120)
            }
            Section("Experience") {
                Toggle("Show menu bar countdown", isOn: boolBinding(\.showMenuBarCountdown))
                Toggle("Guided break available", isOn: boolBinding(\.guidedBreakEnabled))
                Stepper("Guided break length \(appState.config.guidedBreakSeconds)s",
                        value: intBinding(\.guidedBreakSeconds), in: 20...180, step: 5)
                TextField("Alert sound name", text: stringBinding(\.soundName))
            }
            Section("Health") {
                Toggle("Log Done taps to Apple Health (mindful minutes)", isOn: boolBinding(\.healthLoggingEnabled))
                Stepper("Minutes per Done: \(String(format: "%.0f", appState.config.healthMindfulMinutes))",
                        value: Binding(
                            get: { Int(appState.config.healthMindfulMinutes) },
                            set: {
                                var c = appState.config
                                c.healthMindfulMinutes = Double($0)
                                appState.config = c
                            }
                        ),
                        in: 1...15)
                Button("Request Health access…") {
                    HealthLogger.requestAuthorization { _ in }
                }
            }
            Section("Updates") {
                Toggle("Check for updates", isOn: boolBinding(\.updateCheckEnabled))
                TextField("GitHub Releases API URL", text: stringBinding(\.githubReleasesURL))
                Text("Example: https://api.github.com/repos/you/standup-reminder/releases/latest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Check now") {
                    Task { await appState.maybeCheckForUpdates(force: true) }
                }
            }
            Section("Backup") {
                Button("Export settings…") { exportSettings() }
                Button("Import settings…") { importSettings() }
            }
        }
        .padding()
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "standup-reminder-settings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try appState.exportSettings()
            try data.write(to: url)
        } catch {
            AppLog.write("Export failed: \(error.localizedDescription)")
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        do {
            try appState.importSettings(data)
        } catch {
            AppLog.write("Import failed: \(error.localizedDescription)")
        }
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.config[keyPath: keyPath] },
            set: { var c = appState.config; c[keyPath: keyPath] = $0; appState.config = c; appState.refreshNextFire() }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<AppConfig, Int>) -> Binding<Int> {
        Binding(
            get: { appState.config[keyPath: keyPath] },
            set: { var c = appState.config; c[keyPath: keyPath] = $0; appState.config = c; appState.refreshNextFire() }
        )
    }

    private func stringBinding(_ keyPath: WritableKeyPath<AppConfig, String>) -> Binding<String> {
        Binding(
            get: { appState.config[keyPath: keyPath] },
            set: { var c = appState.config; c[keyPath: keyPath] = $0; appState.config = c }
        )
    }
}

private struct ScheduleSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    private let dayNames = [("1","Monday"),("2","Tuesday"),("3","Wednesday"),("4","Thursday"),("5","Friday"),("6","Saturday"),("7","Sunday")]

    var body: some View {
        Form {
            Section("Cadence") {
                Stepper("Base every \(appState.config.intervalMinutes) minutes",
                        value: Binding(
                            get: { appState.config.intervalMinutes },
                            set: { var c = appState.config; c.intervalMinutes = $0; appState.config = c; appState.refreshNextFire() }
                        ), in: 5...120, step: 5)
                Toggle("Adaptive interval", isOn: Binding(
                    get: { appState.config.adaptiveIntervalEnabled },
                    set: { var c = appState.config; c.adaptiveIntervalEnabled = $0; appState.config = c; appState.refreshNextFire() }
                ))
                Stepper("Adaptive min \(appState.config.adaptiveMinMinutes)m",
                        value: intBinding(\.adaptiveMinMinutes), in: 10...60)
                Stepper("Adaptive max \(appState.config.adaptiveMaxMinutes)m",
                        value: intBinding(\.adaptiveMaxMinutes), in: 15...90)
                Text("Effective now: \(appState.effectiveIntervalMinutes)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Weekdays preference", isOn: boolBinding(\.weekdaysOnly))
            }
            Section("Time zone") {
                TextField("Olson ID (empty = automatic)", text: Binding(
                    get: { appState.config.scheduleTimeZoneIdentifier },
                    set: { var c = appState.config; c.scheduleTimeZoneIdentifier = $0; appState.config = c; appState.refreshNextFire() }
                ))
                Text("Current: \(appState.config.scheduleTimeZone.identifier)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Lunch") {
                Toggle("Lunch reminder", isOn: lunchBool(\.enabled))
                Stepper("Hour \(appState.config.lunch.hour)", value: lunchInt(\.hour), in: 0...23)
                Stepper("Minute \(appState.config.lunch.minute)", value: lunchInt(\.minute), in: 0...59)
                TextField("Title", text: lunchString(\.title))
                TextField("Message", text: lunchString(\.body))
            }
            Section("End of day") {
                Toggle("Wind-down reminder", isOn: windBool(\.enabled))
                Stepper("Hour \(appState.config.windDown.hour)", value: windInt(\.hour), in: 0...23)
                Stepper("Minute \(appState.config.windDown.minute)", value: windInt(\.minute), in: 0...59)
                TextField("Title", text: windString(\.title))
                TextField("Message", text: windString(\.body))
            }
            Section("Hours by day") {
                ForEach(dayNames, id: \.0) { key, name in
                    HStack {
                        Toggle(name, isOn: Binding(
                            get: { appState.config.scheduleByWeekday[key] != nil },
                            set: { enabled in
                                var c = appState.config
                                if enabled { c.scheduleByWeekday[key] = c.scheduleByWeekday[key] ?? .standard }
                                else { c.scheduleByWeekday[key] = nil }
                                appState.config = c
                                appState.refreshNextFire()
                            }
                        ))
                        if appState.config.scheduleByWeekday[key] != nil {
                            Stepper("\(appState.config.scheduleByWeekday[key]!.startHour):00", value: Binding(
                                get: { appState.config.scheduleByWeekday[key]?.startHour ?? 9 },
                                set: { v in var c = appState.config; c.scheduleByWeekday[key]?.startHour = v; appState.config = c; appState.refreshNextFire() }
                            ), in: 0...23)
                            Text("–")
                            Stepper("\(appState.config.scheduleByWeekday[key]!.endHour):00", value: Binding(
                                get: { appState.config.scheduleByWeekday[key]?.endHour ?? 17 },
                                set: { v in var c = appState.config; c.scheduleByWeekday[key]?.endHour = v; appState.config = c; appState.refreshNextFire() }
                            ), in: 1...24)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppConfig, Bool>) -> Binding<Bool> {
        Binding(get: { appState.config[keyPath: keyPath] }, set: { v in var c = appState.config; c[keyPath: keyPath] = v; appState.config = c; appState.refreshNextFire() })
    }
    private func intBinding(_ keyPath: WritableKeyPath<AppConfig, Int>) -> Binding<Int> {
        Binding(get: { appState.config[keyPath: keyPath] }, set: { v in var c = appState.config; c[keyPath: keyPath] = v; appState.config = c; appState.refreshNextFire() })
    }
    private func lunchBool(_ k: WritableKeyPath<LunchConfig, Bool>) -> Binding<Bool> {
        Binding(get: { appState.config.lunch[keyPath: k] }, set: { v in var c = appState.config; c.lunch[keyPath: k] = v; appState.config = c; appState.refreshNextFire() })
    }
    private func lunchInt(_ k: WritableKeyPath<LunchConfig, Int>) -> Binding<Int> {
        Binding(get: { appState.config.lunch[keyPath: k] }, set: { v in var c = appState.config; c.lunch[keyPath: k] = v; appState.config = c; appState.refreshNextFire() })
    }
    private func lunchString(_ k: WritableKeyPath<LunchConfig, String>) -> Binding<String> {
        Binding(get: { appState.config.lunch[keyPath: k] }, set: { v in var c = appState.config; c.lunch[keyPath: k] = v; appState.config = c })
    }
    private func windBool(_ k: WritableKeyPath<WindDownConfig, Bool>) -> Binding<Bool> {
        Binding(get: { appState.config.windDown[keyPath: k] }, set: { v in var c = appState.config; c.windDown[keyPath: k] = v; appState.config = c; appState.refreshNextFire() })
    }
    private func windInt(_ k: WritableKeyPath<WindDownConfig, Int>) -> Binding<Int> {
        Binding(get: { appState.config.windDown[keyPath: k] }, set: { v in var c = appState.config; c.windDown[keyPath: k] = v; appState.config = c; appState.refreshNextFire() })
    }
    private func windString(_ k: WritableKeyPath<WindDownConfig, String>) -> Binding<String> {
        Binding(get: { appState.config.windDown[keyPath: k] }, set: { v in var c = appState.config; c.windDown[keyPath: k] = v; appState.config = c })
    }
}

private struct ModesSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Sit / stand desk") {
                Toggle("Alternate sit & stand cues", isOn: Binding(
                    get: { appState.config.sitStandModeEnabled },
                    set: { v in var c = appState.config; c.sitStandModeEnabled = v; appState.config = c }
                ))
                Stepper("Phase length \(appState.config.sitStandPhaseMinutes) min",
                        value: Binding(
                            get: { appState.config.sitStandPhaseMinutes },
                            set: { v in var c = appState.config; c.sitStandPhaseMinutes = v; appState.config = c }
                        ), in: 15...90, step: 5)
                Text("Current phase: \(appState.deskPhase.rawValue). Tapping Done flips the phase.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Reminder pack") {
                Picker("Pack", selection: Binding(
                    get: { appState.config.reminderPack },
                    set: { appState.applyReminderPack($0) }
                )) {
                    ForEach(ReminderPack.allCases) { pack in
                        Text(pack.displayName).tag(pack)
                    }
                }
            }
            Section("Meeting catch-up") {
                Toggle("Remind once after a meeting ends", isOn: Binding(
                    get: { appState.config.meetingCatchUpEnabled },
                    set: { v in var c = appState.config; c.meetingCatchUpEnabled = v; appState.config = c }
                ))
            }
        }
        .padding()
    }
}

private struct QuietSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var denylistText: String = ""

    var body: some View {
        Form {
            Section("Skip when") {
                Toggle("Screen locked", isOn: b(\.skipWhenLocked))
                Toggle("Display asleep", isOn: b(\.skipWhenDisplayAsleep))
                Toggle("Focus / Do Not Disturb", isOn: b(\.skipWhenFocused))
                Toggle("Calendar meeting", isOn: b(\.skipWhenInMeeting))
                Toggle("PTO / OOO calendar day", isOn: b(\.skipOnPTO))
            }
            Section("Deep work (on-device)") {
                Toggle("Quiet during deep work", isOn: b(\.deepWorkEnabled))
                Stepper("Same app for \(appState.config.deepWorkQuietMinutes) min",
                        value: Binding(
                            get: { appState.config.deepWorkQuietMinutes },
                            set: { v in var c = appState.config; c.deepWorkQuietMinutes = v; appState.config = c }
                        ), in: 10...120)
                Toggle("Require fullscreen", isOn: b(\.deepWorkRequireFullscreen))
            }
            Section("App denylist (bundle IDs)") {
                TextEditor(text: $denylistText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 100)
                Button("Save denylist") {
                    var c = appState.config
                    c.denylistBundleIds = denylistText
                        .split(whereSeparator: { $0 == "\n" || $0 == "," })
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    appState.config = c
                }
                Button("Reset denylist defaults") {
                    var c = appState.config
                    c.denylistBundleIds = AppConfig.defaultDenylist
                    appState.config = c
                    denylistText = c.denylistBundleIds.joined(separator: "\n")
                }
            }
        }
        .padding()
        .onAppear { denylistText = appState.config.denylistBundleIds.joined(separator: "\n") }
    }

    private func b(_ keyPath: WritableKeyPath<AppConfig, Bool>) -> Binding<Bool> {
        Binding(get: { appState.config[keyPath: keyPath] }, set: { v in var c = appState.config; c[keyPath: keyPath] = v; appState.config = c })
    }
}

private struct PromptsSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Rotating prompts") {
                ForEach(Array(appState.config.prompts.indices), id: \.self) { index in
                    VStack(alignment: .leading) {
                        TextField("Title", text: Binding(
                            get: { appState.config.prompts[index].title },
                            set: { v in var c = appState.config; c.prompts[index].title = v; appState.config = c }
                        ))
                        TextField("Body", text: Binding(
                            get: { appState.config.prompts[index].body },
                            set: { v in var c = appState.config; c.prompts[index].body = v; appState.config = c }
                        ))
                    }
                    .padding(.vertical, 4)
                }
                Button("Reset pack defaults") {
                    appState.applyReminderPack(appState.config.reminderPack)
                }
            }
        }
        .padding()
    }
}

private struct ProfilesSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var newName = ""

    var body: some View {
        Form {
            Section("Active profile") {
                Picker("Profile", selection: Binding(
                    get: { appState.profiles.activeProfileId },
                    set: { appState.switchProfile(id: $0) }
                )) {
                    ForEach(appState.profiles.profiles) { p in
                        Text(p.name).tag(p.id)
                    }
                }
            }
            Section("Manage") {
                TextField("New profile name", text: $newName)
                Button("Duplicate current as new profile") {
                    let name = newName.isEmpty ? "New profile" : newName
                    var docs = appState.profiles
                    let id = UUID().uuidString
                    docs.profiles.append(ReminderProfile(id: id, name: name, config: appState.config))
                    docs.activeProfileId = id
                    appState.profiles = docs
                    newName = ""
                }
            }
            Text("Profiles store separate schedules (Office Mac vs Laptop, etc.).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct StatsSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local stats").font(.headline)
            Text(appState.weekStatsText())
            let s = appState.stats
            LabeledContent("All-time shown", value: "\(s.shownTotal)")
            LabeledContent("All-time done", value: "\(s.acknowledgedTotal)")
            LabeledContent("All-time snoozed", value: "\(s.snoozedTotal)")
            LabeledContent("All-time skipped", value: "\(s.skippedTotal)")
            Text("Widget snapshot: \(WidgetSnapshot.fileURL.path)")
                .font(.caption2).foregroundStyle(.secondary)
            Button("Reset stats") { appState.stats = StatsSnapshot() }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

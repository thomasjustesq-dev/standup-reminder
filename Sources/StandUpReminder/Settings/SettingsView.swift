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
            SyncPrivacySettingsTab().environmentObject(appState)
                .tabItem { Label("Sync & Privacy", systemImage: "icloud") }
            StatsSettingsTab().environmentObject(appState)
                .tabItem { Label("Stats", systemImage: "chart.bar") }
        }
        .frame(width: 600, height: 500)
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("settings.generalAdvanced") private var showSystemIntegrations = false

    var body: some View {
        Form {
            Section("Presence") {
                Stepper("Idle skip after \(appState.config.idleSkipMinutes) min",
                        value: intBinding(\.idleSkipMinutes), in: 0...120)
                Stepper("Require \(appState.config.minActiveMinutes) min active before reminding",
                        value: intBinding(\.minActiveMinutes), in: 0...120)
            }
            Section("Breaks & schedule UI") {
                Toggle("Show menu bar countdown", isOn: boolBinding(\.showMenuBarCountdown))
                Toggle("Guided break available", isOn: boolBinding(\.guidedBreakEnabled))
                if appState.config.guidedBreakEnabled {
                    Picker("Auto-open guided window", selection: Binding(
                        get: { appState.config.guidedBreakOpenMode },
                        set: { v in var c = appState.config; c.guidedBreakOpenMode = v; appState.config = c }
                    )) {
                        ForEach(GuidedBreakOpenMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    Stepper("Guided break length \(appState.config.guidedBreakSeconds)s",
                            value: intBinding(\.guidedBreakSeconds), in: 20...180, step: 5)
                }
                TextField("Alert sound name", text: stringBinding(\.soundName))
            }
            Section {
                Toggle("Show system integrations", isOn: $showSystemIntegrations)
            }
            if showSystemIntegrations {
                Section("Health") {
                    Toggle("Write mindful minutes to Apple Health on Done", isOn: boolBinding(\.healthLoggingEnabled))
                    Text("Mac writes only (mindful minutes). iOS reads recent workouts so a gym session counts as a break — never writes.")
                        .font(.caption).foregroundStyle(.secondary)
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
                Toggle("Skip weekends (overrides Sat/Sun hours)", isOn: boolBinding(\.weekdaysOnly))
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
                                if enabled {
                                    c.scheduleByWeekday[key] = c.scheduleByWeekday[key] ?? .standard
                                    // Turning on a weekend day must actually take
                                    // effect — the skip-weekends preference would
                                    // silently discard it otherwise.
                                    if key == "6" || key == "7" { c.weekdaysOnly = false }
                                } else {
                                    c.scheduleByWeekday[key] = nil
                                }
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

private struct SyncPrivacySettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("settings.showAdvanced") private var showAdvanced = false

    var body: some View {
        Form {
            Section("Cadence role") {
                Picker("Role", selection: Binding(
                    get: { appState.config.features.cadenceRole },
                    set: { v in var c = appState.config; c.features.cadenceRole = v; appState.config = c }
                )) {
                    ForEach(CadenceRole.allCases) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                Text("Authority evaluates presence (meetings, Focus, idle). Followers only follow shared cadence.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Resolved: \(appState.resolvedCadenceRole.displayName)")
                    .font(.caption2)
            }
            Section("iCloud") {
                Toggle("Sync settings & cadence via iCloud Drive", isOn: featureBool(\.iCloudSyncEnabled))
                Text(appState.syncHealth.summary(iCloudEnabled: appState.config.features.iCloudSyncEnabled))
                    .font(.caption)
                    .foregroundStyle(appState.syncHealth.lastPullWasStale ? .orange : .secondary)
                Button("Push to iCloud now") { _ = appState.pushToiCloud() }
                Button("Pull from iCloud now") { _ = appState.pullFromiCloud() }
                if appState.syncHealth.lastPullWasStale {
                    Button("Force pull (overwrite newer local)") { _ = appState.pullFromiCloud(force: true) }
                }
                Button("Migrate legacy iCloud container…") { appState.migrateLegacyiCloudIfNeeded() }
                Text("Mac is the primary quiet-rule suppressor; phone/watch follow cadence via iCloud.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Everyday options") {
                Toggle("Speak reminders", isOn: featureBool(\.voiceAnnouncementsEnabled))
                Toggle("Weather-aware outdoor walk tips", isOn: featureBool(\.weatherBreaksEnabled))
                Toggle("Prefer reduced motion in UI", isOn: featureBool(\.reduceMotionOverrides))
                Toggle("Show advanced settings", isOn: $showAdvanced)
            }
            if showAdvanced {
                Section("Team / office quiet hours") {
                    Toggle("Respect team quiet windows", isOn: Binding(
                        get: { appState.config.features.teamQuiet.enabled },
                        set: { v in var c = appState.config; c.features.teamQuiet.enabled = v; appState.config = c }
                    ))
                    TextField("Quiet-hours JSON feed URL", text: Binding(
                        get: { appState.config.features.teamQuiet.feedURL },
                        set: { v in var c = appState.config; c.features.teamQuiet.feedURL = v; appState.config = c }
                    ))
                    Button("Refresh feed") { Task { await appState.refreshTeamQuietHours() } }
                    Text("\(appState.config.features.teamQuiet.windows.count) window(s) loaded")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Voice & Watch") {
                    Toggle("Speak only with headphones/external audio", isOn: featureBool(\.speakOnlyWithHeadphones))
                    Toggle("Apple Watch companion bridge", isOn: featureBool(\.watchCompanionEnabled))
                    Text("Watch reachable: \(WatchBridge.shared.isWatchReachable ? "yes" : "no")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Learning & sensors (on-device)") {
                    Toggle("Auto Meeting-heavy pack on busy calendar days", isOn: featureBool(\.autoProfileFromCalendar))
                    Text("Applies once per day when ≥4 meeting-like events are on today's calendar.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Credit Apple Stand hour as a break", isOn: featureBool(\.creditStandHourAsBreak))
                    Toggle("Record quiet-rule block reasons", isOn: featureBool(\.recordBlockReasons))
                    Toggle("Guided break may steal focus", isOn: featureBool(\.guidedBreakStealFocus))
                    Text("Off (default): won't activate over Zoom/Teams/fullscreen.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Learn my schedule from activity", isOn: featureBool(\.learnedScheduleEnabled))
                    if let suggestion = appState.learnedSuggestion {
                        Text("Suggested hours: \(suggestion.startHour):00–\(suggestion.endHour):00")
                        Button("Apply learned schedule to weekdays") { appState.applyLearnedSchedule() }
                    } else {
                        Text("Need ~5 active days before a suggestion appears.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Toggle("Webcam stillness (local face boxes only)", isOn: featureBool(\.webcamStillnessEnabled))
                    Stepper(
                        "Stillness threshold \(appState.config.features.webcamStillnessMinutes)m",
                        value: Binding(
                            get: { appState.config.features.webcamStillnessMinutes },
                            set: { v in
                                var c = appState.config
                                c.features.webcamStillnessMinutes = v
                                appState.config = c
                                WebcamStillnessMonitor.shared.configure(enabled: c.features.webcamStillnessEnabled, thresholdMinutes: v)
                            }
                        ),
                        in: 15...120,
                        step: 5
                    )
                    Text("Camera: \(WebcamStillnessMonitor.shared.status)")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Refresh weather") { Task { await appState.refreshWeather() } }
                    if let weather = appState.weather {
                        Text(String(format: "%.0f°C · %@", weather.temperatureC, weather.summary))
                            .font(.caption)
                    }
                }
                Section("Updates & diagnostics") {
                    TextField("Sparkle appcast URL (empty = GitHub Releases checker)", text: featureString(\.sparkleFeedURL))
                    Toggle("Prefer Sparkle when linked", isOn: featureBool(\.preferSparkleUpdates))
                    Text("Sparkle is wired only in distribution builds with a signed appcast; otherwise the app uses the GitHub Releases API.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Opt-in diagnostics breadcrumbs", isOn: featureBool(\.diagnosticsEnabled))
                    TextField("Diagnostics endpoint (https only)", text: featureString(\.diagnosticsEndpoint))
                    Text("HTTPS required; localhost and private IPs are rejected.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Accessibility") {
                    Toggle("Break demo symbols", isOn: featureBool(\.breakDemoSymbolsEnabled))
                    Toggle("Offer sample-day tour", isOn: featureBool(\.showSampleDayTour))
                    Button("Replay sample-day tour") { appState.showSampleDayTour = true }
                }
            }
        }
        .padding()
        .onChange(of: appState.config.features.webcamStillnessEnabled) { _, enabled in
            WebcamStillnessMonitor.shared.configure(
                enabled: enabled,
                thresholdMinutes: appState.config.features.webcamStillnessMinutes
            )
        }
        .onChange(of: appState.config.features.watchCompanionEnabled) { _, enabled in
            WatchBridge.shared.start(enabled: enabled)
        }
    }

    private func featureBool(_ keyPath: WritableKeyPath<FeatureFlags, Bool>) -> Binding<Bool> {
        Binding(
            get: { appState.config.features[keyPath: keyPath] },
            set: { v in var c = appState.config; c.features[keyPath: keyPath] = v; appState.config = c }
        )
    }

    private func featureString(_ keyPath: WritableKeyPath<FeatureFlags, String>) -> Binding<String> {
        Binding(
            get: { appState.config.features[keyPath: keyPath] },
            set: { v in var c = appState.config; c.features[keyPath: keyPath] = v; appState.config = c }
        )
    }
}

private struct StatsSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly review").font(.headline)
            Text(appState.weekStatsText())
            let week = appState.stats.weekSummary(calendar: appState.config.scheduleCalendar)
            if week.shown > 0 {
                let rate = Int((Double(week.done) / Double(max(week.shown, 1))) * 100)
                LabeledContent("Completion rate", value: "\(rate)% (\(week.done)/\(week.shown))")
                LabeledContent("Snooze rate", value: "\(week.snoozed) snoozes · \(week.skipped) skips")
                if week.selfLogged > 0 {
                    LabeledContent("Self-logged", value: "\(week.selfLogged) (no banner first)")
                }
            }
            if appState.config.features.recordBlockReasons, !appState.blockStats.byReason.isEmpty {
                Text(appState.blockStats.report())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let h = appState.stats.weekHighlights(calendar: appState.config.scheduleCalendar) {
                LabeledContent("Best day", value: "\(h.bestDay ?? "—") · \(h.bestDone) done")
                LabeledContent("Quietest day", value: "\(h.worstDay ?? "—") · \(h.worstDone) done")
            }
            Divider()
            Text("All-time").font(.headline)
            let s = appState.stats
            LabeledContent("Shown", value: "\(s.shownTotal)")
            LabeledContent("Done", value: "\(s.acknowledgedTotal)")
            LabeledContent("Snoozed", value: "\(s.snoozedTotal)")
            LabeledContent("Skipped", value: "\(s.skippedTotal)")
            Text("Widget snapshot: \(WidgetSnapshot.fileURL.path)")
                .font(.caption2).foregroundStyle(.secondary)
            Button("Reset stats") { appState.stats = StatsSnapshot() }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

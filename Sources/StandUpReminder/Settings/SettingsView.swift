import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Aero-Kinetic Settings Window

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case schedule = "Schedule"
    case modes = "Modes"
    case quiet = "Quiet"
    case prompts = "Prompts"
    case profiles = "Profiles"
    case sync = "Sync & Privacy"
    case stats = "Stats"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general: return "gearshape.fill"
        case .schedule: return "calendar"
        case .modes: return "figure.stand"
        case .quiet: return "moon.zzz.fill"
        case .prompts: return "text.bubble.fill"
        case .profiles: return "person.2.fill"
        case .sync: return "icloud.fill"
        case .stats: return "chart.bar.fill"
        }
    }
}

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: SettingsTab = .general

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Aero-Kinetic Tab Navigation Bar
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(selectedTab == tab ? AeroColor.volt : AeroColor.vaporGray)
                            
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(selectedTab == tab ? AeroColor.titaniumWhite : AeroColor.vaporGray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AeroColor.slate)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(AeroColor.specularRim, lineWidth: AeroPalette.specularBorderWidth)
                                    }
                                    .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AeroColor.obsidian)
            .overlay(alignment: .bottom) {
                Divider().overlay(AeroColor.hairline)
            }

            // MARK: - Active Tab Content Canvas
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsTab().environmentObject(appState)
                    case .schedule:
                        ScheduleSettingsTab().environmentObject(appState)
                    case .modes:
                        ModesSettingsTab().environmentObject(appState)
                    case .quiet:
                        QuietSettingsTab().environmentObject(appState)
                    case .prompts:
                        PromptsSettingsTab().environmentObject(appState)
                    case .profiles:
                        ProfilesSettingsTab().environmentObject(appState)
                    case .sync:
                        SyncPrivacySettingsTab().environmentObject(appState)
                    case .stats:
                        StatsSettingsTab().environmentObject(appState)
                    }
                }
                .padding(20)
            }
            .background(AeroColor.void)
        }
        .frame(width: 680, height: 560)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Custom Aero UI Helpers

private struct AeroSectionCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(AeroColor.vaporGray)
                
                if let subtitle = subtitle {
                    Text("· \(subtitle)")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AeroColor.vaporGray.opacity(0.8))
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
        .padding(14)
        .aeroGlassCard(cornerRadius: 14)
    }
}

private struct AeroRow<Content: View>: View {
    let label: String
    var caption: String? = nil
    @ViewBuilder let control: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AeroColor.titaniumWhite)
                Spacer()
                control()
            }
            if let caption = caption {
                Text(caption)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AeroColor.vaporGray)
            }
        }
    }
}

private struct AeroStepper: View {
    let title: String
    let valueText: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AeroColor.titaniumWhite)
            Spacer()
            HStack(spacing: 8) {
                Text(valueText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AeroColor.volt)
                
                HStack(spacing: 2) {
                    Button(action: onDecrement) {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 22)
                            .background(AeroColor.obsidian)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onIncrement) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 22)
                            .background(AeroColor.obsidian)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Tab 1: General

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("settings.generalAdvanced") private var showSystemIntegrations = false

    var body: some View {
        VStack(spacing: 16) {
            AeroSectionCard(title: "Presence Telemetry") {
                AeroStepper(
                    title: "Idle skip threshold",
                    valueText: "\(appState.config.idleSkipMinutes) min",
                    onDecrement: { updateConfig { $0.idleSkipMinutes = max(0, $0.idleSkipMinutes - 5) } },
                    onIncrement: { updateConfig { $0.idleSkipMinutes = min(120, $0.idleSkipMinutes + 5) } }
                )
                
                Divider().overlay(AeroColor.hairline)

                AeroStepper(
                    title: "Active work required before reminding",
                    valueText: "\(appState.config.minActiveMinutes) min",
                    onDecrement: { updateConfig { $0.minActiveMinutes = max(0, $0.minActiveMinutes - 5) } },
                    onIncrement: { updateConfig { $0.minActiveMinutes = min(120, $0.minActiveMinutes + 5) } }
                )
            }

            AeroSectionCard(title: "Breaks & Schedule Interface") {
                AeroRow(label: "Show menu bar countdown", caption: "Renders live circular progress ring and countdown") {
                    Toggle("", isOn: boolBinding(\.showMenuBarCountdown))
                        .toggleStyle(.switch)
                        .tint(AeroColor.volt)
                }

                Divider().overlay(AeroColor.hairline)

                AeroRow(label: "Guided break overlay available") {
                    Toggle("", isOn: boolBinding(\.guidedBreakEnabled))
                        .toggleStyle(.switch)
                        .tint(AeroColor.volt)
                }

                if appState.config.guidedBreakEnabled {
                    Divider().overlay(AeroColor.hairline)
                    
                    AeroRow(label: "Auto-open guided window") {
                        Picker("", selection: Binding(
                            get: { appState.config.guidedBreakOpenMode },
                            set: { v in var c = appState.config; c.guidedBreakOpenMode = v; appState.config = c }
                        )) {
                            ForEach(GuidedBreakOpenMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                    }

                    Divider().overlay(AeroColor.hairline)

                    AeroStepper(
                        title: "Guided break length",
                        valueText: "\(appState.config.guidedBreakSeconds)s",
                        onDecrement: { updateConfig { $0.guidedBreakSeconds = max(20, $0.guidedBreakSeconds - 5) } },
                        onIncrement: { updateConfig { $0.guidedBreakSeconds = min(180, $0.guidedBreakSeconds + 5) } }
                    )
                }

                Divider().overlay(AeroColor.hairline)

                AeroRow(label: "Acoustic chime profile") {
                    TextField("Default (Aero 528Hz)", text: stringBinding(\.soundName))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AeroColor.obsidian)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .frame(width: 140)
                }
            }

            AeroSectionCard(title: "System Integrations") {
                AeroRow(label: "Show advanced integrations") {
                    Toggle("", isOn: $showSystemIntegrations)
                        .toggleStyle(.switch)
                        .tint(AeroColor.volt)
                }

                if showSystemIntegrations {
                    Divider().overlay(AeroColor.hairline)

                    AeroRow(label: "Write mindful minutes to Apple Health on Done", caption: "Mac logs mindful minutes directly to HealthKit") {
                        Toggle("", isOn: boolBinding(\.healthLoggingEnabled))
                            .toggleStyle(.switch)
                            .tint(AeroColor.volt)
                    }

                    AeroStepper(
                        title: "Mindful minutes per Done",
                        valueText: "\(Int(appState.config.healthMindfulMinutes)) min",
                        onDecrement: { updateConfig { $0.healthMindfulMinutes = max(1, $0.healthMindfulMinutes - 1) } },
                        onIncrement: { updateConfig { $0.healthMindfulMinutes = min(15, $0.healthMindfulMinutes + 1) } }
                    )

                    AeroGlassButton(title: "Request HealthKit Access…", systemImage: "heart.fill") {
                        HealthLogger.requestAuthorization { _ in }
                    }
                    .padding(.top, 4)

                    Divider().overlay(AeroColor.hairline)

                    AeroRow(label: "Check for updates automatically") {
                        Toggle("", isOn: boolBinding(\.updateCheckEnabled))
                            .toggleStyle(.switch)
                            .tint(AeroColor.volt)
                    }

                    AeroRow(label: "GitHub Releases API URL") {
                        TextField("https://api.github.com/...", text: stringBinding(\.githubReleasesURL))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AeroColor.obsidian)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .frame(width: 220)
                    }

                    HStack(spacing: 8) {
                        AeroGlassButton(title: "Export Settings…", systemImage: "square.and.arrow.up") {
                            exportSettings()
                        }
                        AeroGlassButton(title: "Import Settings…", systemImage: "square.and.arrow.down") {
                            importSettings()
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func updateConfig(_ mutate: (inout AppConfig) -> Void) {
        var c = appState.config
        mutate(&c)
        appState.config = c
        appState.refreshNextFire()
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

    private func stringBinding(_ keyPath: WritableKeyPath<AppConfig, String>) -> Binding<String> {
        Binding(
            get: { appState.config[keyPath: keyPath] },
            set: { var c = appState.config; c[keyPath: keyPath] = $0; appState.config = c }
        )
    }
}

// MARK: - Tab 2: Schedule

private struct ScheduleSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    private let dayNames = [("1","Monday"),("2","Tuesday"),("3","Wednesday"),("4","Thursday"),("5","Friday"),("6","Saturday"),("7","Sunday")]

    var body: some View {
        VStack(spacing: 16) {
            AeroSectionCard(title: "Base Cadence & Adaptive Engine") {
                AeroStepper(
                    title: "Base Reminder Cadence",
                    valueText: "Every \(appState.config.intervalMinutes)m",
                    onDecrement: { updateConfig { $0.intervalMinutes = max(5, $0.intervalMinutes - 5) } },
                    onIncrement: { updateConfig { $0.intervalMinutes = min(120, $0.intervalMinutes + 5) } }
                )

                Divider().overlay(AeroColor.hairline)

                AeroRow(label: "Adaptive Interval Engine", caption: "Adjusts cadence based on meetings, focus, and posture") {
                    Toggle("", isOn: Binding(
                        get: { appState.config.adaptiveIntervalEnabled },
                        set: { var c = appState.config; c.adaptiveIntervalEnabled = $0; appState.config = c; appState.refreshNextFire() }
                    ))
                    .toggleStyle(.switch)
                    .tint(AeroColor.volt)
                }

                if appState.config.adaptiveIntervalEnabled {
                    AeroStepper(
                        title: "Adaptive Range (Min / Max)",
                        valueText: "\(appState.config.adaptiveMinMinutes)m – \(appState.config.adaptiveMaxMinutes)m",
                        onDecrement: { updateConfig { $0.adaptiveMinMinutes = max(10, $0.adaptiveMinMinutes - 5) } },
                        onIncrement: { updateConfig { $0.adaptiveMaxMinutes = min(90, $0.adaptiveMaxMinutes + 5) } }
                    )
                    
                    HStack {
                        Text("Current effective cadence:")
                            .font(.system(size: 11))
                            .foregroundStyle(AeroColor.vaporGray)
                        Spacer()
                        Text("\(appState.effectiveIntervalMinutes) min")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(AeroColor.volt)
                    }
                }

                Divider().overlay(AeroColor.hairline)

                AeroRow(label: "Skip Weekends (Saturday & Sunday)") {
                    Toggle("", isOn: boolBinding(\.weekdaysOnly))
                        .toggleStyle(.switch)
                        .tint(AeroColor.volt)
                }
            }

            AeroSectionCard(title: "Daily Social Anchors") {
                AeroRow(label: "Lunch Reminder Anchor") {
                    Toggle("", isOn: lunchBool(\.enabled))
                        .toggleStyle(.switch)
                        .tint(AeroColor.volt)
                }

                if appState.config.lunch.enabled {
                    AeroStepper(
                        title: "Lunch Anchor Time",
                        valueText: String(format: "%02d:%02d", appState.config.lunch.hour, appState.config.lunch.minute),
                        onDecrement: { updateConfig { $0.lunch.hour = max(0, $0.lunch.hour - 1) } },
                        onIncrement: { updateConfig { $0.lunch.hour = min(23, $0.lunch.hour + 1) } }
                    )
                }

                Divider().overlay(AeroColor.hairline)

                AeroRow(label: "End of Day Wind-Down") {
                    Toggle("", isOn: windBool(\.enabled))
                        .toggleStyle(.switch)
                        .tint(AeroColor.volt)
                }

                if appState.config.windDown.enabled {
                    AeroStepper(
                        title: "Wind-Down Time",
                        valueText: String(format: "%02d:%02d", appState.config.windDown.hour, appState.config.windDown.minute),
                        onDecrement: { updateConfig { $0.windDown.hour = max(0, $0.windDown.hour - 1) } },
                        onIncrement: { updateConfig { $0.windDown.hour = min(23, $0.windDown.hour + 1) } }
                    )
                }
            }

            AeroSectionCard(title: "Active Schedule Matrix by Day") {
                ForEach(dayNames, id: \.0) { key, name in
                    HStack {
                        Toggle(name, isOn: Binding(
                            get: { appState.config.scheduleByWeekday[key] != nil },
                            set: { enabled in
                                var c = appState.config
                                if enabled {
                                    c.scheduleByWeekday[key] = c.scheduleByWeekday[key] ?? .standard
                                    if key == "6" || key == "7" { c.weekdaysOnly = false }
                                } else {
                                    c.scheduleByWeekday[key] = nil
                                }
                                appState.config = c
                                appState.refreshNextFire()
                            }
                        ))
                        .toggleStyle(.switch)
                        .tint(AeroColor.volt)
                        
                        Spacer()

                        if let schedule = appState.config.scheduleByWeekday[key] {
                            Text(String(format: "%02d:00 – %02d:00", schedule.startHour, schedule.endHour))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AeroColor.volt)
                        } else {
                            Text("OFF")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(AeroColor.vaporGray)
                        }
                    }
                    if key != "7" {
                        Divider().overlay(AeroColor.hairline)
                    }
                }
            }
        }
    }

    private func updateConfig(_ mutate: (inout AppConfig) -> Void) {
        var c = appState.config
        mutate(&c)
        appState.config = c
        appState.refreshNextFire()
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppConfig, Bool>) -> Binding<Bool> {
        Binding(get: { appState.config[keyPath: keyPath] }, set: { v in var c = appState.config; c[keyPath: keyPath] = v; appState.config = c; appState.refreshNextFire() })
    }
    private func lunchBool(_ k: WritableKeyPath<LunchConfig, Bool>) -> Binding<Bool> {
        Binding(get: { appState.config.lunch[keyPath: k] }, set: { v in var c = appState.config; c.lunch[keyPath: k] = v; appState.config = c; appState.refreshNextFire() })
    }
    private func windBool(_ k: WritableKeyPath<WindDownConfig, Bool>) -> Binding<Bool> {
        Binding(get: { appState.config.windDown[keyPath: k] }, set: { v in var c = appState.config; c.windDown[keyPath: k] = v; appState.config = c; appState.refreshNextFire() })
    }
}

// MARK: - Tab 3: Modes

private struct ModesSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            AeroSectionCard(title: "Smart Standing Desk Kinetics") {
                AeroRow(label: "Alternate Sit & Stand Cues", caption: "Alternates reminders between standing and sitting phases") {
                    Toggle("", isOn: Binding(
                        get: { appState.config.sitStandModeEnabled },
                        set: { v in var c = appState.config; c.sitStandModeEnabled = v; appState.config = c }
                    ))
                    .toggleStyle(.switch)
                    .tint(AeroColor.volt)
                }

                if appState.config.sitStandModeEnabled {
                    Divider().overlay(AeroColor.hairline)

                    AeroStepper(
                        title: "Desk Phase Duration",
                        valueText: "\(appState.config.sitStandPhaseMinutes) min",
                        onDecrement: { updateConfig { $0.sitStandPhaseMinutes = max(15, $0.sitStandPhaseMinutes - 5) } },
                        onIncrement: { updateConfig { $0.sitStandPhaseMinutes = min(90, $0.sitStandPhaseMinutes + 5) } }
                    )

                    HStack {
                        Text("Active Desk Phase:")
                            .font(.system(size: 11))
                            .foregroundStyle(AeroColor.vaporGray)
                        Spacer()
                        AeroTelemetryBadge(text: appState.deskPhase.rawValue, statusColor: AeroColor.volt)
                    }
                }
            }

            AeroSectionCard(title: "Reminder Prompt Pack") {
                Picker("Active Pack", selection: Binding(
                    get: { appState.config.reminderPack },
                    set: { appState.applyReminderPack($0) }
                )) {
                    ForEach(ReminderPack.allCases) { pack in
                        Text(pack.displayName).tag(pack)
                    }
                }
            }

            AeroSectionCard(title: "Meeting Catch-Up") {
                AeroRow(label: "Remind Once After Meeting Ends", caption: "Fires a delayed break as soon as your calendar meeting clears") {
                    Toggle("", isOn: Binding(
                        get: { appState.config.meetingCatchUpEnabled },
                        set: { v in var c = appState.config; c.meetingCatchUpEnabled = v; appState.config = c }
                    ))
                    .toggleStyle(.switch)
                    .tint(AeroColor.volt)
                }
            }
        }
    }

    private func updateConfig(_ mutate: (inout AppConfig) -> Void) {
        var c = appState.config
        mutate(&c)
        appState.config = c
        appState.refreshNextFire()
    }
}

// MARK: - Tab 4: Quiet Rules

private struct QuietSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var denylistText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            AeroSectionCard(title: "Intelligent Quiet Gating") {
                AeroRow(label: "Skip when screen is locked") {
                    Toggle("", isOn: b(\.skipWhenLocked)).toggleStyle(.switch).tint(AeroColor.volt)
                }
                Divider().overlay(AeroColor.hairline)
                AeroRow(label: "Skip when display is asleep") {
                    Toggle("", isOn: b(\.skipWhenDisplayAsleep)).toggleStyle(.switch).tint(AeroColor.volt)
                }
                Divider().overlay(AeroColor.hairline)
                AeroRow(label: "Skip during Focus / Do Not Disturb") {
                    Toggle("", isOn: b(\.skipWhenFocused)).toggleStyle(.switch).tint(AeroColor.volt)
                }
                Divider().overlay(AeroColor.hairline)
                AeroRow(label: "Skip during calendar meetings") {
                    Toggle("", isOn: b(\.skipWhenInMeeting)).toggleStyle(.switch).tint(AeroColor.volt)
                }
                Divider().overlay(AeroColor.hairline)
                AeroRow(label: "Skip on PTO / Out of Office calendar days") {
                    Toggle("", isOn: b(\.skipOnPTO)).toggleStyle(.switch).tint(AeroColor.volt)
                }
            }

            AeroSectionCard(title: "On-Device Deep Work Gating") {
                AeroRow(label: "Quiet during unbroken deep work", caption: "Suppresses interruptions while deep in the flow state") {
                    Toggle("", isOn: b(\.deepWorkEnabled)).toggleStyle(.switch).tint(AeroColor.volt)
                }

                if appState.config.deepWorkEnabled {
                    Divider().overlay(AeroColor.hairline)
                    AeroStepper(
                        title: "Frontmost App Lock Duration",
                        valueText: "\(appState.config.deepWorkQuietMinutes)m",
                        onDecrement: { updateConfig { $0.deepWorkQuietMinutes = max(10, $0.deepWorkQuietMinutes - 5) } },
                        onIncrement: { updateConfig { $0.deepWorkQuietMinutes = min(120, $0.deepWorkQuietMinutes + 5) } }
                    )
                    Divider().overlay(AeroColor.hairline)
                    AeroRow(label: "Require fullscreen mode") {
                        Toggle("", isOn: b(\.deepWorkRequireFullscreen)).toggleStyle(.switch).tint(AeroColor.volt)
                    }
                }
            }

            AeroSectionCard(title: "App Denylist (Bundle Identifiers)") {
                TextEditor(text: $denylistText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(minHeight: 90)
                    .padding(6)
                    .background(AeroColor.obsidian)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 8) {
                    AeroGlassButton(title: "Save Denylist", isProminent: true) {
                        var c = appState.config
                        c.denylistBundleIds = denylistText
                            .split(whereSeparator: { $0 == "\n" || $0 == "," })
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        appState.config = c
                    }
                    AeroGlassButton(title: "Reset Defaults") {
                        var c = appState.config
                        c.denylistBundleIds = AppConfig.defaultDenylist
                        appState.config = c
                        denylistText = c.denylistBundleIds.joined(separator: "\n")
                    }
                }
                .padding(.top, 4)
            }
        }
        .onAppear { denylistText = appState.config.denylistBundleIds.joined(separator: "\n") }
    }

    private func b(_ keyPath: WritableKeyPath<AppConfig, Bool>) -> Binding<Bool> {
        Binding(get: { appState.config[keyPath: keyPath] }, set: { v in var c = appState.config; c[keyPath: keyPath] = v; appState.config = c })
    }

    private func updateConfig(_ mutate: (inout AppConfig) -> Void) {
        var c = appState.config
        mutate(&c)
        appState.config = c
        appState.refreshNextFire()
    }
}

// MARK: - Tab 5: Prompts

private struct PromptsSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            AeroSectionCard(title: "Rotating Break Telemetry Prompts") {
                ForEach(Array(appState.config.prompts.indices), id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("PROMPT #\(index + 1)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(AeroColor.volt)
                            Spacer()
                        }
                        TextField("Title", text: Binding(
                            get: { appState.config.prompts[index].title },
                            set: { v in var c = appState.config; c.prompts[index].title = v; appState.config = c }
                        ))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(AeroColor.obsidian)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        TextField("Body", text: Binding(
                            get: { appState.config.prompts[index].body },
                            set: { v in var c = appState.config; c.prompts[index].body = v; appState.config = c }
                        ))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(AeroColor.obsidian)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if index < appState.config.prompts.count - 1 {
                        Divider().overlay(AeroColor.hairline)
                    }
                }

                AeroGlassButton(title: "Reset Pack Defaults", systemImage: "arrow.counterclockwise") {
                    appState.applyReminderPack(appState.config.reminderPack)
                }
                .padding(.top, 6)
            }
        }
    }
}

// MARK: - Tab 6: Profiles

private struct ProfilesSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 16) {
            AeroSectionCard(title: "Active Schedule Profile") {
                Picker("Profile", selection: Binding(
                    get: { appState.profiles.activeProfileId },
                    set: { appState.switchProfile(id: $0) }
                )) {
                    ForEach(appState.profiles.profiles) { p in
                        Text(p.name).tag(p.id)
                    }
                }
            }

            AeroSectionCard(title: "Create & Duplicate Profiles") {
                AeroRow(label: "New Profile Name") {
                    TextField("E.g. Travel MacBook", text: $newName)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AeroColor.obsidian)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .frame(width: 180)
                }

                AeroGlassButton(title: "Duplicate Current as New Profile", systemImage: "plus.square.fill", isProminent: true) {
                    let name = newName.isEmpty ? "New profile" : newName
                    var docs = appState.profiles
                    let id = UUID().uuidString
                    docs.profiles.append(ReminderProfile(id: id, name: name, config: appState.config))
                    docs.activeProfileId = id
                    appState.profiles = docs
                    newName = ""
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Tab 7: Sync & Privacy

private struct SyncPrivacySettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("settings.showAdvanced") private var showAdvanced = false

    var body: some View {
        VStack(spacing: 16) {
            AeroSectionCard(title: "Multi-Device Cadence Authority") {
                Picker("Role", selection: Binding(
                    get: { appState.config.features.cadenceRole },
                    set: { v in var c = appState.config; c.features.cadenceRole = v; appState.config = c }
                )) {
                    ForEach(CadenceRole.allCases) { role in
                        Text(role.displayName).tag(role)
                    }
                }

                HStack {
                    Text("Resolved Role Status:")
                        .font(.system(size: 11))
                        .foregroundStyle(AeroColor.vaporGray)
                    Spacer()
                    AeroTelemetryBadge(
                        text: appState.resolvedCadenceRole.displayName,
                        statusColor: appState.isCadenceAuthority ? AeroColor.volt : AeroColor.ionBlue
                    )
                }
            }

            AeroSectionCard(title: "iCloud Drive Document Sync") {
                AeroRow(label: "Sync Settings & Cadence via iCloud", caption: "Keeps Mac, iPhone, and Apple Watch in sync") {
                    Toggle("", isOn: featureBool(\.iCloudSyncEnabled)).toggleStyle(.switch).tint(AeroColor.volt)
                }

                HStack {
                    Text("Cloud Sync Health:")
                        .font(.system(size: 11))
                        .foregroundStyle(AeroColor.vaporGray)
                    Spacer()
                    Text(appState.syncHealth.summary(iCloudEnabled: appState.config.features.iCloudSyncEnabled))
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AeroColor.titaniumWhite)
                }

                HStack(spacing: 8) {
                    AeroGlassButton(title: "Push to iCloud", systemImage: "arrow.up.icloud") {
                        _ = appState.pushToiCloud()
                    }
                    AeroGlassButton(title: "Pull from iCloud", systemImage: "arrow.down.icloud") {
                        _ = appState.pullFromiCloud()
                    }
                }
                .padding(.top, 4)
            }

            AeroSectionCard(title: "Sensors & Audio Preferences") {
                AeroRow(label: "Synthesized Voice Announcements") {
                    Toggle("", isOn: featureBool(\.voiceAnnouncementsEnabled)).toggleStyle(.switch).tint(AeroColor.volt)
                }
                Divider().overlay(AeroColor.hairline)
                AeroRow(label: "Webcam Stillness Monitor", caption: "On-device Vision face burst tracking") {
                    Toggle("", isOn: featureBool(\.webcamStillnessEnabled)).toggleStyle(.switch).tint(AeroColor.volt)
                }
                Divider().overlay(AeroColor.hairline)
                AeroRow(label: "Apple Watch Companion Bridge") {
                    Toggle("", isOn: featureBool(\.watchCompanionEnabled)).toggleStyle(.switch).tint(AeroColor.volt)
                }
            }
        }
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
}

// MARK: - Tab 8: Stats

private struct StatsSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            AeroSectionCard(title: "Weekly Telemetry Review") {
                let week = appState.stats.weekSummary(calendar: appState.config.scheduleCalendar)
                let rate = week.shown > 0 ? Int((Double(week.done) / Double(max(week.shown, 1))) * 100) : 0

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(rate)%")
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(AeroColor.volt)
                        Text("COMPLETION RATE")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(AeroColor.vaporGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().overlay(AeroColor.hairline)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(week.done)")
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(AeroColor.titaniumWhite)
                        Text("DONE THIS WEEK")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(AeroColor.vaporGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)

                Divider().overlay(AeroColor.hairline)

                HStack {
                    Text("Snoozes & Skips:")
                        .font(.system(size: 11))
                        .foregroundStyle(AeroColor.vaporGray)
                    Spacer()
                    Text("\(week.snoozed) snoozed · \(week.skipped) skipped")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AeroColor.titaniumWhite)
                }

                if let h = appState.stats.weekHighlights(calendar: appState.config.scheduleCalendar) {
                    Divider().overlay(AeroColor.hairline)
                    HStack {
                        Text("Best Day:")
                            .font(.system(size: 11))
                            .foregroundStyle(AeroColor.vaporGray)
                        Spacer()
                        Text("\(h.bestDay ?? "—") (\(h.bestDone) done)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AeroColor.volt)
                    }
                }
            }

            AeroSectionCard(title: "All-Time Records") {
                let s = appState.stats
                HStack {
                    Text("Total Breaks Completed:")
                        .font(.system(size: 11))
                        .foregroundStyle(AeroColor.vaporGray)
                    Spacer()
                    Text("\(s.acknowledgedTotal)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(AeroColor.volt)
                }

                Divider().overlay(AeroColor.hairline)

                HStack {
                    Text("Total Reminders Shown:")
                        .font(.system(size: 11))
                        .foregroundStyle(AeroColor.vaporGray)
                    Spacer()
                    Text("\(s.shownTotal)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(AeroColor.titaniumWhite)
                }

                AeroGlassButton(title: "Reset All Telemetry Records", systemImage: "trash.fill") {
                    appState.stats = StatsSnapshot()
                }
                .padding(.top, 4)
            }
        }
    }
}

#if os(iOS)
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var model: PhoneModel
    @State private var showSettings = false

    private var countdownProgress: Double {
        guard let minutes = model.countdownMinutes else { return 0.0 }
        let total = max(10, model.config.intervalMinutes)
        let elapsed = max(0, total - minutes)
        return min(1.0, Double(elapsed) / Double(total))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // MARK: - Hero Aero-Kinetic Telemetry Card
                    VStack(spacing: 12) {
                        // Authority status badge row
                        HStack {
                            if model.honorsAuthority, let auth = model.authorityPresence {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(AeroColor.volt)
                                        .frame(width: 6, height: 6)
                                        .aeroGlow(color: AeroColor.volt, radius: 4)
                                    Text("AUTHORITY: \(auth.displayName.uppercased())")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .tracking(AeroPalette.telemetryTracking)
                                        .foregroundStyle(AeroColor.titaniumWhite)
                                }
                            } else {
                                Text("LOCAL CADENCE")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .tracking(AeroPalette.telemetryTracking)
                                    .foregroundStyle(AeroColor.vaporGray)
                            }
                            
                            Spacer()
                            
                            if let lease = model.authorityLeaseLine {
                                Text(lease)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(AeroColor.vaporGray)
                            }
                        }
                        
                        // Hero Gauge
                        AeroCountdownGauge(
                            progress: countdownProgress,
                            timeRemainingText: model.countdownMinutes.map { "\($0)m" } ?? "--",
                            subtitle: model.countdownMinutes != nil ? "UNTIL BREAK" : model.statusText,
                            accentColor: model.isPaused ? AeroColor.vaporGray : AeroColor.volt,
                            size: 160
                        )
                        .padding(.vertical, 6)
                        
                        // Status info & warnings
                        VStack(spacing: 4) {
                            Text(model.statusText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AeroColor.vaporGray)
                                .multilineTextAlignment(.center)
                            
                            if let badge = model.degradationBadge {
                                Text(badge)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AeroColor.alertOrange)
                                    .multilineTextAlignment(.center)
                            }
                            if let empty = model.emptyQueueLine {
                                Text(empty)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AeroColor.alertOrange)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        // Primary Actions
                        VStack(spacing: 8) {
                            Button(action: { model.acknowledgeDone() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Done — I took a break")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(AeroColor.void)
                                .background(AeroColor.volt)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .aeroGlow(color: AeroColor.volt, radius: 8)
                            }
                            .buttonStyle(.plain)
                            
                            HStack(spacing: 10) {
                                Button(action: { model.snooze(minutes: 10) }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.arrow.circlepath")
                                        Text("Snooze 10m")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(AeroColor.titaniumWhite)
                                    .background(AeroColor.slate.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AeroColor.hairline, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    if model.isPaused { model.resume() } else { model.pause() }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                                        Text(model.isPaused ? "Resume" : "Pause")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(AeroColor.titaniumWhite)
                                    .background(AeroColor.slate.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AeroColor.hairline, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(18)
                    .aeroGlassCard(cornerRadius: 18)
                    
                    // MARK: - iCloud Seed Banner
                    if model.syncHealth.shouldShowSeedBanner {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AeroColor.alertOrange)
                                Text("iCloud is empty for this app")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AeroColor.alertOrange)
                            }
                            Text("Push settings from the Mac once to seed multi-device sync.")
                                .font(.system(size: 12))
                                .foregroundStyle(AeroColor.vaporGray)
                            
                            HStack(spacing: 12) {
                                Button("Push Phone Settings") { _ = model.pushToiCloud() }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(AeroColor.alertOrange)
                                Spacer()
                                Button("Dismiss") { model.dismissSeedBanner() }
                                    .font(.system(size: 12))
                                    .foregroundStyle(AeroColor.vaporGray)
                            }
                        }
                        .padding(14)
                        .aeroGlassCard(cornerRadius: 14, strokeColor: AeroColor.alertOrange.opacity(0.4))
                    }
                    
                    // MARK: - Coming Up Schedule
                    if !model.upcoming.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("COMING UP")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(AeroColor.vaporGray)
                            
                            ForEach(Array(model.upcoming.prefix(4).enumerated()), id: \.offset) { index, next in
                                HStack {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(index == 0 ? AeroColor.volt : AeroColor.ionBlue)
                                            .frame(width: 6, height: 6)
                                        Text(label(for: next.kind))
                                            .font(.system(size: 14, weight: index == 0 ? .semibold : .regular))
                                            .foregroundStyle(AeroColor.titaniumWhite)
                                    }
                                    Spacer()
                                    Text(next.date, style: .time)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundStyle(index == 0 ? AeroColor.volt : AeroColor.vaporGray)
                                }
                                if index < min(model.upcoming.count - 1, 3) {
                                    Divider().overlay(AeroColor.hairline)
                                }
                            }
                        }
                        .padding(16)
                        .aeroGlassCard(cornerRadius: 16)
                    }
                    
                    // MARK: - This Week Metrics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("THIS WEEK")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(AeroColor.vaporGray)
                        
                        Text(model.weekStatsText())
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AeroColor.titaniumWhite)
                        
                        if let h = model.stats.weekHighlights(calendar: model.config.scheduleCalendar) {
                            Text("Best \(h.bestDay ?? "—") (\(h.bestDone) done) · quietest \(h.worstDay ?? "—")")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(AeroColor.vaporGray)
                        }
                    }
                    .padding(16)
                    .aeroGlassCard(cornerRadius: 16)
                    
                    // Notifications Disabled Alert
                    if !model.notificationsAuthorized {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.slash.fill")
                                .foregroundStyle(AeroColor.alertOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notifications Disabled")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AeroColor.alertOrange)
                                Text("Reminders cannot be delivered.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AeroColor.vaporGray)
                            }
                            Spacer()
                            Button("Enable") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AeroColor.alertOrange)
                        }
                        .padding(14)
                        .aeroGlassCard(cornerRadius: 14, strokeColor: AeroColor.alertOrange.opacity(0.4))
                    }
                }
                .padding(16)
            }
            .background(AeroColor.void.ignoresSafeArea())
            .navigationTitle("Stand Up")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(AeroColor.titaniumWhite)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    .environmentObject(model)
            }
            .sheet(item: $model.pendingGuidedPayload) { item in
                GuidedBreakSheet(payload: item.payload)
            }
        }
        .preferredColorScheme(.dark)
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
                    Toggle("Weekdays only", isOn: Binding(
                        get: { model.config.weekdaysOnly },
                        set: { on in
                            var c = model.config
                            c.weekdaysOnly = on
                            if on {
                                c.scheduleByWeekday["6"] = nil
                                c.scheduleByWeekday["7"] = nil
                            } else {
                                let template = c.scheduleByWeekday["1"] ?? .standard
                                c.scheduleByWeekday["6"] = c.scheduleByWeekday["6"] ?? template
                                c.scheduleByWeekday["7"] = c.scheduleByWeekday["7"] ?? template
                            }
                            model.config = c
                        }
                    ))
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
                    Toggle("Sync settings automatically", isOn: Binding(
                        get: { model.config.features.iCloudSyncEnabled },
                        set: { v in var c = model.config; c.features.iCloudSyncEnabled = v; model.config = c }
                    ))
                    Text("Settings and profiles reconcile when the app opens, returns to the foreground, and refreshes in the background. Changes push immediately.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Push settings to iCloud") {
                        cloudMessage = model.pushToiCloud()
                            ? "Pushed."
                            : "Push failed — check iCloud Drive / entitlements."
                    }
                    Button("Pull settings from iCloud") {
                        cloudMessage = model.pullFromiCloud().userMessage
                    }
                    if let cloudMessage {
                        Text(cloudMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Apple Health") {
                    Toggle("Connect Apple Health", isOn: Binding(
                        get: { model.config.healthLoggingEnabled },
                        set: { enabled in
                            var config = model.config
                            config.healthLoggingEnabled = enabled
                            model.config = config
                            if enabled { model.requestHealthAccess() }
                        }
                    ))
                    if model.config.healthLoggingEnabled {
                        Stepper(
                            "Mindful minutes on Done: \(Int(model.config.healthMindfulMinutes))",
                            value: Binding(
                                get: { Int(model.config.healthMindfulMinutes) },
                                set: { value in
                                    var config = model.config
                                    config.healthMindfulMinutes = Double(value)
                                    model.config = config
                                }
                            ),
                            in: 1...15
                        )
                    }
                    Text(healthStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if model.healthAccessStatus == .denied {
                        Button("Open Health Permissions") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    } else if model.healthAccessStatus != .authorized,
                              model.healthAccessStatus != .unavailable {
                        Button("Connect Apple Health") { model.requestHealthAccess() }
                    }
                }

                Section("Platform limits") {
                    Text("Unlike the Mac menu bar app, this phone cannot observe meetings, Focus/DND, deep work, or idle presence. Scheduled local notifications still fire in those states.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

    private var healthStatusText: String {
        switch model.healthAccessStatus {
        case .authorized:
            return "Connected. Recent workouts count as breaks, and Done writes a mindful session."
        case .notDetermined:
            return "Not connected. Access is requested only when you enable this feature."
        case .denied:
            return "Access denied. Enable Health access in Settings."
        case .unavailable:
            return "Apple Health is unavailable on this device."
        case .failed(let message):
            return "HealthKit error: \(message)"
        }
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

struct GuidedBreakSheet: View {
    @EnvironmentObject private var model: PhoneModel
    @Environment(\.dismiss) private var dismiss
    let payload: ReminderPayload
    @State private var completedSteps = Set<Int>()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(payload.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Steps") {
                    ForEach(Array(payload.guidedSteps.enumerated()), id: \.offset) { index, step in
                        Button {
                            if completedSteps.contains(index) {
                                completedSteps.remove(index)
                            } else {
                                completedSteps.insert(index)
                            }
                        } label: {
                            Label(step, systemImage: completedSteps.contains(index) ? "checkmark.circle.fill" : "circle")
                        }
                        .foregroundStyle(.primary)
                    }
                }
                Section {
                    Button("Done — break taken") {
                        model.acknowledgeDone()
                        dismiss()
                    }
                    .font(.headline)
                }
            }
            .navigationTitle(payload.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Close") { dismiss() }
            }
        }
    }
}
#endif

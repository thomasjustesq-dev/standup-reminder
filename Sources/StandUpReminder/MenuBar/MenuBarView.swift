import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState

    private var countdownInfo: (progress: Double, text: String, subtitle: String) {
        guard appState.config.enabled else {
            return (0.0, "OFF", "DISABLED")
        }
        if appState.isPaused {
            return (0.0, "PAUSED", "HOLD")
        }
        guard let next = appState.nextFireAt else {
            return (0.0, "--", "NO SCHEDULE")
        }
        let now = Date()
        let remaining = max(0, next.timeIntervalSince(now))
        let totalInterval = max(60.0, Double(appState.effectiveIntervalMinutes * 60))
        let elapsed = max(0.0, totalInterval - remaining)
        let progress = min(1.0, elapsed / totalInterval)
        
        let minutes = Int(ceil(remaining / 60))
        if minutes >= 60 {
            let hours = minutes / 60
            let remMin = minutes % 60
            return (progress, "\(hours)h \(remMin)m", "UNTIL BREAK")
        } else if minutes > 0 {
            return (progress, "\(minutes)m", "UNTIL BREAK")
        } else {
            return (1.0, "NOW", "BREAK TIME")
        }
    }

    private var nextFireDetailText: String {
        guard let next = appState.nextFireAt else { return "No upcoming reminder" }
        let formatter = DateFormatter()
        formatter.timeZone = appState.config.scheduleTimeZone
        formatter.dateFormat = "EEE h:mm a"
        return "Next at \(formatter.string(from: next)) · every \(appState.effectiveIntervalMinutes)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            // MARK: - Hero Aero-Kinetic Telemetry Card
            VStack(spacing: 8) {
                // Header Bar (Presence & Authority Badge)
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: appState.presence.symbolName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AeroColor.volt)
                        Text(appState.presence.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AeroColor.titaniumWhite)
                    }
                    
                    Spacer()
                    
                    AeroTelemetryBadge(
                        text: appState.isCadenceAuthority ? "Authority" : "Follower",
                        statusColor: appState.isCadenceAuthority ? AeroColor.volt : AeroColor.ionBlue
                    )
                }
                
                // Hero Circular Countdown Gauge with kinetic desk phase
                AeroCountdownGauge(
                    progress: countdownInfo.progress,
                    timeRemainingText: countdownInfo.text,
                    subtitle: countdownInfo.subtitle,
                    accentColor: appState.isPaused ? AeroColor.vaporGray : (appState.heldStatusLine != nil ? AeroColor.alertOrange : AeroColor.volt),
                    deskPhase: appState.config.sitStandModeEnabled ? appState.deskPhase.rawValue : nil,
                    showsFigure: true,
                    size: 116
                )
                .padding(.vertical, 4)
                
                // Status / Sub-telemetry readout
                VStack(spacing: 2) {
                    Text(appState.statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AeroColor.vaporGray)
                        .lineLimit(1)
                    
                    if let held = appState.heldStatusLine {
                        Text(held)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AeroColor.alertOrange)
                    }
                    
                    if let top = appState.topBlockLine {
                        Text(top)
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(AeroColor.vaporGray.opacity(0.8))
                    }
                }
                
                // Optional Posture Radar
                if appState.config.features.webcamStillnessEnabled {
                    AeroPostureRadar(
                        facePresent: WebcamStillnessMonitor.shared.facePresent,
                        isStillTooLong: WebcamStillnessMonitor.shared.isStillTooLong
                    )
                    .padding(.top, 2)
                }
                
                // Primary Quick Actions
                HStack(spacing: 8) {
                    if appState.isPaused {
                        AeroGlassButton(title: "Resume", systemImage: "play.fill", isProminent: true) {
                            appState.resume()
                        }
                    } else {
                        AeroGlassButton(title: "Break Now", systemImage: "figure.walk", isProminent: true) {
                            appState.testGuided()
                        }
                    }
                    
                    AeroGlassButton(title: "Snooze 10m", systemImage: "clock.arrow.circlepath") {
                        appState.snooze(minutes: 10)
                    }
                    .disabled(!appState.config.enabled)
                }
                .padding(.top, 4)
            }
            .padding(12)
            .aeroGlassCard(cornerRadius: 14)
            
            // MARK: - Alerts & Warnings
            if appState.notificationsAuthorized == false {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AeroColor.alertOrange)
                    Text("Notifications disabled")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AeroColor.alertOrange)
                    Spacer()
                    Button("Enable") {
                        openNotificationsPreferences()
                    }
                    .font(.system(size: 9.5, weight: .bold))
                    .buttonStyle(.plain)
                    .foregroundStyle(AeroColor.alertOrange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AeroColor.alertOrange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            // MARK: - Telemetry Details
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("PROFILE")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(AeroColor.vaporGray)
                    Spacer()
                    Text(appState.activeProfileName)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(AeroColor.titaniumWhite)
                }
                
                HStack {
                    Text("SCHEDULE")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(AeroColor.vaporGray)
                    Spacer()
                    Text(nextFireDetailText)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(AeroColor.titaniumWhite)
                }
                
                if appState.config.sitStandModeEnabled {
                    HStack {
                        Text("DESK PHASE")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(AeroColor.vaporGray)
                        Spacer()
                        Text(appState.deskPhase.rawValue)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(AeroColor.titaniumWhite)
                    }
                }
                
                if appState.config.features.fightingShapeEnabled, let score = FightingShapeMonitor.shared.lastRecoveryScore {
                    HStack {
                        Text("RECOVERY")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(AeroColor.vaporGray)
                        Spacer()
                        Text("\(Int(score))% · \(FightingShapeMonitor.shared.lowRecovery ? "Tightened" : "Nominal")")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(FightingShapeMonitor.shared.lowRecovery ? AeroColor.alertOrange : AeroColor.volt)
                    }
                }
                
                HStack {
                    Text("THIS WEEK")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(AeroColor.vaporGray)
                    Spacer()
                    Text(appState.weekStatsText())
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(AeroColor.titaniumWhite)
                }
                
                if appState.config.features.iCloudSyncEnabled {
                    HStack {
                        Text("ICLOUD SYNC")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(AeroColor.vaporGray)
                        Spacer()
                        Text(appState.syncHealth.summary(iCloudEnabled: true))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(appState.syncHealth.lastPullWasStale || appState.syncHealth.cloudContainerEmpty ? AeroColor.alertOrange : AeroColor.vaporGray)
                    }
                    if let lease = appState.authorityLeaseLine {
                        Text(lease)
                            .font(.system(size: 8.5, weight: .regular))
                            .foregroundStyle(AeroColor.vaporGray.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 4)
            
            Divider()
                .overlay(AeroColor.hairline)
            
            // MARK: - Menu Controls & Actions
            VStack(spacing: 2) {
                Toggle("Reminders enabled", isOn: Binding(
                    get: { appState.config.enabled },
                    set: { appState.setEnabled($0) }
                ))
                .font(.system(size: 11.5))
                .padding(.vertical, 2)
                
                if !appState.isPaused {
                    Button("Pause reminders") { appState.pause() }
                        .disabled(!appState.config.enabled)
                }
                
                Button("Skip rest of today") { appState.skipToday() }
                    .disabled(!appState.config.enabled)
                
                Menu("Switch Profile") {
                    ForEach(appState.profiles.profiles) { profile in
                        Button(profile.name) { appState.switchProfile(id: profile.id) }
                    }
                }
            }
            
            Divider()
                .overlay(AeroColor.hairline)
            
            // Windows & Settings
            VStack(spacing: 2) {
                Button("Today Timeline…") {
                    NotificationCenter.default.post(name: .openDayTimeline, object: nil)
                }
                Button("Guided Break Window…") {
                    NotificationCenter.default.post(name: .openGuidedBreakWindow, object: nil)
                }
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Button("Welcome / Permissions…") {
                    NotificationCenter.default.post(name: .openOnboardingWindow, object: nil)
                }
            }
            
            if let update = appState.updateInfo, update.isNewer, let url = URL(string: update.htmlURL) {
                Divider().overlay(AeroColor.hairline)
                Button("Download update: \(update.tagName)") {
                    NSWorkspace.shared.open(url)
                }
                .foregroundStyle(AeroColor.alertOrange)
            }
            
            Divider()
                .overlay(AeroColor.hairline)
            
            Button("Quit Stand Up Reminder") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            
            #if DEBUG
            if DebugEnvironment.isDebugMode {
                Divider().overlay(AeroColor.hairline)
                Button("Debug Panel…") {
                    NotificationCenter.default.post(name: .openDebugPanel, object: nil)
                }
            }
            #endif
        }
        .padding(10)
        .frame(width: 290, alignment: .leading)
        .onAppear {
            if appState.showOnboarding {
                NotificationCenter.default.post(name: .openOnboardingWindow, object: nil)
            }
            if appState.showGuidedBreak {
                NotificationCenter.default.post(name: .openGuidedBreakWindow, object: nil)
            }
        }
        .onChange(of: appState.showGuidedBreak) { _, shouldOpen in
            if shouldOpen { NotificationCenter.default.post(name: .openGuidedBreakWindow, object: nil) }
        }
        .onChange(of: appState.showSampleDayTour) { _, shouldOpen in
            if shouldOpen { NotificationCenter.default.post(name: .openSampleDayTour, object: nil) }
        }
    }
    
    private func openNotificationsPreferences() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]
        for target in candidates {
            if let url = URL(string: target) {
                NSWorkspace.shared.open(url)
                break
            }
        }
    }
}

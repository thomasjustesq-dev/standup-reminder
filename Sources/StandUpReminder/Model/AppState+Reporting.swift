import Foundation

/// Outward-facing reporting: widget snapshot, weekly stats text, the CLI
/// status report, and settings import/export.
@MainActor
extension AppState {
    func publishWidget() {
        WidgetSnapshotWriter.write(
            from: config,
            nextFireAt: nextFireAt,
            statusMessage: statusMessage,
            stats: stats,
            deskPhase: config.sitStandModeEnabled ? deskPhase : nil,
            profileName: activeProfileName
        )
    }

    func weekStatsText() -> String {
        var w = stats.weekSummary()
        for remote in remoteStats {
            let r = remote.weekSummary()
            w = (w.shown + r.shown, w.done + r.done, w.skipped + r.skipped, w.snoozed + r.snoozed, w.selfLogged + r.selfLogged)
        }
        let suffix = remoteStats.isEmpty ? "" : " (all devices)"
        let breakdown = w.selfLogged > 0 ? " (\(w.selfLogged) self-logged)" : ""
        return "This week: \(w.done) done\(breakdown) · \(w.shown) shown · \(w.snoozed) snoozed · \(w.skipped) skipped\(suffix)"
    }

    func statusReport() -> String {
        let next: String = {
            guard let nextFireAt else { return "none" }
            let formatter = DateFormatter()
            formatter.timeZone = config.scheduleTimeZone
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: nextFireAt)
        }()
        return """
        profile: \(activeProfileName)
        presence: \(presence.displayName)
        cadence: \(resolvedCadenceRole.rawValue)\(isCadenceAuthority ? " (authority)" : " (follower)")
        enabled: \(config.enabled)
        paused: \(isPaused)
        interval: \(effectiveIntervalMinutes)m (base \(config.intervalMinutes))
        deskPhase: \(config.sitStandModeEnabled ? deskPhase.rawValue : "off")
        timezone: \(config.scheduleTimeZone.identifier)
        status: \(statusMessage)
        next: \(next)
        notifications: \(notificationsAuthorized.map { $0 ? "authorized" : "DENIED" } ?? "unknown")
        sync: \(syncHealth.summary(iCloudEnabled: config.features.iCloudSyncEnabled))
        \(evidenceStats.summaryLine())
        update: \(updateInfo.map { "\($0.tagName) \($0.isNewer ? "(newer)" : "")" } ?? "n/a")
        \(weekStatsText())
        config: \(Paths.configFile.path)
        """
    }

    /// CLI `sync-doctor` report.
    func syncDoctorReport() -> String {
        var lines: [String] = []
        lines.append("container: \(CloudSync.isContainerAvailable ? "available" : "UNAVAILABLE")")
        lines.append("iCloud enabled in config: \(config.features.iCloudSyncEnabled)")
        lines.append("identity: \(AppIdentity.iCloudContainer) · \(AppIdentity.appGroupID)")
        lines.append(syncHealth.summary(iCloudEnabled: config.features.iCloudSyncEnabled))
        if let msg = syncHealth.lastPullMessage { lines.append("last pull: \(msg)") }
        if let runtime = CloudSync.pullRuntime() {
            lines.append("runtime.json: \(runtime.deviceName) @ \(runtime.updatedAt)")
            lines.append("  paused=\(runtime.isPaused.map(String.init(describing:)) ?? "nil") snooze=\(runtime.snoozeUntil.map { "\($0)" } ?? "nil") interval=\(runtime.effectiveIntervalMinutes.map(String.init) ?? "nil")")
        } else {
            lines.append("runtime.json: missing")
        }
        if syncHealth.lastPullWasStale {
            lines.append("ACTION: local config newer than iCloud — run icloud-push or icloud-pull --force")
        }
        if !CloudSync.isContainerAvailable {
            lines.append("ACTION: sign into iCloud Drive; enable App Group + iCloud on App ID")
        }
        lines.append(blockStats.report())
        return lines.joined(separator: "\n")
    }

    // MARK: Scheduler Input

    /// Construct a `Scheduler.Input` from the current live state so that
    /// debug commands and the debug panel can call scheduling functions
    /// without duplicating the input-assembly logic.
    func makeSchedulerInput(now: Date = Date()) -> Scheduler.Input {
        Scheduler.Input(
            config: config,
            intervalMinutes: effectiveIntervalMinutes,
            now: now,
            paused: isPaused || !config.enabled || isSkipTodayActive,
            snoozeUntil: snoozeUntil,
            lastReminderAt: lastReminderAt,
            lastAcknowledgedAt: lastAcknowledgedAt,
            deskPhaseStartedAt: deskPhaseStartedAt,
            lunchFiredDayKey: lunchFiredDayKey,
            windDownFiredDayKey: windDownFiredDayKey
        )
    }

    // MARK: Import / Export

    func exportSettings() throws -> Data {
        try ConfigStore.exportJSON()
    }

    func importSettings(_ data: Data) throws {
        config = try ConfigStore.importJSON(data)
        refreshNextFire()
    }
}

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
        enabled: \(config.enabled)
        paused: \(isPaused)
        interval: \(effectiveIntervalMinutes)m (base \(config.intervalMinutes))
        deskPhase: \(config.sitStandModeEnabled ? deskPhase.rawValue : "off")
        timezone: \(config.scheduleTimeZone.identifier)
        status: \(statusMessage)
        next: \(next)
        update: \(updateInfo.map { "\($0.tagName) \($0.isNewer ? "(newer)" : "")" } ?? "n/a")
        \(weekStatsText())
        config: \(Paths.configFile.path)
        """
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

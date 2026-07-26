import Foundation

/// External data flow: iCloud config/runtime/stats sync, weather, team quiet
/// hours, learned schedule, and update checks.
@MainActor
extension AppState {
    @discardableResult
    func pullFromiCloud() -> CloudSync.PullOutcome {
        // A fresh install's auto-created defaults file is not user state; a
        // staleness check against its mtime would forbid ever pulling real
        // settings down to a new device.
        let localStamp = config.hasCompletedOnboarding ? Self.fileMTime(Paths.configFile) : nil
        let outcome = CloudSync.pull(localModifiedAt: localStamp)
        if case let .success(pulledConfig, pulledProfiles, _) = outcome {
            config = pulledConfig
            if let pulledProfiles { profiles = pulledProfiles }
            refreshNextFire()
        }
        statusMessage = outcome.userMessage
        return outcome
    }

    @discardableResult
    func pushToiCloud() -> Bool {
        let ok = CloudSync.push(config: config, profiles: profiles)
        statusMessage = ok ? "Pushed to iCloud" : "iCloud push failed — check iCloud Drive"
        return ok
    }

    /// Weather hourly, team quiet feed every 6h, cross-device runtime/stats
    /// every minute — all on the tick cadence.
    func refreshPeriodicSourcesIfDue() {
        if config.features.weatherBreaksEnabled,
           lastWeatherRefreshAt.map({ Date().timeIntervalSince($0) >= 3600 }) ?? true {
            lastWeatherRefreshAt = Date()
            Task { await self.refreshWeather() }
        }
        if config.features.teamQuiet.enabled,
           !config.features.teamQuiet.feedURL.isEmpty,
           config.features.teamQuiet.lastFetchedAt.map({ Date().timeIntervalSince($0) >= 6 * 3600 }) ?? true {
            Task { await self.refreshTeamQuietHours() }
        }
        FightingShapeMonitor.shared.refreshIfDue(
            enabled: config.features.fightingShapeEnabled,
            baseURL: config.features.fightingShapeBaseURL
        )
        if config.features.iCloudSyncEnabled,
           lastRuntimeSyncAt.map({ Date().timeIntervalSince($0) >= 60 }) ?? true {
            lastRuntimeSyncAt = Date()
            if let doc = CloudSync.pullRuntime() { applyCloudRuntime(doc) }
            if stats != lastPushedStats {
                CloudSync.pushStats(stats, deviceId: CloudSync.deviceId())
                lastPushedStats = stats
            }
            remoteStats = CloudSync.pullRemoteStats(excludingDeviceId: CloudSync.deviceId())
        }
    }

    /// Newest-wins per field, and only ever forward in time — a stale doc
    /// can extend nothing and clear nothing. Docs not newer than this
    /// device's last mutation are ignored entirely (that includes the
    /// device's own last push).
    private func applyCloudRuntime(_ doc: CloudSync.RuntimeDoc) {
        if let local = lastRuntimeMutationAt, doc.updatedAt <= local { return }
        var changed = false
        if let remote = doc.lastAcknowledgedAt, (lastAcknowledgedAt ?? .distantPast) < remote {
            lastAcknowledgedAt = remote; changed = true
        }
        if let remote = doc.lastReminderAt, (lastReminderAt ?? .distantPast) < remote {
            lastReminderAt = remote; changed = true
        }
        if let remote = doc.snoozeUntil, remote > Date(), (snoozeUntil ?? .distantPast) < remote {
            snoozeUntil = remote; changed = true
        }
        if let remote = doc.skipRestOfDayDate, Calendar.current.isDateInToday(remote), !isSkipTodayActive {
            skipRestOfDayDate = remote; changed = true
        }
        if changed {
            statusMessage = "Synced from \(doc.deviceName)"
            refreshNextFire()
        }
    }

    func syncRuntimeToCloud() {
        let stamp = Date()
        lastRuntimeMutationAt = stamp
        guard config.features.iCloudSyncEnabled else { return }
        CloudSync.pushRuntime(CloudSync.RuntimeDoc(
            updatedAt: stamp,
            deviceName: CloudSync.defaultDeviceName(),
            lastReminderAt: lastReminderAt,
            lastAcknowledgedAt: lastAcknowledgedAt,
            snoozeUntil: snoozeUntil,
            skipRestOfDayDate: skipRestOfDayDate
        ))
    }

    func refreshTeamQuietHours() async {
        guard config.features.teamQuiet.enabled,
              !config.features.teamQuiet.feedURL.isEmpty else { return }
        let windows = await TeamQuietHours.fetch(from: config.features.teamQuiet.feedURL)
        var c = config
        c.features.teamQuiet.lastFetchedAt = Date()
        if !windows.isEmpty {
            c.features.teamQuiet.windows = windows
        }
        config = c
    }

    func refreshWeather() async {
        guard config.features.weatherBreaksEnabled else {
            weather = nil
            return
        }
        LocationProvider.shared.refresh()
        let coords: (Double, Double)
        if let lat = config.features.weatherLatitude, let lon = config.features.weatherLongitude {
            coords = (lat, lon)
        } else if let fix = LocationProvider.shared.lastCoordinate {
            coords = (fix.latitude, fix.longitude)
        } else {
            coords = WeatherService.approxCoordinates(for: config.scheduleTimeZone)
        }
        weather = await WeatherService.fetch(latitude: coords.0, longitude: coords.1)
    }

    func refreshLearnedSuggestion() {
        learnedStore = LearnedScheduleStore.load()
        learnedSuggestion = learnedStore.suggestion(calendar: config.scheduleCalendar)
    }

    func applyLearnedSchedule() {
        guard let suggestion = learnedSuggestion else { return }
        var c = config
        for key in c.scheduleByWeekday.keys {
            c.scheduleByWeekday[key] = suggestion
        }
        config = c
        statusMessage = "Applied learned \(suggestion.startHour)–\(suggestion.endHour)"
        refreshNextFire()
        if config.features.diagnosticsEnabled {
            Task {
                await Diagnostics.report(
                    event: "applied_learned_schedule",
                    details: ["start": "\(suggestion.startHour)", "end": "\(suggestion.endHour)"],
                    endpoint: config.features.diagnosticsEndpoint
                )
            }
        }
    }

    func maybeCheckForUpdates(force: Bool = false) async {
        guard config.updateCheckEnabled else { return }
        if !force, let last = lastUpdateCheckAt, Date().timeIntervalSince(last) < 12 * 3600 { return }
        lastUpdateCheckAt = Date()
        persistRuntime()
        if let info = await UpdateChecker.check(releasesURL: config.githubReleasesURL), info.isNewer {
            updateInfo = info
            AppLog.write("Update available: \(info.tagName)")
        }
    }
}

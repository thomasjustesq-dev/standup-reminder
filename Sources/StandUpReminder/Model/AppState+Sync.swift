import Foundation

/// External data flow: iCloud config/runtime/stats sync, weather, team quiet
/// hours, learned schedule, and update checks.
@MainActor
extension AppState {
    @discardableResult
    func pullFromiCloud(force: Bool = false) -> CloudSync.PullOutcome {
        // A fresh install's auto-created defaults file is not user state; a
        // staleness check against its mtime would forbid ever pulling real
        // settings down to a new device.
        let localStamp = (force || !config.hasCompletedOnboarding) ? nil : Self.fileMTime(Paths.configFile)
        let outcome = force ? CloudSync.forcePull() : CloudSync.pull(localModifiedAt: localStamp)
        syncHealth.lastPullAt = Date()
        syncHealth.lastPullMessage = outcome.userMessage
        switch outcome {
        case .success(let pulledConfig, let pulledProfiles, let remoteAt):
            suppressCloudSettingsPush = true
            defer { suppressCloudSettingsPush = false }
            if let pulledProfiles { profiles = pulledProfiles }
            config = pulledConfig
            refreshNextFire()
            syncHealth.lastRuntimeRemoteAt = remoteAt
            syncHealth.lastPullWasStale = false
            syncHealth.cloudContainerEmpty = false
        case .empty:
            syncHealth.lastPullWasStale = false
            syncHealth.cloudContainerEmpty = true
            syncHealth.seedBannerDismissed = false
        case .staleRemote:
            syncHealth.lastPullWasStale = true
            syncHealth.cloudContainerEmpty = false
        default:
            syncHealth.lastPullWasStale = false
        }
        SyncHealth.save(syncHealth)
        statusMessage = outcome.userMessage
        return outcome
    }

    /// Automatic newest-wins settings/profile reconciliation. Equal payloads
    /// are a no-op, so saving a remote pull locally cannot create ping-pong.
    func reconcileSettingsWithCloud() {
        guard config.features.iCloudSyncEnabled else { return }
        let localStamp = [Self.fileMTime(Paths.configFile), Self.fileMTime(ProfileStore.fileURL)]
            .compactMap { $0 }
            .max()
        let outcome = CloudSync.pull(localModifiedAt: nil)
        syncHealth.lastPullAt = Date()
        syncHealth.lastPullMessage = outcome.userMessage

        switch outcome {
        case .success(let remoteConfig, let remoteProfiles, let remoteAt):
            let action = CloudSettingsSyncPolicy.decide(
                localConfig: config,
                localProfiles: profiles,
                localModifiedAt: localStamp,
                remoteConfig: remoteConfig,
                remoteProfiles: remoteProfiles,
                remoteUpdatedAt: remoteAt,
                isFreshInstall: !config.hasCompletedOnboarding
            )
            switch action {
            case .applyRemote:
                suppressCloudSettingsPush = true
                defer { suppressCloudSettingsPush = false }
                if let remoteProfiles { profiles = remoteProfiles }
                config = remoteConfig
                syncHealth.lastRuntimeRemoteAt = remoteAt
                syncHealth.cloudContainerEmpty = false
                syncHealth.lastPullWasStale = false
                statusMessage = "Settings synced from iCloud"
                refreshNextFire()
            case .pushLocal:
                _ = pushToiCloud()
            case .unchanged:
                syncHealth.cloudContainerEmpty = false
                syncHealth.lastPullWasStale = false
                syncHealth.lastPullMessage = "Settings up to date"
            }
        case .empty:
            syncHealth.cloudContainerEmpty = true
            syncHealth.seedBannerDismissed = false
            _ = pushToiCloud()
        case .downloading, .unavailable, .corrupt:
            break
        case .staleRemote:
            // Impossible with localModifiedAt:nil; retain a safe local-wins fallback.
            _ = pushToiCloud()
        }
        SyncHealth.save(syncHealth)
    }

    @discardableResult
    func pushToiCloud() -> Bool {
        let ok = CloudSync.push(config: config, profiles: profiles)
        if ok {
            syncHealth.lastPushAt = Date()
            syncHealth.lastPullWasStale = false
            syncHealth.cloudContainerEmpty = false
            SyncHealth.save(syncHealth)
        }
        statusMessage = ok ? "Pushed to iCloud" : "iCloud push failed — check iCloud Drive"
        return ok
    }

    func dismissCloudSeedBanner() {
        syncHealth.seedBannerDismissed = true
        SyncHealth.save(syncHealth)
    }

    /// One-time copy from `iCloud.com.user.StandUpReminder` when the new container is empty.
    func migrateLegacyiCloudIfNeeded() {
        guard config.features.iCloudSyncEnabled else { return }
        if let note = CloudSync.migrateFromLegacyContainerIfNeeded() {
            syncHealth.lastMigrationAt = Date()
            syncHealth.migrationNote = note
            SyncHealth.save(syncHealth)
            statusMessage = note
        }
    }

    /// Weather hourly, team quiet feed every 6h, cross-device runtime/stats
    /// every minute — all on the tick cadence.
    func refreshPeriodicSourcesIfDue() {
        if config.features.iCloudSyncEnabled,
           lastSettingsSyncAt.map({ Date().timeIntervalSince($0) >= 60 }) ?? true {
            lastSettingsSyncAt = Date()
            reconcileSettingsWithCloud()
        }
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
            migrateLegacyiCloudIfNeeded()
            if let doc = CloudSync.pullRuntime() { applyCloudRuntime(doc) }
            if stats != lastPushedStats {
                CloudSync.pushStats(stats, deviceId: CloudSync.deviceId())
                lastPushedStats = stats
            }
            remoteStats = CloudSync.pullRemoteStats(excludingDeviceId: CloudSync.deviceId())
        }
        maybeApplyScheduleProfileRules()
        maybeCreditStandHour()
    }

    private func maybeApplyScheduleProfileRules() {
        let rules = config.features.scheduleProfileRules
        guard !rules.isEmpty else { return }
        guard let pack = ScheduleProfileRule.activePack(
            rules: rules, at: Date(), calendar: config.scheduleCalendar
        ) else { return }
        guard pack != config.reminderPack, pack != lastScheduleRulePack else { return }
        applyReminderPack(pack)
        lastScheduleRulePack = pack
        statusMessage = "Schedule rule → \(pack.displayName)"
    }

    private func maybeCreditStandHour() {
        guard config.features.creditStandHourAsBreak, config.healthLoggingEnabled else { return }
        if let last = lastStandCreditAt, Calendar.current.isDate(last, equalTo: Date(), toGranularity: .hour) {
            return
        }
        HealthLogger.standHourClosedThisHour { [weak self] closed in
            Task { @MainActor in
                guard let self, closed else { return }
                if let last = self.lastStandCreditAt,
                   Calendar.current.isDate(last, equalTo: Date(), toGranularity: .hour) { return }
                self.lastAcknowledgedAt = Date()
                self.lastStandCreditAt = Date()
                self.recordEvidence(.standHour)
                self.statusMessage = "Stand hour closed — break credited"
                self.refreshNextFire()
                self.syncRuntimeToCloud()
            }
        }
    }

    /// Newest-wins merge via `RuntimeMerge` — remote can extend anchors,
    /// clear snooze/skip, set pause, and publish adaptive interval.
    private func applyCloudRuntime(_ doc: CloudSync.RuntimeDoc) {
        let outcome = RuntimeMerge.apply(
            local: RuntimeMerge.Local(
                lastReminderAt: lastReminderAt,
                lastAcknowledgedAt: lastAcknowledgedAt,
                snoozeUntil: snoozeUntil,
                skipRestOfDayDate: skipRestOfDayDate,
                effectiveIntervalMinutes: effectiveIntervalMinutes,
                isPaused: isPaused,
                lastRuntimeMutationAt: lastRuntimeMutationAt
            ),
            remote: doc,
            calendar: config.scheduleCalendar
        )
        guard outcome.changed else { return }
        lastReminderAt = outcome.local.lastReminderAt
        lastAcknowledgedAt = outcome.local.lastAcknowledgedAt
        snoozeUntil = outcome.local.snoozeUntil
        skipRestOfDayDate = outcome.local.skipRestOfDayDate
        isPaused = outcome.local.isPaused
        // Newest remote doc wins for adaptive interval (multi-Mac / Mac→iOS).
        if let minutes = outcome.local.effectiveIntervalMinutes {
            effectiveIntervalMinutes = minutes
        }
        syncHealth.lastRuntimeRemoteAt = doc.updatedAt
        syncHealth.lastRuntimeRemoteDevice = doc.deviceName
        if let auth = doc.authorityDeviceName {
            remoteAuthorityName = auth
        }
        if let p = doc.authorityPresence {
            remoteAuthorityPresence = p
            if !isCadenceAuthority, let state = PresenceState(rawValue: p) {
                presence = state
            }
        }
        SyncHealth.save(syncHealth)
        statusMessage = "Synced from \(doc.deviceName)"
        refreshNextFire()
    }

    func syncRuntimeToCloud() {
        let stamp = Date()
        lastRuntimeMutationAt = stamp
        guard config.features.iCloudSyncEnabled else { return }
        let claim = isCadenceAuthority && config.features.claimCadenceAuthority
        let ok = CloudSync.pushRuntime(CloudSync.RuntimeDoc(
            updatedAt: stamp,
            deviceName: CloudSync.defaultDeviceName(),
            lastReminderAt: lastReminderAt,
            lastAcknowledgedAt: lastAcknowledgedAt,
            snoozeUntil: snoozeUntil,
            skipRestOfDayDate: skipRestOfDayDate,
            effectiveIntervalMinutes: effectiveIntervalMinutes,
            isPaused: isPaused,
            authorityDeviceId: claim ? CloudSync.deviceId() : nil,
            authorityDeviceName: claim ? CloudSync.defaultDeviceName() : remoteAuthorityName,
            authorityPresence: claim ? presence.rawValue : remoteAuthorityPresence,
            nextFireAt: nextFireAt
        ))
        if ok {
            syncHealth.lastPushAt = stamp
            SyncHealth.save(syncHealth)
        }
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

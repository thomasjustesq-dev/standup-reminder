#if os(iOS)
import Foundation

@MainActor
extension PhoneModel {
    @discardableResult
    func pushToiCloud() -> Bool {
        let ok = CloudSync.push(config: config, profiles: ProfileStore.load())
        if ok {
            syncHealth.lastPushAt = Date()
            syncHealth.cloudContainerEmpty = false
            SyncHealth.save(syncHealth)
        }
        return ok
    }

    func pullFromiCloud() -> CloudSync.PullOutcome {
        // Fresh install: the auto-created defaults file is not user state.
        let mtime = config.hasCompletedOnboarding
            ? (try? FileManager.default.attributesOfItem(atPath: Paths.configFile.path))?[.modificationDate] as? Date
            : nil
        let outcome = CloudSync.pull(localModifiedAt: mtime)
        syncHealth.lastPullAt = Date()
        syncHealth.lastPullMessage = outcome.userMessage
        switch outcome {
        case .success(let pulledConfig, let pulledProfiles, let remoteAt):
            suppressCloudSettingsPush = true
            defer { suppressCloudSettingsPush = false }
            config = pulledConfig
            if let pulledProfiles { ProfileStore.save(pulledProfiles) }
            syncHealth.cloudContainerEmpty = false
            syncHealth.lastPullWasStale = false
            syncHealth.lastRuntimeRemoteAt = remoteAt
        case .empty:
            syncHealth.cloudContainerEmpty = true
            syncHealth.seedBannerDismissed = false
            syncHealth.lastPullWasStale = false
        case .staleRemote:
            syncHealth.lastPullWasStale = true
            syncHealth.cloudContainerEmpty = false
        default:
            syncHealth.lastPullWasStale = false
        }
        SyncHealth.save(syncHealth)
        return outcome
    }

    /// Automatic newest-wins reconciliation for settings and profiles.
    /// Equal payloads are a no-op, preventing pull/save/push loops.
    func reconcileSettingsWithCloud() {
        guard config.features.iCloudSyncEnabled else { return }
        let localConfigStamp = (try? FileManager.default.attributesOfItem(atPath: Paths.configFile.path))?[.modificationDate] as? Date
        let localProfilesStamp = (try? FileManager.default.attributesOfItem(atPath: ProfileStore.fileURL.path))?[.modificationDate] as? Date
        let localStamp = [localConfigStamp, localProfilesStamp].compactMap { $0 }.max()
        let localProfiles = ProfileStore.load()
        let outcome = CloudSync.pull(localModifiedAt: nil)
        syncHealth.lastPullAt = Date()
        syncHealth.lastPullMessage = outcome.userMessage

        switch outcome {
        case .success(let remoteConfig, let remoteProfiles, let remoteAt):
            let action = CloudSettingsSyncPolicy.decide(
                localConfig: config,
                localProfiles: localProfiles,
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
                if let remoteProfiles { ProfileStore.save(remoteProfiles) }
                config = remoteConfig
                syncHealth.cloudContainerEmpty = false
                syncHealth.lastPullWasStale = false
                syncHealth.lastRuntimeRemoteAt = remoteAt
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
        case .staleRemote:
            _ = pushToiCloud()
        case .downloading, .unavailable, .corrupt:
            break
        }
        SyncHealth.save(syncHealth)
    }

    func syncRuntimeToCloud() {
        let stamp = Date()
        lastRuntimeMutationAt = stamp
        guard config.features.iCloudSyncEnabled else { return }
        // Phone is a follower: push anchors only, never claim authority.
        CloudSync.pushRuntime(CloudSync.RuntimeDoc(
            updatedAt: stamp,
            deviceName: CloudSync.defaultDeviceName(),
            lastReminderAt: lastReminderAt,
            lastAcknowledgedAt: lastAcknowledgedAt,
            snoozeUntil: snoozeUntil,
            skipRestOfDayDate: skipRestOfDayDate,
            effectiveIntervalMinutes: cloudEffectiveIntervalMinutes ?? config.intervalMinutes,
            isPaused: isPaused,
            authorityDeviceId: nil,
            authorityDeviceName: authorityName,
            authorityPresence: authorityPresence?.rawValue,
            nextFireAt: authorityNextFireAt
        ))
        syncHealth.lastPushAt = stamp
        SyncHealth.save(syncHealth)
    }

    /// Newest-wins merge via `RuntimeMerge` (clears snooze/skip when remote is newer).
    /// Always refreshes authority presence / next-fire for follower scheduling.
    /// Stale authority lease → clear honor flags so queue rebuilds locally.
    func syncRuntimeFromCloud() {
        guard config.features.iCloudSyncEnabled else { return }
        if let doc = CloudSync.pullRuntime() {
            let outcome = RuntimeMerge.apply(
                local: RuntimeMerge.Local(
                    lastReminderAt: lastReminderAt,
                    lastAcknowledgedAt: lastAcknowledgedAt,
                    snoozeUntil: snoozeUntil,
                    skipRestOfDayDate: skipRestOfDayDate,
                    effectiveIntervalMinutes: cloudEffectiveIntervalMinutes,
                    isPaused: isPaused,
                    lastRuntimeMutationAt: lastRuntimeMutationAt
                ),
                remote: doc,
                calendar: config.scheduleCalendar
            )
            if outcome.changed {
                lastReminderAt = outcome.local.lastReminderAt
                lastAcknowledgedAt = outcome.local.lastAcknowledgedAt
                snoozeUntil = outcome.local.snoozeUntil
                skipRestOfDayDate = outcome.local.skipRestOfDayDate
                cloudEffectiveIntervalMinutes = outcome.local.effectiveIntervalMinutes
                isPaused = outcome.local.isPaused
            }

            // Authority fields only from docs that claim authority (device id set)
            // or that publish presence/gate. Stamp always from doc.updatedAt.
            let claimsAuthority = doc.authorityDeviceId != nil
                || doc.authorityPresence != nil
                || doc.nextFireAt != nil
            let newPresence = doc.authorityPresence.flatMap(PresenceState.init(rawValue:))
            let newGate = doc.nextFireAt
            let newName = doc.authorityDeviceName ?? (claimsAuthority ? doc.deviceName : nil)
            let newStamp = claimsAuthority ? doc.updatedAt : authorityUpdatedAt

            let authorityChanged =
                newPresence != authorityPresence
                || newGate != authorityNextFireAt
                || newName != authorityName
                || newStamp != authorityUpdatedAt

            if claimsAuthority {
                authorityPresence = newPresence
                authorityNextFireAt = newGate
                authorityName = newName
                authorityUpdatedAt = doc.updatedAt
                syncHealth.lastRuntimeRemoteAt = doc.updatedAt
                syncHealth.lastRuntimeRemoteDevice = newName ?? doc.deviceName
                SyncHealth.save(syncHealth)
            }

            if outcome.changed || authorityChanged {
                rescheduleNotifications()
            }
        }
        if stats != lastPushedStats {
            CloudSync.pushStats(stats, deviceId: CloudSync.deviceId())
            lastPushedStats = stats
        }
        remoteStats = CloudSync.pullRemoteStats(excludingDeviceId: CloudSync.deviceId())
    }
}
#endif

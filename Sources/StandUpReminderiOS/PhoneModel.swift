#if os(iOS)
import ActivityKit
import BackgroundTasks
import Combine
import Foundation
import UserNotifications
import WidgetKit

/// iOS counterpart of the Mac's AppState. iOS apps cannot run a background
/// timer, so instead of ticking, the model pre-schedules the next batch of
/// reminders as local notifications (via Scheduler.upcoming) and rebuilds the
/// queue on every interaction or foreground.
@MainActor
final class PhoneModel: ObservableObject {
    static let shared = PhoneModel()

    /// How many future reminders to keep queued (iOS caps pending local
    /// notifications at 64 per app).
    static let queueDepth = 24

    @Published var config: AppConfig {
        didSet {
            ConfigStore.save(config)
            rescheduleNotifications()
        }
    }

    @Published var stats: StatsSnapshot {
        didSet { StatsStore.save(stats) }
    }

    @Published var isPaused = false { didSet { persistRuntime(); rescheduleNotifications() } }
    @Published var snoozeUntil: Date? { didSet { persistRuntime(); rescheduleNotifications() } }
    @Published var skipRestOfDayDate: Date? { didSet { persistRuntime(); rescheduleNotifications() } }
    @Published var lastReminderAt: Date? { didSet { persistRuntime() } }
    @Published var lastAcknowledgedAt: Date? { didSet { persistRuntime() } }
    @Published var upcoming: [Scheduler.Next] = []
    @Published var notificationsAuthorized = false
    @Published var pendingGuidedPayload: GuidedSheetPayload?

    static let backgroundRefreshTaskId = AppIdentity.backgroundRefreshTaskId

    /// Adaptive interval pushed from a Mac peer (iOS has no idle samples).
    private var cloudEffectiveIntervalMinutes: Int?

    private let notificationDelegate = NotificationDelegate()
    private var suppressPersist = false
    private var suppressReschedule = false
    private var deskPhase: DeskPhase = .sit
    private var deskPhaseStartedAt: Date?
    private var lunchFiredDayKey: String?
    private var windDownFiredDayKey: String?
    private var countedDeliveredIds = Set<String>()
    private var lastPushedStats: StatsSnapshot?
    private var remoteStats: [StatsSnapshot] = []
    /// Stamp of this device's most recent runtime mutation (its own pushes
    /// included) — a pulled doc must be strictly newer to apply, or the
    /// phone's own pushed snooze resurrects right after the user resumes.
    private var lastRuntimeMutationAt: Date?
    /// Live Activities may only be *started* in the foreground; tracked from
    /// scenePhase so background reschedules only update/end.
    var isForeground = false

    struct GuidedSheetPayload: Identifiable {
        let id = UUID()
        let payload: ReminderPayload
    }

    var nextFireAt: Date? { upcoming.first?.date }

    var countdownMinutes: Int? {
        guard let nextFireAt else { return nil }
        return max(0, Int(ceil(nextFireAt.timeIntervalSinceNow / 60)))
    }

    var isSnoozing: Bool {
        guard let snoozeUntil else { return false }
        return snoozeUntil > Date()
    }

    var isSkipTodayActive: Bool {
        guard let skipRestOfDayDate else { return false }
        return Calendar.current.isDateInToday(skipRestOfDayDate)
    }

    var statusText: String {
        if !config.enabled { return "Disabled" }
        if isPaused { return "Paused" }
        if isSkipTodayActive { return "Skipped today" }
        if isSnoozing { return "Snoozing" }
        return upcoming.isEmpty ? "Outside work hours" : "Armed"
    }

    private init() {
        config = ConfigStore.load()
        stats = StatsStore.load()
        applyRuntime(RuntimeState.load())
    }

    func start() {
        NotificationManager.configure()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        notificationDelegate.onDone = { [weak self] in self?.acknowledgeDone() }
        notificationDelegate.onSnooze = { [weak self] in self?.snooze(minutes: 10) }
        notificationDelegate.onSkipToday = { [weak self] in self?.skipToday() }
        notificationDelegate.onGuided = { [weak self] payload in
            Task { @MainActor in
                self?.pendingGuidedPayload = GuidedSheetPayload(payload: payload)
            }
        }

        NotificationManager.requestAuthorization { [weak self] granted in
            Task { @MainActor in
                self?.notificationsAuthorized = granted
                self?.rescheduleNotifications()
            }
        }

        if lastReminderAt == nil && lastAcknowledgedAt == nil {
            lastAcknowledgedAt = Date()
        }

        if config.healthLoggingEnabled {
            HealthCredit.requestAuthorizationIfNeeded()
        }

        PhoneWatchBridge.shared.start()
        rescheduleNotifications()
    }

    /// A workout that just ended (swim, lift, Bikram) IS the movement break —
    /// credit it so the app doesn't nag right after training.
    func creditRecentWorkoutIfAny() {
        guard config.healthLoggingEnabled else { return }
        HealthCredit.recentWorkoutEnd { [weak self] end in
            Task { @MainActor in
                guard let self, let end, end <= Date() else { return }
                if (self.lastAcknowledgedAt ?? .distantPast) < end {
                    self.lastAcknowledgedAt = end
                    self.rescheduleNotifications()
                    self.syncRuntimeToCloud()
                }
            }
        }
    }

    // MARK: Actions

    func acknowledgeDone() {
        lastAcknowledgedAt = Date()
        stats.recordDone(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar))
        if config.sitStandModeEnabled {
            deskPhase = (deskPhase == .stand) ? .sit : .stand
            deskPhaseStartedAt = Date()
            persistRuntime()
        }
        rescheduleNotifications()
        syncRuntimeToCloud()
    }

    func snooze(minutes: Int) {
        snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        stats.recordSnooze(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar))
        syncRuntimeToCloud()
    }

    func skipToday() {
        skipRestOfDayDate = Date()
        stats.recordSkip(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar))
        syncRuntimeToCloud()
    }

    func pause() {
        isPaused = true
        syncRuntimeToCloud()
    }

    func resume() {
        suppressReschedule = true
        isPaused = false
        snoozeUntil = nil
        suppressReschedule = false
        rescheduleNotifications()
        // Pushing the cleared snooze (and stamping the mutation) stops this
        // device's own earlier snooze doc from resurrecting it.
        syncRuntimeToCloud()
    }

    // MARK: iCloud

    @discardableResult
    func pushToiCloud() -> Bool {
        CloudSync.push(config: config, profiles: ProfileStore.load())
    }

    func pullFromiCloud() -> CloudSync.PullOutcome {
        // Fresh install: the auto-created defaults file is not user state.
        let mtime = config.hasCompletedOnboarding
            ? (try? FileManager.default.attributesOfItem(atPath: Paths.configFile.path))?[.modificationDate] as? Date
            : nil
        let outcome = CloudSync.pull(localModifiedAt: mtime)
        if case let .success(pulledConfig, pulledProfiles, _) = outcome {
            config = pulledConfig
            if let pulledProfiles { ProfileStore.save(pulledProfiles) }
        }
        return outcome
    }

    private func syncRuntimeToCloud() {
        let stamp = Date()
        lastRuntimeMutationAt = stamp
        guard config.features.iCloudSyncEnabled else { return }
        CloudSync.pushRuntime(CloudSync.RuntimeDoc(
            updatedAt: stamp,
            deviceName: CloudSync.defaultDeviceName(),
            lastReminderAt: lastReminderAt,
            lastAcknowledgedAt: lastAcknowledgedAt,
            snoozeUntil: snoozeUntil,
            skipRestOfDayDate: skipRestOfDayDate,
            effectiveIntervalMinutes: cloudEffectiveIntervalMinutes ?? config.intervalMinutes
        ))
    }

    /// Newest-wins merge via `RuntimeMerge` (clears snooze/skip when remote is newer).
    private func syncRuntimeFromCloud() {
        guard config.features.iCloudSyncEnabled else { return }
        if let doc = CloudSync.pullRuntime() {
            let outcome = RuntimeMerge.apply(
                local: RuntimeMerge.Local(
                    lastReminderAt: lastReminderAt,
                    lastAcknowledgedAt: lastAcknowledgedAt,
                    snoozeUntil: snoozeUntil,
                    skipRestOfDayDate: skipRestOfDayDate,
                    effectiveIntervalMinutes: cloudEffectiveIntervalMinutes,
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
                rescheduleNotifications()
            }
        }
        if stats != lastPushedStats {
            CloudSync.pushStats(stats, deviceId: CloudSync.deviceId())
            lastPushedStats = stats
        }
        remoteStats = CloudSync.pullRemoteStats(excludingDeviceId: CloudSync.deviceId())
    }

    // MARK: Scheduling

    private func schedulerInput(now: Date) -> Scheduler.Input {
        // Prefer Mac-pushed adaptive interval when present so cadence matches.
        let interval = cloudEffectiveIntervalMinutes ?? config.intervalMinutes
        return Scheduler.Input(
            config: config,
            intervalMinutes: interval,
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

    func rescheduleNotifications() {
        guard !suppressReschedule else { return }
        NotificationManager.cancelScheduledQueue()
        let generation = Int(Date().timeIntervalSince1970)
        let generated = Scheduler.upcoming(schedulerInput(now: Date()), count: Self.queueDepth)
        // Exhaustion is judged on the pre-filter count: a quiet-window filter
        // below can shrink a full queue, and a shrunken-but-full queue drains
        // exactly the same way.
        let queueWasFull = generated.count == Self.queueDepth
        // Honor team quiet windows here too — the Mac gates them at fire
        // time, but a pre-scheduled iOS banner would sail through them.
        let chain = generated.filter { next in
            !TeamQuietHours.isInTeamQuiet(config: config.features, at: next.date, calendar: config.scheduleCalendar)
        }
        var promptIndex = 0
        var phase = deskPhase
        for (index, next) in chain.enumerated() {
            let payload = payload(for: next, promptIndex: &promptIndex, deskPhase: &phase)
            NotificationManager.schedule(
                payload,
                at: next.date,
                calendar: config.scheduleCalendar,
                identifier: NotificationManager.queuedIdentifier(generation: generation, slot: "\(index)")
            )
        }
        // With a full queue, exhaustion is possible; make it visible instead
        // of going silently dark when the last slot fires.
        if queueWasFull, let last = chain.last {
            NotificationManager.schedule(
                ReminderPayload(
                    kind: .breakPrompt,
                    title: "Reminders paused",
                    body: "Open Stand Up to keep reminders coming — the scheduled queue ran out.",
                    promptId: Self.sentinelPromptId,
                    guidedSteps: []
                ),
                at: last.date.addingTimeInterval(60),
                calendar: config.scheduleCalendar,
                identifier: NotificationManager.queuedIdentifier(generation: generation, slot: "sentinel")
            )
        }
        upcoming = chain
        PhoneWatchBridge.shared.pushStatus()
        publishWidgetSnapshot()
        updateLiveActivity()
    }

    static let sentinelPromptId = "queue-sentinel"

    private func publishWidgetSnapshot() {
        WidgetSnapshotWriter.write(
            from: config,
            nextFireAt: nextFireAt,
            statusMessage: statusText,
            stats: stats,
            deskPhase: config.sitStandModeEnabled ? deskPhase : nil,
            profileName: "iPhone"
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Live Activity

    private func updateLiveActivity() {
        guard config.features.liveActivityEnabled,
              ActivityAuthorizationInfo().areActivitiesEnabled,
              let next = upcoming.first, next.date > Date() else {
            endLiveActivity()
            return
        }
        let state = BreakActivityAttributes.ContentState(nextFireAt: next.date, title: "Next break")
        let content = ActivityContent(state: state, staleDate: next.date.addingTimeInterval(10 * 60))
        if let activity = Activity<BreakActivityAttributes>.activities.first {
            Task { await activity.update(content) }
        } else if isForeground {
            // ActivityKit only allows *starting* an activity in the
            // foreground; background reschedules (notification actions, BG
            // refresh) wait for the next foreground pass.
            do {
                _ = try Activity.request(attributes: BreakActivityAttributes(profileName: "iPhone"), content: content)
            } catch {
                AppLog.write("Live Activity request failed: \(error.localizedDescription)")
            }
        }
    }

    private func endLiveActivity() {
        for activity in Activity<BreakActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func payload(for next: Scheduler.Next, promptIndex: inout Int, deskPhase: inout DeskPhase) -> ReminderPayload {
        switch next.kind {
        case .lunch:
            return ReminderPayload(
                kind: .lunch,
                title: config.lunch.title,
                body: config.lunch.body,
                promptId: "lunch",
                guidedSteps: ["Stand up", "Step away", "Eat without screens if you can"]
            )
        case .windDown:
            return ReminderContent.windDown(config: config)
        case .sitStand:
            deskPhase = (deskPhase == .stand) ? .sit : .stand
            return ReminderContent.sitStandPayload(phase: deskPhase)
        case .breakPrompt:
            let prompts = config.prompts.isEmpty ? BreakPrompt.defaults : config.prompts
            let prompt = prompts[promptIndex % prompts.count]
            promptIndex += 1
            return ReminderPayload(
                kind: .breakPrompt,
                title: prompt.title,
                body: prompt.body,
                promptId: prompt.id,
                guidedSteps: prompt.guidedSteps
            )
        }
    }

    /// Catch up on reminders that were delivered while the app was not
    /// running, then rebuild the queue from the new anchor.
    func reconcileDelivered() async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
            .filter { $0.request.identifier.hasPrefix(NotificationManager.requestIdPrefix) }
            .sorted { $0.date < $1.date }
        for note in delivered {
            // Dedup key includes the delivery date: queue identifiers embed a
            // generation stamp now, but old installs delivered fixed slot ids
            // whose reuse must not be skipped forever.
            let key = "\(note.request.identifier)@\(note.date.timeIntervalSince1970)"
            guard !countedDeliveredIds.contains(key) else { continue }
            countedDeliveredIds.insert(key)
            let info = note.request.content.userInfo
            let kind = info["kind"] as? String
            let promptId = info["promptId"] as? String
            let date = note.date
            if promptId != Self.sentinelPromptId {
                if lastReminderAt.map({ date > $0 }) ?? true {
                    lastReminderAt = date
                }
                stats.recordShown(on: StatsSnapshot.dayKey(date, calendar: config.scheduleCalendar))
            }
            if kind == ReminderKind.lunch.rawValue {
                lunchFiredDayKey = StatsSnapshot.dayKey(date, calendar: config.scheduleCalendar)
            }
            if kind == ReminderKind.windDown.rawValue {
                windDownFiredDayKey = StatsSnapshot.dayKey(date, calendar: config.scheduleCalendar)
            }
        }
        // Keep Notification Center to the most recent banner and the dedup
        // set bounded (it only guards against double-counting in-session).
        let staleIds = delivered.dropLast().map(\.request.identifier)
        if !staleIds.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: Array(staleIds))
        }
        if countedDeliveredIds.count > 512 { countedDeliveredIds.removeAll() }
        syncRuntimeFromCloud()
        persistRuntime()
        rescheduleNotifications()
    }

    // MARK: Persistence

    private func applyRuntime(_ runtime: RuntimeState) {
        suppressPersist = true
        suppressReschedule = true
        isPaused = runtime.isPaused
        snoozeUntil = runtime.snoozeUntil
        skipRestOfDayDate = runtime.skipRestOfDayDate
        lastReminderAt = runtime.lastReminderAt
        lastAcknowledgedAt = runtime.lastAcknowledgedAt
        deskPhase = runtime.deskPhase
        deskPhaseStartedAt = runtime.deskPhaseStartedAt
        lunchFiredDayKey = runtime.lunchFiredDayKey
        windDownFiredDayKey = runtime.windDownFiredDayKey
        suppressPersist = false
        suppressReschedule = false
    }

    private func persistRuntime() {
        guard !suppressPersist else { return }
        var runtime = RuntimeState()
        runtime.isPaused = isPaused
        runtime.snoozeUntil = snoozeUntil
        runtime.skipRestOfDayDate = skipRestOfDayDate
        runtime.lastReminderAt = lastReminderAt
        runtime.lastAcknowledgedAt = lastAcknowledgedAt
        runtime.deskPhase = deskPhase
        runtime.deskPhaseStartedAt = deskPhaseStartedAt
        runtime.lunchFiredDayKey = lunchFiredDayKey
        runtime.windDownFiredDayKey = windDownFiredDayKey
        RuntimeState.save(runtime)
    }

    func weekStatsText() -> String {
        var week = stats.weekSummary()
        for remote in remoteStats {
            let r = remote.weekSummary()
            week = (week.shown + r.shown, week.done + r.done, week.skipped + r.skipped, week.snoozed + r.snoozed, week.selfLogged + r.selfLogged)
        }
        let suffix = remoteStats.isEmpty ? "" : " (all devices)"
        let breakdown = week.selfLogged > 0 ? " (\(week.selfLogged) self-logged)" : ""
        return "This week: \(week.done) done\(breakdown) · \(week.shown) shown · \(week.snoozed) snoozed · \(week.skipped) skipped\(suffix)"
    }

    // MARK: Background refresh

    /// The pre-scheduled queue covers ~2 days; without a background refill a
    /// user who only glances at banners drains it and the app goes silent.
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshTaskId)
        request.earliestBeginDate = Date().addingTimeInterval(4 * 3600)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            AppLog.write("BG refresh submit failed: \(error.localizedDescription)")
        }
    }

    /// Authorization can be revoked in Settings at any time; re-read it on
    /// every foreground instead of trusting the launch-time answer.
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let ok = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            Task { @MainActor in
                if self.notificationsAuthorized != ok { self.notificationsAuthorized = ok }
            }
        }
    }
}
#endif

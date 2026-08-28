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
///
/// Split across:
/// - `PhoneModel` — published state, start, user actions
/// - `PhoneModel+Cloud` — iCloud config/runtime/stats
/// - `PhoneModel+Scheduling` — notification queue, widgets, live activity
/// - `PhoneModel+Persistence` — local runtime.json
@MainActor
final class PhoneModel: ObservableObject {
    static let shared = PhoneModel()

    /// How many future reminders to keep queued (iOS caps pending local
    /// notifications at 64 per app).
    /// Followers keep a shorter queue — authority owns presence; phone is delivery.
    static let queueDepth = 12
    static let sentinelPromptId = "queue-sentinel"
    static let backgroundRefreshTaskId = AppIdentity.backgroundRefreshTaskId

    @Published var config: AppConfig {
        didSet {
            ConfigStore.save(config, notifyCloud: false)
            rescheduleNotifications()
            guard !suppressCloudSettingsPush, config.features.iCloudSyncEnabled else { return }
            if !oldValue.features.iCloudSyncEnabled {
                reconcileSettingsWithCloud()
            } else {
                _ = pushToiCloud()
            }
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
    /// Published by the Mac (cadence authority) via iCloud runtime.
    @Published var authorityPresence: PresenceState?
    @Published var authorityName: String?
    @Published var authorityNextFireAt: Date?
    /// Stamp of the runtime doc that last supplied authority fields.
    @Published var authorityUpdatedAt: Date?
    @Published var syncHealth: SyncHealth = SyncHealth.load()
    @Published var healthAccessStatus: HealthAccessStatus = .unavailable

    /// Adaptive interval pushed from a Mac peer (iOS has no idle samples).
    var cloudEffectiveIntervalMinutes: Int?

    let notificationDelegate = NotificationDelegate()
    var suppressPersist = false
    var suppressReschedule = false
    var deskPhase: DeskPhase = .sit
    var deskPhaseStartedAt: Date?
    var lunchFiredDayKey: String?
    var windDownFiredDayKey: String?
    var countedDeliveredIds = Set<String>()
    var lastPushedStats: StatsSnapshot?
    var remoteStats: [StatsSnapshot] = []
    /// Stamp of this device's most recent runtime mutation (its own pushes
    /// included) — a pulled doc must be strictly newer to apply, or the
    /// phone's own pushed snooze resurrects right after the user resumes.
    var lastRuntimeMutationAt: Date?
    /// Live Activities may only be *started* in the foreground; tracked from
    /// scenePhase so background reschedules only update/end.
    var isForeground = false
    var suppressCloudSettingsPush = false

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

    var resolvedCadenceRole: CadenceRole {
        CadenceRole.resolved(configRole: config.features.cadenceRole, isMac: false)
    }

    var isFollower: Bool {
        resolvedCadenceRole == .follower
    }

    /// Whether Mac presence/gate should filter the notification queue.
    var honorsAuthority: Bool {
        AuthorityLease.shouldHonorAuthority(
            isFollower: isFollower || config.features.cadenceRole == .automatic,
            authorityUpdatedAt: authorityUpdatedAt
        )
    }

    var authorityLeaseMode: AuthorityLease.Mode {
        AuthorityLease.mode(
            isFollower: isFollower || config.features.cadenceRole == .automatic,
            authorityUpdatedAt: authorityUpdatedAt
        )
    }

    var statusText: String {
        AuthorityLease.followerStatusText(
            configEnabled: config.enabled,
            isPaused: isPaused,
            isSkipToday: isSkipTodayActive,
            isSnoozing: isSnoozing,
            notificationsAuthorized: notificationsAuthorized,
            authorityPresence: authorityPresence,
            authorityName: authorityName,
            authorityUpdatedAt: authorityUpdatedAt,
            upcomingEmpty: upcoming.isEmpty
        )
    }

    var degradationBadge: String? {
        guard isFollower || config.features.cadenceRole == .automatic else { return nil }
        guard config.features.iCloudSyncEnabled else { return nil }
        return AuthorityLease.degradationBadge(
            authorityUpdatedAt: authorityUpdatedAt,
            authorityName: authorityName
        )
    }

    var authorityLeaseLine: String? {
        guard config.features.iCloudSyncEnabled,
              isFollower || config.features.cadenceRole == .automatic else { return nil }
        return SuppressionStatus.leaseLine(
            authorityUpdatedAt: authorityUpdatedAt,
            authorityName: authorityName
        )
    }

    var emptyQueueReason: EmptyQueueReason {
        EmptyQueueReason.classify(
            configEnabled: config.enabled,
            isPaused: isPaused,
            isSkipToday: isSkipTodayActive,
            isSnoozing: isSnoozing,
            notificationsAuthorized: notificationsAuthorized,
            upcomingEmpty: upcoming.isEmpty,
            honorsAuthority: honorsAuthority,
            authorityPresence: authorityPresence
        )
    }

    var emptyQueueLine: String? {
        emptyQueueReason.displayLine
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

        refreshHealthAccessStatus()
        if config.healthLoggingEnabled { requestHealthAccess() }

        PhoneWatchBridge.shared.start()
        reconcileSettingsWithCloud()
        syncRuntimeFromCloud()
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
        if config.healthLoggingEnabled {
            HealthCredit.logMindfulMinutes(config.healthMindfulMinutes)
        }
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

    func dismissSeedBanner() {
        syncHealth.seedBannerDismissed = true
        SyncHealth.save(syncHealth)
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
        refreshHealthAccessStatus()
    }

    func refreshHealthAccessStatus() {
        healthAccessStatus = HealthCredit.authorizationStatus()
    }

    func requestHealthAccess() {
        healthAccessStatus = .notDetermined
        HealthCredit.requestAuthorization { [weak self] status in
            Task { @MainActor in self?.healthAccessStatus = status }
        }
    }

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
}
#endif

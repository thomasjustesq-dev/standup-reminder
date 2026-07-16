#if os(iOS)
import Combine
import Foundation
import UserNotifications

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

    private let notificationDelegate = NotificationDelegate()
    private var suppressPersist = false
    private var suppressReschedule = false
    private var deskPhase: DeskPhase = .sit
    private var deskPhaseStartedAt: Date?
    private var lunchFiredDayKey: String?
    private var windDownFiredDayKey: String?
    private var countedDeliveredIds = Set<String>()

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
        notificationDelegate.onGuided = { _ in }

        NotificationManager.requestAuthorization { [weak self] granted in
            Task { @MainActor in
                self?.notificationsAuthorized = granted
                self?.rescheduleNotifications()
            }
        }

        if lastReminderAt == nil && lastAcknowledgedAt == nil {
            lastAcknowledgedAt = Date()
        }

        PhoneWatchBridge.shared.start()
        rescheduleNotifications()
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
    }

    func snooze(minutes: Int) {
        snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        stats.recordSnooze(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar))
    }

    func skipToday() {
        skipRestOfDayDate = Date()
        stats.recordSkip(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar))
    }

    func pause() { isPaused = true }

    func resume() {
        suppressReschedule = true
        isPaused = false
        snoozeUntil = nil
        suppressReschedule = false
        rescheduleNotifications()
    }

    // MARK: iCloud

    func pushToiCloud() {
        CloudSync.push(config: config, profiles: ProfileStore.load())
    }

    func pullFromiCloud() -> Bool {
        guard let pulled = CloudSync.pull() else { return false }
        config = pulled.0
        ProfileStore.save(pulled.1)
        return true
    }

    // MARK: Scheduling

    private func schedulerInput(now: Date) -> Scheduler.Input {
        Scheduler.Input(
            config: config,
            intervalMinutes: config.intervalMinutes,
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
        let chain = Scheduler.upcoming(schedulerInput(now: Date()), count: Self.queueDepth)
        var promptIndex = 0
        var phase = deskPhase
        for (index, next) in chain.enumerated() {
            let payload = payload(for: next, promptIndex: &promptIndex, deskPhase: &phase)
            NotificationManager.schedule(
                payload,
                at: next.date,
                calendar: config.scheduleCalendar,
                identifier: "\(NotificationManager.queuedIdPrefix)\(index)"
            )
        }
        upcoming = chain
        PhoneWatchBridge.shared.pushStatus()
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
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        for note in delivered where note.request.identifier.hasPrefix(NotificationManager.requestIdPrefix) {
            guard !countedDeliveredIds.contains(note.request.identifier) else { continue }
            countedDeliveredIds.insert(note.request.identifier)
            let kind = note.request.content.userInfo["kind"] as? String
            let date = note.date
            if lastReminderAt.map({ date > $0 }) ?? true {
                lastReminderAt = date
                stats.recordShown(on: StatsSnapshot.dayKey(date, calendar: config.scheduleCalendar))
            }
            if kind == ReminderKind.lunch.rawValue {
                lunchFiredDayKey = StatsSnapshot.dayKey(date, calendar: config.scheduleCalendar)
            }
            if kind == ReminderKind.windDown.rawValue {
                windDownFiredDayKey = StatsSnapshot.dayKey(date, calendar: config.scheduleCalendar)
            }
        }
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
        let week = stats.weekSummary()
        return "This week: \(week.done) done · \(week.shown) shown · \(week.snoozed) snoozed · \(week.skipped) skipped"
    }
}
#endif

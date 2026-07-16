import AppKit
import Combine
import Foundation
import ServiceManagement
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var config: AppConfig {
        didSet { ConfigStore.save(config) }
    }

    @Published var stats: StatsSnapshot {
        didSet { StatsStore.save(stats) }
    }

    @Published var isPaused = false {
        didSet { persistRuntime() }
    }
    @Published var snoozeUntil: Date? {
        didSet { persistRuntime() }
    }
    @Published var skipRestOfDayDate: Date? {
        didSet { persistRuntime() }
    }
    @Published var lastReminderAt: Date? {
        didSet { persistRuntime() }
    }
    @Published var lastAcknowledgedAt: Date? {
        didSet { persistRuntime() }
    }
    @Published var nextFireAt: Date?
    @Published var statusMessage: String = "Starting…"
    @Published var showOnboarding = false
    @Published var activeSince: Date?

    private var timer: Timer?
    private let notificationDelegate = NotificationDelegate()
    private var promptCursor: Int = 0
    private var suppressRuntimePersist = false

    var menuBarSymbolName: String {
        if !config.enabled { return "pause.circle" }
        if isPaused { return "pause.circle.fill" }
        if isSnoozing { return "zzz" }
        if isSkipTodayActive { return "moon.zzz" }
        return "figure.stand"
    }

    var isSnoozing: Bool {
        guard let snoozeUntil else { return false }
        return snoozeUntil > Date()
    }

    var isSkipTodayActive: Bool {
        guard let skipRestOfDayDate else { return false }
        return Calendar.current.isDateInToday(skipRestOfDayDate)
    }

    private init() {
        config = ConfigStore.load()
        stats = StatsStore.load()
        showOnboarding = !config.hasCompletedOnboarding
        applyRuntime(RuntimeState.load())
    }

    private func applyRuntime(_ runtime: RuntimeState) {
        suppressRuntimePersist = true
        isPaused = runtime.isPaused
        snoozeUntil = runtime.snoozeUntil
        skipRestOfDayDate = runtime.skipRestOfDayDate
        lastReminderAt = runtime.lastReminderAt
        lastAcknowledgedAt = runtime.lastAcknowledgedAt
        promptCursor = runtime.promptCursor
        suppressRuntimePersist = false
    }

    private func persistRuntime() {
        guard !suppressRuntimePersist else { return }
        let runtime = RuntimeState(
            isPaused: isPaused,
            snoozeUntil: snoozeUntil,
            skipRestOfDayDate: skipRestOfDayDate,
            lastReminderAt: lastReminderAt,
            lastAcknowledgedAt: lastAcknowledgedAt,
            promptCursor: promptCursor
        )
        RuntimeState.save(runtime)
    }

    func reloadRuntimeFromDisk() {
        applyRuntime(RuntimeState.load())
        refreshNextFire()
    }

    func start() {
        NotificationManager.configure()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        notificationDelegate.onDone = { [weak self] in self?.acknowledgeDone() }
        notificationDelegate.onSnooze = { [weak self] in self?.snooze(minutes: 10) }
        notificationDelegate.onSkipToday = { [weak self] in self?.skipToday() }

        DisplaySleepMonitor.shared.start()
        FocusMonitor.requestAuthorizationIfNeeded()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reloadRuntimeFromDisk()
                self?.tick()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        tick()
        refreshNextFire()
        registerLoginItemIfPossible()
    }

    func completeOnboarding(enableCalendar: Bool, enableFocus: Bool) {
        NotificationManager.requestAuthorization { _ in }
        if enableCalendar {
            CalendarMonitor.requestAccess { granted in
                AppLog.write("Calendar granted: \(granted)")
            }
        }
        if enableFocus {
            FocusMonitor.requestAuthorizationIfNeeded()
        }
        config.hasCompletedOnboarding = true
        showOnboarding = false
        statusMessage = "Reminders armed"
    }

    func setEnabled(_ enabled: Bool) {
        config.enabled = enabled
        if enabled { isPaused = false }
        refreshNextFire()
        statusMessage = enabled ? "Reminders on" : "Reminders off"
    }

    func pause() {
        isPaused = true
        statusMessage = "Paused"
        refreshNextFire()
    }

    func resume() {
        isPaused = false
        snoozeUntil = nil
        statusMessage = "Resumed"
        refreshNextFire()
    }

    func snooze(minutes: Int) {
        snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        stats.recordSnooze(on: StatsSnapshot.dayKey())
        statusMessage = "Snoozed \(minutes)m"
        refreshNextFire()
        AppLog.write("snoozed \(minutes)m")
    }

    func skipToday() {
        skipRestOfDayDate = Date()
        stats.recordSkip(on: StatsSnapshot.dayKey())
        statusMessage = "Skipping rest of today"
        refreshNextFire()
        AppLog.write("skip today")
    }

    func acknowledgeDone() {
        lastAcknowledgedAt = Date()
        stats.recordDone(on: StatsSnapshot.dayKey())
        statusMessage = "Nice — break logged"
        AppLog.write("acknowledged done")
    }

    func testStandUp() { fire(force: true, preferLunch: false) }
    func testLunch() { fire(force: true, preferLunch: true) }

    func tick() {
        updateActivityWindow()
        refreshNextFire()
        guard shouldFireNow(force: false) else { return }
        guard isOnScheduleBoundary() || config.isLunchTime() else { return }
        if let last = lastReminderAt, Date().timeIntervalSince(last) < 90 {
            return
        }
        fire(force: false, preferLunch: config.isLunchTime())
    }

    private func updateActivityWindow() {
        let idle = IdleMonitor.secondsIdle()
        if idle < 60 {
            if activeSince == nil { activeSince = Date().addingTimeInterval(-idle) }
        } else if idle >= TimeInterval(max(1, config.idleSkipMinutes) * 60) {
            activeSince = nil
        }
    }

    private func isOnScheduleBoundary(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let minute = calendar.component(.minute, from: now)
        let interval = max(1, config.intervalMinutes)
        return minute % interval == 0
    }

    func shouldFireNow(force: Bool) -> Bool {
        if force { return true }
        guard config.enabled else {
            statusMessage = "Disabled"
            return false
        }
        guard !isPaused else {
            statusMessage = "Paused"
            return false
        }
        if isSkipTodayActive {
            statusMessage = "Skipped today"
            return false
        }
        if isSnoozing {
            statusMessage = "Snoozing"
            return false
        }
        guard config.isWithinWorkHours() else {
            statusMessage = "Outside work hours"
            return false
        }
        if config.skipWhenDisplayAsleep && DisplaySleepMonitor.shared.isDisplayAsleep {
            statusMessage = "Display asleep"
            return false
        }
        if config.skipWhenLocked && DisplaySleepMonitor.isScreenLocked() {
            statusMessage = "Screen locked"
            return false
        }
        if config.skipWhenFocused && FocusMonitor.isFocused() {
            statusMessage = "Focus mode on"
            return false
        }
        if config.skipWhenInMeeting && CalendarMonitor.isInMeeting() {
            statusMessage = "In a meeting"
            return false
        }
        if IdleMonitor.isIdle(thresholdMinutes: config.idleSkipMinutes) {
            statusMessage = "Idle — skipped"
            return false
        }
        if config.minActiveMinutes > 0, !config.isLunchTime() {
            let activeFor = activeSince.map { Date().timeIntervalSince($0) } ?? 0
            if activeFor < TimeInterval(config.minActiveMinutes * 60) {
                statusMessage = "Warming up (active \(Int(activeFor / 60))m)"
                return false
            }
        }
        statusMessage = "Armed"
        return true
    }

    private func fire(force: Bool, preferLunch: Bool) {
        guard shouldFireNow(force: force) else { return }

        let payload: ReminderPayload
        if preferLunch {
            payload = ReminderPayload(
                kind: .lunch,
                title: config.lunch.title,
                body: config.lunch.body,
                promptId: "lunch"
            )
        } else {
            let prompts = config.prompts.isEmpty ? BreakPrompt.defaults : config.prompts
            let index = promptCursor % prompts.count
            promptCursor += 1
            persistRuntime()
            let prompt = prompts[index]
            payload = ReminderPayload(
                kind: .breakPrompt,
                title: prompt.title,
                body: prompt.body,
                promptId: prompt.id
            )
        }

        NotificationManager.deliver(payload, soundName: config.soundName)
        if let sound = NSSound(named: NSSound.Name(config.soundName)) {
            sound.play()
        }
        lastReminderAt = Date()
        stats.recordShown(on: StatsSnapshot.dayKey())
        statusMessage = "Reminded"
        refreshNextFire()
    }

    func refreshNextFire() {
        nextFireAt = Self.computeNextFire(
            config: config,
            from: Date(),
            paused: isPaused || !config.enabled || isSkipTodayActive,
            snoozeUntil: snoozeUntil
        )
    }

    nonisolated static func computeNextFire(
        config: AppConfig,
        from date: Date,
        paused: Bool,
        snoozeUntil: Date?,
        calendar: Calendar = .current
    ) -> Date? {
        if paused { return nil }
        var cursor = date.addingTimeInterval(60)
        if let snoozeUntil, snoozeUntil > cursor {
            cursor = snoozeUntil
        }

        for _ in 0..<(60 * 24 * 14) {
            if let snoozeUntil, cursor < snoozeUntil {
                cursor = snoozeUntil
            }
            if config.isWithinWorkHours(at: cursor, calendar: calendar) {
                let minute = calendar.component(.minute, from: cursor)
                let onBoundary = minute % max(1, config.intervalMinutes) == 0
                let lunch = config.isLunchTime(at: cursor, calendar: calendar)
                if onBoundary || lunch {
                    var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: cursor)
                    comps.second = 0
                    return calendar.date(from: comps)
                }
            }
            cursor = cursor.addingTimeInterval(60)
        }
        return nil
    }

    private func registerLoginItemIfPossible() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                AppLog.write("Login item registered")
            } catch {
                AppLog.write("Login item not registered: \(error.localizedDescription)")
            }
        }
    }

    func weekStatsText() -> String {
        let w = stats.weekSummary()
        return "This week: \(w.done) done · \(w.shown) shown · \(w.snoozed) snoozed · \(w.skipped) skipped"
    }

    func statusReport() -> String {
        let next: String = {
            guard let nextFireAt else { return "none" }
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: nextFireAt)
        }()
        return """
        enabled: \(config.enabled)
        paused: \(isPaused)
        snoozing: \(isSnoozing)
        skipToday: \(isSkipTodayActive)
        status: \(statusMessage)
        next: \(next)
        \(weekStatsText())
        config: \(Paths.configFile.path)
        """
    }
}

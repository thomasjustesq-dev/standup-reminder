import AppKit
import Combine
import Foundation
import ServiceManagement
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var config: AppConfig {
        didSet {
            ConfigStore.save(config)
            syncActiveProfileConfig()
            publishWidget()
        }
    }

    @Published var stats: StatsSnapshot {
        didSet {
            StatsStore.save(stats)
            publishWidget()
        }
    }

    @Published var profiles: ProfileDocument {
        didSet { ProfileStore.save(profiles) }
    }

    @Published var isPaused = false { didSet { persistRuntime() } }
    @Published var snoozeUntil: Date? { didSet { persistRuntime() } }
    @Published var skipRestOfDayDate: Date? { didSet { persistRuntime() } }
    @Published var lastReminderAt: Date? { didSet { persistRuntime() } }
    @Published var lastAcknowledgedAt: Date? { didSet { persistRuntime() } }
    @Published var nextFireAt: Date?
    @Published var statusMessage: String = "Starting…" { didSet { publishWidget() } }
    @Published var showOnboarding = false
    @Published var activeSince: Date?
    @Published var deskPhase: DeskPhase = .sit { didSet { persistRuntime() } }
    @Published var pendingGuidedPayload: ReminderPayload?
    @Published var showGuidedBreak = false
    @Published var updateInfo: UpdateInfo?
    @Published var effectiveIntervalMinutes: Int = 30

    private var timer: Timer?
    private let notificationDelegate = NotificationDelegate()
    private var promptCursor: Int = 0
    private var suppressRuntimePersist = false
    private var deskPhaseStartedAt: Date?
    private var pendingMeetingCatchUp = false
    private var lastMeetingState = false
    private var windDownFiredDayKey: String?
    private var activitySamples: [Double] = []
    private var frontmostBundleId: String?
    private var frontmostSince: Date?
    private var lastUpdateCheckAt: Date?

    var activeProfileName: String {
        ProfileStore.activeProfile(in: profiles).name
    }

    var menuBarSymbolName: String {
        if !config.enabled { return "pause.circle" }
        if isPaused { return "pause.circle.fill" }
        if isSnoozing { return "zzz" }
        if isSkipTodayActive { return "moon.zzz" }
        if config.sitStandModeEnabled {
            return deskPhase == .stand ? "figure.stand" : "desktopcomputer"
        }
        return "figure.stand"
    }

    var menuBarTitle: String {
        if config.showMenuBarCountdown, let mins = countdownMinutes {
            return "\(mins)m"
        }
        return ""
    }

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

    private init() {
        profiles = ProfileStore.load()
        let active = ProfileStore.activeProfile(in: profiles)
        // Prefer profile config; fall back to legacy config.json once.
        if FileManager.default.fileExists(atPath: Paths.configFile.path),
           profiles.profiles.count <= 2 {
            config = ConfigStore.load()
        } else {
            config = active.config
        }
        stats = StatsStore.load()
        showOnboarding = !config.hasCompletedOnboarding
        effectiveIntervalMinutes = config.intervalMinutes
        applyRuntime(RuntimeState.load())
    }

    private func syncActiveProfileConfig() {
        guard let idx = profiles.profiles.firstIndex(where: { $0.id == profiles.activeProfileId }) else { return }
        guard profiles.profiles[idx].config != config else { return }
        var docs = profiles
        docs.profiles[idx].config = config
        profiles = docs
    }

    func switchProfile(id: String) {
        guard let profile = profiles.profiles.first(where: { $0.id == id }) else { return }
        var docs = profiles
        docs.activeProfileId = id
        profiles = docs
        config = profile.config
        statusMessage = "Profile: \(profile.name)"
        refreshNextFire()
    }

    func applyReminderPack(_ pack: ReminderPack) {
        config = config.applying(pack: pack)
    }

    private func applyRuntime(_ runtime: RuntimeState) {
        suppressRuntimePersist = true
        isPaused = runtime.isPaused
        snoozeUntil = runtime.snoozeUntil
        skipRestOfDayDate = runtime.skipRestOfDayDate
        lastReminderAt = runtime.lastReminderAt
        lastAcknowledgedAt = runtime.lastAcknowledgedAt
        promptCursor = runtime.promptCursor
        deskPhase = runtime.deskPhase
        deskPhaseStartedAt = runtime.deskPhaseStartedAt
        pendingMeetingCatchUp = runtime.pendingMeetingCatchUp
        lastMeetingState = runtime.lastMeetingState
        windDownFiredDayKey = runtime.windDownFiredDayKey
        activitySamples = runtime.activitySamples
        frontmostBundleId = runtime.frontmostBundleId
        frontmostSince = runtime.frontmostSince
        lastUpdateCheckAt = runtime.lastUpdateCheckAt
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
            promptCursor: promptCursor,
            deskPhase: deskPhase,
            deskPhaseStartedAt: deskPhaseStartedAt,
            pendingMeetingCatchUp: pendingMeetingCatchUp,
            lastMeetingState: lastMeetingState,
            windDownFiredDayKey: windDownFiredDayKey,
            activitySamples: activitySamples,
            frontmostBundleId: frontmostBundleId,
            frontmostSince: frontmostSince,
            lastUpdateCheckAt: lastUpdateCheckAt
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
        notificationDelegate.onGuided = { [weak self] payload in self?.openGuidedBreak(payload) }

        DisplaySleepMonitor.shared.start()
        FocusMonitor.requestAuthorizationIfNeeded()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reloadRuntimeFromDisk()
                self?.tick()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        tick()
        refreshNextFire()
        registerLoginItemIfPossible()
        Task { await self.maybeCheckForUpdates(force: false) }
    }

    func completeOnboarding(enableCalendar: Bool, enableFocus: Bool, enableHealth: Bool) {
        NotificationManager.requestAuthorization { _ in }
        if enableCalendar {
            CalendarMonitor.requestAccess { granted in AppLog.write("Calendar granted: \(granted)") }
        }
        if enableFocus { FocusMonitor.requestAuthorizationIfNeeded() }
        if enableHealth {
            config.healthLoggingEnabled = true
            HealthLogger.requestAuthorization { granted in AppLog.write("Health granted: \(granted)") }
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
    }

    func skipToday() {
        skipRestOfDayDate = Date()
        stats.recordSkip(on: StatsSnapshot.dayKey())
        statusMessage = "Skipping rest of today"
        refreshNextFire()
    }

    func acknowledgeDone() {
        lastAcknowledgedAt = Date()
        stats.recordDone(on: StatsSnapshot.dayKey())
        if config.sitStandModeEnabled {
            toggleDeskPhase()
        }
        if config.healthLoggingEnabled {
            HealthLogger.logMindfulMinutes(config.healthMindfulMinutes)
        }
        statusMessage = "Nice — break logged"
        showGuidedBreak = false
    }

    func openGuidedBreak(_ payload: ReminderPayload) {
        pendingGuidedPayload = payload
        showGuidedBreak = true
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openGuidedBreakWindow, object: nil)
    }

    func testStandUp() { fire(force: true, mode: .breakPrompt) }
    func testLunch() { fire(force: true, mode: .lunch) }
    func testWindDown() { fire(force: true, mode: .windDown) }
    func testGuided() {
        let payload = ReminderPayload(
            kind: .breakPrompt,
            title: "Guided Break",
            body: "Follow the short sequence.",
            promptId: "guided-test",
            guidedSteps: ["Stand up", "Shoulder rolls ×10", "Look far away 20s", "Drink water"]
        )
        openGuidedBreak(payload)
    }

    func tick() {
        updateActivityWindow()
        updateFrontmostTracking()
        updateMeetingCatchUpFlag()
        persistRuntime()
        effectiveIntervalMinutes = AdaptiveInterval.resolvedMinutes(config: config, samples: activitySamples)
        refreshNextFire()
        publishWidget()

        if pendingMeetingCatchUp && config.meetingCatchUpEnabled && !CalendarMonitor.isInMeeting() {
            pendingMeetingCatchUp = false
            persistRuntime()
            fire(force: true, mode: .meetingCatchUp)
            return
        }

        if shouldFireWindDown() {
            fire(force: false, mode: .windDown)
            return
        }

        guard shouldFireNow(force: false) else { return }
        guard isOnScheduleBoundary() || config.isLunchTime() || shouldFireSitStand() else { return }
        if let last = lastReminderAt, Date().timeIntervalSince(last) < 90 { return }

        if config.isLunchTime() {
            fire(force: false, mode: .lunch)
        } else if config.sitStandModeEnabled && shouldFireSitStand() {
            fire(force: false, mode: .sitStand)
        } else {
            fire(force: false, mode: .breakPrompt)
        }
    }

    private enum FireMode {
        case lunch, windDown, sitStand, breakPrompt, meetingCatchUp
    }

    private func shouldFireWindDown() -> Bool {
        guard config.windDown.enabled, config.isWindDownTime() else { return false }
        let day = StatsSnapshot.dayKey(calendar: config.scheduleCalendar)
        if windDownFiredDayKey == day { return false }
        return shouldFireNow(force: false) || (!isPaused && config.enabled && !isSkipTodayActive)
    }

    private func shouldFireSitStand() -> Bool {
        guard config.sitStandModeEnabled else { return false }
        let started = deskPhaseStartedAt ?? lastReminderAt ?? Date().addingTimeInterval(-TimeInterval(config.sitStandPhaseMinutes * 60))
        return Date().timeIntervalSince(started) >= TimeInterval(config.sitStandPhaseMinutes * 60)
    }

    private func toggleDeskPhase() {
        deskPhase = (deskPhase == .stand) ? .sit : .stand
        deskPhaseStartedAt = Date()
        persistRuntime()
    }

    private func updateActivityWindow() {
        let idle = IdleMonitor.secondsIdle()
        activitySamples.append(idle)
        if activitySamples.count > 24 { activitySamples.removeFirst(activitySamples.count - 24) }

        if idle < 60 {
            if activeSince == nil { activeSince = Date().addingTimeInterval(-idle) }
        } else if idle >= TimeInterval(max(1, config.idleSkipMinutes) * 60) {
            activeSince = nil
        }
    }

    private func updateFrontmostTracking() {
        let current = DeepWorkMonitor.frontmostBundleId()
        if current != frontmostBundleId {
            frontmostBundleId = current
            frontmostSince = Date()
        }
    }

    private func updateMeetingCatchUpFlag() {
        let inMeeting = CalendarMonitor.isInMeeting()
        if lastMeetingState && !inMeeting && config.meetingCatchUpEnabled {
            if let last = lastReminderAt {
                if Date().timeIntervalSince(last) >= TimeInterval(effectiveIntervalMinutes * 60) {
                    pendingMeetingCatchUp = true
                }
            } else {
                pendingMeetingCatchUp = true
            }
        }
        if inMeeting && config.meetingCatchUpEnabled && isOnScheduleBoundary() {
            pendingMeetingCatchUp = true
        }
        lastMeetingState = inMeeting
    }

    private func isOnScheduleBoundary(now: Date = Date()) -> Bool {
        let minute = config.scheduleCalendar.component(.minute, from: now)
        let interval = max(1, effectiveIntervalMinutes)
        return minute % interval == 0
    }

    func shouldFireNow(force: Bool) -> Bool {
        if force { return true }
        guard config.enabled else { statusMessage = "Disabled"; return false }
        guard !isPaused else { statusMessage = "Paused"; return false }
        if isSkipTodayActive { statusMessage = "Skipped today"; return false }
        if isSnoozing { statusMessage = "Snoozing"; return false }

        if config.skipOnPTO && CalendarMonitor.isOutOfOffice(keywords: config.ptoKeywords, calendar: config.scheduleCalendar) {
            statusMessage = "PTO / OOO"
            return false
        }
        guard config.isWithinWorkHours() || config.isWindDownTime() else {
            statusMessage = "Outside work hours"
            return false
        }
        if config.skipWhenDisplayAsleep && DisplaySleepMonitor.shared.isDisplayAsleep {
            statusMessage = "Display asleep"; return false
        }
        if config.skipWhenLocked && DisplaySleepMonitor.isScreenLocked() {
            statusMessage = "Screen locked"; return false
        }
        if config.skipWhenFocused && FocusMonitor.isFocused() {
            statusMessage = "Focus mode on"; return false
        }
        if config.skipWhenInMeeting && CalendarMonitor.isInMeeting() {
            statusMessage = "In a meeting"; return false
        }
        if DeepWorkMonitor.isDenylisted(bundleId: frontmostBundleId, denylist: config.denylistBundleIds) {
            statusMessage = "Quiet app (denylist)"; return false
        }
        if config.deepWorkEnabled && DeepWorkMonitor.isInDeepWork(
            frontmostBundleId: frontmostBundleId,
            frontmostSince: frontmostSince,
            quietMinutes: config.deepWorkQuietMinutes,
            requireFullscreen: config.deepWorkRequireFullscreen
        ) {
            statusMessage = "Deep work"; return false
        }
        if IdleMonitor.isIdle(thresholdMinutes: config.idleSkipMinutes) {
            statusMessage = "Idle — skipped"; return false
        }
        if config.minActiveMinutes > 0, !config.isLunchTime(), !config.isWindDownTime() {
            let activeFor = activeSince.map { Date().timeIntervalSince($0) } ?? 0
            if activeFor < TimeInterval(config.minActiveMinutes * 60) {
                statusMessage = "Warming up (active \(Int(activeFor / 60))m)"
                return false
            }
        }
        statusMessage = "Armed"
        return true
    }

    private func fire(force: Bool, mode: FireMode) {
        // Wind-down / catch-up can bypass some quiet rules when forced
        if mode != .windDown && mode != .meetingCatchUp {
            guard shouldFireNow(force: force) else { return }
        } else if !force {
            guard config.enabled, !isPaused, !isSkipTodayActive else { return }
        }

        let payload: ReminderPayload
        switch mode {
        case .lunch:
            payload = ReminderPayload(
                kind: .lunch,
                title: config.lunch.title,
                body: config.lunch.body,
                promptId: "lunch",
                guidedSteps: ["Stand up", "Step away from the desk", "Eat without screens if you can"]
            )
        case .windDown:
            payload = ReminderContent.windDown(config: config)
            windDownFiredDayKey = StatsSnapshot.dayKey(calendar: config.scheduleCalendar)
            persistRuntime()
        case .sitStand:
            // Announce the phase we want the user to switch INTO
            let next: DeskPhase = deskPhase == .stand ? .sit : .stand
            payload = ReminderContent.sitStandPayload(phase: next)
        case .meetingCatchUp:
            payload = ReminderContent.meetingCatchUp()
        case .breakPrompt:
            let prompts = config.prompts.isEmpty ? BreakPrompt.defaults : config.prompts
            let index = promptCursor % prompts.count
            promptCursor += 1
            persistRuntime()
            let prompt = prompts[index]
            payload = ReminderPayload(
                kind: .breakPrompt,
                title: prompt.title,
                body: prompt.body,
                promptId: prompt.id,
                guidedSteps: prompt.guidedSteps
            )
        }

        NotificationManager.deliver(payload, soundName: config.soundName)
        if let sound = NSSound(named: NSSound.Name(config.soundName)) { sound.play() }
        lastReminderAt = Date()
        stats.recordShown(on: StatsSnapshot.dayKey())

        if mode == .sitStand {
            deskPhaseStartedAt = Date()
            // Phase flips when user taps Done; still advance timer baseline now
            persistRuntime()
        }

        if config.guidedBreakEnabled && (mode == .breakPrompt || mode == .sitStand || mode == .meetingCatchUp) {
            // Auto-open guided UI optionally — only if user prefers; keep subtle: don't auto-steal focus every time
            // Open only when guidedBreakSeconds > 0 and mode is catch-up or sitStand
            if mode == .meetingCatchUp || mode == .sitStand {
                openGuidedBreak(payload)
            }
        }

        statusMessage = "Reminded"
        refreshNextFire()
        publishWidget()
    }

    func refreshNextFire() {
        effectiveIntervalMinutes = AdaptiveInterval.resolvedMinutes(config: config, samples: activitySamples)
        nextFireAt = Self.computeNextFire(
            config: config,
            intervalMinutes: effectiveIntervalMinutes,
            from: Date(),
            paused: isPaused || !config.enabled || isSkipTodayActive,
            snoozeUntil: snoozeUntil,
            deskPhaseStartedAt: deskPhaseStartedAt,
            sitStandEnabled: config.sitStandModeEnabled
        )
        publishWidget()
    }

    nonisolated static func computeNextFire(
        config: AppConfig,
        intervalMinutes: Int,
        from date: Date,
        paused: Bool,
        snoozeUntil: Date?,
        deskPhaseStartedAt: Date?,
        sitStandEnabled: Bool
    ) -> Date? {
        if paused { return nil }
        let calendar = config.scheduleCalendar
        var cursor = date.addingTimeInterval(60)
        if let snoozeUntil, snoozeUntil > cursor { cursor = snoozeUntil }

        for _ in 0..<(60 * 24 * 14) {
            if let snoozeUntil, cursor < snoozeUntil { cursor = snoozeUntil }

            if config.isWindDownTime(at: cursor) {
                return flooredMinute(cursor, calendar: calendar)
            }
            if sitStandEnabled, let started = deskPhaseStartedAt {
                let due = started.addingTimeInterval(TimeInterval(config.sitStandPhaseMinutes * 60))
                if due >= date && config.isWithinWorkHours(at: due) {
                    // Candidate; still scan for sooner lunch/boundary
                }
            }
            if config.isWithinWorkHours(at: cursor) {
                let minute = calendar.component(.minute, from: cursor)
                let onBoundary = minute % max(1, intervalMinutes) == 0
                if onBoundary || config.isLunchTime(at: cursor) {
                    return flooredMinute(cursor, calendar: calendar)
                }
            }
            cursor = cursor.addingTimeInterval(60)
        }
        return nil
    }

    nonisolated private static func flooredMinute(_ date: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        comps.second = 0
        return calendar.date(from: comps) ?? date
    }

    private func publishWidget() {
        WidgetSnapshotWriter.write(
            from: config,
            nextFireAt: nextFireAt,
            statusMessage: statusMessage,
            stats: stats,
            deskPhase: config.sitStandModeEnabled ? deskPhase : nil,
            profileName: activeProfileName
        )
    }

    private func registerLoginItemIfPossible() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
            } catch {
                AppLog.write("Login item not registered: \(error.localizedDescription)")
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

    func weekStatsText() -> String {
        let w = stats.weekSummary()
        return "This week: \(w.done) done · \(w.shown) shown · \(w.snoozed) snoozed · \(w.skipped) skipped"
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

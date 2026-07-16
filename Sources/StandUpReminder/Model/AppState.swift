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
    @Published var weather: WeatherSnapshot?
    @Published var learnedSuggestion: DaySchedule?
    @Published var showSampleDayTour = false

    private var learnedStore = LearnedScheduleStore.load()
    private var timer: Timer?
    private let notificationDelegate = NotificationDelegate()
    private var promptCursor: Int = 0
    private var suppressRuntimePersist = false
    private var deskPhaseStartedAt: Date?
    private var pendingMeetingCatchUp = false
    private var lastMeetingState = false
    private var windDownFiredDayKey: String?
    private var lunchFiredDayKey: String?
    private var scheduledNext: Scheduler.Next?
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
        let loadedProfiles = ProfileStore.load()
        let active = ProfileStore.activeProfile(in: loadedProfiles)
        profiles = loadedProfiles
        // Prefer profile config; fall back to legacy config.json once.
        if FileManager.default.fileExists(atPath: Paths.configFile.path),
           loadedProfiles.profiles.count <= 2 {
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
        lunchFiredDayKey = runtime.lunchFiredDayKey
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
            lunchFiredDayKey: lunchFiredDayKey,
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
        // First run: establish the cadence anchor so the first break arrives
        // one interval from launch rather than sliding forever.
        if lastReminderAt == nil && lastAcknowledgedAt == nil {
            lastAcknowledgedAt = Date()
        }
        tick()
        refreshNextFire()
        registerLoginItemIfPossible()

        NotificationCenter.default.addObserver(
            forName: .configDidSaveForCloud,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.config.features.iCloudSyncEnabled else { return }
                CloudSync.push(config: self.config, profiles: self.profiles)
            }
        }

        WatchBridge.shared.start(enabled: config.features.watchCompanionEnabled)
        WebcamStillnessMonitor.shared.configure(
            enabled: config.features.webcamStillnessEnabled,
            thresholdMinutes: config.features.webcamStillnessMinutes
        )
        Diagnostics.installExceptionHook(
            enabled: config.features.diagnosticsEnabled,
            endpoint: config.features.diagnosticsEndpoint
        )
        SparkleUpdater.start(
            feedURL: config.features.sparkleFeedURL,
            preferSparkle: config.features.preferSparkleUpdates
        )

        if config.features.showSampleDayTour && !config.hasCompletedOnboarding {
            showSampleDayTour = true
            NotificationCenter.default.post(name: .openSampleDayTour, object: nil)
        }

        Task { await self.maybeCheckForUpdates(force: false) }
        Task { await self.refreshTeamQuietHours() }
        Task { await self.refreshWeather() }
        refreshLearnedSuggestion()
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
        if config.features.showSampleDayTour {
            showSampleDayTour = true
        }
        statusMessage = "Reminders armed"
    }

    func pullFromiCloud() {
        guard let pulled = CloudSync.pull() else {
            statusMessage = "iCloud pull failed / empty"
            return
        }
        config = pulled.0
        profiles = pulled.1
        statusMessage = "Pulled from iCloud"
        refreshNextFire()
    }

    func pushToiCloud() {
        CloudSync.push(config: config, profiles: profiles)
        statusMessage = "Pushed to iCloud"
    }

    func refreshTeamQuietHours() async {
        guard config.features.teamQuiet.enabled,
              !config.features.teamQuiet.feedURL.isEmpty else { return }
        let windows = await TeamQuietHours.fetch(from: config.features.teamQuiet.feedURL)
        if !windows.isEmpty {
            var c = config
            c.features.teamQuiet.windows = windows
            c.features.teamQuiet.lastFetchedAt = Date()
            config = c
        }
    }

    func refreshWeather() async {
        guard config.features.weatherBreaksEnabled else {
            weather = nil
            return
        }
        let coords = WeatherService.approxCoordinates(for: config.scheduleTimeZone)
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
        WatchBridge.shared.sendStatus(
            status: "done",
            nextFire: nextFireAt,
            countdownMinutes: countdownMinutes
        )
        statusMessage = "Nice — break logged"
        showGuidedBreak = false
        if config.features.diagnosticsEnabled {
            Task {
                await Diagnostics.report(
                    event: "break_done",
                    endpoint: config.features.diagnosticsEndpoint
                )
            }
        }
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
        refreshNextFire()
        updateMeetingCatchUpFlag()
        persistRuntime()
        publishWidget()

        if pendingMeetingCatchUp && config.meetingCatchUpEnabled && !CalendarMonitor.isInMeeting() {
            pendingMeetingCatchUp = false
            persistRuntime()
            fire(force: true, mode: .meetingCatchUp)
            return
        }

        if let last = lastReminderAt, Date().timeIntervalSince(last) < 90 { return }

        if config.features.webcamStillnessEnabled,
           WebcamStillnessMonitor.shared.isStillTooLong,
           lastReminderAt.map({ Date().timeIntervalSince($0) >= 10 * 60 }) ?? true,
           shouldFireNow(force: false) {
            fire(force: true, mode: .breakPrompt)
            return
        }

        guard let next = scheduledNext, Date() >= next.date else {
            _ = shouldFireNow(force: false) // keeps the menu status message current
            return
        }

        switch next.kind {
        case .windDown: fire(force: false, mode: .windDown)
        case .lunch: fire(force: false, mode: .lunch)
        case .sitStand: fire(force: false, mode: .sitStand)
        case .breakPrompt: fire(force: false, mode: .breakPrompt)
        }
    }

    private enum FireMode {
        case lunch, windDown, sitStand, breakPrompt, meetingCatchUp
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
            if config.features.learnedScheduleEnabled {
                learnedStore.recordActivity(at: Date(), calendar: config.scheduleCalendar)
                LearnedScheduleStore.save(learnedStore)
            }
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
        // A break that comes due while in a meeting converts into a catch-up.
        if inMeeting, config.meetingCatchUpEnabled,
           let next = scheduledNext,
           next.kind == .breakPrompt || next.kind == .sitStand,
           Date() >= next.date {
            pendingMeetingCatchUp = true
        }
        lastMeetingState = inMeeting
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
        if TeamQuietHours.isInTeamQuiet(config: config.features, calendar: config.scheduleCalendar) {
            statusMessage = "Team quiet hours"
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
            lunchFiredDayKey = StatsSnapshot.dayKey(calendar: config.scheduleCalendar)
            persistRuntime()
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
            var body = prompt.body
            if config.features.weatherBreaksEnabled, let weather, weather.isNiceForWalk,
               prompt.id == "stand" || prompt.id == "walk" || prompt.id == "water" {
                body += " \(weather.summary)"
            }
            payload = ReminderPayload(
                kind: .breakPrompt,
                title: prompt.title,
                body: body,
                promptId: prompt.id,
                guidedSteps: prompt.guidedSteps
            )
        }

        var delivered = payload
        if config.features.weatherBreaksEnabled, let weather, weather.isNiceForWalk, mode == .meetingCatchUp {
            delivered = ReminderPayload(
                kind: payload.kind,
                title: payload.title,
                body: payload.body + " " + weather.summary,
                promptId: payload.promptId,
                guidedSteps: payload.guidedSteps
            )
        }

        NotificationManager.deliver(delivered, soundName: config.soundName)
        if let sound = NSSound(named: NSSound.Name(config.soundName)) { sound.play() }
        if config.features.voiceAnnouncementsEnabled {
            VoiceAnnouncer.speak(
                "\(delivered.title). \(delivered.body)",
                headphonesOnly: config.features.speakOnlyWithHeadphones
            )
        }
        if config.features.watchCompanionEnabled {
            WatchBridge.shared.notifyReminder(title: delivered.title, body: delivered.body)
            WatchBridge.shared.sendStatus(
                status: statusMessage,
                nextFire: nextFireAt,
                countdownMinutes: countdownMinutes
            )
        }
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
        scheduledNext = Scheduler.next(Scheduler.Input(
            config: config,
            intervalMinutes: effectiveIntervalMinutes,
            now: Date(),
            paused: isPaused || !config.enabled || isSkipTodayActive,
            snoozeUntil: snoozeUntil,
            lastReminderAt: lastReminderAt,
            lastAcknowledgedAt: lastAcknowledgedAt,
            deskPhaseStartedAt: deskPhaseStartedAt,
            lunchFiredDayKey: lunchFiredDayKey,
            windDownFiredDayKey: windDownFiredDayKey
        ))
        nextFireAt = scheduledNext?.date
        publishWidget()
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

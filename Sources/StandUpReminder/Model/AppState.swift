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
    /// nil = not yet determined/unknown; false = user denied notifications.
    @Published var notificationsAuthorized: Bool?

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
    private var lastWeatherRefreshAt: Date?
    private var lastSavedRuntime: RuntimeState?
    private var knownRuntimeMTime: Date?
    private var knownConfigMTime: Date?
    private var knownProfilesMTime: Date?
    private var lastObservedIdleSeconds: Double = 0
    private var lastSamplesPersistAt: Date?
    private var lastAdaptiveComputedAt: Date?
    private var lastAdaptiveAnchor: Date?

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
        // Two stores can describe the current config: the active profile and
        // config.json (which the CLI and hand edits write). Whichever was
        // written most recently wins — a profile-count heuristic here once
        // meant config.json was silently ignored as soon as a third profile
        // existed.
        let configMTime = Self.fileMTime(Paths.configFile)
        let profilesMTime = Self.fileMTime(ProfileStore.fileURL)
        if let configMTime, FileManager.default.fileExists(atPath: Paths.configFile.path),
           configMTime >= (profilesMTime ?? .distantPast) {
            config = ConfigStore.load()
        } else {
            config = active.config.validated()
        }
        stats = StatsStore.load()
        showOnboarding = !config.hasCompletedOnboarding
        effectiveIntervalMinutes = config.intervalMinutes
        applyRuntime(RuntimeState.load())
        knownRuntimeMTime = Self.fileMTime(RuntimeState.fileURL)
        knownConfigMTime = Self.fileMTime(Paths.configFile)
        knownProfilesMTime = Self.fileMTime(ProfileStore.fileURL)
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
        lastSavedRuntime = runtime
    }

    private static func fileMTime(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// Pick up state written by another process (the CLI runs as a separate
    /// instance of this binary and mutates the same JSON stores on disk).
    /// Reload before persisting so a CLI write is not clobbered by a tick.
    func reloadExternalChangesIfNeeded() {
        if let mtime = Self.fileMTime(RuntimeState.fileURL), mtime != knownRuntimeMTime {
            knownRuntimeMTime = mtime
            applyRuntime(RuntimeState.load())
        }
        if let mtime = Self.fileMTime(Paths.configFile), mtime != knownConfigMTime {
            knownConfigMTime = mtime
            let loaded = ConfigStore.load()
            if loaded != config { config = loaded }
        }
        if let mtime = Self.fileMTime(ProfileStore.fileURL), mtime != knownProfilesMTime {
            knownProfilesMTime = mtime
            let loaded = ProfileStore.load()
            if loaded != profiles { profiles = loaded }
        }
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
        // activitySamples change every tick; comparing them made this a
        // guaranteed 15-second disk write. Persist when meaningful state
        // changed, and batch the samples on a 5-minute cadence.
        var comparable = runtime
        comparable.activitySamples = []
        var lastComparable = lastSavedRuntime
        lastComparable?.activitySamples = []
        let samplesDue = lastSamplesPersistAt.map { Date().timeIntervalSince($0) >= 5 * 60 } ?? true
        guard comparable != lastComparable || samplesDue else { return }
        RuntimeState.save(runtime)
        lastSavedRuntime = runtime
        lastSamplesPersistAt = Date()
        knownRuntimeMTime = Self.fileMTime(RuntimeState.fileURL)
    }

    func start() {
        NotificationManager.configure()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        // Ask once if never asked (the onboarding "Not now" path used to leave
        // authorization permanently undetermined), then track the real status
        // so denied notifications are surfaced instead of silently swallowed.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                NotificationManager.requestAuthorization { _ in
                    Task { @MainActor in AppState.shared.refreshNotificationAuthorization() }
                }
            } else {
                Task { @MainActor in AppState.shared.refreshNotificationAuthorization() }
            }
        }
        notificationDelegate.onDone = { [weak self] in self?.acknowledgeDone() }
        notificationDelegate.onSnooze = { [weak self] in self?.snooze(minutes: 10) }
        notificationDelegate.onSkipToday = { [weak self] in self?.skipToday() }
        notificationDelegate.onGuided = { [weak self] payload in self?.openGuidedBreak(payload) }

        DisplaySleepMonitor.shared.start()
        FocusMonitor.requestAuthorizationIfNeeded()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: .standUpExternalStateChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppState.shared.reloadExternalChangesIfNeeded()
                AppState.shared.refreshNextFire()
            }
        }
        // Test commands from the CLI run in-app: a second CLI process could
        // deliver a banner, but its notification actions and windows would
        // die with the process.
        DistributedNotificationCenter.default().addObserver(
            forName: .standUpRemoteCommand,
            object: nil,
            queue: .main
        ) { note in
            let command = note.object as? String
            Task { @MainActor in
                AppState.shared.handleRemoteCommand(command)
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
        // The menu-style MenuBarExtra can't open windows while its menu is
        // closed, so window presentation on launch goes through the AppDelegate.
        if showOnboarding {
            NotificationCenter.default.post(name: .openOnboardingWindow, object: nil)
        }

        Task { await self.maybeCheckForUpdates(force: false) }
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

    @discardableResult
    func pullFromiCloud() -> CloudSync.PullOutcome {
        let outcome = CloudSync.pull(localModifiedAt: Self.fileMTime(Paths.configFile))
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

    /// Weather hourly, team quiet feed every 6h, on the tick cadence.
    private func refreshPeriodicSourcesIfDue() {
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
        if let fix = LocationProvider.shared.lastCoordinate {
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
        stats.recordSnooze(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar))
        statusMessage = "Snoozed \(minutes)m"
        refreshNextFire()
    }

    func skipToday() {
        skipRestOfDayDate = Date()
        stats.recordSkip(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar))
        statusMessage = "Skipping rest of today"
        refreshNextFire()
    }

    func acknowledgeDone() {
        lastAcknowledgedAt = Date()
        stats.recordDone(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar))
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

    func testStandUp() { fire(mode: .breakPrompt, gate: .none) }
    func testLunch() { fire(mode: .lunch, gate: .none) }
    func testWindDown() { fire(mode: .windDown, gate: .none) }

    func handleRemoteCommand(_ command: String?) {
        switch command {
        case "test": testStandUp()
        case "test-lunch": testLunch()
        case "test-wind-down": testWindDown()
        case "test-guided": testGuided()
        default: break
        }
    }
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
        reloadExternalChangesIfNeeded()
        refreshPeriodicSourcesIfDue()
        refreshNotificationAuthorization()
        updateActivityWindow()
        updateFrontmostTracking()
        refreshNextFire()
        updateMeetingCatchUpFlag()
        persistRuntime()
        publishWidget()

        if pendingMeetingCatchUp && config.meetingCatchUpEnabled && !CalendarMonitor.isInMeeting() {
            // Only clear the flag once the reminder can actually land — a
            // locked screen, sleeping display, or empty desk defers the
            // catch-up to the next tick instead of chiming into the void.
            if environmentAllowsInterruption() {
                pendingMeetingCatchUp = false
                persistRuntime()
                fire(mode: .meetingCatchUp, gate: .environment)
                return
            }
        }

        if let last = lastReminderAt, Date().timeIntervalSince(last) < 90 { return }

        if config.features.webcamStillnessEnabled,
           WebcamStillnessMonitor.shared.isStillTooLong,
           lastReminderAt.map({ Date().timeIntervalSince($0) >= 10 * 60 }) ?? true {
            fire(mode: .breakPrompt, gate: .full)
            return
        }

        guard let next = scheduledNext, Date() >= next.date else {
            _ = shouldFireNow(force: false) // keeps the menu status message current
            return
        }

        // A cadence break or desk-phase flip landing right after a lunch,
        // wind-down, or catch-up would double-notify; defer the collision
        // loser instead of firing it 90 seconds later.
        if next.kind == .breakPrompt || next.kind == .sitStand,
           let last = lastReminderAt, Date().timeIntervalSince(last) < 10 * 60 {
            return
        }

        switch next.kind {
        case .windDown: fire(mode: .windDown, gate: .environment)
        case .lunch: fire(mode: .lunch, gate: .full)
        case .sitStand: fire(mode: .sitStand, gate: .full)
        case .breakPrompt: fire(mode: .breakPrompt, gate: .full)
        }
    }

    func refreshNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authorized: Bool?
            switch settings.authorizationStatus {
            case .authorized, .provisional: authorized = true
            case .denied: authorized = false
            default: authorized = nil
            }
            Task { @MainActor in
                if AppState.shared.notificationsAuthorized != authorized {
                    AppState.shared.notificationsAuthorized = authorized
                }
            }
        }
    }

    private enum FireMode {
        case lunch, windDown, sitStand, breakPrompt, meetingCatchUp
    }

    private enum FireGate {
        /// Every quiet rule applies (shouldFireNow).
        case full
        /// Wind-down and meeting catch-up bypass focus/meeting/deep-work
        /// suppression but must never interrupt a locked screen, sleeping
        /// display, off-hours, or an empty desk.
        case environment
        /// Explicit user test commands.
        case none
    }

    private func environmentAllowsInterruption() -> Bool {
        guard config.enabled, !isPaused, !isSkipTodayActive else { return false }
        guard config.isWithinWorkHours() || config.isWindDownTime() else { return false }
        if config.skipWhenDisplayAsleep && DisplaySleepMonitor.shared.isDisplayAsleep { return false }
        if config.skipWhenLocked && DisplaySleepMonitor.isScreenLocked() { return false }
        if IdleMonitor.isIdle(thresholdMinutes: config.idleSkipMinutes) { return false }
        return true
    }

    private func toggleDeskPhase() {
        deskPhase = (deskPhase == .stand) ? .sit : .stand
        deskPhaseStartedAt = Date()
        persistRuntime()
    }

    private func updateActivityWindow() {
        let idle = IdleMonitor.secondsIdle()
        defer { lastObservedIdleSeconds = idle }
        activitySamples.append(idle)
        if activitySamples.count > 24 { activitySamples.removeFirst(activitySamples.count - 24) }

        if idle < 60 {
            // Returning from an absence at least as long as the idle-skip
            // threshold means a real break just happened — credit it, so the
            // stale overdue reminder doesn't fire at someone who just walked
            // back from the thing it would have asked for.
            let awayThreshold = TimeInterval(max(1, config.idleSkipMinutes) * 60)
            if lastObservedIdleSeconds >= awayThreshold {
                lastAcknowledgedAt = Date()
                statusMessage = "Away \(Int(lastObservedIdleSeconds / 60))m — break credited"
                refreshNextFire()
            }
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
        // Deep-work suppression is bounded: once you're two full intervals
        // past the last break, the longest sitting stretch of the day is
        // exactly when a reminder matters most — stop suppressing.
        let overdueLimit = TimeInterval(max(1, effectiveIntervalMinutes) * 60) * 2
        let sinceAnchor = Scheduler.cadenceAnchor(
            lastReminderAt: lastReminderAt,
            lastAcknowledgedAt: lastAcknowledgedAt
        ).map { Date().timeIntervalSince($0) } ?? 0
        if sinceAnchor < overdueLimit,
           config.deepWorkEnabled && DeepWorkMonitor.isInDeepWork(
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

    private func fire(mode: FireMode, gate: FireGate) {
        switch gate {
        case .full:
            guard shouldFireNow(force: false) else { return }
        case .environment:
            guard environmentAllowsInterruption() else { return }
        case .none:
            break
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

        NotificationManager.deliver(delivered)
        // Focus/DND suppresses the banner system-side; don't be the app that
        // stays silent on screen but chimes and talks over a hearing.
        let bannerSuppressed = FocusMonitor.isFocused()
        if !bannerSuppressed {
            if let sound = NSSound(named: NSSound.Name(config.soundName)) {
                sound.play()
            } else {
                NSSound.beep()
            }
            if config.features.voiceAnnouncementsEnabled {
                VoiceAnnouncer.speak(
                    "\(delivered.title). \(delivered.body)",
                    headphonesOnly: config.features.speakOnlyWithHeadphones
                )
            }
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
        if notificationsAuthorized == false {
            AppLog.write("Reminder fired but notifications are denied — no banner was shown")
        } else {
            stats.recordShown(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar))
        }

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

        statusMessage = notificationsAuthorized == false
            ? "Notifications blocked — allow in System Settings"
            : "Reminded"
        refreshNextFire()
        publishWidget()
    }

    func refreshNextFire() {
        // Recompute the adaptive interval when the cadence anchor moves (a
        // break happened) or every few minutes — recomputing on every 15 s
        // tick let the six-minute activity window drag the next-break time
        // around by tens of minutes.
        let anchor = Scheduler.cadenceAnchor(lastReminderAt: lastReminderAt, lastAcknowledgedAt: lastAcknowledgedAt)
        let recomputeDue = lastAdaptiveComputedAt.map { Date().timeIntervalSince($0) >= 5 * 60 } ?? true
        if recomputeDue || anchor != lastAdaptiveAnchor {
            effectiveIntervalMinutes = AdaptiveInterval.resolvedMinutes(config: config, samples: activitySamples)
            lastAdaptiveComputedAt = Date()
            lastAdaptiveAnchor = anchor
        }
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

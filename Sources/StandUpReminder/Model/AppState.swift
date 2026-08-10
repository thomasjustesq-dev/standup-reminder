import AppKit
import Combine
import Foundation
import ServiceManagement
import UserNotifications

/// Core state, persistence, and startup wiring.
///
/// AppState is split across files by responsibility (same module, so members
/// used across those files are internal rather than private):
///   AppState.swift            — state, init, persistence, start()
///   AppState+Tick.swift       — 15-second tick engine, fire gates, delivery
///   AppState+Commands.swift   — user/CLI actions (pause, snooze, done, tests)
///   AppState+Sync.swift       — iCloud, weather, team quiet, learned, updates
///   AppState+Reporting.swift  — widget snapshot, status text, import/export
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
    /// Resolved presence (one state). Updated every tick.
    @Published var presence: PresenceState = .atDesk
    @Published var adaptiveSuggestion: AdaptiveSuggestion?
    @Published var showDayTimeline = false

    // MARK: Stored state shared with the extension files (internal by design)

    var learnedStore = LearnedScheduleStore.load()
    var promptCursor: Int = 0
    var deskPhaseStartedAt: Date?
    var pendingMeetingCatchUp = false
    var lastMeetingState = false
    var windDownFiredDayKey: String?
    var lunchFiredDayKey: String?
    var scheduledNext: Scheduler.Next?
    var activitySamples: [Double] = []
    var frontmostBundleId: String?
    var frontmostSince: Date?
    var lastUpdateCheckAt: Date?
    var lastWeatherRefreshAt: Date?
    var lastObservedIdleSeconds: Double = 0
    var lastAdaptiveComputedAt: Date?
    var lastAdaptiveAnchor: Date?
    var lastRuntimeSyncAt: Date?
    var lastPushedStats: StatsSnapshot?
    var remoteStats: [StatsSnapshot] = []
    /// Stamp of this device's most recent runtime mutation (including its own
    /// pushes). A pulled doc must be strictly newer to apply — otherwise the
    /// device's own pushed snooze resurrects right after the user cancels it.
    var lastRuntimeMutationAt: Date?
    var pendingMeetingCatchUpSetAt: Date?
    /// Set when a banner is actually shown and cleared when the user logs the
    /// break. A Done with no outstanding shown banner is a self-logged break.
    var shownAwaitingAck = false
    /// Day key when auto meeting-heavy pack was last applied (once per day max).
    var autoPackAppliedDayKey: String?
    var syncHealth = SyncHealth.load()
    var blockStats = BlockStats.load()
    var lastScheduleRulePack: ReminderPack?
    var lastStandCreditAt: Date?
    var evidenceStats = EvidenceStats.load()
    var remoteAuthorityName: String?
    var remoteAuthorityPresence: String?

    #if os(macOS)
    var resolvedCadenceRole: CadenceRole {
        CadenceRole.resolved(configRole: config.features.cadenceRole, isMac: true)
    }
    #else
    var resolvedCadenceRole: CadenceRole {
        CadenceRole.resolved(configRole: config.features.cadenceRole, isMac: false)
    }
    #endif

    var isCadenceAuthority: Bool { resolvedCadenceRole == .authority }

    // MARK: Truly private state (used only in this file)

    private var timer: Timer?
    private let notificationDelegate = NotificationDelegate()
    private var suppressRuntimePersist = false
    private var lastSavedRuntime: RuntimeState?
    private var knownRuntimeMTime: Date?
    private var knownConfigMTime: Date?
    private var knownProfilesMTime: Date?
    private var lastSamplesPersistAt: Date?

    var activeProfileName: String {
        ProfileStore.activeProfile(in: profiles).name
    }

    var menuBarSymbolName: String {
        presence.symbolName
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
        pendingMeetingCatchUpSetAt = runtime.pendingMeetingCatchUpSetAt
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

    static func fileMTime(_ url: URL) -> Date? {
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

    func persistRuntime() {
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
            pendingMeetingCatchUpSetAt: pendingMeetingCatchUpSetAt,
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
        notificationDelegate.onGuided = { [weak self] payload in
            self?.openGuidedBreak(payload, userInitiated: true)
        }

        DisplaySleepMonitor.shared.start()
        FocusMonitor.requestAuthorizationIfNeeded()

        timer?.invalidate()
        let tickTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        // A menu bar app that runs all day has no business pinning a repeating
        // timer to exact deadlines — a tolerance lets macOS coalesce wakeups
        // with other work, which is real battery life on a laptop.
        tickTimer.tolerance = 5
        timer = tickTimer
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

    private func registerLoginItemIfPossible() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
            } catch {
                AppLog.write("Login item not registered: \(error.localizedDescription)")
            }
        }
    }
}

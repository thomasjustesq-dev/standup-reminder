import AppKit
import Foundation

/// User- and CLI-initiated actions: pause/resume/snooze/skip, break logging,
/// guided breaks, profiles, packs, and the in-app test commands.
@MainActor
extension AppState {
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
        syncRuntimeToCloud()
    }

    func resume() {
        isPaused = false
        snoozeUntil = nil
        statusMessage = "Resumed"
        refreshNextFire()
        // Pushing the cleared snooze (and stamping the mutation) is what
        // stops the device's own earlier snooze doc from resurrecting it.
        syncRuntimeToCloud()
    }

    func snooze(minutes: Int) {
        snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        stats.recordSnooze(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar))
        statusMessage = "Snoozed \(minutes)m"
        refreshNextFire()
        syncRuntimeToCloud()
    }

    func skipToday() {
        skipRestOfDayDate = Date()
        stats.recordSkip(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar))
        statusMessage = "Skipping rest of today"
        refreshNextFire()
        syncRuntimeToCloud()
    }

    func acknowledgeDone() {
        lastAcknowledgedAt = Date()
        // A Done that answers a banner we actually showed is a normal break;
        // anything else (guided window opened from the menu, test commands, a
        // second tap) is self-logged — the distinction keeps "done > shown"
        // weeks explainable in the weekly stats.
        let selfLogged = !shownAwaitingAck
        shownAwaitingAck = false
        stats.recordDone(on: StatsSnapshot.dayKey(calendar: config.scheduleCalendar), selfLogged: selfLogged)
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
        syncRuntimeToCloud()
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
}

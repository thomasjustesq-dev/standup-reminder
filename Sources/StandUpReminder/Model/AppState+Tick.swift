import AppKit
import Foundation

/// The 15-second tick engine: decides whether a reminder fires now, applies
/// the quiet-rule gates, and delivers it. State lives on AppState (core file).
@MainActor
extension AppState {
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
            // A catch-up that couldn't land for a couple of intervals is
            // stale (locked screen into the evening → don't fire yesterday's
            // catch-up tomorrow morning).
            let maxAge = max(TimeInterval(effectiveIntervalMinutes * 60) * 2, 30 * 60)
            if let setAt = pendingMeetingCatchUpSetAt, Date().timeIntervalSince(setAt) > maxAge {
                pendingMeetingCatchUp = false
                pendingMeetingCatchUpSetAt = nil
                persistRuntime()
            } else if environmentAllowsInterruption() {
                // Only clear the flag once the reminder can actually land — a
                // locked screen, sleeping display, or empty desk defers the
                // catch-up to the next tick instead of chiming into the void.
                pendingMeetingCatchUp = false
                pendingMeetingCatchUpSetAt = nil
                persistRuntime()
                fire(mode: .meetingCatchUp, gate: .environment)
                return
            }
        }

        if let last = lastReminderAt, Date().timeIntervalSince(last) < 90 { return }

        // Only claim the tick when the fire can actually pass its gates —
        // returning after a declined fire would starve the scheduled
        // wind-down below until its grace window expired for the day.
        if config.features.webcamStillnessEnabled,
           WebcamStillnessMonitor.shared.isStillTooLong,
           lastReminderAt.map({ Date().timeIntervalSince($0) >= 10 * 60 }) ?? true,
           shouldFireNow(force: false) {
            fire(mode: .breakPrompt, gate: .full)
            return
        }

        guard let next = scheduledNext, Date() >= next.date else {
            _ = shouldFireNow(force: false) // keeps the menu status message current
            return
        }

        // A cadence break or desk-phase flip landing right after a lunch,
        // wind-down, or catch-up would double-notify; defer the collision
        // loser instead of firing it 90 seconds later. Capped at the
        // effective interval so a deliberately short cadence isn't clamped.
        let collisionDefer = min(10 * 60, TimeInterval(max(1, effectiveIntervalMinutes) * 60))
        if next.kind == .breakPrompt || next.kind == .sitStand,
           let last = lastReminderAt, Date().timeIntervalSince(last) < collisionDefer {
            return
        }

        switch next.kind {
        case .windDown: fire(mode: .windDown, gate: .environment)
        case .lunch: fire(mode: .lunch, gate: .full)
        case .sitStand: fire(mode: .sitStand, gate: .full)
        case .breakPrompt: fire(mode: .breakPrompt, gate: .full)
        }
    }

    enum FireMode {
        case lunch, windDown, sitStand, breakPrompt, meetingCatchUp
    }

    enum FireGate {
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

    func toggleDeskPhase() {
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
                syncRuntimeToCloud()
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
        let wasPending = pendingMeetingCatchUp
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
        if pendingMeetingCatchUp && !wasPending {
            pendingMeetingCatchUpSetAt = Date()
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

    func fire(mode: FireMode, gate: FireGate) {
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
            shownAwaitingAck = true
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
        syncRuntimeToCloud()
    }

    func refreshNextFire() {
        // Recompute the adaptive interval when the cadence anchor moves (a
        // break happened) or every few minutes — recomputing on every 15 s
        // tick let the six-minute activity window drag the next-break time
        // around by tens of minutes.
        let anchor = Scheduler.cadenceAnchor(lastReminderAt: lastReminderAt, lastAcknowledgedAt: lastAcknowledgedAt)
        let recomputeDue = lastAdaptiveComputedAt.map { Date().timeIntervalSince($0) >= 5 * 60 } ?? true
        if recomputeDue || anchor != lastAdaptiveAnchor {
            var minutes = AdaptiveInterval.resolvedMinutes(config: config, samples: activitySamples)
            if FightingShapeMonitor.shared.lowRecovery {
                minutes = max(config.adaptiveMinMinutes, Int(Double(minutes) * 0.8))
            }
            effectiveIntervalMinutes = minutes
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
}

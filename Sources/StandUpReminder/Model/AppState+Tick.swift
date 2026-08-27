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

        if pendingMeetingCatchUp && config.meetingCatchUpEnabled
            && !CalendarMonitor.isInMeeting(titleDenylist: config.features.calendarTitleDenylist) {
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
        FireGateEvaluator.environmentAllows(fireGateContext())
    }

    private func fireGateContext() -> FireGateContext {
        let overdueLimit = TimeInterval(max(1, effectiveIntervalMinutes) * 60) * 2
        let sinceAnchor = Scheduler.cadenceAnchor(
            lastReminderAt: lastReminderAt,
            lastAcknowledgedAt: lastAcknowledgedAt
        ).map { Date().timeIntervalSince($0) } ?? 0
        let activeFor = activeSince.map { Date().timeIntervalSince($0) } ?? 0
        return FireGateContext(
            enabled: config.enabled,
            paused: isPaused,
            skipToday: isSkipTodayActive,
            snoozing: isSnoozing,
            onPTO: config.skipOnPTO && CalendarMonitor.isOutOfOffice(
                keywords: config.ptoKeywords, calendar: config.scheduleCalendar
            ),
            teamQuiet: TeamQuietHours.isInTeamQuiet(config: config.features, calendar: config.scheduleCalendar),
            withinWorkHoursOrWindDown: config.isWithinWorkHours() || config.isWindDownTime(),
            displayAsleep: DisplaySleepMonitor.shared.isDisplayAsleep,
            skipWhenDisplayAsleep: config.skipWhenDisplayAsleep,
            screenLocked: DisplaySleepMonitor.isScreenLocked(),
            skipWhenLocked: config.skipWhenLocked,
            focused: FocusMonitor.isFocused(),
            skipWhenFocused: config.skipWhenFocused,
            inMeeting: CalendarMonitor.isInMeeting(titleDenylist: config.features.calendarTitleDenylist),
            skipWhenInMeeting: config.skipWhenInMeeting,
            denylisted: DeepWorkMonitor.isDenylisted(
                bundleId: frontmostBundleId, denylist: config.denylistBundleIds
            ),
            deepWork: DeepWorkMonitor.isInDeepWork(
                frontmostBundleId: frontmostBundleId,
                frontmostSince: frontmostSince,
                quietMinutes: config.deepWorkQuietMinutes,
                requireFullscreen: config.deepWorkRequireFullscreen
            ),
            deepWorkEnabled: config.deepWorkEnabled,
            sinceAnchor: sinceAnchor,
            overdueLimit: overdueLimit,
            idle: IdleMonitor.isIdle(thresholdMinutes: config.idleSkipMinutes),
            activeFor: activeFor,
            minActiveSeconds: TimeInterval(config.minActiveMinutes * 60),
            isLunchOrWindDown: config.isLunchTime() || config.isWindDownTime(),
            onBreak: showGuidedBreak
        )
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
                recordEvidence(.awayReturn)
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
        let inMeeting = CalendarMonitor.isInMeeting(titleDenylist: config.features.calendarTitleDenylist)
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
        // Followers do not independently invent quiet-rule fires; they only
        // deliver when schedule hits (phone) or when authority says at-desk.
        if !isCadenceAuthority {
            presence = remoteAuthorityPresence.flatMap(PresenceState.init(rawValue:)) ?? .atDesk
            statusMessage = remoteAuthorityName.map { "Follower · \($0): \(presence.displayName)" }
                ?? "Follower · waiting for authority"
            return false // Mac follower never fires local banners; phone uses notifications
        }
        let result = FireGateEvaluator.evaluate(fireGateContext())
        presence = result.presence
        statusMessage = result.status
        if !result.allowed, config.features.recordBlockReasons,
           SuppressionStatus.isHoldStatus(result.status) {
            blockStats.record(
                reason: result.status,
                dayKey: StatsSnapshot.dayKey(calendar: config.scheduleCalendar)
            )
            BlockStats.save(blockStats)
        }
        return result.allowed
    }

    /// Glanceable “Held: Meeting · 2m ago” for the menu bar.
    var heldStatusLine: String? {
        SuppressionStatus.heldLine(
            currentStatus: statusMessage,
            lastReason: blockStats.lastReason,
            lastAt: blockStats.lastAt
        )
    }

    /// Top quiet-rule counter for today.
    var topBlockLine: String? {
        blockStats.topBlockLine()
    }

    /// Runtime peer / authority lease age when iCloud is on.
    var authorityLeaseLine: String? {
        guard config.features.iCloudSyncEnabled else { return nil }
        return SuppressionStatus.leaseLine(
            authorityUpdatedAt: syncHealth.lastRuntimeRemoteAt,
            authorityName: syncHealth.lastRuntimeRemoteDevice ?? remoteAuthorityName
        )
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
            if config.soundName.isEmpty || config.soundName.lowercased() == "aero" {
                AeroAcoustics.play(.breakAlert)
            } else if let sound = NSSound(named: NSSound.Name(config.soundName)) {
                sound.play()
            } else {
                AeroAcoustics.play(.breakAlert)
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

        if config.guidedBreakEnabled {
            let modeKey: String = {
                switch mode {
                case .breakPrompt: return "breakPrompt"
                case .sitStand: return "sitStand"
                case .meetingCatchUp: return "meetingCatchUp"
                case .lunch, .windDown: return "other"
                }
            }()
            if config.guidedBreakOpenMode.shouldAutoOpen(mode: modeKey) {
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
            // Hysteresis: ignore 1–4 minute noise so multi-device sync doesn't thrash.
            if RuntimeMerge.shouldPublishAdaptiveChange(from: effectiveIntervalMinutes, to: minutes)
                || lastAdaptiveComputedAt == nil {
                effectiveIntervalMinutes = minutes
                if config.features.iCloudSyncEnabled {
                    syncRuntimeToCloud()
                }
            }
            adaptiveSuggestion = AdaptiveCoach.suggest(
                config: config, stats: stats, samples: activitySamples,
                calendar: config.scheduleCalendar
            )
            lastAdaptiveComputedAt = Date()
            lastAdaptiveAnchor = anchor
        }
        maybeAutoSwitchMeetingHeavyPack()
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

    /// Opt-in: if today's calendar looks meeting-heavy, switch to the
    /// Meeting-heavy pack once per day.
    private func maybeAutoSwitchMeetingHeavyPack() {
        guard config.features.autoProfileFromCalendar else { return }
        let day = StatsSnapshot.dayKey(calendar: config.scheduleCalendar)
        guard autoPackAppliedDayKey != day else { return }
        let count = CalendarMonitor.meetingEventCountToday(
            calendar: config.scheduleCalendar,
            titleDenylist: config.features.calendarTitleDenylist
        )
        guard count >= 4, config.reminderPack != .meetingHeavy else { return }
        applyReminderPack(.meetingHeavy)
        autoPackAppliedDayKey = day
        statusMessage = "Meeting-heavy day (\(count) events) — pack applied"
    }
}

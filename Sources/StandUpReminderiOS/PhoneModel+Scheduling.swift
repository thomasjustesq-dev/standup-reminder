#if os(iOS)
import ActivityKit
import Foundation
import UserNotifications
import WidgetKit

@MainActor
extension PhoneModel {
    func schedulerInput(now: Date) -> Scheduler.Input {
        // Prefer Mac-pushed adaptive interval when present so cadence matches.
        let interval = cloudEffectiveIntervalMinutes ?? config.intervalMinutes
        return Scheduler.Input(
            config: config,
            intervalMinutes: interval,
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
        let generation = Int(Date().timeIntervalSince1970)
        let now = Date()
        let generated = Scheduler.upcoming(schedulerInput(now: now), count: Self.queueDepth)
        // Exhaustion is judged on the pre-filter count: a quiet-window filter
        // below can shrink a full queue, and a shrunken-but-full queue drains
        // exactly the same way.
        let queueWasFull = generated.count == Self.queueDepth
        // Honor team quiet windows + cadence-authority presence / next-fire gate
        // only while the authority lease is alive.
        var chain = generated.filter { next in
            !TeamQuietHours.isInTeamQuiet(config: config.features, at: next.date, calendar: config.scheduleCalendar)
        }
        if isFollower || config.features.cadenceRole == .automatic {
            chain = FollowerSchedulePolicy.applyAuthorityFilters(
                chain: chain,
                authorityPresence: authorityPresence,
                authorityNextFireAt: authorityNextFireAt,
                now: now,
                honorAuthority: honorsAuthority
            )
        }
        var promptIndex = 0
        var phase = deskPhase
        for (index, next) in chain.enumerated() {
            let payload = payload(for: next, promptIndex: &promptIndex, deskPhase: &phase)
            NotificationManager.schedule(
                payload,
                at: next.date,
                calendar: config.scheduleCalendar,
                identifier: NotificationManager.queuedIdentifier(generation: generation, slot: "\(index)")
            )
        }
        // With a full queue, exhaustion is possible; make it visible instead
        // of going silently dark when the last slot fires.
        if queueWasFull, let last = chain.last {
            NotificationManager.schedule(
                ReminderPayload(
                    kind: .breakPrompt,
                    title: "Reminders paused",
                    body: "Open Stand Up to keep reminders coming — the scheduled queue ran out.",
                    promptId: Self.sentinelPromptId,
                    guidedSteps: []
                ),
                at: last.date.addingTimeInterval(60),
                calendar: config.scheduleCalendar,
                identifier: NotificationManager.queuedIdentifier(generation: generation, slot: "sentinel")
            )
        }
        upcoming = chain
        PhoneWatchBridge.shared.pushStatus()
        publishWidgetSnapshot()
        updateLiveActivity()
    }

    func publishWidgetSnapshot() {
        WidgetSnapshotWriter.write(
            from: config,
            nextFireAt: nextFireAt,
            statusMessage: statusText,
            stats: stats,
            deskPhase: config.sitStandModeEnabled ? deskPhase : nil,
            profileName: "iPhone"
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateLiveActivity() {
        guard config.features.liveActivityEnabled,
              ActivityAuthorizationInfo().areActivitiesEnabled,
              let next = upcoming.first, next.date > Date() else {
            endLiveActivity()
            return
        }
        let state = BreakActivityAttributes.ContentState(nextFireAt: next.date, title: "Next break")
        let content = ActivityContent(state: state, staleDate: next.date.addingTimeInterval(10 * 60))
        if let activity = Activity<BreakActivityAttributes>.activities.first {
            Task { await activity.update(content) }
        } else if isForeground {
            // ActivityKit only allows *starting* an activity in the
            // foreground; background reschedules (notification actions, BG
            // refresh) wait for the next foreground pass.
            do {
                _ = try Activity.request(attributes: BreakActivityAttributes(profileName: "iPhone"), content: content)
            } catch {
                AppLog.write("Live Activity request failed: \(error.localizedDescription)")
            }
        }
    }

    func endLiveActivity() {
        for activity in Activity<BreakActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func payload(for next: Scheduler.Next, promptIndex: inout Int, deskPhase: inout DeskPhase) -> ReminderPayload {
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
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
            .filter { $0.request.identifier.hasPrefix(NotificationManager.requestIdPrefix) }
            .sorted { $0.date < $1.date }
        for note in delivered {
            // Dedup key includes the delivery date: queue identifiers embed a
            // generation stamp now, but old installs delivered fixed slot ids
            // whose reuse must not be skipped forever.
            let key = "\(note.request.identifier)@\(note.date.timeIntervalSince1970)"
            guard !countedDeliveredIds.contains(key) else { continue }
            countedDeliveredIds.insert(key)
            let info = note.request.content.userInfo
            let kind = info["kind"] as? String
            let promptId = info["promptId"] as? String
            let date = note.date
            if promptId != Self.sentinelPromptId {
                if lastReminderAt.map({ date > $0 }) ?? true {
                    lastReminderAt = date
                }
                stats.recordShown(on: StatsSnapshot.dayKey(date, calendar: config.scheduleCalendar))
            }
            if kind == ReminderKind.lunch.rawValue {
                lunchFiredDayKey = StatsSnapshot.dayKey(date, calendar: config.scheduleCalendar)
            }
            if kind == ReminderKind.windDown.rawValue {
                windDownFiredDayKey = StatsSnapshot.dayKey(date, calendar: config.scheduleCalendar)
            }
        }
        // Keep Notification Center to the most recent banner and the dedup
        // set bounded (it only guards against double-counting in-session).
        let staleIds = delivered.dropLast().map(\.request.identifier)
        if !staleIds.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: Array(staleIds))
        }
        if countedDeliveredIds.count > 512 { countedDeliveredIds.removeAll() }
        syncRuntimeFromCloud()
        persistRuntime()
        rescheduleNotifications()
    }
}
#endif

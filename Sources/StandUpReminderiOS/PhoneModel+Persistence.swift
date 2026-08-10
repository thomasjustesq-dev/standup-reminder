#if os(iOS)
import Foundation

@MainActor
extension PhoneModel {
    func applyRuntime(_ runtime: RuntimeState) {
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

    func persistRuntime() {
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
}
#endif

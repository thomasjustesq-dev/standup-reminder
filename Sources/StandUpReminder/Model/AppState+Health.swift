import Foundation

extension AppState {
    func refreshHealthAccessStatus() {
        healthAccessStatus = HealthLogger.authorizationStatus()
    }

    func requestHealthAccess() {
        guard HealthLogger.isAvailable else {
            healthAccessStatus = .unavailable
            statusMessage = "Apple Health is unavailable on this Mac; connect it on iPhone"
            return
        }
        healthAccessStatus = .notDetermined
        HealthLogger.requestAuthorization { [weak self] status in
            guard let self else { return }
            self.healthAccessStatus = status
            self.statusMessage = status == .authorized
                ? "Apple Health connected"
                : status.displayName
        }
    }
}

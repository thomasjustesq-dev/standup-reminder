import Foundation
import HealthKit

enum HealthLogger {
    private static let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard isAvailable,
              let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            completion(false)
            return
        }
        store.requestAuthorization(toShare: [mindful], read: []) { granted, error in
            if let error { AppLog.write("Health auth error: \(error.localizedDescription)") }
            DispatchQueue.main.async { completion(granted) }
        }
    }

    static func logMindfulMinutes(_ minutes: Double) {
        guard minutes > 0,
              isAvailable,
              let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }

        let end = Date()
        let start = end.addingTimeInterval(-minutes * 60)
        let sample = HKCategorySample(
            type: mindful,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )
        store.save(sample) { success, error in
            if let error {
                AppLog.write("Health save error: \(error.localizedDescription)")
            } else if success {
                AppLog.write("Logged \(minutes) mindful minute(s) to Health")
            }
        }
    }
}

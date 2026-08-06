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
        var read: Set<HKObjectType> = []
        if let stand = HKObjectType.categoryType(forIdentifier: .appleStandHour) {
            read.insert(stand)
        }
        store.requestAuthorization(toShare: [mindful], read: read) { granted, error in
            if let error { AppLog.write("Health auth error: \(error.localizedDescription)") }
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// True if the current clock hour already has a closed Apple Stand hour sample.
    static func standHourClosedThisHour(completion: @escaping (Bool) -> Void) {
        guard isAvailable,
              let stand = HKObjectType.categoryType(forIdentifier: .appleStandHour) else {
            completion(false)
            return
        }
        let calendar = Calendar.current
        let now = Date()
        guard let start = calendar.dateInterval(of: .hour, for: now)?.start else {
            completion(false)
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let query = HKSampleQuery(
            sampleType: stand,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in
            let closed = (samples as? [HKCategorySample])?.contains {
                $0.value == HKCategoryValueAppleStandHour.stood.rawValue
            } ?? false
            DispatchQueue.main.async { completion(closed) }
        }
        store.execute(query)
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

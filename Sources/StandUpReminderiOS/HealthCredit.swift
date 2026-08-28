#if os(iOS)
import Foundation
import HealthKit

/// Reads workout end times to auto-credit training and writes the configured
/// mindful-session duration when the user marks a break Done.
enum HealthCredit {
    private static let store = HKHealthStore()

    static func authorizationStatus() -> HealthAccessStatus {
        guard HKHealthStore.isHealthDataAvailable(),
              let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            return .unavailable
        }
        switch store.authorizationStatus(for: mindful) {
        case .notDetermined: return .notDetermined
        case .sharingAuthorized: return .authorized
        case .sharingDenied: return .denied
        @unknown default: return .notDetermined
        }
    }

    static func requestAuthorization(completion: @escaping (HealthAccessStatus) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            completion(.unavailable)
            return
        }
        store.requestAuthorization(toShare: [mindful], read: [HKObjectType.workoutType()]) { _, error in
            let status: HealthAccessStatus
            if let error {
                AppLog.write("HealthKit auth error: \(error.localizedDescription)")
                status = .failed(error.localizedDescription)
            } else {
                status = authorizationStatus()
            }
            DispatchQueue.main.async { completion(status) }
        }
    }

    static func logMindfulMinutes(_ minutes: Double) {
        guard minutes > 0,
              authorizationStatus().canWriteMindfulSessions,
              let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        let end = Date()
        let sample = HKCategorySample(
            type: mindful,
            value: HKCategoryValue.notApplicable.rawValue,
            start: end.addingTimeInterval(-minutes * 60),
            end: end
        )
        store.save(sample) { success, error in
            if let error {
                AppLog.write("HealthKit mindful save failed: \(error.localizedDescription)")
            } else if success {
                AppLog.write("Logged \(minutes) mindful minute(s) to Health")
            }
        }
    }

    /// End date of the most recent workout that finished within
    /// `windowHours`, or nil.
    static func recentWorkoutEnd(windowHours: Double = 3, completion: @escaping (Date?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { completion(nil); return }
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-windowHours * 3600),
            end: nil,
            options: []
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: .workoutType(),
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sort]
        ) { _, samples, error in
            if let error { AppLog.write("HealthKit workout query failed: \(error.localizedDescription)") }
            let end = (samples?.first as? HKWorkout)?.endDate
            DispatchQueue.main.async { completion(end) }
        }
        store.execute(query)
    }
}
#endif

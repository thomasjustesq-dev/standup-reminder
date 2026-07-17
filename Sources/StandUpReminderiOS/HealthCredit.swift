#if os(iOS)
import Foundation
import HealthKit

/// Read-only HealthKit access: the app never writes health samples (the
/// user's health pipeline is curated elsewhere); it only reads workout end
/// times to auto-credit training as a movement break.
enum HealthCredit {
    private static let store = HKHealthStore()

    static func requestAuthorizationIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        store.requestAuthorization(toShare: nil, read: [HKObjectType.workoutType()]) { _, error in
            if let error { AppLog.write("HealthKit auth error: \(error.localizedDescription)") }
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

#if os(iOS)
import BackgroundTasks
import SwiftUI

@main
struct StandUpReminderiOSApp: App {
    @StateObject private var model = PhoneModel.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Registration must happen before the app finishes launching.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: PhoneModel.backgroundRefreshTaskId,
            using: nil
        ) { task in
            // Exactly one completion point: the work task always completes
            // the BGTask; expiration only cancels (a second setTaskCompleted
            // from the expiration handler could race the success path).
            let work = Task { @MainActor in
                PhoneModel.shared.scheduleBackgroundRefresh()
                await PhoneModel.shared.reconcileDelivered()
                task.setTaskCompleted(success: !Task.isCancelled)
            }
            task.expirationHandler = {
                work.cancel()
            }
        }
        PhoneModel.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                PhoneModel.shared.isForeground = true
                PhoneModel.shared.refreshAuthorizationStatus()
                PhoneModel.shared.creditRecentWorkoutIfAny()
                // Pull authority presence / next-fire before rebuild.
                Task { await PhoneModel.shared.reconcileDelivered() }
            case .background:
                PhoneModel.shared.isForeground = false
                PhoneModel.shared.scheduleBackgroundRefresh()
            default:
                break
            }
        }
    }
}
#endif

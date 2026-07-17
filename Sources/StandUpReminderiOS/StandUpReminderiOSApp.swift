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
            let work = Task { @MainActor in
                PhoneModel.shared.scheduleBackgroundRefresh()
                await PhoneModel.shared.reconcileDelivered()
                if !Task.isCancelled { task.setTaskCompleted(success: true) }
            }
            task.expirationHandler = {
                work.cancel()
                task.setTaskCompleted(success: false)
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
                PhoneModel.shared.refreshAuthorizationStatus()
                PhoneModel.shared.creditRecentWorkoutIfAny()
                Task { await PhoneModel.shared.reconcileDelivered() }
            case .background:
                PhoneModel.shared.scheduleBackgroundRefresh()
            default:
                break
            }
        }
    }
}
#endif

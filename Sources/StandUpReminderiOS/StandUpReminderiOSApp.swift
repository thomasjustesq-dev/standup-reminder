#if os(iOS)
import SwiftUI

@main
struct StandUpReminderiOSApp: App {
    @StateObject private var model = PhoneModel.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        PhoneModel.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await PhoneModel.shared.reconcileDelivered() }
            }
        }
    }
}
#endif

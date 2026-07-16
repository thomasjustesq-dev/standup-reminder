import AppKit
import SwiftUI

@main
struct StandUpReminderApp: App {
    @ObservedObject private var appState = AppState.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            if appState.config.showMenuBarCountdown, !appState.menuBarTitle.isEmpty {
                Text("\(appState.menuBarTitle)")
            } else {
                Image(systemName: appState.menuBarSymbolName)
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        Window("Welcome", id: "onboarding") {
            OnboardingView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)

        Window("Guided Break", id: "guided-break") {
            GuidedBreakView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var guidedObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            if CLI.runIfNeeded() {
                try? await Task.sleep(nanoseconds: 700_000_000)
                NSApp.terminate(nil)
                return
            }

            NSApp.setActivationPolicy(.accessory)
            AppState.shared.start()

            // Open guided break window when requested.
            guidedObserver = NotificationCenter.default.addObserver(
                forName: .openGuidedBreakWindow,
                object: nil,
                queue: .main
            ) { _ in
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.identifier?.rawValue == "guided-break" {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
                // SwiftUI Window scenes open via openWindow from views; fallback activate.
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

extension Notification.Name {
    static let openGuidedBreakWindow = Notification.Name("openGuidedBreakWindow")
}

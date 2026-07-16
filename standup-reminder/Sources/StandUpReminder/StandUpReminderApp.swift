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
            Label("Stand Up Reminder", systemImage: appState.menuBarSymbolName)
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
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cliExitPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            if CLI.runIfNeeded() {
                self.cliExitPending = true
                try? await Task.sleep(nanoseconds: 700_000_000)
                NSApp.terminate(nil)
                return
            }

            NSApp.setActivationPolicy(.accessory)
            AppState.shared.start()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

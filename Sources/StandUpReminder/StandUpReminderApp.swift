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
                    .accessibilityLabel("Next break in \(appState.menuBarTitle)")
            } else {
                Image(systemName: appState.menuBarSymbolName)
                    .accessibilityLabel("Stand Up Reminder")
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

        Window("Sample Day", id: "sample-day") {
            SampleDayTourView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var observers: [Any] = []
    private var fallbackWindows: [String: NSWindow] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            if await CLI.runIfNeeded() {
                try? await Task.sleep(nanoseconds: 700_000_000)
                NSApp.terminate(nil)
                return
            }

            NSApp.setActivationPolicy(.accessory)
            AppState.shared.start()

            observe(.openGuidedBreakWindow) { [weak self] in
                self?.present(id: "guided-break", title: "Guided Break") {
                    GuidedBreakView().environmentObject(AppState.shared)
                }
            }
            observe(.openSampleDayTour) { [weak self] in
                self?.present(id: "sample-day", title: "Sample Day") {
                    SampleDayTourView().environmentObject(AppState.shared)
                }
            }
            observe(.openOnboardingWindow) { [weak self] in
                self?.present(id: "onboarding", title: "Welcome") {
                    OnboardingView().environmentObject(AppState.shared)
                }
            }
        }
    }

    private func observe(_ name: Notification.Name, handler: @escaping @MainActor () -> Void) {
        observers.append(NotificationCenter.default.addObserver(
            forName: name, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in handler() }
        })
    }

    /// The menu-style MenuBarExtra only mounts its view while the menu is
    /// open, so SwiftUI's openWindow may have no caller when a notification
    /// action or launch path needs a window. Front the SwiftUI-scene window
    /// if one exists; otherwise host the same view in an AppKit window.
    @MainActor
    private func present<Content: View>(id: String, title: String, @ViewBuilder content: () -> Content) {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.identifier?.rawValue == id {
            window.makeKeyAndOrderFront(nil)
            return
        }
        if let existing = fallbackWindows[id] {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let controller = NSHostingController(rootView: content())
        let window = NSWindow(contentViewController: controller)
        window.title = title
        window.identifier = NSUserInterfaceItemIdentifier("fallback-\(id)")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        fallbackWindows[id] = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

extension Notification.Name {
    static let openGuidedBreakWindow = Notification.Name("openGuidedBreakWindow")
    static let openSampleDayTour = Notification.Name("openSampleDayTour")
    static let openOnboardingWindow = Notification.Name("openOnboardingWindow")
    /// Posted via DistributedNotificationCenter by the CLI process after it
    /// mutates state on disk, so the running app picks it up immediately.
    static let standUpExternalStateChanged = Notification.Name("com.user.StandUpReminder.externalStateChanged")
    /// Posted via DistributedNotificationCenter by the CLI process to run a
    /// command (e.g. a test reminder) inside the running app, where windows
    /// and notification actions actually live.
    static let standUpRemoteCommand = Notification.Name("com.user.StandUpReminder.remoteCommand")
}

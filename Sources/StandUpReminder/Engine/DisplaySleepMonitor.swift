import AppKit
import CoreGraphics
import Foundation

final class DisplaySleepMonitor {
    static let shared = DisplaySleepMonitor()

    private(set) var isDisplayAsleep = false
    private var workspaceObservers: [NSObjectProtocol] = []

    private init() {}

    func start() {
        guard workspaceObservers.isEmpty else { return }
        let nc = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.isDisplayAsleep = true
                AppLog.write("display asleep")
            },
            nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.isDisplayAsleep = false
                AppLog.write("display awake")
            }
        ]
    }

    func stop() {
        let nc = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            nc.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    /// Screen lock best-effort via CoreGraphics session dictionary.
    static func isScreenLocked() -> Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        if let locked = dict["CGSSessionScreenIsLocked"] as? Int { return locked != 0 }
        if let locked = dict["CGSSessionScreenIsLocked"] as? Bool { return locked }
        return false
    }
}

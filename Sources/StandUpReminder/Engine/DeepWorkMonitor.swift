import AppKit
import CoreGraphics
import Foundation

enum DeepWorkMonitor {
    static func frontmostBundleId() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    static func isFullscreenFrontmost() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let pid = app.processIdentifier
        for window in info {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32, ownerPID == pid else { continue }
            guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let height = bounds["Height"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat else { continue }
            if let screen = NSScreen.main {
                let frame = screen.frame
                if width >= frame.width * 0.95 && height >= frame.height * 0.9 {
                    return true
                }
            }
        }
        return false
    }

    static func isDenylisted(bundleId: String?, denylist: [String]) -> Bool {
        guard let bundleId else { return false }
        return denylist.contains(bundleId)
    }

    static func isInDeepWork(
        frontmostBundleId: String?,
        frontmostSince: Date?,
        quietMinutes: Int,
        requireFullscreen: Bool
    ) -> Bool {
        guard quietMinutes > 0,
              frontmostSince != nil,
              frontmostBundleId != nil,
              let frontmostSince else { return false }
        let elapsed = Date().timeIntervalSince(frontmostSince)
        guard elapsed >= TimeInterval(quietMinutes * 60) else { return false }
        if requireFullscreen { return isFullscreenFrontmost() }
        return true
    }
}

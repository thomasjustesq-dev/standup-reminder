import Foundation

enum Paths {
    private static let lock = NSLock()
    /// When set (tests only), all support-file paths resolve under this directory
    /// instead of the user's real Application Support.
    private static var supportOverride: URL?

    /// Point Application Support (and related state files) at a fresh temp
    /// directory. Call `resetSupportDirectoryOverride()` in tearDown.
    @discardableResult
    static func useTemporarySupportDirectory(label: String = "tests") -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StandUpReminder-\(label)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        lock.lock()
        supportOverride = dir
        lock.unlock()
        return dir
    }

    static func resetSupportDirectoryOverride() {
        lock.lock()
        let previous = supportOverride
        supportOverride = nil
        lock.unlock()
        if let previous {
            try? FileManager.default.removeItem(at: previous)
        }
    }

    static var appSupport: URL {
        lock.lock()
        let override = supportOverride
        lock.unlock()
        if let override {
            try? FileManager.default.createDirectory(at: override, withIntermediateDirectories: true)
            return override
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("StandUpReminder", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var configFile: URL { appSupport.appendingPathComponent("config.json") }
    static var statsFile: URL { appSupport.appendingPathComponent("stats.json") }
    static var logFile: URL {
        lock.lock()
        let override = supportOverride
        lock.unlock()
        if let override {
            return override.appendingPathComponent("standup-reminder.log")
        }
        // Library/Logs resolves inside the sandbox container on iOS/watchOS
        // and to ~/Library/Logs on macOS (homeDirectoryForCurrentUser is
        // macOS-only, so it can't be used in shared code).
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let logs = library.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("standup-reminder.log")
    }
}

enum AppLog {
    private static let lock = NSLock()
    private static let maxLogBytes = 512_000

    static func write(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let path = Paths.logFile.path
        lock.lock()
        defer { lock.unlock() }
        rotateIfNeeded(path: path)
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: path) {
                if let handle = try? FileHandle(forWritingTo: Paths.logFile) {
                    defer { try? handle.close() }
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                }
            } else {
                try? data.write(to: Paths.logFile)
            }
        }
        #if DEBUG
        print(message)
        #endif
    }

    private static func rotateIfNeeded(path: String) {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int,
              size > maxLogBytes else { return }
        let old = Paths.logFile.deletingPathExtension().appendingPathExtension("old.log")
        try? FileManager.default.removeItem(at: old)
        try? FileManager.default.moveItem(at: Paths.logFile, to: old)
    }
}

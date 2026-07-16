import AppKit
import Foundation

enum Diagnostics {
    static func breadcrumb(_ message: String) {
        AppLog.write("[diag] \(message)")
    }

    static func report(event: String, details: [String: String] = [:], endpoint: String) async {
        guard !endpoint.isEmpty, let url = URL(string: endpoint) else { return }
        var body: [String: Any] = [
            "event": event,
            "app": "StandUpReminder",
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4.0.0",
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        for (k, v) in details { body[k] = v }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                AppLog.write("Diagnostics POST \(http.statusCode)")
            }
        } catch {
            AppLog.write("Diagnostics failed: \(error.localizedDescription)")
        }
    }

    static func installExceptionHook(enabled: Bool, endpoint: String) {
        guard enabled else { return }
        NSSetUncaughtExceptionHandler { exception in
            AppLog.write("Uncaught: \(exception.name.rawValue) \(exception.reason ?? "")")
            let line = "CRASH \(exception.name.rawValue): \(exception.reason ?? "")\n"
            if let data = line.data(using: .utf8) {
                let url = Paths.logFile
                if FileManager.default.fileExists(atPath: url.path),
                   let handle = try? FileHandle(forWritingTo: url) {
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                } else {
                    try? data.write(to: url)
                }
            }
            _ = endpoint
        }
    }
}

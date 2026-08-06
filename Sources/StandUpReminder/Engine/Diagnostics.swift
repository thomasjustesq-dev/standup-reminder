import AppKit
import Foundation

enum Diagnostics {
    // The uncaught-exception handler is a C function pointer and cannot capture
    // context, so the endpoint lives in lock-guarded static storage instead.
    private static let stateLock = NSLock()
    private static var crashEndpoint = ""

    static func breadcrumb(_ message: String) {
        AppLog.write("[diag] \(message)")
    }

    static func report(event: String, details: [String: String] = [:], endpoint: String) async {
        // Empty endpoint = local breadcrumbs only (AppLog). No network.
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard case let .success(url) = DiagnosticsURL.validate(endpoint) else {
            AppLog.write("Diagnostics endpoint rejected (https + public host required)")
            return
        }
        guard let request = postRequest(url: url, event: event, details: details) else { return }
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
        let accepted: String
        switch DiagnosticsURL.validate(endpoint) {
        case .success(let url):
            accepted = url.absoluteString
        case .failure:
            AppLog.write("Diagnostics crash hook not installed — endpoint rejected")
            return
        }
        stateLock.lock()
        crashEndpoint = accepted
        stateLock.unlock()
        NSSetUncaughtExceptionHandler { exception in
            Diagnostics.recordCrash(name: exception.name.rawValue, reason: exception.reason ?? "")
        }
    }

    private static func recordCrash(name: String, reason: String) {
        AppLog.write("CRASH \(name): \(reason)")
        stateLock.lock()
        let endpoint = crashEndpoint
        stateLock.unlock()
        guard case let .success(url) = DiagnosticsURL.validate(endpoint) else { return }
        guard let request = postRequest(url: url, event: "crash", details: ["name": name, "reason": reason]) else { return }
        // The process is about to die; give the POST a moment to leave the machine.
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, _, _ in semaphore.signal() }.resume()
        _ = semaphore.wait(timeout: .now() + 2)
    }

    private static func postRequest(url: URL, event: String, details: [String: String]) -> URLRequest? {
        var body: [String: Any] = [
            "event": event,
            "app": "StandUpReminder",
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? AppVersion.marketing,
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        for (k, v) in details { body[k] = v }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        return request
    }
}

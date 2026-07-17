import Foundation

/// Optional, off-by-default bridge to the local Fighting Shape health
/// backend: on low-recovery days (Whoop red), the break cadence tightens
/// gently — under-recovered is exactly when long sitting stretches hurt.
///
/// Config carries only the base URL (it syncs across devices); the API key
/// is read from `fightingshape-api-key` in Application Support and never
/// leaves this machine.
final class FightingShapeMonitor {
    static let shared = FightingShapeMonitor()

    private(set) var lowRecovery = false
    private(set) var lastRecoveryScore: Double?
    private var lastFetchAt: Date?

    private static let redThreshold = 34.0

    func refreshIfDue(enabled: Bool, baseURL: String) {
        guard enabled, !baseURL.isEmpty else {
            lowRecovery = false
            return
        }
        guard lastFetchAt.map({ Date().timeIntervalSince($0) >= 3600 }) ?? true else { return }
        lastFetchAt = Date()

        guard let url = URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/summary") else { return }
        var request = URLRequest(url: url, timeoutInterval: 10)
        let keyURL = Paths.appSupport.appendingPathComponent("fightingshape-api-key")
        if let key = try? String(contentsOf: keyURL, encoding: .utf8) {
            request.setValue(key.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "X-API-Key")
        }

        Task { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      let json = try? JSONSerialization.jsonObject(with: data) else { return }
                guard let score = Self.findRecovery(in: json) else { return }
                await MainActor.run {
                    self?.lastRecoveryScore = score
                    self?.lowRecovery = score < Self.redThreshold
                    if score < Self.redThreshold {
                        AppLog.write("Fighting Shape recovery \(Int(score))% — tightening break cadence")
                    }
                }
            } catch {
                AppLog.write("Fighting Shape fetch failed: \(error.localizedDescription)")
            }
        }
    }

    /// Shallow search for a recovery-like score so minor backend payload
    /// changes don't break the integration.
    static func findRecovery(in json: Any, depth: Int = 0) -> Double? {
        guard depth < 4 else { return nil }
        guard let dict = json as? [String: Any] else { return nil }
        for key in ["recovery", "recovery_score", "recoveryScore", "readiness"] {
            if let value = dict[key] as? Double, (0...100).contains(value) { return value }
            if let value = dict[key] as? Int, (0...100).contains(value) { return Double(value) }
        }
        for value in dict.values {
            if let found = findRecovery(in: value, depth: depth + 1) { return found }
        }
        return nil
    }
}

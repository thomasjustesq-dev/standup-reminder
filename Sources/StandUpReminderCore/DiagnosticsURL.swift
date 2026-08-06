import Foundation

/// Validates opt-in diagnostics POST endpoints so a mistyped or hostile URL
/// cannot siphon crash breadcrumbs to an arbitrary host.
enum DiagnosticsURL {
    enum Rejection: Error, Equatable {
        case empty
        case notHTTPS
        case invalid
        case blockedHost
    }

    /// Accept only https URLs with a public-ish host (no localhost / link-local / bare IPs in private ranges).
    static func validate(_ raw: String) -> Result<URL, Rejection> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return .failure(.invalid)
        }
        guard scheme == "https" else { return .failure(.notHTTPS) }
        guard let host = url.host?.lowercased(), !host.isEmpty else { return .failure(.invalid) }
        if isBlockedHost(host) { return .failure(.blockedHost) }
        return .success(url)
    }

    private static func isBlockedHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".localhost") { return true }
        if host == "0.0.0.0" || host == "::1" { return true }
        // IPv4 private / link-local / loopback
        let parts = host.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4 {
            let a = parts[0], b = parts[1]
            if a == 10 { return true }
            if a == 127 { return true }
            if a == 192 && b == 168 { return true }
            if a == 172 && (16...31).contains(b) { return true }
            if a == 169 && b == 254 { return true }
        }
        return false
    }
}

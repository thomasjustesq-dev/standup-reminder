import Foundation

enum AppDenylist {
    static func normalized(_ entries: [String]) -> [String] {
        var seen = Set<String>()
        return entries.compactMap { entry in
            let normalized = entry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return normalized
        }
    }

    static func contains(bundleIdentifier: String?, entries: [String]) -> Bool {
        guard let bundleIdentifier else { return false }
        let target = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized(entries).contains(target)
    }
}

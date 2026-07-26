import Foundation

struct UpdateInfo: Equatable {
    var tagName: String
    var htmlURL: String
    var isNewer: Bool
}

enum UpdateChecker {
    static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4.0.0"

    static func check(releasesURL: String) async -> UpdateInfo? {
        let urlString = releasesURL.isEmpty
            ? "" // disabled unless configured
            : releasesURL
        guard let url = URL(string: urlString), !urlString.isEmpty else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue("StandUpReminder/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            // GitHub Releases API: array of releases, or latest release object
            if let latest = try? JSONDecoder().decode(GitHubRelease.self, from: data) {
                return makeInfo(tag: latest.tag_name, html: latest.html_url)
            }
            if let list = try? JSONDecoder().decode([GitHubRelease].self, from: data), let latest = list.first {
                return makeInfo(tag: latest.tag_name, html: latest.html_url)
            }
        } catch {
            AppLog.write("Update check failed: \(error.localizedDescription)")
        }
        return nil
    }

    private static func makeInfo(tag: String, html: String) -> UpdateInfo {
        let normalized = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        return UpdateInfo(
            tagName: tag,
            htmlURL: html,
            isNewer: compareVersions(normalized, currentVersion) > 0
        )
    }

    /// Returns 1 if a > b, -1 if a < b, 0 if equal (semver-ish).
    static func compareVersions(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").compactMap { Int($0) }
        let pb = b.split(separator: ".").compactMap { Int($0) }
        let count = max(pa.count, pb.count)
        for i in 0..<count {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x > y { return 1 }
            if x < y { return -1 }
        }
        return 0
    }

    private struct GitHubRelease: Decodable {
        var tag_name: String
        var html_url: String
    }
}

import Foundation

enum TeamQuietHours {
    struct Feed: Codable {
        var windows: [QuietWindow]
    }

    static func isInTeamQuiet(config: FeatureFlags, at date: Date = Date(), calendar: Calendar) -> Bool {
        guard config.teamQuiet.enabled else { return false }
        return config.teamQuiet.windows.contains { $0.contains(date, calendar: calendar) }
    }

    static func fetch(from urlString: String) async -> [QuietWindow] {
        guard let url = URL(string: urlString), !urlString.isEmpty else { return [] }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            let feed = try JSONDecoder().decode(Feed.self, from: data)
            AppLog.write("Team quiet hours fetched: \(feed.windows.count) window(s)")
            return feed.windows
        } catch {
            AppLog.write("Team quiet fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}

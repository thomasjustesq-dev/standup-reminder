import CoreLocation
import Foundation

struct WeatherSnapshot: Equatable {
    var temperatureC: Double
    var weatherCode: Int
    var isNiceForWalk: Bool
    var summary: String
}

enum WeatherService {
    /// Open-Meteo — no API key. Uses approximate location from TimeZone or fallback.
    static func fetch(latitude: Double, longitude: Double) async -> WeatherSnapshot? {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "celsius")
        ]
        guard let url = comps.url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteo.self, from: data)
            let code = decoded.current.weather_code
            let temp = decoded.current.temperature_2m
            let nice = (temp >= 8 && temp <= 28) && ![51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99].contains(code)
            let summary = nice ? "Nice weather for a short outdoor walk." : "Weather is meh — stretch indoors is fine."
            return WeatherSnapshot(temperatureC: temp, weatherCode: code, isNiceForWalk: nice, summary: summary)
        } catch {
            AppLog.write("Weather fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Rough city coords from timezone identifier (best-effort, offline table).
    static func approxCoordinates(for timeZone: TimeZone) -> (Double, Double) {
        let id = timeZone.identifier.lowercased()
        if id.contains("new_york") || id.contains("detroit") { return (40.71, -74.01) }
        if id.contains("chicago") { return (41.88, -87.63) }
        if id.contains("denver") { return (39.74, -104.99) }
        if id.contains("los_angeles") { return (34.05, -118.24) }
        if id.contains("london") { return (51.51, -0.13) }
        if id.contains("paris") { return (48.86, 2.35) }
        if id.contains("tokyo") { return (35.68, 139.65) }
        if id.contains("sydney") { return (-33.87, 151.21) }
        if id.contains("toronto") { return (43.65, -79.38) }
        if id.contains("vancouver") { return (49.28, -123.12) }
        return (37.77, -122.42) // SF fallback
    }

    private struct OpenMeteo: Decodable {
        struct Current: Decodable {
            var temperature_2m: Double
            var weather_code: Int
        }
        var current: Current
    }
}

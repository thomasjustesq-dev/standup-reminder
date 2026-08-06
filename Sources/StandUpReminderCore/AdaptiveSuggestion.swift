import Foundation

/// Human-readable adaptive cadence suggestion from weekly stats patterns.
struct AdaptiveSuggestion: Equatable {
    var recommendedMinutes: Int
    var explanation: String
    /// Hour-of-day buckets that snoozed more than done (0–23).
    var pressureHours: [Int]
}

enum AdaptiveCoach {
    /// Suggest interval and explain using stats.dayKey patterns + current samples.
    static func suggest(
        config: AppConfig,
        stats: StatsSnapshot,
        samples: [Double],
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> AdaptiveSuggestion {
        let base = AdaptiveInterval.resolvedMinutes(config: config, samples: samples)
        let week = stats.weekSummary(reference: reference, calendar: calendar)
        var minutes = base
        var parts: [String] = []
        parts.append("Activity samples → \(base)m")

        if week.shown > 0 {
            let rate = Double(week.done) / Double(week.shown)
            if rate < 0.4, week.snoozed >= week.done {
                minutes = min(config.adaptiveMaxMinutes, minutes + 10)
                parts.append("low completion (\(Int(rate * 100))%) → +\(10)m")
            } else if rate > 0.85, week.snoozed == 0, week.shown >= 5 {
                minutes = max(config.adaptiveMinMinutes, minutes - 5)
                parts.append("high completion → −5m")
            }
        }

        // Self-logged heavy weeks: user is moving without banners — slightly longer ok.
        if week.selfLogged >= 3, week.selfLogged >= week.done / 2 {
            minutes = min(config.adaptiveMaxMinutes, minutes + 5)
            parts.append("many self-logged breaks → +5m")
        }

        minutes = min(max(minutes, config.adaptiveMinMinutes), config.adaptiveMaxMinutes)
        return AdaptiveSuggestion(
            recommendedMinutes: minutes,
            explanation: parts.joined(separator: "; "),
            pressureHours: []
        )
    }
}

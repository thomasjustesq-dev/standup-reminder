import Foundation

enum AdaptiveInterval {
    /// Map recent idle samples (seconds idle at sample time) to an interval.
    /// Low idle ⇒ highly active at keyboard ⇒ shorter breaks.
    /// Higher idle ⇒ lighter day ⇒ longer gaps.
    static func resolvedMinutes(config: AppConfig, samples: [Double]) -> Int {
        guard config.adaptiveIntervalEnabled else { return config.intervalMinutes }
        let minM = min(config.adaptiveMinMinutes, config.adaptiveMaxMinutes)
        let maxM = max(config.adaptiveMinMinutes, config.adaptiveMaxMinutes)
        guard !samples.isEmpty else { return config.intervalMinutes.clamped(to: minM...maxM) }

        let avgIdle = samples.reduce(0, +) / Double(samples.count)
        // avgIdle ~0–30s ⇒ very active; ~120s+ ⇒ light presence
        let activity = 1.0 - min(1.0, avgIdle / 180.0)
        let span = Double(maxM - minM)
        let value = Double(maxM) - activity * span
        return Int(value.rounded()).clamped(to: minM...maxM)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

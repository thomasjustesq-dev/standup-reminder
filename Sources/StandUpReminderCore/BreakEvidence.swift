import Foundation

/// How a break was completed — self-report vs sensor-backed evidence.
enum BreakEvidence: String, Codable, Equatable {
    /// User tapped Done without a shown banner (menu / test / guided).
    case selfLogged
    /// User acknowledged a banner we actually delivered.
    case bannerAck
    /// Mac idle → active after a long away stretch.
    case awayReturn
    /// Apple Stand hour closed for the current hour.
    case standHour
    /// Recent HealthKit workout end.
    case workout
    /// Step count rose during the break window (when available).
    case steps

    var displayName: String {
        switch self {
        case .selfLogged: return "Self-logged"
        case .bannerAck: return "Banner Done"
        case .awayReturn: return "Away return"
        case .standHour: return "Stand hour"
        case .workout: return "Workout"
        case .steps: return "Steps"
        }
    }

    var isEvidenceBacked: Bool {
        switch self {
        case .selfLogged: return false
        case .bannerAck, .awayReturn, .standHour, .workout, .steps: return true
        }
    }
}

extension DayStats {
    // Optional counters for evidence mix — stored if present, decode-tolerant.
    // We reuse selfLogged for non-banner dones; evidence breakdown is in a side file.
}

/// Rolling evidence totals (not merged into DayStats to keep old files clean).
struct EvidenceStats: Codable, Equatable {
    var byKind: [String: Int] = [:]

    static var fileURL: URL { Paths.appSupport.appendingPathComponent("evidence-stats.json") }

    static func load() -> EvidenceStats {
        guard let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONCoding.decoder().decode(EvidenceStats.self, from: data) else {
            return EvidenceStats()
        }
        return doc
    }

    static func save(_ stats: EvidenceStats) {
        guard let data = try? JSONCoding.encoder().encode(stats) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    mutating func record(_ evidence: BreakEvidence) {
        byKind[evidence.rawValue, default: 0] += 1
    }

    func summaryLine() -> String {
        guard !byKind.isEmpty else { return "No evidence-backed breaks yet." }
        let parts = byKind.sorted { $0.value > $1.value }.prefix(4).map { "\($0.key) \($0.value)" }
        return "Evidence: " + parts.joined(separator: " · ")
    }
}

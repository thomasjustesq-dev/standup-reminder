import Foundation

enum DeskPhase: String, Codable {
    case sit
    case stand
}

struct RuntimeState: Codable, Equatable {
    var isPaused: Bool = false
    var snoozeUntil: Date?
    var skipRestOfDayDate: Date?
    var lastReminderAt: Date?
    var lastAcknowledgedAt: Date?
    var promptCursor: Int = 0
    var deskPhase: DeskPhase = .sit
    var deskPhaseStartedAt: Date?
    var pendingMeetingCatchUp: Bool = false
    var lastMeetingState: Bool = false
    var windDownFiredDayKey: String?
    var lunchFiredDayKey: String?
    var activitySamples: [Double] = [] // recent idle-seconds samples for adaptive interval
    var frontmostBundleId: String?
    var frontmostSince: Date?
    var lastUpdateCheckAt: Date?

    static var fileURL: URL { Paths.appSupport.appendingPathComponent("runtime.json") }

    static func load() -> RuntimeState {
        let decoder = JSONCoding.decoder()
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let state = try? decoder.decode(RuntimeState.self, from: data) else {
            return RuntimeState()
        }
        return state
    }

    static func save(_ state: RuntimeState) {
        guard let data = try? JSONCoding.encoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

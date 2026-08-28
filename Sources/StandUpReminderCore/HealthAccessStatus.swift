import Foundation

enum HealthAccessStatus: Equatable {
    case unavailable
    case notDetermined
    case authorized
    case denied
    case failed(String)

    var canWriteMindfulSessions: Bool {
        self == .authorized
    }

    var displayName: String {
        switch self {
        case .unavailable: return "Unavailable on this device"
        case .notDetermined: return "Not connected"
        case .authorized: return "Connected"
        case .denied: return "Access denied"
        case .failed(let message): return "HealthKit error: \(message)"
        }
    }
}

import Foundation

/// Single source of truth for JSON encoding/decoding of app state.
///
/// Every store (config, profiles, runtime, stats, widget, iCloud) must use these
/// coders. v4.0 mixed ISO 8601 and epoch-double date strategies between stores,
/// which broke iCloud pull the moment a config contained a Date.
enum JSONCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        // Accept ISO 8601 (current format) and the epoch-double values that
        // v4.0's default-strategy stores wrote, so upgrades keep user data.
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                if let date = iso8601.date(from: string) { return date }
                if let date = iso8601Fractional.date(from: string) { return date }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognized date string: \(string)"
                )
            }
            let seconds = try container.decode(Double.self)
            return Date(timeIntervalSinceReferenceDate: seconds)
        }
        return decoder
    }

    private static let iso8601 = ISO8601DateFormatter()

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

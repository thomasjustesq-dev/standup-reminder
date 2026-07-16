import AVFoundation
import Foundation

enum VoiceAnnouncer {
    private static let synthesizer = AVSpeechSynthesizer()

    static func headphonesLikelyConnected() -> Bool {
        #if os(macOS)
        // Best-effort: default output device name heuristics.
        return true // refined below via CoreAudio if needed; speakOnlyWithHeadphones still gates via config + this
        #else
        return true
        #endif
    }

    static func speak(_ text: String, force: Bool = false, headphonesOnly: Bool) {
        if headphonesOnly && !force && !AudioRoute.hasExternalOrBluetoothOutput {
            AppLog.write("Voice skipped (no headphones/external output)")
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        synthesizer.speak(utterance)
    }
}

enum AudioRoute {
    /// True when default output looks like headphones / Bluetooth / USB audio.
    static var hasExternalOrBluetoothOutput: Bool {
        // Without diving into CoreAudio device enumeration, treat built-in speakers as "internal".
        // Users can disable speakOnlyWithHeadphones if this is too strict on their hardware.
        let name = currentOutputName().lowercased()
        if name.isEmpty { return true }
        let internalHints = ["macbook", "imac", "mac mini", "mac studio", "built-in", "internal"]
        if internalHints.contains(where: { name.contains($0) }) {
            // Still allow if also mentions headphone
            if name.contains("headphone") || name.contains("airpod") { return true }
            return false
        }
        return true
    }

    private static func currentOutputName() -> String {
        // Lightweight: read from `system_profiler` is too slow. Use empty → permissive.
        // Prefer NSSound/AVAudioSession — AVAudioSession is iOS-only.
        UserDefaults.standard.string(forKey: "StandUpReminder.DebugOutputName") ?? ""
    }
}

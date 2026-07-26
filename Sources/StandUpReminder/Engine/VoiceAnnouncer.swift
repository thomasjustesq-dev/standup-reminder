import AVFoundation
import CoreAudio
import Foundation

enum VoiceAnnouncer {
    private static let synthesizer = AVSpeechSynthesizer()

    static func speak(_ text: String, force: Bool = false, headphonesOnly: Bool) {
        if headphonesOnly && !force && !AudioRoute.hasExternalOrBluetoothOutput {
            AppLog.write("Voice skipped (no headphones/external output)")
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        // AVSpeechSynthesisVoice wants BCP-47 ("en-US"); Locale.identifier is "en_US".
        if let language = Locale.preferredLanguages.first,
           let voice = AVSpeechSynthesisVoice(language: language) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
    }
}

enum AudioRoute {
    /// True when the default output device is not the built-in speakers —
    /// headphone jack, Bluetooth, USB, AirPlay, HDMI, and so on.
    /// Fails closed (false) so "headphones only" never speaks aloud by accident.
    static var hasExternalOrBluetoothOutput: Bool {
        guard let deviceID: AudioDeviceID = property(
            AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            scope: kAudioObjectPropertyScopeGlobal
        ) else { return false }

        guard let transport: UInt32 = property(
            deviceID,
            selector: kAudioDevicePropertyTransportType,
            scope: kAudioObjectPropertyScopeGlobal
        ) else { return false }

        guard transport == kAudioDeviceTransportTypeBuiltIn else { return true }

        // Built-in device: headphones on the jack report data source 'hdpn'.
        let headphoneSource: UInt32 = 0x6864_706E // 'hdpn'
        if let source: UInt32 = property(
            deviceID,
            selector: kAudioDevicePropertyDataSource,
            scope: kAudioObjectPropertyScopeOutput
        ) {
            return source == headphoneSource
        }
        return false
    }

    private static func property<T>(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> T? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(objectID, &address) else { return nil }
        var size = UInt32(MemoryLayout<T>.size)
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer) == noErr,
              size == UInt32(MemoryLayout<T>.size) else { return nil }
        return pointer.pointee
    }
}

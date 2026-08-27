import AppKit
import AudioToolbox
import AVFoundation

/// Synthesized spatial acoustic engine for Aero-Kinetic audio cues.
/// Produces stereo harmonic glass chimes at pure solfeggio frequencies (528Hz base /
/// 1056Hz harmonic) with smooth exponential decay curves; the base tone sits left,
/// the harmonic right, with a short Haas delay for spatial width.
public enum AeroAcoustics {
    public enum Cue {
        case breakAlert
        case breakDone
        case snooze
    }

    @MainActor
    public static func play(_ cue: Cue) {
        Task.detached(priority: .high) {
            generateTone(for: cue)
        }
    }

    private static func generateTone(for cue: Cue) {
        let sampleRate: Double = 44100.0
        let duration: Double = {
            switch cue {
            case .breakAlert: return 1.2
            case .breakDone: return 0.8
            case .snooze: return 0.4
            }
        }()

        let numSamples = Int(sampleRate * duration)
        // Interleaved stereo (L,R) — the chime is spatial, not mono.
        var pcmData = [Float](repeating: 0, count: numSamples * 2)

        let baseFreq: Double = {
            switch cue {
            case .breakAlert: return 528.0 // 528Hz "Transformation / Clarity" frequency
            case .breakDone: return 880.0  // 880Hz A5 high resolution resolution
            case .snooze: return 440.0     // 440Hz A4 gentle pause
            }
        }()

        let secondFreq: Double = {
            switch cue {
            case .breakAlert: return 1056.0
            case .breakDone: return 1320.0
            case .snooze: return 660.0
            }
        }()

        // Stereo image: base tone sits slightly left, harmonic slightly right,
        // with a short Haas-style delay on the right channel for width.
        let haasDelaySeconds = 0.006
        let basePan: (left: Double, right: Double) = (1.0, 0.72)
        let harmonicPan: (left: Double, right: Double) = (0.70, 1.0)

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let tR = max(0.0, t - haasDelaySeconds)
            let decay = exp(-t * (cue == .breakDone ? 4.5 : 3.0)) // Exponential glass decay
            let decayR = exp(-tR * (cue == .breakDone ? 4.5 : 3.0))

            let envelope: Double
            if t < 0.008 {
                envelope = t / 0.008 // Soft 8ms attack to avoid speaker pop
            } else {
                envelope = decay
            }
            let envelopeR = t < 0.008 ? envelope : decayR

            let baseL = sin(2.0 * .pi * baseFreq * t) * 0.65
            let harmonicL = sin(2.0 * .pi * secondFreq * t) * 0.35
            let baseR = sin(2.0 * .pi * baseFreq * tR) * 0.65
            let harmonicR = sin(2.0 * .pi * secondFreq * tR) * 0.35

            let left = (baseL * basePan.left + harmonicL * harmonicPan.left) * envelope * 0.7
            let right = (baseR * basePan.right + harmonicR * harmonicPan.right) * envelopeR * 0.7

            pcmData[i * 2] = Float(left)
            pcmData[i * 2 + 1] = Float(right)
        }

        // Convert PCM float to AudioBuffer and play via AudioToolbox / CoreAudio
        playPCM(pcmData, sampleRate: sampleRate)
    }

    private static func playPCM(_ pcmData: [Float], sampleRate: Double) {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 8,
            mFramesPerPacket: 1,
            mBytesPerFrame: 8,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        var audioQueue: AudioQueueRef?
        let status = AudioQueueNewOutput(&asbd, { _, _, _ in }, nil, nil, nil, 0, &audioQueue)
        guard status == noErr, let queue = audioQueue else { return }

        let bufferByteSize = UInt32(pcmData.count * MemoryLayout<Float>.size)
        var buffer: AudioQueueBufferRef?
        AudioQueueAllocateBuffer(queue, bufferByteSize, &buffer)

        if let buffer = buffer {
            buffer.pointee.mAudioDataByteSize = bufferByteSize
            memcpy(buffer.pointee.mAudioData, pcmData, Int(bufferByteSize))
            AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
            AudioQueueStart(queue, nil)

            // Auto-dispose after playback (2 interleaved samples per frame)
            let sleepSeconds = Double(pcmData.count) / 2.0 / sampleRate + 0.1
            Thread.sleep(forTimeInterval: sleepSeconds)
            AudioQueueStop(queue, false)
            AudioQueueDispose(queue, true)
        }
    }
}

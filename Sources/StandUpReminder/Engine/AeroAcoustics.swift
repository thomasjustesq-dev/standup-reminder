import AppKit
import AudioToolbox
import AVFoundation

/// Synthesized spatial acoustic engine for Aero-Kinetic audio cues.
/// Produces harmonic glass chimes at pure solfeggio frequencies (528Hz base / 1056Hz harmonic)
/// with smooth exponential decay curves.
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
        var pcmData = [Float](repeating: 0, count: numSamples)

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

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let decay = exp(-t * (cue == .breakDone ? 4.5 : 3.0)) // Exponential glass decay
            
            let sample1 = sin(2.0 * .pi * baseFreq * t) * 0.65
            let sample2 = sin(2.0 * .pi * secondFreq * t) * 0.35
            
            let envelope: Double
            if t < 0.008 {
                envelope = t / 0.008 // Soft 8ms attack to avoid speaker pop
            } else {
                envelope = decay
            }
            
            pcmData[i] = Float((sample1 + sample2) * envelope * 0.7)
        }

        // Convert PCM float to AudioBuffer and play via AudioToolbox / CoreAudio
        playPCM(pcmData, sampleRate: sampleRate)
    }

    private static func playPCM(_ pcmData: [Float], sampleRate: Double) {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
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

            // Auto-dispose after playback
            let sleepSeconds = Double(pcmData.count) / sampleRate + 0.1
            Thread.sleep(forTimeInterval: sleepSeconds)
            AudioQueueStop(queue, false)
            AudioQueueDispose(queue, true)
        }
    }
}

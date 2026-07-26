import AVFoundation
import Combine
import CoreMedia
import Foundation
import Vision

/// Opt-in, on-device stillness heuristic using the camera face detector.
/// Frames are never uploaded — only a local "face present & stable" signal is kept.
@MainActor
final class WebcamStillnessMonitor: NSObject, ObservableObject {
    static let shared = WebcamStillnessMonitor()

    @Published private(set) var isStillTooLong = false
    @Published private(set) var facePresent = false
    @Published private(set) var status: String = "Off"

    private let frameGate = FrameGate()
    private var session: AVCaptureSession?
    private var lastMotionAt = Date()
    private var lastFaceBox: CGRect?
    private var timer: Timer?
    private var enabled = false
    private var thresholdMinutes = 45

    func configure(enabled: Bool, thresholdMinutes: Int) {
        self.thresholdMinutes = max(10, thresholdMinutes)
        if enabled { start() } else { stop() }
    }

    func start() {
        guard !enabled else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { self.beginSession() }
                    else { self.status = "Camera denied" }
                }
            }
        default:
            status = "Camera denied"
        }
    }

    func stop() {
        enabled = false
        timer?.invalidate()
        timer = nil
        session?.stopRunning()
        session = nil
        isStillTooLong = false
        status = "Off"
    }

    private func beginSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .low
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            status = "No camera"
            return
        }
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "standup.webcam"))
        if session.canAddOutput(output) { session.addOutput(output) }
        self.session = session
        enabled = true
        status = "Watching (on-device)"
        session.startRunning()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateStillness() }
        }
    }

    private func evaluateStillness() {
        guard enabled else { return }
        let minutes = Date().timeIntervalSince(lastMotionAt) / 60
        isStillTooLong = facePresent && minutes >= Double(thresholdMinutes)
        if isStillTooLong {
            status = String(format: "Still ~%.0fm", minutes)
        }
    }
}

extension WebcamStillnessMonitor: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Face detection on every camera frame burns CPU/battery for a
        // signal that only needs minute-level resolution.
        guard frameGate.shouldProcess(minInterval: 3) else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, options: [:])
        let request = VNDetectFaceRectanglesRequest()
        try? requestHandler.perform([request])
        let faces = request.results ?? []
        Task { @MainActor in
            self.facePresent = !faces.isEmpty
            if let face = faces.first {
                let box = face.boundingBox
                if let last = self.lastFaceBox {
                    let dx = abs(box.midX - last.midX)
                    let dy = abs(box.midY - last.midY)
                    if dx > 0.02 || dy > 0.02 {
                        self.lastMotionAt = Date()
                    }
                } else {
                    self.lastMotionAt = Date()
                }
                self.lastFaceBox = box
            }
        }
    }
}

/// Lock-guarded frame throttle usable from the capture queue.
final class FrameGate: @unchecked Sendable {
    private let lock = NSLock()
    private var lastProcessedAt = Date.distantPast

    func shouldProcess(minInterval: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        guard now.timeIntervalSince(lastProcessedAt) >= minInterval else { return false }
        lastProcessedAt = now
        return true
    }
}

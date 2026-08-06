import AVFoundation
import Combine
import CoreMedia
import Foundation
import Vision

/// Opt-in, on-device stillness heuristic using the camera face detector.
/// Frames are never uploaded — only a local "face present & stable" signal is kept.
///
/// Power policy: the capture session runs in short bursts (default 6s every
/// 3 minutes) instead of continuous green-light streaming.
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
    private var evaluateTimer: Timer?
    private var burstTimer: Timer?
    private var enabled = false
    private var thresholdMinutes = 45
    private var burstActive = false

    /// How long each sample burst runs.
    private let burstDuration: TimeInterval = 6
    /// Gap between bursts when not still-too-long (tighter when overdue).
    private let idleBurstInterval: TimeInterval = 3 * 60
    private let overdueBurstInterval: TimeInterval = 60

    func configure(enabled: Bool, thresholdMinutes: Int) {
        self.thresholdMinutes = max(10, thresholdMinutes)
        if enabled { start() } else { stop() }
    }

    func start() {
        guard !enabled else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginBurstCycle()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { self.beginBurstCycle() }
                    else { self.status = "Camera denied" }
                }
            }
        default:
            status = "Camera denied"
        }
    }

    func stop() {
        enabled = false
        evaluateTimer?.invalidate()
        evaluateTimer = nil
        burstTimer?.invalidate()
        burstTimer = nil
        stopSession()
        isStillTooLong = false
        status = "Off"
    }

    private func beginBurstCycle() {
        enabled = true
        status = "Burst sampling (on-device)"
        evaluateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateStillness() }
        }
        scheduleNextBurst(after: 1)
    }

    private func scheduleNextBurst(after delay: TimeInterval) {
        burstTimer?.invalidate()
        burstTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.runBurst() }
        }
    }

    private func runBurst() {
        guard enabled else { return }
        startSessionIfNeeded()
        burstActive = true
        status = "Sampling…"
        DispatchQueue.main.asyncAfter(deadline: .now() + burstDuration) { [weak self] in
            guard let self, self.enabled else { return }
            self.burstActive = false
            self.stopSession()
            self.evaluateStillness()
            let interval = self.isStillTooLong ? self.overdueBurstInterval : self.idleBurstInterval
            self.status = self.isStillTooLong
                ? String(format: "Still — next sample %.0fs", interval)
                : String(format: "Idle sample in %.0fm", interval / 60)
            self.scheduleNextBurst(after: interval)
        }
    }

    private func startSessionIfNeeded() {
        if session != nil { return }
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
        session.startRunning()
    }

    private func stopSession() {
        session?.stopRunning()
        session = nil
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
        guard frameGate.shouldProcess(minInterval: 1.5) else { return }
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

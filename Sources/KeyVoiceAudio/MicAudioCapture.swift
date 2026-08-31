import Foundation
import AVFoundation
import KeyVoiceCore

/// Microphone capture via `AVAudioEngine`; emits raw buffers live and auto-commits past the cap.
///
/// The tap forwards each buffer to `onBuffer` on the audio render thread — the Transcriber is
/// responsible for copying anything it retains (the engine reuses tap buffers). A `maxRecording`
/// timeout fires `onAutoCommit` so a held key can never record forever (plan cap).
public final class MicAudioCapture: AudioCapturing {
    public var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    public var onAutoCommit: (() -> Void)?

    private let config: AppConfig
    private let engine = AVAudioEngine()
    private var timeout: DispatchWorkItem?
    private var running = false

    public init(config: AppConfig = AppConfig()) { self.config = config }

    public func start() throws {
        guard !running else { return }
        try ensureMicrophonePermission()

        let input = engine.inputNode
        // The tap format must match the node's own output format, or `installTap` traps.
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.onBuffer?(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw KeyVoiceError.microphoneBusy
        }
        running = true

        // Hard cap: auto-commit if the user holds past `maxRecording`.
        let work = DispatchWorkItem { [weak self] in self?.onAutoCommit?() }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + config.maxRecording, execute: work)
    }

    public func stop() {
        timeout?.cancel()
        timeout = nil
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
    }

    // MARK: - Permission

    private func ensureMicrophonePermission() throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .denied, .restricted:
            throw KeyVoiceError.microphoneDenied
        case .notDetermined:
            // First run: block briefly for the system prompt. Runs off the render thread.
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                granted = ok
                semaphore.signal()
            }
            semaphore.wait()
            if !granted { throw KeyVoiceError.microphoneDenied }
        @unknown default:
            throw KeyVoiceError.microphoneDenied
        }
    }
}

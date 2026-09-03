import Foundation
import AVFoundation
import CoreAudio
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
        // Route capture to the user's chosen input device if they picked one (Settings → Microphone).
        // Any failure falls back to the system default — we never block recording on device routing.
        if let uid = UserDefaults.standard.string(forKey: "micDeviceID"),
           let deviceID = Self.audioDeviceID(forUID: uid) {
            Self.setInputDevice(deviceID, on: engine)
        }
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

    // MARK: - Input device selection (CoreAudio)

    /// Resolve a CoreAudio device id from an `AVCaptureDevice.uniqueID` (which, for audio, is the
    /// device's CoreAudio UID). Returns nil if not found so the caller keeps the system default.
    private static func audioDeviceID(forUID uid: String) -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else { return nil }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr
        else { return nil }

        var uidAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        for id in ids {
            var cfUID: CFString? = nil
            var uidSize = UInt32(MemoryLayout<CFString?>.size)
            let status = withUnsafeMutablePointer(to: &cfUID) {
                AudioObjectGetPropertyData(id, &uidAddr, 0, nil, &uidSize, $0)
            }
            if status == noErr, (cfUID as String?) == uid { return id }
        }
        return nil
    }

    /// Point the engine's input (AUHAL) at a specific device. Must run before the engine starts.
    private static func setInputDevice(_ deviceID: AudioDeviceID, on engine: AVAudioEngine) {
        guard let audioUnit = engine.inputNode.audioUnit else { return }
        var dev = deviceID
        _ = AudioUnitSetProperty(audioUnit,
                                 kAudioOutputUnitProperty_CurrentDevice,
                                 kAudioUnitScope_Global, 0,
                                 &dev, UInt32(MemoryLayout<AudioDeviceID>.size))
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

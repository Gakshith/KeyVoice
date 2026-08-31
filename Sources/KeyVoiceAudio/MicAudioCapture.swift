import Foundation
import AVFAudio
import KeyVoiceCore

/// Microphone capture via AVAudioEngine; emits buffers live and auto-commits past the cap.
/// STUB — real implementation lands on branch `speech` (plan Phase 3).
public final class MicAudioCapture: AudioCapturing {
    public var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    public var onAutoCommit: (() -> Void)?
    private let config: AppConfig
    public init(config: AppConfig = AppConfig()) { self.config = config }

    public func start() throws {
        // TODO(speech): install a tap on the input node; forward buffers to onBuffer;
        // start a maxRecording timer that fires onAutoCommit; throw microphoneBusy on start failure.
    }

    public func stop() {}
}

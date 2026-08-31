import Foundation
import AVFAudio
import KeyVoiceCore

/// Fallback transcription via WhisperKit (`small.en`). Buffers audio during the hold and
/// transcribes on finish. STUB — real implementation lands on branch `speech` (plan Phase 4).
/// The WhisperKit SPM dependency is added when this engine is implemented, to keep the base build
/// dependency-free until then.
public final class WhisperKitEngine: Transcriber {
    public init() {}

    public func beginSession() throws {
        // TODO(speech): reset the PCM buffer accumulator.
    }
    public func feed(_ buffer: AVAudioPCMBuffer) {
        // TODO(speech): accumulate 16kHz mono samples.
    }
    public func finishSession() async throws -> String {
        // TODO(speech): run WhisperKit on the accumulated audio; return the transcript.
        return ""
    }
    public func cancelSession() {}
}

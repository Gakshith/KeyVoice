import Foundation
import AVFAudio
import KeyVoiceCore

/// On-device streaming transcription via Apple's SpeechAnalyzer/SpeechTranscriber (macOS 26+).
/// STUB — real implementation lands on branch `speech` (plan Phase 4).
public final class SpeechTranscriberEngine: Transcriber {
    public init() {}

    public func beginSession() throws {
        // TODO(speech): @available(macOS 26,*) SpeechAnalyzer + SpeechTranscriber; ensure locale
        // assets installed via AssetInventory (else throw transcriptionAssetsMissing → WhisperKit fallback).
    }
    public func feed(_ buffer: AVAudioPCMBuffer) {
        // TODO(speech): append buffer to the analyzer's input sequence.
    }
    public func finishSession() async throws -> String {
        // TODO(speech): finalize and return the transcript.
        return ""
    }
    public func cancelSession() {}
}

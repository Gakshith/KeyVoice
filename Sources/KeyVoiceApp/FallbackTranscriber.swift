import Foundation
import AVFAudio
import KeyVoiceCore

/// Tries the primary transcriber; if it can't start this session — Apple SpeechAnalyzer needs
/// macOS 26 and its English assets — it transparently falls back to the secondary for that session.
/// Keeps the Coordinator unaware of engine selection (it holds one `Transcriber`).
final class FallbackTranscriber: Transcriber {
    private let primary: Transcriber
    private let fallback: Transcriber
    private var active: Transcriber?

    init(primary: Transcriber, fallback: Transcriber) {
        self.primary = primary
        self.fallback = fallback
    }

    func beginSession() throws {
        do {
            try primary.beginSession()
            active = primary
        } catch {
            Log.warn("primary transcriber unavailable (\(error)); falling back")
            try fallback.beginSession()
            active = fallback
        }
    }

    func feed(_ buffer: AVAudioPCMBuffer) { active?.feed(buffer) }

    func finishSession() async throws -> String {
        guard let active else { return "" }
        return try await active.finishSession()
    }

    func cancelSession() {
        active?.cancelSession()
        active = nil
    }
}

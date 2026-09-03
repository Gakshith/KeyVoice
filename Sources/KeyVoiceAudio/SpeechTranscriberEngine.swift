import Foundation
import AVFoundation
import KeyVoiceCore
#if canImport(Speech)
import Speech
#endif

/// On-device streaming transcription via Apple's `SpeechAnalyzer` + `SpeechTranscriber`
/// (the WWDC25 Speech framework, macOS 26+).
///
/// This is a *streaming* engine: `beginSession` spins up the analyzer and a background pipeline,
/// `feed` pushes live microphone buffers into it during the hold, and `finishSession` finalizes and
/// returns the accumulated transcript — so on key-up the text is essentially already there.
///
/// On macOS < 26, or when the transcriber / its assets are unavailable, `beginSession` throws and the
/// error surfaces to the menu bar + HUD (Apple-only; there is no secondary engine).
public final class SpeechTranscriberEngine: Transcriber {

    /// Locale we transcribe in. `en-US`; normalized to the framework's supported equivalent at setup.
    private let requestedLocale = Locale(identifier: "en-US")

    /// Raw mic buffers flow through this stream into the background pipeline.
    private var rawContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    /// The pipeline task; its value is the finalized transcript.
    private var runTask: Task<String, Error>?

    /// Live partial transcript, emitted as the user speaks (finalized-so-far + the volatile tail).
    /// The app shell points this at the on-screen caption. Called off the main actor.
    public var onPartial: (@Sendable (String) -> Void)?

    public init() {}

    public func beginSession() throws {
        guard #available(macOS 26, *) else {
            // Streaming Speech API doesn't exist on the deploy target — fall back.
            throw KeyVoiceError.transcriptionAssetsMissing
        }
        try beginSessionAvailable()
    }

    public func feed(_ buffer: AVAudioPCMBuffer) {
        // The engine reuses tap buffers, so hand the pipeline its own copy.
        guard let copy = buffer.deepCopy() else { return }
        rawContinuation?.yield(copy)
    }

    public func finishSession() async throws -> String {
        guard let task = runTask else { return "" }
        rawContinuation?.finish()
        defer { cleanup() }
        do {
            return try await task.value
        } catch let error as KeyVoiceError {
            throw error
        } catch is CancellationError {
            return ""
        } catch {
            throw KeyVoiceError.transcriptionFailed(error.localizedDescription)
        }
    }

    public func cancelSession() {
        rawContinuation?.finish()
        runTask?.cancel()
        cleanup()
    }

    private func cleanup() {
        rawContinuation = nil
        runTask = nil
    }

    // MARK: - macOS 26 path

    @available(macOS 26, *)
    private func beginSessionAvailable() throws {
        // Cheap synchronous gate; async availability (assets) is resolved inside the pipeline.
        guard SpeechTranscriber.isAvailable else {
            throw KeyVoiceError.transcriptionAssetsMissing
        }

        // Idempotent: deterministically end any lingering session before starting a new one, so a
        // rapid begin→commit→begin can't leave two pipelines fighting over state (audit P0 · CORE).
        if runTask != nil {
            rawContinuation?.finish()
            runTask?.cancel()
            cleanup()
        }

        let (rawStream, continuation) = AsyncStream.makeStream(of: AVAudioPCMBuffer.self)
        rawContinuation = continuation
        let locale = requestedLocale
        let onPartial = onPartial
        runTask = Task { try await Self.runPipeline(rawStream: rawStream, locale: locale, onPartial: onPartial) }
    }

    /// Owns the whole analyzer lifecycle for one dictation and returns the final transcript.
    @available(macOS 26, *)
    private static func runPipeline(
        rawStream: AsyncStream<AVAudioPCMBuffer>,
        locale: Locale,
        onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String {
        // Volatile results give us the live partial transcript for the streaming caption.
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )

        try await ensureAssets(for: transcriber)

        let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // Collect finalized segments; emit finalized-so-far + the volatile tail for the live caption.
        let resultsTask = Task { () -> String in
            var finalized = AttributedString()
            for try await result in transcriber.results {
                if result.isFinal {
                    finalized += result.text
                    onPartial?(String(finalized.characters))
                } else {
                    onPartial?(String((finalized + result.text).characters))
                }
            }
            return String(finalized.characters)
        }

        // Bridge raw mic buffers → analyzer input, converting to the analyzer's format as needed.
        let (inputStream, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)

        do {
            try await analyzer.start(inputSequence: inputStream)

            var converter: AudioFormatConverter?
            for await raw in rawStream {
                let buffer: AVAudioPCMBuffer
                if let target = analyzerFormat, target != raw.format {
                    if converter == nil { converter = AudioFormatConverter(to: target) }
                    guard let converted = converter?.convert(raw) else { continue }
                    buffer = converted
                } else {
                    buffer = raw
                }
                inputContinuation.yield(AnalyzerInput(buffer: buffer))
            }
            inputContinuation.finish()

            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            inputContinuation.finish()
            resultsTask.cancel()
            await analyzer.cancelAndFinishNow()
            throw KeyVoiceError.transcriptionFailed(error.localizedDescription)
        }

        return try await resultsTask.value
    }

    /// Confirm the locale model is installed; download it on demand, or throw so we fall back.
    @available(macOS 26, *)
    private static func ensureAssets(for transcriber: SpeechTranscriber) async throws {
        switch await AssetInventory.status(forModules: [transcriber]) {
        case .installed:
            return
        case .unsupported:
            throw KeyVoiceError.transcriptionAssetsMissing
        case .supported, .downloading:
            // Model is supported but not on disk yet — request installation.
            // NOTE: first-run install is a real download and can be slow; the app should pre-warm
            // this so a dictation hold doesn't block on it. Until installed, the fallback covers.
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
                throw KeyVoiceError.transcriptionAssetsMissing
            }
            try await request.downloadAndInstall()
        @unknown default:
            throw KeyVoiceError.transcriptionAssetsMissing
        }
    }
}

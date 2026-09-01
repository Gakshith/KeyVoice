import Foundation
import AVFAudio

/// The pipeline spine. Owns one dictation run at a time and drives:
///
///   begin → lock target + start mic/transcriber → commit → finalize → clean → verify target → paste
///
/// Everything runs on the main actor. Network/transcription happen inside an awaited Task that a new
/// `begin` cancels (single-flight — plan fix C2, no overlapping runs corrupting the clipboard).
@MainActor
public final class Coordinator {
    private let hotkey: HotkeyMonitoring
    private let audio: AudioCapturing
    private let transcriber: Transcriber
    private let cleaner: Cleaner
    private let inserter: TextInserter
    private let targets: TargetProvider
    private let config: AppConfig

    /// Menu-bar status sink. Set by the app shell.
    public var onStatus: ((PipelineStatus) -> Void)?

    /// Optional passive tap on the live microphone buffers, called alongside the transcriber (never
    /// a second capture). The app shell points this at the audio level meter that drives the HUD.
    public var audioMonitor: ((AVAudioPCMBuffer) -> Void)?

    private var lockedTarget: Target?
    private var isRecording = false
    private var runTask: Task<Void, Never>?

    public init(
        hotkey: HotkeyMonitoring,
        audio: AudioCapturing,
        transcriber: Transcriber,
        cleaner: Cleaner,
        inserter: TextInserter,
        targets: TargetProvider,
        config: AppConfig = AppConfig()
    ) {
        self.hotkey = hotkey
        self.audio = audio
        self.transcriber = transcriber
        self.cleaner = cleaner
        self.inserter = inserter
        self.targets = targets
        self.config = config
    }

    public func start() throws {
        hotkey.onEvent = { [weak self] event in
            // The tap callback runs on its run loop; hop to the main actor before touching state.
            Task { @MainActor in self?.handle(event) }
        }
        audio.onBuffer = { [weak self] buffer in
            self?.audioMonitor?(buffer)          // level meter for the HUD (passive)
            self?.transcriber.feed(buffer)
        }
        audio.onAutoCommit = { [weak self] in self?.handle(.commit(holdDuration: self?.config.maxRecording ?? 0)) }
        try hotkey.start()
        emit(.idle)
    }

    // MARK: - Hotkey handling

    private func handle(_ event: HotkeyEvent) {
        switch event {
        case .begin:           beginRecording()
        case .commit(let held): commitRecording(held: held)
        case .cancel(let why):  cancelRecording(why)
        }
    }

    private func beginRecording() {
        // A new dictation supersedes any run still finishing.
        runTask?.cancel()
        runTask = nil

        guard let target = targets.currentTarget() else {
            // No editable field focused → do nothing, but say so (never a silent no-op).
            emit(.skippedNoSpeech)
            Log.info("begin ignored: no focused text field")
            return
        }
        lockedTarget = target
        do {
            try transcriber.beginSession()
            try audio.start()
            isRecording = true
            emit(.listening)
            Log.info("recording → \(target.appName) (\(target.bundleId))")
        } catch {
            isRecording = false
            surface(error)
        }
    }

    private func cancelRecording(_ why: CancelReason) {
        guard isRecording else { return }
        isRecording = false
        audio.stop()
        transcriber.cancelSession()
        lockedTarget = nil
        emit(.idle)
        Log.info("cancelled: \(why.rawValue)")
    }

    private func commitRecording(held: TimeInterval) {
        guard isRecording else { return }
        isRecording = false
        audio.stop()
        guard let target = lockedTarget else { emit(.idle); return }

        emit(.thinking)
        runTask = Task { [weak self] in
            await self?.finishPipeline(target: target)
        }
    }

    // MARK: - Async tail: finalize → clean → verify → paste

    private func finishPipeline(target: Target) async {
        do {
            let raw = try await transcriber.finishSession()
            if Task.isCancelled { return }

            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= config.minTranscriptChars else {
                emit(.skippedNoSpeech)                       // silence / mis-fire → nothing pasted
                Log.info("no speech; skipped")
                return
            }

            // Cleanup with a length-aware deadline; nil ⇒ paste raw (never block the user).
            let deadline = config.cleanupDeadline(forCharacters: trimmed.count)
            let cleaned = await withDeadline(deadline) { [cleaner, ctx = target.appContext] in
                await cleaner.clean(trimmed, app: ctx)
            } ?? nil

            if Task.isCancelled { return }
            let finalText = cleaned ?? trimmed

            // Re-verify the caret is still where we started — refuse to paste into a stranger.
            guard targets.stillValid(target) else {
                emit(.abortedTargetLost)
                Log.warn("target moved; refused paste into wrong window")
                return
            }

            try inserter.insert(finalText, into: target)
            emit(cleaned == nil ? .insertedRaw : .inserted)
            Log.info("pasted \(finalText.count) chars (\(cleaned == nil ? "raw" : "cleaned"))")
        } catch {
            surface(error)
        }
    }

    // MARK: - Helpers

    /// Races `work` against a timeout. Returns nil if the deadline wins.
    private func withDeadline<T>(_ seconds: TimeInterval, _ work: @escaping () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func surface(_ error: Error) {
        let msg = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        emit(.error(msg))
        Log.error(msg)
    }

    private func emit(_ status: PipelineStatus) { onStatus?(status) }
}

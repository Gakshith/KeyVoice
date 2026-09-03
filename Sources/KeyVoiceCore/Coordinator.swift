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

    /// Called after text is successfully inserted, so the app shell can record it to history.
    public var onCompleted: ((DictationResult) -> Void)?

    /// Optional final transform applied to the text just before insertion — the app shell points
    /// this at the user's dictionary replacements and snippet expansions.
    public var transform: ((String) -> String)?

    /// Optional per-app style lookup (bundle id → style kind). The shell points this at the user's
    /// Styles rules; the resolved hint rides into the cleaner via `AppContext.styleHint`.
    public var styleProvider: ((String) -> String?)?

    /// Optional target-language lookup (→ language name, or nil). The shell points this at the user's
    /// translation setting; rides into the cleaner via `AppContext.translateTo`.
    public var languageProvider: (() -> String?)?

    /// Called with the finalized text when there was no valid destination to paste into — no editable
    /// field at the start, or the target went away before insertion. The app shell shows the no-target
    /// scratchpad so the words are never lost or pasted into the wrong place (NEW-2 / P0 · DATA).
    public var onNoTarget: ((String) -> Void)?

    /// Hold duration of the current dictation, captured at commit, used for words-per-minute.
    private var lastHoldDuration: TimeInterval = 0

    private var lockedTarget: Target?
    private var isRecording = false
    private var runTask: Task<Void, Never>?
    /// Monotonic id of the current dictation. The async tail checks it against `self.session` after
    /// every await, so a superseded run can never insert text or clear newer state (audit P0 · CORE).
    private var session = 0

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
        Log.info("coordinator armed and ready")
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
        // A new dictation supersedes any run still finishing. Tear the old one down deterministically
        // so a lingering audio/transcriber session can't feed or clear the new one (audit P0 · CORE).
        session &+= 1
        runTask?.cancel()
        runTask = nil
        if isRecording { audio.stop() }
        transcriber.cancelSession()          // idempotent — ends any in-flight engine session

        // Never capture from a secure/password field — that text is neither shown nor stored.
        if targets.isSecureFieldFocused() {
            emit(.skippedNoSpeech)
            Log.info("begin ignored: secure field focused")
            return
        }

        // Capture the target if there is one. nil is fine: on release, the text goes to the
        // no-target scratchpad instead of being pasted (never a silent no-op, never a wrong paste).
        lockedTarget = targets.currentTarget()
        do {
            try transcriber.beginSession()
            try audio.start()
            isRecording = true
            emit(.listening)
            if let t = lockedTarget {
                Log.info("recording → \(t.appName) (\(t.bundleId)) [session \(session)]")
            } else {
                Log.info("recording → no target, will use scratchpad [session \(session)]")
            }
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

        lastHoldDuration = held
        emit(.thinking)
        let mySession = session
        let target = lockedTarget        // may be nil → scratchpad on finish
        runTask = Task { [weak self] in
            await self?.finishPipeline(target: target, session: mySession)
        }
    }

    // MARK: - Async tail: finalize → clean → verify → paste

    private func finishPipeline(target: Target?, session mySession: Int) async {
        do {
            let raw = try await transcriber.finishSession()
            // A newer dictation started while we were transcribing → this run is stale; drop it.
            guard mySession == session, !Task.isCancelled else { return }

            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= config.minTranscriptChars else {
                emit(.skippedNoSpeech)                       // silence / mis-fire → nothing pasted
                Log.info("no speech; skipped")
                return
            }

            // Resolve the user's per-app style (only meaningful with a target). A Verbatim style
            // bypasses cleanup entirely (audit R-2) — never rewrite text the user asked to keep as-is.
            let styleHint = target.flatMap { styleProvider?($0.bundleId) }
            let isVerbatim = styleHint?.caseInsensitiveCompare("verbatim") == .orderedSame

            let cleaned: String?
            if isVerbatim {
                cleaned = nil
            } else {
                // Cleanup with a length-aware deadline; nil ⇒ paste raw (never block the user).
                let deadline = config.cleanupDeadline(forCharacters: trimmed.count)
                let translateTo = languageProvider?()
                let ctx = AppContext(bundleId: target?.bundleId ?? "", appName: target?.appName ?? "",
                                     styleHint: styleHint, translateTo: translateTo)
                cleaned = await withDeadline(deadline) { [cleaner] in
                    await cleaner.clean(trimmed, app: ctx)
                } ?? nil
            }

            guard mySession == session, !Task.isCancelled else { return }
            var finalText = cleaned ?? trimmed
            if let transform { finalText = transform(finalText) }   // e.g. dictionary replacements

            // Route: paste into a target we can still prove, otherwise hand the text to the no-target
            // scratchpad — fail closed, never guess a destination (NEW-2 / P0 · DATA).
            if let target, targets.stillValid(target) {
                try inserter.insert(finalText, into: target)
                emit(cleaned == nil ? .insertedRaw : .inserted)
                onCompleted?(DictationResult(text: finalText, app: target.appContext, duration: lastHoldDuration))
                Log.info("pasted \(finalText.count) chars (\(cleaned == nil ? "raw" : "cleaned"))")
            } else {
                onNoTarget?(finalText)
                emit(.capturedNoTarget)
                onCompleted?(DictationResult(text: finalText,
                                             app: AppContext(bundleId: "", appName: "No destination"),
                                             duration: lastHoldDuration))
                Log.info("no target → scratchpad (\(finalText.count) chars)")
            }
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

import Foundation
import AVFAudio

// The five seams the Coordinator drives. Concrete implementations live in the feature modules and
// are injected by the app shell, so each can be built and swapped independently (the modular requirement).

/// Turns held speech into text. Streaming by contract: audio is fed live during the hold so the
/// transcript is essentially ready on release (plan seam 1 — NOT file-based).
public protocol Transcriber: AnyObject {
    /// Called on key-down, once the debounce has passed. Prepare to receive buffers.
    func beginSession() throws
    /// Live microphone buffers during the hold.
    func feed(_ buffer: AVAudioPCMBuffer)
    /// Called on key-up. Returns the finalized transcript (may be empty for silence).
    func finishSession() async throws -> String
    /// Called when the gesture is cancelled (combo key, too-short tap). Discard everything.
    func cancelSession()
}

/// Fixes grammar and formats the raw transcript for the destination app.
/// Returns `nil` on any failure/timeout so the caller can paste the raw text instead (never blocks).
public protocol Cleaner: Sendable {
    func clean(_ text: String, app: AppContext) async -> String?
}

/// Puts text at the cursor in whatever app is focused. Runs on the main thread.
public protocol TextInserter {
    func insert(_ text: String, into target: Target) throws
}

/// Captures the current dictation target and re-verifies it before a paste.
public protocol TargetProvider {
    /// The frontmost app + focused element right now, or nil if no editable field is focused.
    func currentTarget() -> Target?
    /// True if `target` is still the frontmost/focused destination (safe to paste).
    func stillValid(_ target: Target) -> Bool
}

/// The global push-to-talk key. Emits begin/commit/cancel; never blocks normal typing.
public protocol HotkeyMonitoring: AnyObject {
    var onEvent: ((HotkeyEvent) -> Void)? { get set }
    func start() throws
    func stop()
}

/// The microphone. Emits raw buffers; auto-commits if the user holds too long (plan cap).
public protocol AudioCapturing: AnyObject {
    var onBuffer: ((AVAudioPCMBuffer) -> Void)? { get set }
    var onAutoCommit: (() -> Void)? { get set }
    func start() throws
    func stop()
}

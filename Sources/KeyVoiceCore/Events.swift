import Foundation

/// What the push-to-talk key tells the Coordinator.
public enum HotkeyEvent {
    /// Right-Option went down and survived the debounce with no other key pressed.
    case begin
    /// Right-Option was released after a valid hold. Time held is for logging/telemetry.
    case commit(holdDuration: TimeInterval)
    /// The gesture was aborted — a combo key was pressed, or the hold was too short.
    case cancel(reason: CancelReason)
}

public enum CancelReason: String {
    case comboKey      // another key was pressed while holding (e.g. ⌥+E accent)
    case tooShort      // released before the debounce threshold
    case superseded    // a new dictation started before this one finished
}

/// What the app shows in the menu bar and logs. Every failure is visible — nothing fails silently.
public enum PipelineStatus: Equatable {
    case idle
    case listening
    case thinking            // transcribing + cleaning
    case inserted            // cleaned text pasted
    case insertedRaw         // cleanup failed/slow, raw text pasted
    case skippedNoSpeech     // empty/near-empty transcript, nothing pasted
    case abortedTargetLost   // focus moved apps; refused to paste into the wrong window
    case capturedNoTarget    // no editable field focused; text saved to the scratchpad instead
    case error(String)       // permission / mic / key / asset problem
}

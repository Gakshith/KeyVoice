import KeyVoiceCore

/// What the on-screen HUD is doing. This is the HUD's own vocabulary — the SwiftUI views know
/// only this and a live audio level, never transcripts, targets, or error strings.
///
/// `HUDPhase.from(_:)` is the ONE place pipeline vocabulary crosses into the HUD module. Keeping the
/// mapping a pure function (no UIKit/AppKit) means it's unit-testable with no window on screen.
public enum HUDPhase: Equatable {
    /// Nothing on screen. The resting state.
    case hidden
    /// Springing up — the key was just pressed.
    case appear
    /// Speaking — the ribbon reacts to the live voice level.
    case listening
    /// Released; transcribing + Claude cleanup. A calm swirl.
    case thinking
    /// Text landed. One confident pulse; `streak` flies the accent toward the cursor, then fades.
    case done(streak: Bool)
    /// Nothing heard, target lost, or an error — deflate to an amber line, then fade.
    case deflate

    /// Maps a pipeline status to what the HUD should show. The controller owns show/hide from this.
    public static func from(_ status: PipelineStatus) -> HUDPhase {
        switch status {
        case .idle:                              return .hidden
        case .listening:                         return .listening
        case .thinking:                          return .thinking
        case .inserted, .insertedRaw:            return .done(streak: true)
        case .skippedNoSpeech, .abortedTargetLost, .error:
                                                 return .deflate
        }
    }
}

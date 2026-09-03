import Foundation

/// Tunables in one place. Values come from the plan's decisions and are easy to adjust during Phase 6.
public struct AppConfig: Sendable {
    /// Minimum hold before we treat it as dictation (ignores accidental taps and ⌥-accent combos).
    public var minHold: TimeInterval = 0.20
    /// Hard cap on a single dictation; auto-commits and warns past this.
    public var maxRecording: TimeInterval = 90.0
    /// Right-Option hardware keycode (Left-Option is 58).
    public var rightOptionKeyCode: Int64 = 61

    /// Claude model for cleanup — fastest tier, verified against the API reference.
    public var cleanupModel: String = "claude-haiku-4-5"
    /// Base cleanup deadline for short text; scaled up with transcript length.
    public var cleanupDeadlineShort: TimeInterval = 1.5
    /// Ceiling the length-scaled deadline never exceeds.
    public var cleanupDeadlineMax: TimeInterval = 4.0
    /// Below this many characters we treat the transcript as "short".
    public var shortTranscriptChars: Int = 120

    /// A transcript this short (trimmed) is treated as no-speech: no cleanup call, no paste.
    public var minTranscriptChars: Int = 1

    public init() {}

    /// Length-aware cleanup deadline (plan fix for B3 — long dictations no longer fall back to raw).
    public func cleanupDeadline(forCharacters count: Int) -> TimeInterval {
        guard count > shortTranscriptChars else { return cleanupDeadlineShort }
        let extra = Double(count - shortTranscriptChars) / 200.0  // ~+1s per 200 chars
        return min(cleanupDeadlineShort + extra, cleanupDeadlineMax)
    }
}

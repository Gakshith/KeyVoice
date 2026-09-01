import Foundation
import AVFAudio

/// Turns live microphone buffers into a smoothed 0…1 loudness the HUD can draw.
///
/// It does NOT open its own audio engine — the Coordinator fans each captured buffer to `process(_:)`
/// alongside the transcriber (one tap, no second capture path). The RMS reduction runs on the audio
/// thread (cheap); only the final float is published, on the main actor, via `onLevel`.
///
/// Phase 0 note: this is the wired stub. Real RMS + envelope-follower smoothing land on the
/// `audio-level` branch; the `process(_:)` / `onLevel` surface is frozen here so the app shell can
/// wire it now.
public final class AudioLevelMeter {
    /// Smoothed level, 0…1, delivered on the main actor.
    public var onLevel: ((Float) -> Void)?

    public init() {}

    /// Fold one capture buffer into the running level. Called on the audio render thread.
    public func process(_ buffer: AVAudioPCMBuffer) {
        // TODO(audio-level): compute RMS via vDSP, dB-normalize, envelope-follow, publish on main.
        let level: Float = 0
        DispatchQueue.main.async { [onLevel] in onLevel?(level) }
    }
}

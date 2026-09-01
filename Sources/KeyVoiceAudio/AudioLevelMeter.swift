import Foundation
import AVFAudio
import Accelerate

/// Turns live microphone buffers into a smoothed 0…1 loudness the HUD can draw.
///
/// It does NOT open its own audio engine — the Coordinator fans each captured buffer to `process(_:)`
/// alongside the transcriber (one tap, no second capture path). The RMS reduction runs on the audio
/// thread (cheap, no allocation, no locks); only the final float is published, on the main actor, via
/// `onLevel`.
///
/// Pipeline: `vDSP_rmsqv` over channel 0 → dB → normalize a −50…0 dB window to 0…1 → hop to main →
/// asymmetric one-pole envelope follower (fast attack, slow release) → `onLevel`.
public final class AudioLevelMeter {

    // MARK: Tuning constants (depend on mic gain — adjust here, not in the hot path)

    /// dB that maps to 0 (quiet floor). Below this the level pins to 0.
    private static let floorDB: Float = -50
    /// dB that maps to 1 (loud ceiling). At/above this the level pins to 1.
    private static let ceilingDB: Float = 0
    /// Envelope rise time constant: level swells quickly.
    private static let attack: Float = 0.03   // seconds
    /// Envelope fall time constant: level settles gently.
    private static let release: Float = 0.25  // seconds
    /// Floor guarding log10 against a zero/denormal RMS.
    private static let rmsFloor: Float = 1e-7

    /// Smoothed level, 0…1, delivered on the main thread.
    public var onLevel: ((Float) -> Void)?

    /// Envelope-follower state. Touched ONLY on the main thread — never shared with the audio thread.
    private var envelope: Float = 0
    /// Wall-clock of the last main-thread envelope update, for a robust dt when buffers vary.
    private var lastUpdate: CFTimeInterval = 0

    public init() {}

    /// Fold one capture buffer into the running level. Called on the audio render thread.
    ///
    /// The audio thread only reduces the buffer to a single normalized float (RMS → dB → 0…1) — no
    /// allocation, no locks. Envelope smoothing and delivery happen on main.
    public func process(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else { return }

        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(buffer.frameLength))

        let db = 20 * log10(max(rms, Self.rmsFloor))
        let span = Self.ceilingDB - Self.floorDB
        let normalized = min(max((db - Self.floorDB) / span, 0), 1)

        // Buffer duration is the natural dt for the envelope.
        let sampleRate = Float(buffer.format.sampleRate)
        let dt = sampleRate > 0 ? Float(buffer.frameLength) / sampleRate : 0

        DispatchQueue.main.async { [weak self] in
            self?.updateEnvelope(target: normalized, bufferDT: dt)
        }
    }

    /// Advance the one-pole envelope toward `target` and publish. Main thread only.
    private func updateEnvelope(target: Float, bufferDT: Float) {
        // Prefer wall-clock dt (survives coalesced async hops); fall back to the buffer duration.
        let now = CFAbsoluteTimeGetCurrent()
        var dt = bufferDT
        if lastUpdate > 0 {
            let measured = Float(now - lastUpdate)
            if measured > 0 { dt = measured }
        }
        lastUpdate = now
        if dt <= 0 { dt = bufferDT > 0 ? bufferDT : 0.01 }

        let tau = target > envelope ? Self.attack : Self.release
        let coeff = exp(-dt / tau)
        envelope = target + coeff * (envelope - target)

        onLevel?(envelope)
    }
}

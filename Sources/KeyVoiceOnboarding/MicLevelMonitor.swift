import Foundation
import Observation
import AVFoundation
import Accelerate

/// A lightweight live microphone level meter for the onboarding mic-test step.
///
/// It taps the default input with an `AVAudioEngine`, computes a per-buffer RMS on the
/// realtime audio thread (cheap: one `vDSP_rmsqv` pass), and republishes a smoothed 0...1
/// `level` on the main thread for SwiftUI to animate against. The engine is started on
/// `start()` and torn down on `stop()`, so the mic is never left running once the step is
/// off screen.
@MainActor
@Observable
public final class MicLevelMonitor {
    /// Smoothed input loudness, clamped to 0...1. Safe to bind to a view.
    public private(set) var level: Double = 0

    /// True while the audio engine is actively tapping the input.
    public private(set) var isRunning = false

    private let engine = AVAudioEngine()

    public init() {}

    /// Begin tapping the microphone. No-op if already running. Silently degrades to a flat
    /// level if the engine can't start (e.g. no input device / permission denied) — callers
    /// gate this behind a granted-microphone check and show their own prompt otherwise.
    public func start() {
        guard !isRunning else { return }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        // A zero-channel / zero-rate format means there's no usable input yet; bail cleanly.
        guard format.channelCount > 0, format.sampleRate > 0 else { return }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            let rms = MicLevelMonitor.rms(of: buffer)
            // Hand the scalar back to the main actor; keep the audio-thread work to the RMS above.
            DispatchQueue.main.async {
                self?.ingest(rms)
            }
        }

        engine.prepare()
        do {
            try engine.start()
            isRunning = true
        } catch {
            // Couldn't start — leave level at 0 and stay not-running so the view shows its idle state.
            input.removeTap(onBus: 0)
            isRunning = false
        }
    }

    /// Stop tapping and release the input. No-op if not running. Resets the published level.
    public func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        level = 0
    }

    /// Map a raw RMS to a perceptual 0...1 and smooth it: fast attack so a spoken word jumps,
    /// slower release so the orb settles rather than flickering.
    private func ingest(_ rms: Float) {
        let gained = min(1.0, Double(rms) * 12)              // typical speech RMS is small; lift it into view
        let shaped = pow(gained, 0.6)                        // ease so quiet speech still reads
        let coeff = shaped > level ? 0.55 : 0.12             // attack vs. release
        level += (shaped - level) * coeff
    }

    /// Root-mean-square of the first channel. Runs on the audio thread, so it stays a single vDSP call.
    private static func rms(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        var value: Float = 0
        vDSP_rmsqv(channels[0], 1, &value, vDSP_Length(buffer.frameLength))
        return value
    }
}

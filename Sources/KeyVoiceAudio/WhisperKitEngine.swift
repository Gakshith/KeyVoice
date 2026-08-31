import Foundation
import AVFoundation
import KeyVoiceCore

/// Fallback transcription via WhisperKit (`small.en`).
///
/// Accumulates the held audio as 16 kHz mono Float samples (WhisperKit's expected input) and
/// transcribes on finish. Everything around the model call is implemented; the call itself is a
/// one-line wiring change once the SPM dependency is added (see the TODO in `finishSession`).
public final class WhisperKitEngine: Transcriber {

    /// WhisperKit consumes 16 kHz mono Float32 PCM.
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false
    )!

    private var converter: AudioFormatConverter?
    /// Accumulated 16 kHz mono samples for the current hold.
    private var samples: [Float] = []

    public init() {}

    public func beginSession() throws {
        samples.removeAll(keepingCapacity: true)
        converter = AudioFormatConverter(to: targetFormat)
    }

    public func feed(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let source: AVAudioPCMBuffer
        if buffer.format == targetFormat {
            source = buffer
        } else if let converted = converter.convert(buffer) {
            source = converted
        } else {
            return
        }
        guard let channel = source.floatChannelData?[0] else { return }
        samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(source.frameLength)))
    }

    public func finishSession() async throws -> String {
        let audio = samples
        samples.removeAll(keepingCapacity: false)
        guard !audio.isEmpty else { return "" }
        // TODO(lead): add WhisperKit SPM dep and run small.en on `audio` (16 kHz mono Float).
        // e.g. `let result = try await whisperKit.transcribe(audioArray: audio); return result.text`
        // Everything up to here (accumulation + resampling to 16 kHz mono) is done — this is the
        // only line to change. Returning "" until then keeps the pipeline honest (no fake output).
        return ""
    }

    public func cancelSession() {
        samples.removeAll(keepingCapacity: false)
        converter = nil
    }
}

// MARK: - Shared audio helpers (module-internal; also used by SpeechTranscriberEngine)

/// Resamples/reformats PCM buffers into a fixed target format, reusing one `AVAudioConverter`.
/// Rebuilds the underlying converter if the source format changes mid-stream.
final class AudioFormatConverter {
    private let target: AVAudioFormat
    private var converter: AVAudioConverter?
    private var sourceFormat: AVAudioFormat?

    init(to target: AVAudioFormat) { self.target = target }

    func convert(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if converter == nil || sourceFormat != input.format {
            converter = AVAudioConverter(from: input.format, to: target)
            sourceFormat = input.format
        }
        guard let converter else { return nil }

        let ratio = target.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }

        var supplied = false
        var convError: NSError?
        let status = converter.convert(to: output, error: &convError) { _, inStatus in
            if supplied {
                inStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inStatus.pointee = .haveData
            return input
        }
        if status == .error || output.frameLength == 0 { return nil }
        return output
    }
}

extension AVAudioPCMBuffer {
    /// A standalone copy of this buffer's samples. Tap buffers are reused by the engine after the
    /// callback returns, so anything retained past the callback must be copied first.
    func deepCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        copy.frameLength = frameLength
        let src = UnsafeMutableAudioBufferListPointer(mutableAudioBufferList)
        let dst = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for i in 0..<min(src.count, dst.count) {
            guard let source = src[i].mData, let dest = dst[i].mData else { continue }
            let bytes = Int(src[i].mDataByteSize)
            memcpy(dest, source, bytes)
            dst[i].mDataByteSize = src[i].mDataByteSize
        }
        return copy
    }
}

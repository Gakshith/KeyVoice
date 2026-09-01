import Foundation
import AVFoundation

// Shared audio helpers for the KeyVoiceAudio module. (Previously lived alongside the WhisperKit
// engine; extracted here when that engine was removed, since SpeechTranscriberEngine relies on them.)

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

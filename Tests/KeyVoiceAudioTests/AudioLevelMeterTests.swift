import XCTest
import AVFAudio
@testable import KeyVoiceAudio

final class AudioLevelMeterTests: XCTestCase {

    /// Mono 44.1k float buffer whose channel 0 is filled with a constant amplitude.
    private func makeBuffer(amplitude: Float, frames: AVAudioFrameCount = 4096) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let ptr = buffer.floatChannelData![0]
        for i in 0..<Int(frames) { ptr[i] = amplitude }
        return buffer
    }

    func testLoudBufferProducesNonZeroLevel() {
        let meter = AudioLevelMeter()
        let expect = expectation(description: "level delivered")
        var received: Float = -1
        meter.onLevel = { level in
            received = level
            expect.fulfill()
        }
        // ~ -6 dBFS constant tone: comfortably inside the -50..0 dB window.
        meter.process(makeBuffer(amplitude: 0.5))
        wait(for: [expect], timeout: 1.0)
        XCTAssertGreaterThan(received, 0.1, "a loud buffer should drive the level well above 0")
        XCTAssertLessThanOrEqual(received, 1.0)
    }

    func testSilenceProducesNearZeroLevel() {
        let meter = AudioLevelMeter()
        let expect = expectation(description: "level delivered")
        var received: Float = -1
        meter.onLevel = { level in
            received = level
            expect.fulfill()
        }
        meter.process(makeBuffer(amplitude: 0))
        wait(for: [expect], timeout: 1.0)
        XCTAssertEqual(received, 0, accuracy: 0.001, "silence should map to ~0")
    }
}

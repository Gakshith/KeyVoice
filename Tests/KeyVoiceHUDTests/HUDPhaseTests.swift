import XCTest
import KeyVoiceCore
@testable import KeyVoiceHUD

/// Pins the one place pipeline vocabulary crosses into the HUD: the status → phase map.
/// No window on screen — pure logic, runs anywhere.
final class HUDPhaseTests: XCTestCase {

    func testEveryStatusMaps() {
        // Exhaustive: if a PipelineStatus case is ever added, this list must grow with it.
        let cases: [(PipelineStatus, HUDPhase)] = [
            (.idle,              .hidden),
            (.listening,         .listening),
            (.thinking,          .thinking),
            (.inserted,          .done(streak: true)),
            (.insertedRaw,       .done(streak: true)),
            (.skippedNoSpeech,   .deflate),
            (.abortedTargetLost, .deflate),
            (.error("boom"),     .deflate),
        ]
        for (status, expected) in cases {
            XCTAssertEqual(HUDPhase.from(status), expected, "\(status) should map to \(expected)")
        }
    }

    func testIdleHidesAndListeningShows() {
        XCTAssertEqual(HUDPhase.from(.idle), .hidden)
        XCTAssertNotEqual(HUDPhase.from(.listening), .hidden)
    }

    @MainActor
    func testSetLevelIgnoredWhenNotListening() {
        let hud = HUDController()
        hud.update(.thinking)
        hud.setLevel(0.9)
        XCTAssertEqual(hud.viewModel.level, 0, "level must be ignored unless listening")

        hud.update(.listening)
        hud.setLevel(0.5)
        XCTAssertEqual(hud.viewModel.level, 0.5, accuracy: 0.001)
    }
}

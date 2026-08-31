import XCTest
@testable import KeyVoiceCore

/// Pure-logic tests — no hardware, so they run anywhere and pin the behavior reviewers care about.
final class ConfigTests: XCTestCase {

    func testShortTranscriptUsesBaseDeadline() {
        let c = AppConfig()
        XCTAssertEqual(c.cleanupDeadline(forCharacters: 10), c.cleanupDeadlineShort, accuracy: 0.001)
        XCTAssertEqual(c.cleanupDeadline(forCharacters: c.shortTranscriptChars), c.cleanupDeadlineShort, accuracy: 0.001)
    }

    func testLongTranscriptScalesDeadlineUp() {
        let c = AppConfig()
        let short = c.cleanupDeadline(forCharacters: 10)
        let long = c.cleanupDeadline(forCharacters: 500)
        XCTAssertGreaterThan(long, short, "a long dictation must get more time, not fall back to raw")
    }

    func testDeadlineNeverExceedsCeiling() {
        let c = AppConfig()
        XCTAssertLessThanOrEqual(c.cleanupDeadline(forCharacters: 100_000), c.cleanupDeadlineMax)
    }

    func testRightOptionKeyCodeIs61() {
        // Left-Option is 58; 61 is the value the hotkey tap keys off.
        XCTAssertEqual(AppConfig().rightOptionKeyCode, 61)
    }
}

final class AppContextTests: XCTestCase {
    func testEquality() {
        let a = AppContext(bundleId: "com.apple.Notes", appName: "Notes")
        let b = AppContext(bundleId: "com.apple.Notes", appName: "Notes")
        XCTAssertEqual(a, b)
    }
}

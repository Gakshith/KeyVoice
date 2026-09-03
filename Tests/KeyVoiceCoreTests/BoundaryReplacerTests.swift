import XCTest
@testable import KeyVoiceCore

final class BoundaryReplacerTests: XCTestCase {
    func testDoesNotReplaceInsideWords() {
        let text = "concatenate category scatter"

        XCTAssertEqual(
            BoundaryReplacer.apply([(from: "cat", to: "dog")], to: text),
            text
        )
    }

    func testReplacesWholeWord() {
        XCTAssertEqual(
            BoundaryReplacer.apply([(from: "cat", to: "dog")], to: "the cat sat"),
            "the dog sat"
        )
    }

    func testMatchesCaseInsensitivelyAndPreservesReplacementCasing() {
        XCTAssertEqual(
            BoundaryReplacer.apply([(from: "cat", to: "Dog")], to: "CAT Cat cat"),
            "Dog Dog Dog"
        )
    }

    func testReplacesNextToPunctuation() {
        XCTAssertEqual(
            BoundaryReplacer.apply([(from: "cat", to: "dog")], to: "cat, (cat) cat."),
            "dog, (dog) dog."
        )
    }

    func testReplacesMultiWordPhraseAsAUnit() {
        XCTAssertEqual(
            BoundaryReplacer.apply(
                [(from: "meeting link", to: "https://example.com")],
                to: "Open the meeting link, please."
            ),
            "Open the https://example.com, please."
        )
    }

    func testAppliesRulesInOrder() {
        let rules = [
            (from: "meeting link", to: "X"),
            (from: "meeting", to: "Y")
        ]

        XCTAssertEqual(BoundaryReplacer.apply(rules, to: "meeting link"), "X")
    }

    func testSkipsEmptyFromRule() {
        let text = "unchanged"

        XCTAssertEqual(
            BoundaryReplacer.apply([(from: "", to: "replacement")], to: text),
            text
        )
    }

    func testReturnsUnchangedStringWhenNothingMatches() {
        let text = "the dog sat"

        XCTAssertEqual(
            BoundaryReplacer.apply([(from: "cat", to: "bird")], to: text),
            text
        )
    }

    func testTreatsReplacementAsLiteralText() {
        XCTAssertEqual(
            BoundaryReplacer.apply([(from: "cat", to: #"$1\home"#)], to: "cat"),
            #"$1\home"#
        )
    }
}

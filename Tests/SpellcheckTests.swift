import XCTest
import UIKit

@MainActor
final class SpellcheckTests: XCTestCase {
    func testFindsWordAtEndWithoutTouchingEarlierText() {
        XCTAssertEqual(Spellcheck.currentWord(before: "hello teh", after: "", selection: nil), "teh")
        XCTAssertEqual(Spellcheck.currentWord(before: "hello\nteh", after: "", selection: nil), "teh")
        XCTAssertEqual(Spellcheck.currentWord(before: "don't", after: "", selection: nil), "don't")
        XCTAssertEqual(Spellcheck.currentWord(before: "café", after: ".", selection: nil), "café")
    }

    func testDoesNotReplaceSelectionsOrPartialWords() {
        XCTAssertNil(Spellcheck.currentWord(before: "teh", after: "rest", selection: nil))
        XCTAssertNil(Spellcheck.currentWord(before: "teh", after: "2", selection: nil))
        XCTAssertNil(Spellcheck.currentWord(before: "teh", after: "", selection: "selected"))
        XCTAssertNil(Spellcheck.currentWord(before: nil, after: nil, selection: nil))
        XCTAssertNil(Spellcheck.currentWord(before: "teh ", after: "", selection: nil))
    }

    func testSkipsAddressesIdentifiersNumbersAndLongTokens() {
        for word in ["a@teh", "https://teh", "abc123", "some_teh", "teh.", String(repeating: "a", count: 41)] {
            XCTAssertNil(Spellcheck.currentWord(before: word, after: "", selection: nil), word)
        }
    }

    func testSmallEditPolicy() {
        for pair in [("teh", "the"), ("recieve", "receive"), ("helo", "hello"),
                     ("helllo", "hello"), ("cat", "bat")] {
            XCTAssertTrue(Spellcheck.isSmallEdit(pair.0, pair.1))
        }
        for pair in [("a", "hello"), ("hello", "hello"), ("bad", "good"), ("abc", "cba")] {
            XCTAssertFalse(Spellcheck.isSmallEdit(pair.0, pair.1))
        }
    }

    func testNativeTypoSuggestionsAndSpaceCorrection() throws {
        try requireEnglish()
        let spellcheck = Spellcheck()
        XCTAssertEqual(spellcheck.suggestions(for: "teh").first, "the")
        XCTAssertEqual(spellcheck.automaticCorrection(for: "teh"), "the")
        XCTAssertEqual(spellcheck.automaticCorrection(for: "recieve"), "receive")
        XCTAssertTrue(spellcheck.suggestions(for: "keyboar").contains("keyboard"))
    }

    func testValidWordsNamesAndShortWordsAreNotAutocorrected() throws {
        try requireEnglish()
        let spellcheck = Spellcheck()
        for word in ["hello", "hi", "Teh", "TEH", "ab", "don't"] {
            XCTAssertNil(spellcheck.automaticCorrection(for: word), word)
        }
    }

    func testUniqueSwapBeatsOtherOneEditGuesses() {
        XCTAssertEqual(Spellcheck.confidentCorrection(for: "teh", guesses: ["the", "ten", "tea"]), "the")
        XCTAssertEqual(Spellcheck.confidentCorrection(for: "recieve", guesses: ["receive", "relieve"]), "receive")
        XCTAssertNil(Spellcheck.confidentCorrection(for: "aeb", guesses: ["abe", "eab"]))
    }

    func testOtherEditsNeedALongerWordAndNoCompetingGuess() {
        XCTAssertEqual(Spellcheck.confidentCorrection(for: "helllo", guesses: ["hello", "hello"]), "hello")
        XCTAssertEqual(Spellcheck.confidentCorrection(for: "keyboar", guesses: ["keyboard"]), "keyboard")
        XCTAssertNil(Spellcheck.confidentCorrection(for: "keyboar", guesses: ["keyboard", "key boar"]))
        XCTAssertNil(Spellcheck.confidentCorrection(for: "helo", guesses: ["hello"]))
        XCTAssertNil(Spellcheck.confidentCorrection(for: "caterx", guesses: ["cater", "caters"]))
        // A third candidate still counts even though the bar only displays two.
        XCTAssertNil(Spellcheck.confidentCorrection(for: "caterx", guesses: ["cater", "catering", "caters"]))
    }

    func testConfidenceNeverPromotesLowerRankedGuessesOrChangesNames() {
        XCTAssertNil(Spellcheck.confidentCorrection(for: "teh", guesses: ["tea", "the"]))
        for word in ["Teh", "TEH", "ab", "don't", "abc123"] {
            XCTAssertNil(Spellcheck.confidentCorrection(for: word, guesses: ["the"]))
        }
        XCTAssertNil(Spellcheck.confidentCorrection(for: "jacobx", guesses: ["Jacobs"]))
        XCTAssertNil(Spellcheck.confidentCorrection(for: "teh", guesses: []))
    }

    func testCorrectionBoundariesExcludeContractionsAndAddresses() {
        for boundary in [" ", "\n", ".", ",", "!", "?", ";", ":"] {
            XCTAssertTrue(Spellcheck.isCorrectionBoundary(boundary))
        }
        for text in ["'", "’", "@", "/", "-", "_", "a", "", "hello"] {
            XCTAssertFalse(Spellcheck.isCorrectionBoundary(text))
        }
    }

    private func requireEnglish() throws {
        guard UITextChecker.availableLanguages.contains("en_US") else {
            throw XCTSkip("English dictionary unavailable")
        }
    }
}

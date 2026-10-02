import XCTest
import UIKit

/// Research probe, not an autocorrect feature: records what this OS actually returns.
@MainActor
final class SpellcheckerProbeTests: XCTestCase {
    func testNativeSpellingCandidates() throws {
        guard UITextChecker.availableLanguages.contains("en_US") else {
            throw XCTSkip("English dictionary is unavailable on this runtime")
        }
        let checker = UITextChecker()
        for word in ["teh", "recieve", "keyboar", "hi"] {
            let range = NSRange(word.startIndex..<word.endIndex, in: word)
            let misspelled = checker.rangeOfMisspelledWord(in: word, range: range,
                startingAt: 0, wrap: false, language: "en_US")
            let guesses = checker.guesses(forWordRange: range, in: word, language: "en_US") ?? []
            let completions = checker.completions(forPartialWordRange: range, in: word, language: "en_US") ?? []
            print("SPELLCHECK PROBE: \(word), misspelled=\(misspelled.location != NSNotFound), guesses=\(Array(guesses.prefix(5))), completions=\(Array(completions.prefix(5)))")
        }
    }
}

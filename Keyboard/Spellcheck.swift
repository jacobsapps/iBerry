import UIKit

/// Word-level spelling only. UIKit supplies candidates; we own the correction policy.
@MainActor
final class Spellcheck {
    private let checker = UITextChecker()
    private let language = "en_US"

    func suggestions(for word: String) -> [String] {
        guard UITextChecker.availableLanguages.contains(language) else { return [] }
        let range = NSRange(word.startIndex..<word.endIndex, in: word)
        let guesses = checker.guesses(forWordRange: range, in: word, language: language) ?? []
        let completions = checker.completions(forPartialWordRange: range, in: word, language: language) ?? []
        var result: [String] = []
        for candidate in guesses + completions {
            guard candidate != word, candidate.allSatisfy(Self.isWordCharacter),
                  !result.contains(candidate) else { continue }
            result.append(candidate)
        }
        return Array(result.prefix(2))
    }

    func automaticCorrection(for word: String) -> String? {
        guard UITextChecker.availableLanguages.contains(language) else { return nil }
        let range = NSRange(word.startIndex..<word.endIndex, in: word)
        guard checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0,
              wrap: false, language: language).location != NSNotFound else { return nil }
        // Check all spelling guesses, not just the two displayed suggestions or completions.
        let guesses = checker.guesses(forWordRange: range, in: word, language: language) ?? []
        return Self.confidentCorrection(for: word, guesses: guesses)
    }

    /// A conservative rule, not a probability: ambiguous candidates stay suggestions.
    static func confidentCorrection(for word: String, guesses: [String]) -> String? {
        guard word.count >= 3, word == word.lowercased(), word.allSatisfy({ $0.isLetter }),
              let first = guesses.first, first == first.lowercased(),
              first.allSatisfy({ $0.isLetter }), isSmallEdit(word, first) else { return nil }
        let nearby = Set(guesses.filter { isSmallEdit(word, $0) })
        // Swapped neighbors are stronger evidence than a different letter (teh → the, not ten).
        if isAdjacentSwap(word, first) {
            return nearby.filter { isAdjacentSwap(word, $0) }.count == 1 ? first : nil
        }
        // Other one-edit corrections need a longer word and no competing one-edit guess.
        return word.count >= 5 && nearby.count == 1 ? first : nil
    }

    static func isCorrectionBoundary(_ text: String) -> Bool {
        [" ", "\n", ".", ",", "!", "?", ";", ":"].contains(text)
    }

    static func currentWord(before: String?, after: String?, selection: String?) -> String? {
        guard selection?.isEmpty != false, let before, let last = before.last,
              isWordCharacter(last),
              after?.first.map({ isWordCharacter($0) || $0.isNumber }) != true else { return nil }
        let token = String(before.split(whereSeparator: { $0.isWhitespace }).last ?? "")
        // Skip URLs, email addresses, identifiers and mixed-number tokens entirely.
        guard !token.isEmpty, token.count <= 40, token.contains(where: { $0.isLetter }),
              token.allSatisfy(isWordCharacter) else { return nil }
        return token
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "'" || character == "’"
    }

    /// One substitution, insertion, deletion, or adjacent transposition (teh → the).
    static func isSmallEdit(_ original: String, _ candidate: String) -> Bool {
        let a = Array(original), b = Array(candidate)
        if a.count == b.count {
            let differences = a.indices.filter { a[$0] != b[$0] }
            if differences.count == 1 { return true }
            return isAdjacentSwap(original, candidate)
        }
        let shorter = a.count < b.count ? a : b
        let longer = a.count < b.count ? b : a
        guard longer.count == shorter.count + 1 else { return false }
        let mismatch = shorter.indices.first { shorter[$0] != longer[$0] } ?? shorter.count
        return Array(longer[..<mismatch]) + Array(longer[(mismatch + 1)...]) == shorter
    }

    private static func isAdjacentSwap(_ original: String, _ candidate: String) -> Bool {
        let a = Array(original), b = Array(candidate)
        guard a.count == b.count else { return false }
        let differences = a.indices.filter { a[$0] != b[$0] }
        guard differences.count == 2 else { return false }
        let i = differences[0], j = differences[1]
        return j == i + 1 && a[i] == b[j] && a[j] == b[i]
    }
}

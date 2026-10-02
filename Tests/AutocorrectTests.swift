import XCTest
import UIKit

/// Controller unit tests with an in-memory document; no simulator UI automation.
@MainActor
final class AutocorrectTests: XCTestCase {
    final class Document: NSObject, UITextDocumentProxy {
        var before = ""
        var after = ""
        var selectedText: String?
        var contextAvailable = true
        var autocorrectionType: UITextAutocorrectionType = .yes
        var keyboardType: UIKeyboardType = .default
        var documentContextBeforeInput: String? { contextAvailable ? before : nil }
        var documentContextAfterInput: String? { contextAvailable ? after : nil }
        var documentInputMode: UITextInputMode? { nil }
        let documentIdentifier = UUID()
        var hasText: Bool { !before.isEmpty || !after.isEmpty }
        func insertText(_ text: String) { before += text; selectedText = nil }
        func deleteBackward() {
            if selectedText != nil { selectedText = nil }
            else if !before.isEmpty { before.removeLast() }
        }
        func adjustTextPosition(byCharacterOffset offset: Int) {
            if offset < 0 {
                for _ in 0..<(-offset) where !before.isEmpty { after.insert(before.removeLast(), at: after.startIndex) }
            } else {
                for _ in 0..<offset where !after.isEmpty { before.append(after.removeFirst()) }
            }
        }
        func setMarkedText(_ markedText: String, selectedRange: NSRange) { insertText(markedText) }
        func unmarkText() {}
    }

    final class Keyboard: KeyboardViewController {
        let document = Document()
        override var textDocumentProxy: any UITextDocumentProxy { document }
    }

    func testEveryBoundaryCorrectsAndBackspaceRestoresTheOriginal() throws {
        try requireEnglish()
        for (title, boundary) in [("space", " "), ("return", "\n"), (".", "."), (",", ","),
                                  ("!", "!"), ("?", "?"), (";", ";"), (":", ":")] {
            let keyboard = makeKeyboard("hello teh")
            if boundary != " " && boundary != "\n" { try tap("123", on: keyboard) }
            try tap(title, on: keyboard)
            XCTAssertEqual(keyboard.document.before, "hello the" + boundary)
            try tap("Delete", on: keyboard)
            XCTAssertEqual(keyboard.document.before, "hello teh")
            try tap(title, on: keyboard)
            XCTAssertEqual(keyboard.document.before, "hello teh" + boundary, "Undo must prevent immediate recorrection")
        }
    }

    func testUncertainWordRemainsLiteralButStillHasSuggestions() throws {
        try requireEnglish()
        let keyboard = makeKeyboard("helo")
        let candidates = Spellcheck().suggestions(for: "helo")
        XCTAssertFalse(candidates.isEmpty)
        for candidate in candidates {
            XCTAssertTrue(buttons(in: keyboard.view).contains { $0.accessibilityLabel == "Replace helo with \(candidate)" })
        }
        try tap("space", on: keyboard)
        XCTAssertEqual(keyboard.document.before, "helo ")
    }

    func testExplicitSuggestionAndKeepOriginalStillWork() throws {
        try requireEnglish()
        let keyboard = makeKeyboard("teh")
        try tap("Replace teh with the", on: keyboard)
        XCTAssertEqual(keyboard.document.before, "the ")
        keyboard.document.before = "teh"
        keyboard.textDidChange(nil)
        try tap("Keep teh", on: keyboard)
        XCTAssertEqual(keyboard.document.before, "teh ")
    }

    func testHostOptOutAndAddressFieldsDoNotAutocorrect() throws {
        try requireEnglish()
        let keyboard = makeKeyboard("teh")
        keyboard.document.autocorrectionType = .no
        try tap("space", on: keyboard)
        XCTAssertEqual(keyboard.document.before, "teh ")
        for type: UIKeyboardType in [.URL, .emailAddress, .numberPad, .phonePad, .decimalPad, .asciiCapableNumberPad] {
            let keyboard = makeKeyboard("teh")
            keyboard.document.keyboardType = type
            try tap("space", on: keyboard)
            XCTAssertEqual(keyboard.document.before, "teh ")
        }
    }

    func testFurtherTypingOrChangedDocumentCannotUndoAnOldCorrection() throws {
        try requireEnglish()
        let keyboard = makeKeyboard("teh")
        try tap("space", on: keyboard)
        try tap("a", on: keyboard)
        try tap("Delete", on: keyboard)
        XCTAssertEqual(keyboard.document.before, "the ")

        keyboard.document.before = "teh"
        try tap("space", on: keyboard)
        keyboard.document.before = "different"
        try tap("Delete", on: keyboard)
        XCTAssertEqual(keyboard.document.before, "differen")
    }

    func testSelectionCursorAndMissingContextDoNotTriggerReplacement() throws {
        try requireEnglish()
        let keyboard = makeKeyboard("teh")
        keyboard.document.after = "rest"
        try tap("space", on: keyboard)
        XCTAssertEqual(keyboard.document.before, "teh ")
        XCTAssertEqual(keyboard.document.after, "rest")

        keyboard.document.before = "teh"
        keyboard.document.after = ""
        keyboard.document.selectedText = "selected"
        try tap("space", on: keyboard)
        XCTAssertEqual(keyboard.document.before, "teh ")

        keyboard.document.before = "teh"
        keyboard.document.contextAvailable = false
        try tap("space", on: keyboard)
        XCTAssertEqual(keyboard.document.before, "teh ")
    }

    private func makeKeyboard(_ text: String) -> Keyboard {
        let keyboard = Keyboard()
        keyboard.document.before = text
        keyboard.loadViewIfNeeded()
        return keyboard
    }

    private func buttons(in view: UIView) -> [KeyButton] {
        view.subviews.flatMap { ($0 as? KeyButton).map { [$0] } ?? buttons(in: $0) }
    }

    private func tap(_ label: String, on keyboard: Keyboard) throws {
        let button = try XCTUnwrap(buttons(in: keyboard.view).first { $0.accessibilityLabel == label }, label)
        XCTAssertTrue(button.accessibilityActivate())
    }

    private func requireEnglish() throws {
        guard UITextChecker.availableLanguages.contains("en_US") else { throw XCTSkip("English dictionary unavailable") }
    }
}

import UIKit

/// Assembles keys and spelling suggestions; edits only through the document proxy.
class KeyboardViewController: UIInputViewController {
    private let haptics = Haptics()
    private let rows = UIStackView()
    private let suggestionBar = UIStackView()
    private let spellcheck = Spellcheck()
    private var keptWord: String?
    private var undoCorrection: (original: String, inserted: String, before: String?, after: String?)?
    private var shifted = false
    private var symbols = false
    private var moreSymbols = false
    private var showsGlobe = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KeyButton.keyboardBackground
        rows.axis = .vertical
        rows.spacing = 12
        rows.distribution = .fillEqually
        rows.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rows)

        suggestionBar.distribution = .fillEqually
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(suggestionBar)

        // 44 pt suggestions above the unchanged four rows of key caps.
        let height = view.heightAnchor.constraint(equalToConstant: 260)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            height,
            suggestionBar.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            suggestionBar.heightAnchor.constraint(equalToConstant: 44),
            rows.topAnchor.constraint(greaterThanOrEqualTo: suggestionBar.bottomAnchor, constant: 8),
            rows.heightAnchor.constraint(equalToConstant: 204),
            rows.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
            rows.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 3),
            rows.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -3)
        ])
        buildKeys()
        updateSuggestions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        haptics.prepare()
        updateSuggestions()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if showsGlobe != needsInputModeSwitchKey { buildKeys() }
    }

    private func buildKeys() {
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        showsGlobe = needsInputModeSwitchKey
        let layout = symbols
            ? (moreSymbols ? ["[]{}#%^*+=", "_\\|~<>€£¥•", ".,?!'"]
                           : ["1234567890", "-/:;()$&@\"", ".,?!'"])
            : ["qwertyuiop", "asdfghjkl", "zxcvbnm"]

        for (index, letters) in layout.enumerated() {
            let row = makeRow()
            let characters = makeRow()
            for letter in letters {
                let text = shifted && !symbols ? String(letter).uppercased() : String(letter)
                characters.addArrangedSubview(key(text) { [weak self] in self?.insert(text) })
            }
            row.addArrangedSubview(characters)
            rows.addArrangedSubview(row)

            if index == 1 && !symbols {
                // Half a key inset at either side; letter widths stay identical.
                row.distribution = .fill
                row.spacing = 0
                let leading = UIView()
                let trailing = UIView()
                row.insertArrangedSubview(leading, at: 0)
                row.addArrangedSubview(trailing)
                leading.widthAnchor.constraint(equalTo: trailing.widthAnchor).isActive = true
                characters.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor,
                                                   multiplier: 0.9, constant: -6).isActive = true
            }
            if index == 2 {
                row.distribution = .equalSpacing
                characters.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor,
                                                   multiplier: 0.7, constant: -6).isActive = true
                let left = key(symbols ? (moreSymbols ? "123" : "#+=") : "Shift",
                               special: true) { [weak self] in
                    guard let self else { return }
                    if symbols { moreSymbols.toggle() } else { shifted.toggle() }
                    buildKeys()
                }
                if !symbols {
                    left.useSymbol(shifted ? "shift.fill" : "shift")
                    left.isSelected = shifted
                    left.accessibilityLabel = shifted ? "Shift on" : "Shift"
                }
                let delete = key("Delete", special: true) { [weak self] in
                    self?.delete()
                }
                delete.useSymbol("delete.left")
                row.insertArrangedSubview(left, at: 0)
                row.addArrangedSubview(delete)
                for modifier in [left, delete] {
                    modifier.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor,
                                                     multiplier: 0.12, constant: -3).isActive = true
                }
            }
        }

        let bottom = makeRow()
        rows.addArrangedSubview(bottom)
        bottom.distribution = .fill
        let mode = key(symbols ? "ABC" : "123", special: true) { [weak self] in
            guard let self else { return }
            symbols.toggle()
            moreSymbols = false
            buildKeys()
        }
        bottom.addArrangedSubview(mode)
        mode.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor,
                                    multiplier: showsGlobe ? 0.125 : 0.25, constant: -6).isActive = true
        if showsGlobe {
            let globe = key("Next keyboard", special: true) { [weak self] in self?.advanceToNextInputMode() }
            globe.useSymbol("globe")
            bottom.addArrangedSubview(globe)
            globe.widthAnchor.constraint(equalTo: mode.widthAnchor).isActive = true
        }
        bottom.addArrangedSubview(key("space") { [weak self] in self?.insert(" ") })
        let enter = key("return", special: true) { [weak self] in self?.insert("\n") }
        bottom.addArrangedSubview(enter)
        enter.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor,
                                     multiplier: 0.25, constant: -6).isActive = true
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateSuggestions()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        undoCorrection = nil
        keptWord = nil
        updateSuggestions()
    }

    private var currentWord: String? {
        switch textDocumentProxy.keyboardType {
        case .URL, .emailAddress, .numberPad, .phonePad, .decimalPad, .asciiCapableNumberPad:
            return nil
        default:
            return Spellcheck.currentWord(before: textDocumentProxy.documentContextBeforeInput,
                after: textDocumentProxy.documentContextAfterInput, selection: textDocumentProxy.selectedText)
        }
    }

    private func updateSuggestions() {
        suggestionBar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let word = currentWord
        let candidates = word.map { spellcheck.suggestions(for: $0) } ?? []
        let context = textDocumentProxy.documentContextBeforeInput
        let titles = word.map { ["“\($0)”"] + candidates } ?? []
        for index in 0..<3 {
            let title = index < titles.count ? titles[index] : ""
            let button = KeyButton(title, suggestion: true, haptics: haptics) { [weak self] in
                guard let self, let word, currentWord == word,
                      textDocumentProxy.documentContextBeforeInput == context else { return }
                if index == 0 {
                    keptWord = word
                    insert(" ")
                } else {
                    replace(word, with: candidates[index - 1])
                    textDocumentProxy.insertText(" ")
                    undoCorrection = nil
                    keptWord = nil
                    updateSuggestions()
                }
            }
            button.isEnabled = !title.isEmpty
            button.isAccessibilityElement = !title.isEmpty
            button.accessibilityLabel = index == 0 ? "Keep \(word ?? "")" : "Replace \(word ?? "") with \(title)"
            button.isSelected = index == 1 && !title.isEmpty
            suggestionBar.addArrangedSubview(button)
            if index < 2 {
                let divider = UIView()
                divider.backgroundColor = .separator
                divider.isUserInteractionEnabled = false
                divider.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(divider)
                NSLayoutConstraint.activate([
                    divider.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                    divider.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                    divider.widthAnchor.constraint(equalToConstant: 1),
                    divider.heightAnchor.constraint(equalToConstant: 24)
                ])
            }
        }
    }

    private func insert(_ text: String) {
        undoCorrection = nil
        let word = currentWord
        let correction = Spellcheck.isCorrectionBoundary(text) && word != keptWord && textDocumentProxy.autocorrectionType != .no
            ? word.flatMap { spellcheck.automaticCorrection(for: $0) } : nil
        if let word, let correction {
            replace(word, with: correction)
            textDocumentProxy.insertText(text)
            undoCorrection = (word, correction + text, textDocumentProxy.documentContextBeforeInput,
                              textDocumentProxy.documentContextAfterInput)
        } else {
            textDocumentProxy.insertText(text)
        }
        keptWord = nil
        if shifted {
            shifted = false
            buildKeys()
        }
        updateSuggestions()
    }

    private func delete() {
        if let undo = undoCorrection, let expectedBefore = undo.before,
           textDocumentProxy.selectedText?.isEmpty != false,
           textDocumentProxy.documentContextBeforeInput == expectedBefore,
           textDocumentProxy.documentContextAfterInput == undo.after {
            replace(undo.inserted, with: undo.original)
            keptWord = undo.original // Retyping a boundary keeps the spelling the user restored.
        } else {
            textDocumentProxy.deleteBackward()
            keptWord = nil
        }
        undoCorrection = nil
        updateSuggestions()
    }

    private func replace(_ word: String, with replacement: String) {
        for _ in word { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(replacement)
    }

    private func key(_ title: String, special: Bool = false,
                     action: @escaping () -> Void) -> KeyButton {
        KeyButton(title, special: special, haptics: haptics, action: action)
    }

    private func makeRow() -> UIStackView {
        let row = UIStackView()
        row.spacing = 6
        row.distribution = .fillEqually
        return row
    }
}

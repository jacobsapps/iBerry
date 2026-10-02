import UIKit

/// Knows how a press feels, but not what the key does.
final class KeyButton: UIButton {
    private let special: Bool
    private let suggestion: Bool

    init(_ title: String, special: Bool = false, suggestion: Bool = false, haptics: Haptics,
         action: @escaping () -> Void) {
        self.special = special
        self.suggestion = suggestion
        super.init(frame: .zero)

        // UIKit owns tracking: dragging out and back does not trigger another DOWN.
        addAction(UIAction { _ in haptics.heavy() }, for: .touchDown)
        addAction(UIAction { _ in
            haptics.heavy()
            action()
        }, for: .touchUpInside)
        addAction(UIAction { _ in haptics.heavy() }, for: .touchUpOutside)
        // Cancellation has no UP event and must not type anything.

        setTitle(title, for: .normal)
        setTitleColor(.label, for: .normal)
        let isLetter = title.first?.isLetter == true
        let isLowercase = title.first?.isLowercase == true
        let characterSize: CGFloat = isLetter && isLowercase ? 25 : 22
        titleLabel?.font = .systemFont(ofSize: title.count == 1 ? characterSize : (title == "#+=" ? 13.5 : 16))
        accessibilityLabel = title
        tintColor = .label
        layer.cornerRadius = 5
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        if suggestion {
            titleLabel?.font = .systemFont(ofSize: 17)
            titleLabel?.adjustsFontSizeToFitWidth = true
            titleLabel?.minimumScaleFactor = 0.7
            layer.shadowOpacity = 0
        }
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("Use init(_:special:haptics:action:)") }

    override var isHighlighted: Bool {
        didSet { updateAppearance() }
    }

    // Match the keyboard, not generic grouped-table colors.
    static let keyboardBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 43 / 255, alpha: 1)
            : UIColor(red: 208 / 255, green: 211 / 255, blue: 218 / 255, alpha: 1)
    }

    private func updateAppearance() {
        if suggestion {
            backgroundColor = isHighlighted ? .tertiarySystemFill : .clear
            titleLabel?.font = .systemFont(ofSize: 17, weight: isSelected ? .medium : .regular)
            return
        }
        tintColor = isSelected ? .black : .label
        if isSelected {
            backgroundColor = .white
            return
        }
        let modifier = special && !isSelected
        let highlighted = isHighlighted
        backgroundColor = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(white: (modifier != highlighted ? 70 : 107) / 255, alpha: 1)
            }
            return modifier != highlighted
                ? UIColor(red: 169 / 255, green: 175 / 255, blue: 188 / 255, alpha: 1)
                : .white
        }
    }

    override func layoutSubviews() {
        titleLabel?.transform = .identity
        super.layoutSubviews()
        // Optical alignment from the native reference; capitals/digits stay centered.
        if !suggestion, currentTitle?.count == 1, let character = currentTitle?.first {
            let lift: CGFloat = character.isLowercase ? -3 :
                (character.isLetter || character.isNumber ? 0 : -1.5)
            titleLabel?.transform = CGAffineTransform(translationX: 0, y: lift)
        }
    }

    func useSymbol(_ name: String) {
        setTitle(nil, for: .normal)
        setImage(UIImage(systemName: name, withConfiguration:
            UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)), for: .normal)
    }

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    // Fill half the visual gutters without shrinking the visible key caps.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -3, dy: -6).contains(point)
    }

    override func accessibilityActivate() -> Bool {
        sendActions(for: .touchDown)
        sendActions(for: .touchUpInside)
        return true
    }
}

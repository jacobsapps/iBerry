import XCTest
import UIKit

@MainActor
final class KeyboardTests: XCTestCase {
    final class GeneratorSpy: UIImpactFeedbackGenerator {
        var events: [String] = []
        override func prepare() { events.append("prepare") }
        override func impactOccurred(intensity: CGFloat) {
            events.append("heavy:\(intensity)")
        }
    }

    func testDownAndUpRequestTwoImpactsThenType() {
        let generator = GeneratorSpy(style: .heavy)
        let key = KeyButton("a", haptics: Haptics(generator: generator)) {
            generator.events.append("type")
        }
        key.sendActions(for: .touchDown)
        XCTAssertEqual(generator.events, ["heavy:1.0", "prepare"])
        key.sendActions(for: .touchUpInside)
        XCTAssertEqual(generator.events, ["heavy:1.0", "prepare", "heavy:1.0", "prepare", "type"])
    }

    func testOutsideReleaseHasSecondImpactButDoesNotType() {
        let generator = GeneratorSpy(style: .heavy)
        let key = KeyButton("a", haptics: Haptics(generator: generator)) { XCTFail("Must not type") }
        key.sendActions(for: .touchDown)
        key.sendActions(for: .touchUpOutside)
        XCTAssertEqual(generator.events, ["heavy:1.0", "prepare", "heavy:1.0", "prepare"])
    }

    func testDraggingDoesNotAddImpacts() {
        let generator = GeneratorSpy(style: .heavy)
        let key = KeyButton("a", haptics: Haptics(generator: generator)) {}
        key.sendActions(for: .touchDown)
        key.sendActions(for: .touchDragExit)
        key.sendActions(for: .touchDragEnter)
        key.sendActions(for: .touchDragInside)
        XCTAssertEqual(generator.events, ["heavy:1.0", "prepare"])
        key.sendActions(for: .touchUpInside)
        XCTAssertEqual(generator.events.count, 4)
    }

    func testCancellationDoesNotTypeOrAddAnImpact() {
        let generator = GeneratorSpy(style: .heavy)
        var typed = 0
        let key = KeyButton("a", haptics: Haptics(generator: generator)) { typed += 1 }
        key.sendActions(for: .touchDown)
        key.sendActions(for: .touchCancel)
        XCTAssertEqual(generator.events, ["heavy:1.0", "prepare"])
        XCTAssertEqual(typed, 0)
        key.sendActions(for: .touchDown)
        key.sendActions(for: .touchUpInside)
        XCTAssertEqual(typed, 1)
        XCTAssertEqual(generator.events.count, 6)
    }

    func testAccessibilityActivationUsesBothEdges() {
        let generator = GeneratorSpy(style: .heavy)
        let key = KeyButton("a", haptics: Haptics(generator: generator)) {
            generator.events.append("type")
        }
        XCTAssertTrue(key.accessibilityActivate())
        XCTAssertEqual(generator.events, ["heavy:1.0", "prepare", "heavy:1.0", "prepare", "type"])
    }

    func testPreparingDoesNotPlayAnImpact() {
        let generator = GeneratorSpy(style: .heavy)
        Haptics(generator: generator).prepare()
        XCTAssertEqual(generator.events, ["prepare"])
    }

    func testKeyboardBuildsLettersShiftAndSymbols() throws {
        let keyboard = KeyboardViewController()
        keyboard.loadViewIfNeeded()
        func keys(_ view: UIView) -> [KeyButton] {
            view.subviews.flatMap { ($0 as? KeyButton).map { [$0] } ?? keys($0) }
        }
        func key(_ label: String) throws -> KeyButton {
            try XCTUnwrap(keys(keyboard.view).first { $0.accessibilityLabel == label }, label)
        }
        XCTAssertEqual(keys(keyboard.view).filter { $0.currentTitle?.count == 1 && $0.currentTitle!.first!.isLetter == true }.count, 26)
        try key("Shift").sendActions(for: .touchUpInside)
        XCTAssertNotNil(try key("Q"))
        XCTAssertNotNil(try key("Shift on"))
        try key("123").sendActions(for: .touchUpInside)
        XCTAssertNotNil(try key("1"))
        XCTAssertNotNil(try key("Delete"))
        XCTAssertNotNil(try key("space"))
        XCTAssertNotNil(try key("return"))
        try key("ABC").sendActions(for: .touchUpInside)
        XCTAssertNotNil(try key("Q"))
    }
    func testLetterGeometryMatchesAcrossRowsAndPhoneWidths() throws {
        for width: CGFloat in [320, 375, 390, 430] {
            let keyboard = KeyboardViewController()
            keyboard.loadViewIfNeeded()
            keyboard.view.frame = CGRect(x: 0, y: 0, width: width, height: 260)
            keyboard.view.layoutIfNeeded()
            func keys(_ view: UIView) -> [KeyButton] {
                view.subviews.flatMap { ($0 as? KeyButton).map { [$0] } ?? keys($0) }
            }
            let letters = keys(keyboard.view).filter {
                $0.currentTitle?.count == 1 && $0.currentTitle?.first?.isLetter == true
            }
            XCTAssertEqual(letters.count, 26)
            for key in letters {
                XCTAssertEqual(key.bounds.height, 42, accuracy: 0.5)
                XCTAssertEqual(key.bounds.width, width / 10 - 6, accuracy: 0.5)
            }
        }
    }

    func testSymbolsHaveTenKeysInSecondRowAndAWorkingSecondPage() throws {
        let keyboard = KeyboardViewController()
        keyboard.loadViewIfNeeded()
        func keys(_ view: UIView) -> [KeyButton] {
            view.subviews.flatMap { ($0 as? KeyButton).map { [$0] } ?? keys($0) }
        }
        func tap(_ title: String) throws {
            try XCTUnwrap(keys(keyboard.view).first { $0.currentTitle == title })
                .sendActions(for: .touchUpInside)
        }
        try tap("123")
        XCTAssertTrue(keys(keyboard.view).contains { $0.currentTitle == "\"" })
        try tap("#+=")
        XCTAssertTrue(keys(keyboard.view).contains { $0.currentTitle == "[" })
        try tap("ABC")
        XCTAssertTrue(keys(keyboard.view).contains { $0.currentTitle == "q" })
    }

    func testKeyHitAreaIncludesHalfTheGutter() {
        let key = KeyButton("a", haptics: Haptics(generator: GeneratorSpy(style: .heavy))) {}
        key.frame = CGRect(x: 0, y: 0, width: 31.5, height: 42)
        XCTAssertTrue(key.point(inside: CGPoint(x: -2, y: 20), with: nil))
        XCTAssertTrue(key.point(inside: CGPoint(x: 15, y: 46), with: nil))
        XCTAssertFalse(key.point(inside: CGPoint(x: -4, y: 20), with: nil))
    }

    func testNativeTypographyAndLayoutDoNotAccumulateOffsets() {
        for (title, size, offset): (String, CGFloat, CGFloat) in [
            ("q", 25, -3), ("Q", 22, 0), ("1", 22, 0), ("@", 22, -1.5), ("#+=", 13.5, 0)
        ] {
            let key = KeyButton(title, haptics: Haptics(generator: GeneratorSpy(style: .heavy))) {}
            key.frame = CGRect(x: 0, y: 0, width: 42, height: 42)
            for _ in 0..<3 {
                key.setNeedsLayout()
                key.layoutIfNeeded()
                XCTAssertEqual(key.titleLabel?.font.pointSize, size)
                XCTAssertEqual(key.titleLabel?.transform.ty, offset)
            }
        }
    }

    func testPressHighlightRestoresWithoutPlayingExtraImpacts() throws {
        let generator = GeneratorSpy(style: .heavy)
        let key = KeyButton("a", haptics: Haptics(generator: generator)) {}
        let light = UITraitCollection(userInterfaceStyle: .light)
        let original = try XCTUnwrap(key.backgroundColor).resolvedColor(with: light)
        key.isHighlighted = true
        XCTAssertNotEqual(key.backgroundColor?.resolvedColor(with: light), original)
        key.isHighlighted = false
        XCTAssertEqual(key.backgroundColor?.resolvedColor(with: light), original)
        XCTAssertTrue(generator.events.isEmpty)
    }

    func testSelectedShiftStaysWhiteInDarkAppearance() throws {
        let key = KeyButton("Shift", special: true, haptics: Haptics(generator: GeneratorSpy(style: .heavy))) {}
        key.useSymbol("shift.fill")
        key.isSelected = true
        XCTAssertEqual(key.backgroundColor?.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)), .white)
        XCTAssertEqual(key.tintColor, .black)
    }

    func testSuggestionUsesQuietAppearanceAndTheSameHapticPair() {
        let generator = GeneratorSpy(style: .heavy)
        let key = KeyButton("the", suggestion: true, haptics: Haptics(generator: generator)) {
            generator.events.append("replace")
        }
        key.isSelected = true
        XCTAssertEqual(key.backgroundColor, .clear)
        XCTAssertEqual(key.layer.shadowOpacity, 0)
        XCTAssertEqual(key.titleLabel?.font.pointSize, 17)
        key.sendActions(for: .touchDown)
        key.sendActions(for: .touchUpInside)
        XCTAssertEqual(generator.events, ["heavy:1.0", "prepare", "heavy:1.0", "prepare", "replace"])
        key.isHighlighted = true
        XCTAssertNotEqual(key.backgroundColor, .clear)
        key.isHighlighted = false
        XCTAssertEqual(key.backgroundColor, .clear)
    }

}

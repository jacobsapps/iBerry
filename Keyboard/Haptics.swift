import UIKit

/// One generator, shared by every key in this keyboard.
@MainActor
final class Haptics {
    private let generator: UIImpactFeedbackGenerator

    init(generator: UIImpactFeedbackGenerator? = nil) {
        self.generator = generator ?? UIImpactFeedbackGenerator(style: .heavy)
    }

    func prepare() {
        generator.prepare()
    }

    func heavy() {
        generator.impactOccurred(intensity: 1)
        generator.prepare()
    }
}

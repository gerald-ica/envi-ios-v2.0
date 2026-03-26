import SwiftUI

// MARK: - ENVI Animation Presets

extension Animation {
    /// Default spring for interactive transitions — snappy yet organic.
    static let enviSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)

    /// Quick ease-out for dismiss / collapse motions.
    static let enviEaseOut = Animation.easeOut(duration: 0.25)

    /// Soft ease-in for fade-in appearances.
    static let enviFadeIn = Animation.easeIn(duration: 0.3)

    /// Slower ease-in-out for ambient / background animations.
    static let enviSlow = Animation.easeInOut(duration: 0.6)
}

// MARK: - ENVI Transition Presets

extension AnyTransition {
    /// Slide from trailing on insertion, slide to leading on removal — with opacity.
    static let enviSlide = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    /// Simple opacity fade using the ENVI fade-in curve.
    static let enviFade = AnyTransition.opacity.animation(.enviFadeIn)
}

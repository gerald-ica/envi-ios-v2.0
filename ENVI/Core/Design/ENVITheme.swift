import SwiftUI
import UIKit

/// Central design token store for the ENVI design system.
/// Contains all color definitions for light and dark modes,
/// plus gradient and shadow presets.
enum ENVITheme {

    // MARK: - Light Mode Colors
    enum Light {
        static let background   = Color(hex: "#FAF9F6")
        static let surfaceLow   = Color(hex: "#F4F3F0")
        static let surfaceHigh  = Color(hex: "#E9E8E5")
        static let text         = Color(hex: "#484551")
        static let textLight    = Color(hex: "#7A7786")
        static let primary      = Color(hex: "#30217C")
        static let secondary    = Color(hex: "#4646D8")
        static let border       = Color(hex: "#E0DFDc")
    }

    // MARK: - Dark Mode Colors
    enum Dark {
        static let background   = Color(hex: "#0A0A0F")
        static let surfaceLow   = Color(hex: "#1A1A2E")
        static let surfaceHigh  = Color(hex: "#252540")
        static let text         = Color.white
        static let textLight    = Color.white.opacity(0.55)
        static let primary      = Color(hex: "#7B68EE")
        static let secondary    = Color(hex: "#9B8AFB")
        static let border       = Color.white.opacity(0.12)
    }

    // MARK: - Semantic Colors (adapt to current scheme)
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.background : Light.background
    }

    static func surfaceLow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.surfaceLow : Light.surfaceLow
    }

    static func surfaceHigh(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.surfaceHigh : Light.surfaceHigh
    }

    static func text(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.text : Light.text
    }

    static func textLight(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.textLight : Light.textLight
    }

    static func primary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.primary : Light.primary
    }

    static func secondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.secondary : Light.secondary
    }

    static func border(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.border : Light.border
    }

    // MARK: - Status Colors
    static let success  = Color(hex: "#22C55E")
    static let warning  = Color(hex: "#F59E0B")
    static let error    = Color(hex: "#EF4444")
    static let info     = Color(hex: "#3B82F6")

    // MARK: - Gradients
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "#7B68EE"), Color(hex: "#9B8AFB")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardOverlayGradient = LinearGradient(
        colors: [.clear, .black.opacity(0.7)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Shadows
    enum Shadow {
        static let card = (color: Color.black.opacity(0.12), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(4))
        static let elevated = (color: Color.black.opacity(0.2), radius: CGFloat(24), x: CGFloat(0), y: CGFloat(8))
    }

    // MARK: - UIKit Colors
    enum UIKit {
        static let backgroundDark   = UIColor(hex: "#0A0A0F")
        static let surfaceLowDark   = UIColor(hex: "#1A1A2E")
        static let surfaceHighDark  = UIColor(hex: "#252540")
        static let primaryDark      = UIColor(hex: "#7B68EE")
        static let secondaryDark    = UIColor(hex: "#9B8AFB")
        static let textDark         = UIColor.white
        static let textLightDark    = UIColor.white.withAlphaComponent(0.55)
    }
}

import SwiftUI
import UIKit

/// Central design token store for the ENVI design system.
/// Monochromatic palette: black, white, and neutral grays.
/// Accent #30217C used sparingly in subtle dark gradients only (max 20%).
enum ENVITheme {

    // MARK: - Light Mode Colors
    enum Light {
        static let background   = Color(hex: "#FFFFFF")
        static let surfaceLow   = Color(hex: "#F4F4F4")
        static let surfaceHigh  = Color(hex: "#E8E8E8")
        static let text         = Color(hex: "#000000")
        static let textSecondary = Color.black.opacity(0.7)
        static let textLight    = Color.black.opacity(0.5)
        static let primary      = Color(hex: "#000000")
        static let secondary    = Color.black.opacity(0.7)
        static let border       = Color.black.opacity(0.12)
        static let accent       = Color(hex: "#30217C")
    }

    // MARK: - Dark Mode Colors
    enum Dark {
        static let background   = Color(hex: "#000000")
        static let surfaceLow   = Color(hex: "#1A1A1A")
        static let surfaceHigh  = Color(hex: "#2A2A2A")
        static let text         = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let primary      = Color.white
        static let secondary    = Color.white.opacity(0.7)
        static let border       = Color.white.opacity(0.12)
        static let accent       = Color(hex: "#30217C")
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

    static func textSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.textSecondary : Light.textSecondary
    }

    /// Kept for backward compat — maps to textSecondary
    static func textLight(for scheme: ColorScheme) -> Color {
        textSecondary(for: scheme)
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

    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.accent : Light.accent
    }

    // MARK: - Status Colors (data contexts only — charts, metrics)
    static let success  = Color(hex: "#22C55E")
    static let warning  = Color(hex: "#F59E0B")
    static let error    = Color(hex: "#EF4444")
    static let info     = Color(hex: "#3B82F6")

    // MARK: - Social Platform Colors (from Sketch design system)
    static let instagram = Color(hex: "#E4405E")
    static let tiktok    = Color(hex: "#25EFE6")
    static let twitter   = Color(hex: "#1CA1F1")
    static let linkedin  = Color(hex: "#0A66C1")

    // MARK: - Neutral
    static let neutral   = Color(hex: "#545454")

    // MARK: - Gradients
    /// Primary gradient — monochromatic white for dark mode
    static let primaryGradient = LinearGradient(
        colors: [Color.white, Color.white.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Card overlay gradient — black overlay on images (fine as-is)
    static let cardOverlayGradient = LinearGradient(
        colors: [.clear, .black.opacity(0.7)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Accent gradient — only for specific dark sections, max 20% coverage
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "#1A1A1A"), Color(hex: "#30217C").opacity(0.2)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Shadows
    enum Shadow {
        static let card = (color: Color.black.opacity(0.12), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(4))
        static let elevated = (color: Color.black.opacity(0.2), radius: CGFloat(24), x: CGFloat(0), y: CGFloat(8))
    }

    // MARK: - UIKit Colors (monochromatic, matching SwiftUI tokens)
    enum UIKit {
        static let backgroundDark   = UIColor(hex: "#000000")
        static let surfaceLowDark   = UIColor(hex: "#1A1A1A")
        static let surfaceHighDark  = UIColor(hex: "#2A2A2A")
        static let primaryDark      = UIColor.white
        static let secondaryDark    = UIColor.white.withAlphaComponent(0.7)
        static let textDark         = UIColor.white
        static let textLightDark    = UIColor.white.withAlphaComponent(0.7)
    }
}

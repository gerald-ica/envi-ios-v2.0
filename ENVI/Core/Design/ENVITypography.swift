import SwiftUI
import UIKit
import CoreText

/// Typography tokens for the ENVI design system.
/// Manages font registration and provides semantic text styles.
enum ENVITypography {

    // MARK: - Font Names
    static let interRegular   = "Inter-Regular"
    static let interMedium    = "Inter-Medium"
    static let interSemiBold  = "Inter-SemiBold"
    static let interBold      = "Inter-Bold"
    static let interExtraBold = "Inter-ExtraBold"
    static let interBlack     = "Inter-Black"
    static let spaceMono      = "SpaceMono-Regular"
    static let spaceMonoBold  = "SpaceMono-Bold"

    // MARK: - Text Styles (SwiftUI)
    enum Style {
        case displayLarge    // Inter Black 32
        case displayMedium   // Inter ExtraBold 28
        case heading         // Inter Bold 22
        case subheading      // Inter SemiBold 17
        case body            // Inter Regular 15
        case caption         // Inter Medium 13
        case label           // Space Mono 11, uppercased, tracking 0.08em
        case badge           // Space Mono Bold 10, uppercased

        var font: Font {
            switch self {
            case .displayLarge:  return .interBlack(32)
            case .displayMedium: return .interExtraBold(28)
            case .heading:       return .interBold(22)
            case .subheading:    return .interSemiBold(17)
            case .body:          return .interRegular(15)
            case .caption:       return .interMedium(13)
            case .label:         return .spaceMono(11)
            case .badge:         return .spaceMonoBold(10)
            }
        }

        var uiFont: UIFont {
            switch self {
            case .displayLarge:  return .interBlack(32)
            case .displayMedium: return .interExtraBold(28)
            case .heading:       return .interBold(22)
            case .subheading:    return .interSemiBold(17)
            case .body:          return .interRegular(15)
            case .caption:       return .interMedium(13)
            case .label:         return .spaceMono(11)
            case .badge:         return .spaceMonoBold(10)
            }
        }

        var tracking: CGFloat? {
            switch self {
            case .label: return 0.88  // 0.08em * 11pt
            case .badge: return 0.80  // 0.08em * 10pt
            default: return nil
            }
        }

        var isUppercased: Bool {
            switch self {
            case .label, .badge: return true
            default: return false
            }
        }
    }

    // MARK: - Font Registration
    /// Register custom fonts from the bundle at app launch.
    static func registerFonts() {
        let fontNames = [
            "Inter-Regular", "Inter-Medium", "Inter-SemiBold",
            "Inter-Bold", "Inter-ExtraBold", "Inter-Black",
            "SpaceMono-Regular", "SpaceMono-Bold",
            "SpaceMono-Italic", "SpaceMono-BoldItalic"
        ]

        for fontName in fontNames {
            if let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
            }
        }
    }
}

// MARK: - SwiftUI View Extension
extension View {
    func enviTextStyle(_ style: ENVITypography.Style) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking ?? 0)
    }
}

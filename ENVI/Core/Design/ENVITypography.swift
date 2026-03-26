import SwiftUI
import UIKit
import CoreText

/// Typography tokens for the ENVI design system.
/// Space Mono = headings, display, labels, nav, buttons, tags → ALL UPPERCASE
/// Inter = body text, descriptions, placeholders → sentence case
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
        case displayLarge    // SpaceMono-Bold 32, uppercase, tracking: -2px
        case displayMedium   // SpaceMono-Bold 28, uppercase, tracking: -1.5px
        case heading         // SpaceMono-Bold 22, uppercase, tracking: -1px
        case subheading      // SpaceMono-Regular 17, uppercase, tracking: +0.5px
        case body            // Inter-Regular 15, sentence case, tracking: +0.3px
        case caption         // Inter-Medium 13, sentence case, tracking: +0.5px
        case label           // SpaceMono-Bold 11, uppercase, tracking: +2.5px
        case badge           // SpaceMono-Bold 10, uppercase, tracking: +2px

        var font: Font {
            switch self {
            case .displayLarge:  return .spaceMonoBold(32)
            case .displayMedium: return .spaceMonoBold(28)
            case .heading:       return .spaceMonoBold(22)
            case .subheading:    return .spaceMono(17)
            case .body:          return .interRegular(15)
            case .caption:       return .interMedium(13)
            case .label:         return .spaceMonoBold(11)
            case .badge:         return .spaceMonoBold(10)
            }
        }

        var uiFont: UIFont {
            switch self {
            case .displayLarge:  return .spaceMonoBold(32)
            case .displayMedium: return .spaceMonoBold(28)
            case .heading:       return .spaceMonoBold(22)
            case .subheading:    return .spaceMono(17)
            case .body:          return .interRegular(15)
            case .caption:       return .interMedium(13)
            case .label:         return .spaceMonoBold(11)
            case .badge:         return .spaceMonoBold(10)
            }
        }

        var tracking: CGFloat {
            switch self {
            case .displayLarge:  return -2.0
            case .displayMedium: return -1.5
            case .heading:       return -1.0
            case .subheading:    return 0.5
            case .body:          return 0.3
            case .caption:       return 0.5
            case .label:         return 2.5
            case .badge:         return 2.0
            }
        }

        var isUppercased: Bool {
            switch self {
            case .displayLarge, .displayMedium, .heading, .subheading, .label, .badge:
                return true
            case .body, .caption:
                return false
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
            .tracking(style.tracking)
    }
}

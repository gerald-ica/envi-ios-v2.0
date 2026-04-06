import Foundation
import SwiftUI

// MARK: - ENVI-0751 App Theme

/// A selectable visual theme defining the app's color palette.
struct AppTheme: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var primaryColor: String
    var accentColor: String
    var isDark: Bool

    /// Resolved SwiftUI primary color.
    var primary: Color { Color(hex: primaryColor) }

    /// Resolved SwiftUI accent color.
    var accent: Color { Color(hex: accentColor) }
}

extension AppTheme {
    static let builtIn: [AppTheme] = [
        AppTheme(id: "theme-mono", name: "Monochrome", primaryColor: "#000000", accentColor: "#30217C", isDark: false),
        AppTheme(id: "theme-dark", name: "Midnight", primaryColor: "#FFFFFF", accentColor: "#30217C", isDark: true),
        AppTheme(id: "theme-ocean", name: "Ocean", primaryColor: "#0A3D62", accentColor: "#3B82F6", isDark: true),
        AppTheme(id: "theme-forest", name: "Forest", primaryColor: "#1B4332", accentColor: "#22C55E", isDark: true),
        AppTheme(id: "theme-sunset", name: "Sunset", primaryColor: "#7C2D12", accentColor: "#F59E0B", isDark: false),
    ]
}

// MARK: - ENVI-0752 Accessibility Settings

/// User-configurable accessibility preferences.
struct AccessibilitySettings: Codable, Equatable {
    var textScale: Double
    var reduceMotion: Bool
    var highContrast: Bool
    var voiceOverHints: Bool

    static let `default` = AccessibilitySettings(
        textScale: 1.0,
        reduceMotion: false,
        highContrast: false,
        voiceOverHints: true
    )
}

// MARK: - ENVI-0753 Haptic Feedback

/// Haptic feedback intensity and context variants.
enum HapticFeedback: String, Codable, CaseIterable, Identifiable {
    case light
    case medium
    case heavy
    case selection
    case success
    case error

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// Trigger the corresponding UIKit haptic.
    func fire() {
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - ENVI-0754 Onboarding Tooltip

/// A contextual tooltip shown during feature onboarding.
struct OnboardingTooltip: Identifiable, Codable, Equatable {
    let id: String
    var targetView: String
    var message: String
    var priority: Int
}

extension OnboardingTooltip {
    static let mock: [OnboardingTooltip] = [
        OnboardingTooltip(id: "tip-feed", targetView: "FeedView", message: "Swipe to explore trending content", priority: 1),
        OnboardingTooltip(id: "tip-analytics", targetView: "AnalyticsView", message: "Track your performance metrics here", priority: 2),
        OnboardingTooltip(id: "tip-schedule", targetView: "ScheduleView", message: "Drag posts to reschedule them", priority: 3),
    ]
}

// MARK: - ENVI-0755 Deep Link Route

/// A parsed deep link route with path components and query parameters.
struct DeepLinkRoute: Identifiable, Codable, Equatable {
    var id: String { path }
    var path: String
    var parameters: [String: String]
    var handler: String
}

extension DeepLinkRoute {
    static let mock: [DeepLinkRoute] = [
        DeepLinkRoute(path: "/post/detail", parameters: ["postId": "abc-123"], handler: "PostDetailHandler"),
        DeepLinkRoute(path: "/profile", parameters: ["userId": "user-42"], handler: "ProfileHandler"),
        DeepLinkRoute(path: "/settings/theme", parameters: [:], handler: "ThemeHandler"),
    ]
}

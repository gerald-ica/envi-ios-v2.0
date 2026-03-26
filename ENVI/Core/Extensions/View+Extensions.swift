import SwiftUI

extension View {
    /// Apply ENVI card shadow
    func enviCardShadow() -> some View {
        self.shadow(
            color: ENVITheme.Shadow.card.color,
            radius: ENVITheme.Shadow.card.radius,
            x: ENVITheme.Shadow.card.x,
            y: ENVITheme.Shadow.card.y
        )
    }

    /// Apply ENVI elevated shadow
    func enviElevatedShadow() -> some View {
        self.shadow(
            color: ENVITheme.Shadow.elevated.color,
            radius: ENVITheme.Shadow.elevated.radius,
            x: ENVITheme.Shadow.elevated.x,
            y: ENVITheme.Shadow.elevated.y
        )
    }

    /// Conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Apply preferred color scheme from ThemeManager
    func enviTheme(_ themeManager: ThemeManager) -> some View {
        self.preferredColorScheme(themeManager.colorScheme)
    }
}

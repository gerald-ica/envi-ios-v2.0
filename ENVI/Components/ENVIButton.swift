import SwiftUI

/// ENVI design system button with primary, secondary, outline, and ghost variants.
/// Monochromatic palette. Space Mono Bold, UPPERCASE text.
/// Supports loading state (spinner) and leading SF Symbol icon.
struct ENVIButton: View {
    enum Style {
        case primary
        case secondary
        case outline
        case ghost
    }

    let title: String
    let style: Style
    let isFullWidth: Bool
    let isEnabled: Bool
    let isLoading: Bool
    let icon: String?
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// Backwards-compatible initialiser that maps the old `variant` name to `style`.
    init(
        _ title: String,
        variant: Style = .primary,
        style: Style? = nil,
        isFullWidth: Bool = true,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style ?? variant
        self.isFullWidth = isFullWidth
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: ENVISpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(title.uppercased())
                        .font(.spaceMonoBold(15))
                        .tracking(1.0)
                }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, ENVISpacing.xxl)
            .padding(.vertical, ENVISpacing.lg)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(borderColor, lineWidth: hasBorder ? 1.5 : 0)
            )
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.5)
    }

    private var hasBorder: Bool {
        style == .secondary || style == .outline
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return colorScheme == .dark ? .white : .black
        case .secondary:
            return .clear
        case .outline:
            return .clear
        case .ghost:
            return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return colorScheme == .dark ? .black : .white
        case .secondary:
            return ENVITheme.text(for: colorScheme)
        case .outline:
            return ENVITheme.text(for: colorScheme)
        case .ghost:
            return ENVITheme.textLight(for: colorScheme)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return .clear
        case .secondary:
            return ENVITheme.text(for: colorScheme)
        case .outline:
            return ENVITheme.border(for: colorScheme)
        case .ghost:
            return .clear
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ENVIButton("Continue", variant: .primary) {}
        ENVIButton("Skip", variant: .secondary) {}
        ENVIButton("Outline", style: .outline) {}
        ENVIButton("Cancel", variant: .ghost) {}
        ENVIButton("With Icon", icon: "arrow.right") {}
        ENVIButton("Loading", isLoading: true) {}
        ENVIButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .preferredColorScheme(.dark)
}

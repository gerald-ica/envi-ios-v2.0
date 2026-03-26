import SwiftUI

/// ENVI design system button with primary, secondary, and ghost variants.
struct ENVIButton: View {
    enum Variant {
        case primary
        case secondary
        case ghost
    }

    let title: String
    let variant: Variant
    let isFullWidth: Bool
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    init(
        _ title: String,
        variant: Variant = .primary,
        isFullWidth: Bool = true,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.isFullWidth = isFullWidth
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.interSemiBold(15))
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.horizontal, ENVISpacing.xxl)
                .padding(.vertical, ENVISpacing.lg)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(borderColor, lineWidth: variant == .secondary ? 1.5 : 0)
                )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return ENVITheme.primary(for: colorScheme)
        case .secondary:
            return .clear
        case .ghost:
            return .clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return ENVITheme.primary(for: colorScheme)
        case .ghost:
            return ENVITheme.textLight(for: colorScheme)
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary:
            return .clear
        case .secondary:
            return ENVITheme.primary(for: colorScheme)
        case .ghost:
            return .clear
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ENVIButton("Continue", variant: .primary) {}
        ENVIButton("Skip", variant: .secondary) {}
        ENVIButton("Cancel", variant: .ghost) {}
        ENVIButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .preferredColorScheme(.dark)
}

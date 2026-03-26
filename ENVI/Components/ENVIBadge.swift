import SwiftUI

/// Small status badge for the ENVI design system.
/// Monochromatic colors only — no colored badges.
struct ENVIBadge: View {
    let text: String
    var style: BadgeStyle = .standard

    enum BadgeStyle {
        case standard   // white/0.15 bg, white text (dark) or black/0.1 bg, black text (light)
        case inverted   // white bg, black text (dark) or black bg, white text (light)
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text.uppercased())
            .font(.spaceMonoBold(10))
            .tracking(2.0)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private var foregroundColor: Color {
        switch style {
        case .standard:
            return colorScheme == .dark ? .white : .black
        case .inverted:
            return colorScheme == .dark ? .black : .white
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .standard:
            return colorScheme == .dark
                ? Color.white.opacity(0.15)
                : Color.black.opacity(0.1)
        case .inverted:
            return colorScheme == .dark ? .white : .black
        }
    }
}

/// Legacy initializer for backward compat — color param is ignored, always monochromatic.
extension ENVIBadge {
    init(text: String, color: Color) {
        self.text = text
        self.style = .standard
    }
}

#Preview {
    HStack {
        ENVIBadge(text: "Connected")
        ENVIBadge(text: "New", style: .inverted)
        ENVIBadge(text: "Live")
    }
    .preferredColorScheme(.dark)
}

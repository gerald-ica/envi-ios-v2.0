import SwiftUI

/// Filter or action chip for the ENVI design system.
/// Monochromatic. Space Mono, UPPERCASE text. 8px radius.
struct ENVIChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.spaceMonoBold(11))
                .tracking(1.5)
                .foregroundColor(chipForeground)
                .padding(.horizontal, ENVISpacing.lg)
                .padding(.vertical, ENVISpacing.sm)
                .background(chipBackground)
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(chipBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var chipForeground: Color {
        if isSelected {
            return colorScheme == .dark ? .black : .white
        }
        return ENVITheme.textLight(for: colorScheme)
    }

    private var chipBackground: Color {
        if isSelected {
            return colorScheme == .dark ? .white : .black
        }
        return .clear
    }

    private var chipBorder: Color {
        if isSelected { return .clear }
        return ENVITheme.border(for: colorScheme)
    }
}

#Preview {
    HStack {
        ENVIChip(title: "All", isSelected: true) {}
        ENVIChip(title: "Photos", isSelected: false) {}
        ENVIChip(title: "Videos", isSelected: false) {}
    }
    .padding()
    .preferredColorScheme(.dark)
}

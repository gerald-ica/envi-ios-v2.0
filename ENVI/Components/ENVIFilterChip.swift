import SwiftUI

/// Selectable filter chip for horizontal filter bars in the ENVI design system.
/// Inverts foreground/background when selected. Includes a subtle border when deselected.
struct ENVIFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.interMedium(13))
                .foregroundColor(
                    isSelected
                        ? ENVITheme.background(for: colorScheme)
                        : ENVITheme.text(for: colorScheme)
                )
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(
                    isSelected
                        ? ENVITheme.text(for: colorScheme)
                        : ENVITheme.surfaceLow(for: colorScheme)
                )
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(
                            isSelected ? Color.clear : ENVITheme.border(for: colorScheme),
                            lineWidth: 1
                        )
                )
        }
    }
}

#Preview {
    HStack {
        ENVIFilterChip(title: "All", isSelected: true) {}
        ENVIFilterChip(title: "Active", isSelected: false) {}
        ENVIFilterChip(title: "Draft", isSelected: false) {}
    }
    .padding()
    .preferredColorScheme(.dark)
}

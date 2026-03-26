import SwiftUI

/// Filter or action chip for the ENVI design system.
struct ENVIChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.interMedium(13))
                .foregroundColor(isSelected ? .white : ENVITheme.textLight(for: colorScheme))
                .padding(.horizontal, ENVISpacing.lg)
                .padding(.vertical, ENVISpacing.sm)
                .background(
                    isSelected
                        ? ENVITheme.primary(for: colorScheme)
                        : ENVITheme.surfaceLow(for: colorScheme)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? .clear : ENVITheme.border(for: colorScheme),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
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

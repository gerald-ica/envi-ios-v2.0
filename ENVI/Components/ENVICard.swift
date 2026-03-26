import SwiftUI

/// Elevated card container for the ENVI design system.
/// Background: surfaceLow (neutral gray). Corner radius: 12px.
struct ENVICard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(ENVISpacing.lg)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
            .enviCardShadow()
    }
}

#Preview {
    ENVICard {
        VStack(alignment: .leading, spacing: 8) {
            Text("CARD TITLE")
                .font(.spaceMonoBold(17))
                .tracking(-0.5)
            Text("Card content goes here")
                .font(.interRegular(15))
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}

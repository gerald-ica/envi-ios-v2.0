import SwiftUI

/// Elevated card container for the ENVI design system.
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
            .enviCardShadow()
    }
}

#Preview {
    ENVICard {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card Title")
                .font(.interBold(17))
            Text("Card content goes here")
                .font(.interRegular(15))
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}

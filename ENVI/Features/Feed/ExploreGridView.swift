import SwiftUI

/// Discover/trending content grid shown on the Explore tab.
/// Shared across: Main App Feed (10), Library & Search page.
struct ExploreGridView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let items: [ExploreCard] = [
        ExploreCard(imageName: "Closer", platform: .instagram, title: "Golden Hour Desert", engagement: "45.2K"),
        ExploreCard(imageName: "culture-food", platform: .tiktok, title: "Bangkok Street Food", engagement: "32.1K"),
        ExploreCard(imageName: "cyclist", platform: .instagram, title: "Morning City Ride", engagement: "67.8K"),
        ExploreCard(imageName: "fashion-group", platform: .instagram, title: "NYFW Squad", engagement: "54.3K"),
        ExploreCard(imageName: "fire-stunt", platform: .instagram, title: "Behind the Scenes", engagement: "38.9K"),
        ExploreCard(imageName: "industrial-girl", platform: .tiktok, title: "Industrial Aesthetic", engagement: "72.1K"),
        ExploreCard(imageName: "runway", platform: .instagram, title: "Milan Fashion Week", engagement: "41.6K"),
        ExploreCard(imageName: "studio-fashion", platform: .instagram, title: "Studio Session", engagement: "35.4K"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: ENVISpacing.md),
        GridItem(.flexible(), spacing: ENVISpacing.md),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            Text("Discover trending content across your connected platforms.")
                .font(.interSemiBold(14))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
                ForEach(items) { card in
                    exploreCardView(card)
                }
            }
        }
    }

    @ViewBuilder
    private func exploreCardView(_ card: ExploreCard) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Thumbnail
            Image(card.imageName)
                .resizable()
                .aspectRatio(3 / 4, contentMode: .fill)
                .clipped()

            // Gradient overlay
            ENVITheme.cardOverlayGradient

            // Content overlay
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                // Platform badge
                HStack(spacing: ENVISpacing.xs) {
                    Image(systemName: card.platform.iconName)
                        .font(.system(size: 10))
                    Text(card.platform.rawValue)
                        .font(.spaceMono(9))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, ENVISpacing.sm)
                .padding(.vertical, ENVISpacing.xs)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                Text(card.title)
                    .font(.interMedium(12))
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Engagement count
                HStack(spacing: ENVISpacing.xs) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 10))
                    Text(card.engagement)
                        .font(.spaceMono(10))
                }
                .foregroundColor(.white.opacity(0.7))
            }
            .padding(ENVISpacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }
}

// MARK: - Model

private struct ExploreCard: Identifiable {
    let id = UUID()
    let imageName: String
    let platform: SocialPlatform
    let title: String
    let engagement: String
}

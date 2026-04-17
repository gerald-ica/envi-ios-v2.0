import SwiftUI

/// Search overlay presented from the feed top nav.
struct FeedSearchView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let recentSearches = ["street photography tips", "carousel best practices", "tiktok trends"]
    private let trending = [
        TrendingTopic(title: "AI-Generated Thumbnails", subtitle: "12.4K creators discussing"),
        TrendingTopic(title: "Vertical Video Strategy", subtitle: "8.9K posts this week"),
        TrendingTopic(title: "Instagram Threads Growth", subtitle: "6.1K new threads"),
        TrendingTopic(title: "YouTube Shorts Monetization", subtitle: "5.3K creators sharing"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar
            HStack(spacing: ENVISpacing.md) {
                HStack(spacing: ENVISpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))

                    TextField("Search content, creators, topics...", text: $searchText)
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm + 2)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))

                Button("Cancel") {
                    dismiss()
                }
                .font(.interMedium(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.top, ENVISpacing.xl)
            .padding(.bottom, ENVISpacing.lg)

            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    if searchText.isEmpty {
                        // Recent Searches
                        VStack(alignment: .leading, spacing: ENVISpacing.md) {
                            Text("RECENT SEARCHES")
                                .font(.spaceMonoBold(11))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                                .padding(.horizontal, ENVISpacing.xl)

                            ForEach(recentSearches, id: \.self) { search in
                                Button {
                                    searchText = search
                                } label: {
                                    HStack(spacing: ENVISpacing.md) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 14))
                                            .foregroundColor(ENVITheme.textLight(for: colorScheme))

                                        Text(search)
                                            .font(.interRegular(14))
                                            .foregroundColor(ENVITheme.text(for: colorScheme))

                                        Spacer()
                                    }
                                    .padding(.horizontal, ENVISpacing.xl)
                                    .padding(.vertical, ENVISpacing.sm)
                                }
                            }
                        }

                        // Trending
                        VStack(alignment: .leading, spacing: ENVISpacing.md) {
                            Text("TRENDING")
                                .font(.spaceMonoBold(11))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                                .padding(.horizontal, ENVISpacing.xl)

                            ForEach(Array(trending.enumerated()), id: \.element.id) { index, topic in
                                HStack(spacing: ENVISpacing.md) {
                                    Text("\(index + 1)")
                                        .font(.spaceMonoBold(16))
                                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                                        .frame(width: 28, alignment: .center)

                                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                                        Text(topic.title)
                                            .font(.interMedium(14))
                                            .foregroundColor(ENVITheme.text(for: colorScheme))

                                        Text(topic.subtitle)
                                            .font(.interRegular(12))
                                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.trend.up")
                                        .font(.system(size: 12))
                                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                                }
                                .padding(.horizontal, ENVISpacing.xl)
                                .padding(.vertical, ENVISpacing.sm)
                            }
                        }
                    } else {
                        // No-results placeholder (will connect to ContentRepository later)
                        VStack(spacing: ENVISpacing.md) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))

                            Text("Search results for \"\(searchText)\"")
                                .font(.interMedium(14))
                                .foregroundColor(ENVITheme.text(for: colorScheme))

                            Text("Content search will connect to your feed data.")
                                .font(.interRegular(12))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, ENVISpacing.xxxxl)
                    }
                }
                .padding(.top, ENVISpacing.sm)
            }
        }
        .background(ENVITheme.background(for: colorScheme))
    }
}

/// Backward-compatible name used by existing navigation call sites.
typealias HomeFeedSearchView = FeedSearchView

// MARK: - Model

private struct TrendingTopic: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

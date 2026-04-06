import SwiftUI

/// Resurfaced content suggestions with reasons — hidden gems and seasonal picks.
struct HiddenGemView: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header

                if viewModel.isLoadingGems {
                    ProgressView()
                        .tint(ENVITheme.primary(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.top, ENVISpacing.xxxxl)
                } else {
                    gemsSection
                    seasonalSection
                }
            }
            .padding(.horizontal, ENVISpacing.lg)
            .padding(.bottom, ENVISpacing.xxxl)
        }
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
        .task {
            await viewModel.loadHiddenGems()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("HIDDEN GEMS")
                .font(.spaceMonoBold(13))
                .tracking(-0.3)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Content worth revisiting based on performance signals.")
                .font(.spaceMono(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.top, ENVISpacing.md)
    }

    // MARK: - Gems Section

    @ViewBuilder
    private var gemsSection: some View {
        if viewModel.hiddenGems.isEmpty {
            emptyCard(
                icon: "sparkles",
                title: "No Hidden Gems Yet",
                subtitle: "We'll surface high-potential content as your library grows."
            )
        } else {
            VStack(spacing: ENVISpacing.sm) {
                sectionLabel("RESURFACED")

                ForEach(viewModel.hiddenGems) { gem in
                    gemCard(gem)
                }
            }
        }
    }

    private func gemCard(_ gem: HiddenGem) -> some View {
        HStack(alignment: .top, spacing: ENVISpacing.md) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: ENVIRadius.md)
                .fill(ENVITheme.surfaceHigh(for: colorScheme))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                )

            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text(gem.title)
                    .font(.spaceMonoBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)

                Text(gem.reason)
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(2)

                if let published = gem.lastPublished {
                    Text("Last published \(published, style: .relative) ago")
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme).opacity(0.7))
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.top, ENVISpacing.xs)
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Seasonal Section

    @ViewBuilder
    private var seasonalSection: some View {
        if !viewModel.seasonalSuggestions.isEmpty {
            VStack(spacing: ENVISpacing.sm) {
                sectionLabel("SEASONAL")

                ForEach(viewModel.seasonalSuggestions) { suggestion in
                    seasonalCard(suggestion)
                }
            }
        }
    }

    private func seasonalCard(_ suggestion: SeasonalSuggestion) -> some View {
        HStack(alignment: .top, spacing: ENVISpacing.md) {
            // Season badge
            VStack {
                Image(systemName: iconForSeason(suggestion.season))
                    .font(.system(size: 18))
                    .foregroundColor(ENVITheme.primary(for: colorScheme))
                Text(suggestion.season.uppercased())
                    .font(.spaceMono(8))
                    .tracking(0.5)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            .frame(width: 56, height: 56)
            .background(ENVITheme.surfaceHigh(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))

            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text(suggestion.title)
                    .font(.spaceMonoBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)

                Text(suggestion.reason)
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.top, ENVISpacing.xs)
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.spaceMonoBold(10))
            .tracking(0.8)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text(title)
                .font(.spaceMonoBold(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(subtitle)
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(ENVISpacing.xl)
        .frame(maxWidth: .infinity)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    private func iconForSeason(_ season: String) -> String {
        switch season.lowercased() {
        case "spring": return "leaf"
        case "summer": return "sun.max"
        case "fall", "autumn": return "wind"
        case "winter": return "snowflake"
        default: return "calendar"
        }
    }
}

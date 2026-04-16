import SwiftUI

/// Top performing content: sortable table with platform badges and trend indicators.
struct ContentLeaderboardView: View {
    @ObservedObject var viewModel: AdvancedAnalyticsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Header
            HStack {
                Text("CONTENT LEADERBOARD")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                Spacer()

                sortMenu
            }

            if viewModel.contentPerformance.isEmpty {
                Text("No content data available.")
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            } else {
                // Column headers
                columnHeaders

                Divider().overlay(ENVITheme.border(for: colorScheme))

                // Rows
                ForEach(Array(viewModel.contentPerformance.enumerated()), id: \.element.id) { index, content in
                    contentRow(index: index + 1, content: content)

                    if index < viewModel.contentPerformance.count - 1 {
                        Divider().overlay(ENVITheme.border(for: colorScheme).opacity(0.5))
                    }
                }
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            Button {
                viewModel.contentSortField = .impressions
                Task { await viewModel.reloadContent() }
            } label: {
                Label("Impressions", systemImage: viewModel.contentSortField == .impressions ? "checkmark" : "")
            }
            Button {
                viewModel.contentSortField = .engagement
                Task { await viewModel.reloadContent() }
            } label: {
                Label("Engagement", systemImage: viewModel.contentSortField == .engagement ? "checkmark" : "")
            }
            Button {
                viewModel.contentSortField = .saves
                Task { await viewModel.reloadContent() }
            } label: {
                Label("Saves", systemImage: viewModel.contentSortField == .saves ? "checkmark" : "")
            }
            Button {
                viewModel.contentSortField = .shares
                Task { await viewModel.reloadContent() }
            } label: {
                Label("Shares", systemImage: viewModel.contentSortField == .shares ? "checkmark" : "")
            }
            Button {
                viewModel.contentSortField = .clickRate
                Task { await viewModel.reloadContent() }
            } label: {
                Label("Click Rate", systemImage: viewModel.contentSortField == .clickRate ? "checkmark" : "")
            }
        } label: {
            HStack(spacing: ENVISpacing.xs) {
                Text(sortLabel)
                    .font(.interMedium(11))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(ENVITheme.text(for: colorScheme))
            .padding(.horizontal, ENVISpacing.md)
            .padding(.vertical, ENVISpacing.xs)
            .background(ENVITheme.surfaceHigh(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }

    // MARK: - Column Headers

    private var columnHeaders: some View {
        HStack(spacing: ENVISpacing.sm) {
            Text("#")
                .frame(width: 20, alignment: .leading)
            Text("Content")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Impr.")
                .frame(width: 52, alignment: .trailing)
            Text("Eng.")
                .frame(width: 44, alignment: .trailing)
            Text("CTR")
                .frame(width: 38, alignment: .trailing)
        }
        .font(.spaceMono(9))
        .foregroundColor(ENVITheme.textLight(for: colorScheme))
    }

    // MARK: - Content Row

    @ViewBuilder
    private func contentRow(index: Int, content: ContentPerformance) -> some View {
        HStack(spacing: ENVISpacing.sm) {
            // Rank
            Text("\(index)")
                .font(.spaceMonoBold(12))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                .frame(width: 20, alignment: .leading)

            // Title + platform badge
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.interMedium(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)

                HStack(spacing: ENVISpacing.xs) {
                    // Platform badge
                    Text(content.platform.rawValue)
                        .font(.spaceMono(8))
                        .foregroundColor(content.platform.brandColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(content.platform.brandColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Saves + shares
                    Label("\(formatCompact(content.saves))", systemImage: "bookmark")
                        .font(.interRegular(9))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))

                    Label("\(formatCompact(content.shares))", systemImage: "arrowshape.turn.up.right")
                        .font(.interRegular(9))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Impressions
            Text(formatCompact(content.impressions))
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .frame(width: 52, alignment: .trailing)

            // Engagement
            Text(formatCompact(content.engagement))
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .frame(width: 44, alignment: .trailing)

            // Click rate with trend arrow
            HStack(spacing: 2) {
                Image(systemName: content.clickRate >= 3.0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(content.clickRate >= 3.0 ? ENVITheme.success : ENVITheme.error)
                Text(String(format: "%.1f%%", content.clickRate))
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }
            .frame(width: 38, alignment: .trailing)
        }
        .padding(.vertical, ENVISpacing.xs)
    }

    // MARK: - Helpers

    private var sortLabel: String {
        switch viewModel.contentSortField {
        case .impressions: return "Impressions"
        case .engagement:  return "Engagement"
        case .saves:       return "Saves"
        case .shares:      return "Shares"
        case .clickRate:   return "CTR"
        }
    }

    private func formatCompact(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

#Preview {
    ScrollView {
        ContentLeaderboardView(viewModel: AdvancedAnalyticsViewModel())
            .padding(ENVISpacing.xl)
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}

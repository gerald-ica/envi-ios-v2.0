import SwiftUI
import Charts

/// Demographics breakdown with horizontal bar charts for age/gender/location and a pie chart for platform split.
struct AudienceDemographicsView: View {
    @ObservedObject var viewModel: AdvancedAnalyticsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            Text("AUDIENCE DEMOGRAPHICS")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            if viewModel.demographics.isEmpty {
                Text("No demographic data available.")
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            } else {
                // Age breakdown
                demographicSection(title: "AGE", data: viewModel.demographicsByAge)

                Divider().overlay(ENVITheme.border(for: colorScheme))

                // Gender breakdown
                demographicSection(title: "GENDER", data: viewModel.demographicsByGender)

                Divider().overlay(ENVITheme.border(for: colorScheme))

                // Location breakdown
                demographicSection(title: "TOP LOCATIONS", data: viewModel.demographicsByLocation)

                Divider().overlay(ENVITheme.border(for: colorScheme))

                // Platform pie chart
                platformPieChart
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Horizontal Bar Section

    @ViewBuilder
    private func demographicSection(title: String, data: [(label: String, total: Double)]) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text(title)
                .font(.spaceMono(10))
                .tracking(0.80)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            let maxValue = data.map(\.total).max() ?? 1

            ForEach(data, id: \.label) { item in
                HStack(spacing: ENVISpacing.sm) {
                    Text(item.label)
                        .font(.interMedium(11))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .frame(width: 90, alignment: .leading)

                    GeometryReader { geo in
                        let barWidth = geo.size.width * CGFloat(item.total / maxValue)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ENVITheme.text(for: colorScheme).opacity(0.7))
                            .frame(width: max(barWidth, 4), height: 14)
                    }
                    .frame(height: 14)

                    Text(String(format: "%.0f%%", item.total))
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Platform Pie Chart

    @ViewBuilder
    private var platformPieChart: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("PLATFORM SPLIT")
                .font(.spaceMono(10))
                .tracking(0.80)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            let platformData = platformDistribution

            HStack(spacing: ENVISpacing.lg) {
                Chart(platformData, id: \.platform) { item in
                    SectorMark(
                        angle: .value("Share", item.share),
                        innerRadius: .ratio(0.55),
                        angularInset: 1
                    )
                    .foregroundStyle(item.platform.brandColor)
                }
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    ForEach(platformData, id: \.platform) { item in
                        HStack(spacing: ENVISpacing.xs) {
                            Circle()
                                .fill(item.platform.brandColor)
                                .frame(width: 8, height: 8)
                            Text(item.platform.rawValue)
                                .font(.interRegular(11))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                            Spacer()
                            Text(String(format: "%.0f%%", item.share))
                                .font(.spaceMono(10))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private struct PlatformShare {
        let platform: SocialPlatform
        let share: Double
    }

    /// Derives a rough platform distribution from content performance data.
    private var platformDistribution: [PlatformShare] {
        let content = viewModel.contentPerformance
        guard !content.isEmpty else {
            return [
                PlatformShare(platform: .instagram, share: 40),
                PlatformShare(platform: .tiktok, share: 35),
                PlatformShare(platform: .youtube, share: 25),
            ]
        }
        let totalImpressions = content.reduce(0) { $0 + $1.impressions }
        guard totalImpressions > 0 else { return [] }
        let grouped = Dictionary(grouping: content, by: \.platform)
        return grouped.map { platform, items in
            let sum = items.reduce(0) { $0 + $1.impressions }
            return PlatformShare(platform: platform, share: Double(sum) / Double(totalImpressions) * 100)
        }
        .sorted { $0.share > $1.share }
    }
}

#Preview {
    ScrollView {
        AudienceDemographicsView(viewModel: AdvancedAnalyticsViewModel())
            .padding(ENVISpacing.xl)
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}

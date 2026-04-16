import SwiftUI
import Charts

/// Detailed performance report with line chart, platform filter, date range, and export.
struct PerformanceReportView: View {
    @ObservedObject var viewModel: AdvancedAnalyticsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Header
            HStack {
                Text("PERFORMANCE REPORT")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                Spacer()

                // Export button
                Button {
                    // Export action placeholder
                } label: {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .medium))
                        Text("Export")
                            .font(.interMedium(11))
                    }
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.xs)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }

            // Date range
            Text(dateRangeLabel)
                .font(.interRegular(11))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            // Platform filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    platformChip(nil, label: "All")
                    ForEach(viewModel.report.platforms) { platform in
                        platformChip(platform, label: platform.rawValue)
                    }
                }
            }

            // Line Chart
            Chart(viewModel.filteredMetrics) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Platform", point.platform.rawValue))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartForegroundStyleScale(platformColorMapping)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                        .foregroundStyle(ENVITheme.border(for: colorScheme))
                    AxisValueLabel()
                        .font(.spaceMono(9))
                        .foregroundStyle(ENVITheme.textLight(for: colorScheme))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                        .foregroundStyle(ENVITheme.border(for: colorScheme))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.spaceMono(9))
                        .foregroundStyle(ENVITheme.textLight(for: colorScheme))
                }
            }
            .chartLegend(.hidden)
            .frame(height: 220)

            // Platform legend
            HStack(spacing: ENVISpacing.lg) {
                ForEach(viewModel.report.platforms) { platform in
                    HStack(spacing: ENVISpacing.xs) {
                        Circle()
                            .fill(platform.brandColor)
                            .frame(width: 8, height: 8)
                        Text(platform.rawValue)
                            .font(.interRegular(10))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }
                }
            }

            // Summary
            Text(viewModel.report.summary)
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.top, ENVISpacing.xs)

            // Period comparison
            if !viewModel.periodComparison.isEmpty {
                Divider()
                    .overlay(ENVITheme.border(for: colorScheme))

                Text("VS PREVIOUS PERIOD")
                    .font(.spaceMono(10))
                    .tracking(0.80)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                HStack(spacing: ENVISpacing.md) {
                    ForEach(viewModel.periodComparison) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.metricName)
                                .font(.interRegular(10))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                            Text(String(format: "%+.1f%%", item.changePercent))
                                .font(.spaceMonoBold(14))
                                .foregroundColor(item.isPositive ? ENVITheme.success : ENVITheme.error)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Helpers

    private var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let start = formatter.string(from: viewModel.report.dateRange.start)
        let end = formatter.string(from: viewModel.report.dateRange.end)
        return "\(start) – \(end)"
    }

    private var platformColorMapping: KeyValuePairs<String, Color> {
        [
            SocialPlatform.instagram.rawValue: SocialPlatform.instagram.brandColor,
            SocialPlatform.tiktok.rawValue: ENVITheme.text(for: colorScheme),
            SocialPlatform.youtube.rawValue: SocialPlatform.youtube.brandColor,
            SocialPlatform.x.rawValue: SocialPlatform.x.brandColor,
            SocialPlatform.threads.rawValue: ENVITheme.textSecondary(for: colorScheme),
            SocialPlatform.linkedin.rawValue: SocialPlatform.linkedin.brandColor,
        ]
    }

    @ViewBuilder
    private func platformChip(_ platform: SocialPlatform?, label: String) -> some View {
        let isSelected = viewModel.selectedPlatformFilter == platform
        Button {
            viewModel.selectedPlatformFilter = platform
        } label: {
            Text(label)
                .font(.interMedium(11))
                .foregroundColor(isSelected ? ENVITheme.background(for: colorScheme) : ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.xs)
                .background(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.surfaceHigh(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }
}

#Preview {
    ScrollView {
        PerformanceReportView(viewModel: AdvancedAnalyticsViewModel())
            .padding(ENVISpacing.xl)
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}

import SwiftUI

/// Weekly summary view with highlights, top content, key metrics, and recommendations.
struct WeeklyDigestView: View {
    @ObservedObject var viewModel: BenchmarkViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var digest: WeeklyDigest { viewModel.weeklyDigest }

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEEKLY DIGEST")
                        .font(.spaceMono(11))
                        .tracking(0.88)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Text("Week of \(weekLabel)")
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                Button {
                    Task { await viewModel.loadAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            }

            // Highlights
            if !digest.highlights.isEmpty {
                sectionCard(title: "HIGHLIGHTS") {
                    VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                        ForEach(Array(digest.highlights.enumerated()), id: \.offset) { _, highlight in
                            HStack(alignment: .top, spacing: ENVISpacing.sm) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(ENVITheme.warning)
                                    .padding(.top, 3)

                                Text(highlight)
                                    .font(.interRegular(13))
                                    .foregroundColor(ENVITheme.text(for: colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            // Top Content
            if !digest.topContent.isEmpty {
                sectionCard(title: "TOP CONTENT") {
                    VStack(spacing: ENVISpacing.sm) {
                        ForEach(Array(digest.topContent.enumerated()), id: \.element.id) { index, content in
                            HStack(spacing: ENVISpacing.md) {
                                Text("#\(index + 1)")
                                    .font(.spaceMonoBold(14))
                                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                                    .frame(width: 28, alignment: .center)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(content.title)
                                        .font(.interMedium(13))
                                        .foregroundColor(ENVITheme.text(for: colorScheme))
                                        .lineLimit(1)

                                    HStack(spacing: ENVISpacing.md) {
                                        metricLabel("Reach", value: formatNumber(content.reach))
                                        metricLabel("Eng.", value: formatNumber(content.engagement))
                                        metricLabel("Saves", value: formatNumber(content.saves))
                                    }
                                }

                                Spacer()
                            }

                            if index < digest.topContent.count - 1 {
                                Divider()
                                    .background(ENVITheme.border(for: colorScheme))
                            }
                        }
                    }
                }
            }

            // Key Metrics
            if !digest.keyMetrics.isEmpty {
                sectionCard(title: "KEY METRICS") {
                    VStack(spacing: ENVISpacing.sm) {
                        ForEach(digest.keyMetrics) { metric in
                            HStack {
                                Text(metric.metric)
                                    .font(.interRegular(12))
                                    .foregroundColor(ENVITheme.text(for: colorScheme))

                                Spacer()

                                Text(formattedMetricValue(metric.userValue))
                                    .font(.spaceMonoBold(13))
                                    .foregroundColor(ENVITheme.text(for: colorScheme))

                                percentileIndicator(metric.percentile)
                            }
                        }
                    }
                }
            }

            // Recommendations
            if !digest.recommendations.isEmpty {
                sectionCard(title: "RECOMMENDATIONS") {
                    VStack(alignment: .leading, spacing: ENVISpacing.md) {
                        ForEach(Array(digest.recommendations.enumerated()), id: \.offset) { index, rec in
                            HStack(alignment: .top, spacing: ENVISpacing.sm) {
                                Text("\(index + 1)")
                                    .font(.spaceMonoBold(11))
                                    .foregroundColor(ENVITheme.background(for: colorScheme))
                                    .frame(width: 20, height: 20)
                                    .background(ENVITheme.text(for: colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text(rec)
                                    .font(.interRegular(12))
                                    .foregroundColor(ENVITheme.text(for: colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .padding(ENVISpacing.lg)
    }

    // MARK: - Section Card

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text(title)
                .font(.spaceMono(10))
                .tracking(0.8)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            content()
        }
        .padding(ENVISpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Metric Label

    @ViewBuilder
    private func metricLabel(_ label: String, value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.spaceMono(9))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Text(value)
                .font(.spaceMonoBold(9))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
    }

    // MARK: - Percentile Indicator

    @ViewBuilder
    private func percentileIndicator(_ percentile: Int) -> some View {
        let color: Color = percentile >= 75 ? ENVITheme.success : (percentile >= 50 ? ENVITheme.warning : ENVITheme.error)
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("P\(percentile)")
                .font(.spaceMono(9))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Formatting

    private var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: digest.weekStarting)
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "%.1fK", Double(value) / 1000)
        }
        return "\(value)"
    }

    private func formattedMetricValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        WeeklyDigestView(viewModel: BenchmarkViewModel(repository: MockBenchmarkRepository()))
    }
}

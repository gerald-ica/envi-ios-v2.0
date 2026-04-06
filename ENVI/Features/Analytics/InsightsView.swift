import SwiftUI

/// Actionable insight cards with impact rating, confidence level, and apply button.
struct InsightsView: View {
    @ObservedObject var viewModel: BenchmarkViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Header
            HStack {
                Text("INSIGHTS")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Text("\(viewModel.insights.count) insights")
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            // Trend signals section
            if !viewModel.hotTrends.isEmpty {
                Text("TRENDING NOW")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.top, ENVISpacing.sm)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.sm) {
                        ForEach(viewModel.hotTrends) { trend in
                            trendPill(trend)
                        }
                    }
                }
            }

            // Insight cards
            if viewModel.prioritizedInsights.isEmpty {
                Text("No insights available yet.")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, ENVISpacing.xl)
            } else {
                ForEach(viewModel.prioritizedInsights) { insight in
                    insightCard(insight)
                }
            }
        }
        .padding(ENVISpacing.lg)
    }

    // MARK: - Trend Pill

    @ViewBuilder
    private func trendPill(_ trend: TrendSignal) -> some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: directionIcon(trend.direction))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(directionColor(trend.direction))

            Text(trend.topic)
                .font(.interMedium(11))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("\(Int(trend.momentum))")
                .font(.spaceMonoBold(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.md)
        .padding(.vertical, ENVISpacing.sm)
        .background(ENVITheme.surfaceHigh(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    // MARK: - Insight Card

    @ViewBuilder
    private func insightCard(_ insight: InsightCard) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Title + impact badge
            HStack(alignment: .top) {
                Text(insight.title)
                    .font(.interMedium(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                impactBadge(insight.impact)
            }

            // Description
            Text(insight.description)
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            // Confidence bar
            HStack(spacing: ENVISpacing.sm) {
                Text("Confidence")
                    .font(.spaceMono(9))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ENVITheme.border(for: colorScheme))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ENVITheme.text(for: colorScheme))
                            .frame(width: geo.size.width * insight.confidence)
                    }
                }
                .frame(height: 4)

                Text("\(Int(insight.confidence * 100))%")
                    .font(.spaceMono(9))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .frame(width: 32, alignment: .trailing)
            }

            // Actionable advice
            HStack(alignment: .top, spacing: ENVISpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                    .foregroundColor(ENVITheme.warning)

                Text(insight.actionableAdvice)
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(ENVISpacing.sm)
            .background(ENVITheme.surfaceHigh(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

            // Apply button
            Button {
                // Apply action placeholder
            } label: {
                Text("Apply Recommendation")
                    .font(.interMedium(11))
                    .foregroundColor(ENVITheme.background(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.text(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Impact Badge

    @ViewBuilder
    private func impactBadge(_ impact: ImpactLevel) -> some View {
        let color: Color = {
            switch impact {
            case .high:   return ENVITheme.error
            case .medium: return ENVITheme.warning
            case .low:    return ENVITheme.success
            }
        }()

        Text(impact.displayName.uppercased())
            .font(.spaceMonoBold(9))
            .foregroundColor(.white)
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    // MARK: - Helpers

    private func directionIcon(_ direction: TrendDirection) -> String {
        switch direction {
        case .up:     return "arrow.up.right"
        case .down:   return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    private func directionColor(_ direction: TrendDirection) -> Color {
        switch direction {
        case .up:     return ENVITheme.success
        case .down:   return ENVITheme.error
        case .stable: return ENVITheme.warning
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        InsightsView(viewModel: BenchmarkViewModel(repository: MockBenchmarkRepository()))
    }
}

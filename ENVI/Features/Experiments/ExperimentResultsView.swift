import SwiftUI

/// Side-by-side variant comparison with winner badge, confidence bar, and recommendation.
struct ExperimentResultsView: View {
    let experiment: Experiment
    let result: ABTestResult?
    let isLoading: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let result {
                    VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                        experimentHeader
                        confidenceSection(result: result)
                        variantComparison(result: result)
                        recommendationCard(result: result)
                    }
                    .padding(ENVISpacing.xl)
                } else {
                    Text("No results available.")
                        .font(.interRegular(15))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Experiment Header

    private var experimentHeader: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text(experiment.name)
                .font(.interSemiBold(20))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            if !experiment.hypothesis.isEmpty {
                Text(experiment.hypothesis)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            HStack(spacing: ENVISpacing.md) {
                HStack(spacing: ENVISpacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(experiment.dateRangeLabel)
                        .font(.spaceMono(10))
                }

                HStack(spacing: ENVISpacing.xs) {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: 10))
                    Text("\(experiment.variants.count) variants")
                        .font(.spaceMono(10))
                }
            }
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Confidence Section

    private func confidenceSection(result: ABTestResult) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("CONFIDENCE")
                .font(.spaceMono(10))
                .tracking(1.0)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            // Confidence bar
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                HStack {
                    Text(result.formattedConfidence)
                        .font(.spaceMonoBold(24))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Spacer()

                    Text(result.formattedImprovement)
                        .font(.spaceMonoBold(17))
                        .foregroundColor(result.improvement >= 0 ? ENVITheme.text(for: colorScheme) : ENVITheme.error)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ENVITheme.surfaceHigh(for: colorScheme))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(ENVITheme.text(for: colorScheme))
                            .frame(width: geo.size.width * min(result.confidence, 1.0), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("Statistical confidence")
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    Spacer()
                    Text("Improvement")
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
            .padding(ENVISpacing.lg)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
    }

    // MARK: - Variant Comparison

    private func variantComparison(result: ABTestResult) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("VARIANT COMPARISON")
                .font(.spaceMono(10))
                .tracking(1.0)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            HStack(alignment: .top, spacing: ENVISpacing.md) {
                ForEach(experiment.variants) { variant in
                    variantCard(variant: variant, isWinner: variant.id == result.winner)
                }
            }
        }
    }

    private func variantCard(variant: ExperimentVariant, isWinner: Bool) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Header with winner badge
            HStack {
                Text(variant.name.uppercased())
                    .font(.spaceMonoBold(12))
                    .tracking(0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                if isWinner {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 9))
                        Text("WINNER")
                            .font(.spaceMono(9))
                            .tracking(0.5)
                    }
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, ENVISpacing.xs)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }

            // Caption
            Text(variant.caption)
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .lineLimit(2)

            Divider()
                .background(ENVITheme.border(for: colorScheme))

            // Metrics
            metricRow(label: "Impressions", value: formatNumber(variant.metrics.impressions))
            metricRow(label: "Engagement", value: formatNumber(variant.metrics.engagement))
            metricRow(label: "Click Rate", value: variant.metrics.formattedClickRate)
            metricRow(label: "Conversion", value: variant.metrics.formattedConversionRate)
        }
        .padding(ENVISpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(
                    isWinner ? ENVITheme.text(for: colorScheme).opacity(0.4) : ENVITheme.border(for: colorScheme),
                    lineWidth: isWinner ? 2 : 1
                )
        )
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Spacer()
            Text(value)
                .font(.spaceMonoBold(11))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
    }

    // MARK: - Recommendation Card

    private func recommendationCard(result: ABTestResult) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                Text("RECOMMENDATION")
                    .font(.spaceMono(10))
                    .tracking(1.0)
            }
            .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(result.recommendation)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ENVISpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

#Preview {
    ExperimentResultsView(
        experiment: Experiment.mock,
        result: ABTestResult.mock,
        isLoading: false
    )
    .preferredColorScheme(.dark)
}

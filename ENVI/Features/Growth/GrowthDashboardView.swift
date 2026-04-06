import SwiftUI

/// Growth dashboard displaying growth metrics, viral loop funnels, and shareable asset performance.
struct GrowthDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var metrics: [GrowthMetric] = GrowthMetric.mockList
    @State private var viralLoops: [ViralLoop] = ViralLoop.mockList
    @State private var assets: [ShareableAsset] = ShareableAsset.mockList

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                metricsGrid
                viralLoopsSection
                shareableAssetsSection
            }
            .padding(ENVISpacing.lg)
        }
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("GROWTH")
                .font(.spaceMono(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Metrics, loops, and virality")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: ENVISpacing.md),
            GridItem(.flexible(), spacing: ENVISpacing.md),
        ]

        return LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
            ForEach(metrics) { metric in
                metricCard(metric)
            }
        }
    }

    private func metricCard(_ metric: GrowthMetric) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Text(metric.name.uppercased())
                    .font(.spaceMono(10))
                    .tracking(1)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Image(systemName: metric.trend.iconName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(trendColor(metric.trend))
            }

            Text(formattedValue(metric.value))
                .font(.spaceMonoBold(22))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(metric.period)
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Viral Loops Section

    private var viralLoopsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("VIRAL LOOPS")
                .font(.spaceMono(13))
                .tracking(1)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            ForEach(viralLoops) { loop in
                viralLoopCard(loop)
            }
        }
    }

    private func viralLoopCard(_ loop: ViralLoop) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                Text(loop.name)
                    .font(.spaceMonoBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text("\(Int(loop.conversionRate * 100))% CVR")
                    .font(.spaceMono(12))
                    .foregroundColor(ENVITheme.success)
            }

            // Funnel steps
            HStack(spacing: ENVISpacing.xs) {
                ForEach(Array(loop.steps.enumerated()), id: \.element.id) { index, step in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }

                    Text(step.name)
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, ENVISpacing.xs)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Shareable Assets Section

    private var shareableAssetsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("SHAREABLE ASSETS")
                .font(.spaceMono(13))
                .tracking(1)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            ForEach(assets) { asset in
                assetRow(asset)
            }
        }
    }

    private func assetRow(_ asset: ShareableAsset) -> some View {
        HStack(spacing: ENVISpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .fill(ENVITheme.surfaceHigh(for: colorScheme))
                    .frame(width: 40, height: 40)
                Image(systemName: "link")
                    .font(.system(size: 16))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.shareURL)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)

                HStack(spacing: ENVISpacing.md) {
                    Label("\(asset.views)", systemImage: "eye")
                    Label("\(asset.conversions)", systemImage: "arrow.turn.down.right")
                }
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Text("\(Int(asset.conversionRate * 100))%")
                .font(.spaceMonoBold(14))
                .foregroundColor(ENVITheme.success)
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

    private func trendColor(_ trend: MetricTrend) -> Color {
        switch trend {
        case .up:   return ENVITheme.success
        case .down: return ENVITheme.error
        case .flat: return ENVITheme.textSecondary(for: colorScheme)
        }
    }

    private func formattedValue(_ value: Double) -> String {
        if value == value.rounded() && value >= 1 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

#Preview {
    GrowthDashboardView()
        .preferredColorScheme(.dark)
}

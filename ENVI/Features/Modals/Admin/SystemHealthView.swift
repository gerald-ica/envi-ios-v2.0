import SwiftUI

/// System health dashboard with real-time status indicators (ENVI-0956..0960).
///
/// Phase 19 Plan 01 — repo-in-view anti-pattern removed; now backed by
/// `SystemHealthViewModel`.
struct SystemHealthView: View {

    @StateObject private var viewModel: SystemHealthViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(viewModel: SystemHealthViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? SystemHealthViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                if viewModel.isLoading {
                    ENVILoadingState()
                } else if let message = viewModel.errorMessage {
                    ENVIErrorBanner(message: message)
                } else {
                    overallBanner
                    metricsGrid
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await viewModel.load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("SYSTEM HEALTH")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Infrastructure monitoring")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Overall Banner

    private var overallBanner: some View {
        HStack(spacing: ENVISpacing.md) {
            Image(systemName: viewModel.overallStatus.iconName)
                .font(.system(size: 28))
                .foregroundColor(statusColor(for: viewModel.overallStatus))

            VStack(alignment: .leading, spacing: 2) {
                Text("Overall Status")
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Text(viewModel.overallStatus.displayName.uppercased())
                    .font(.spaceMonoBold(18))
                    .foregroundColor(statusColor(for: viewModel.overallStatus))
            }

            Spacer()

            Text("\(viewModel.healthyCount)/\(viewModel.metrics.count)")
                .font(.spaceMonoBold(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.lg)
        .background(statusColor(for: viewModel.overallStatus).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: ENVISpacing.md),
            GridItem(.flexible(), spacing: ENVISpacing.md),
        ]

        return LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
            ForEach(viewModel.metrics) { metric in
                metricCard(metric)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func metricCard(_ metric: SystemHealthMetric) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Image(systemName: metric.status.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(statusColor(for: metric.status))

                Spacer()

                Text(metric.status.displayName.uppercased())
                    .font(.spaceMonoBold(9))
                    .tracking(0.5)
                    .foregroundColor(statusColor(for: metric.status))
            }

            Text(metric.formattedValue)
                .font(.spaceMonoBold(24))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(metric.name)
                .font(.interRegular(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .lineLimit(1)

            // Threshold bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ENVITheme.surfaceLow(for: colorScheme))
                        .frame(height: 4)

                    let ratio = min(metric.value / metric.threshold, 1.0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(statusColor(for: metric.status))
                        .frame(width: geo.size.width * ratio, height: 4)
                }
            }
            .frame(height: 4)

            Text("Threshold: \(String(format: "%.0f", metric.threshold))")
                .font(.interRegular(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
    }

    // MARK: - Helpers

    private func statusColor(for status: HealthStatus) -> Color {
        switch status {
        case .healthy:  return .green
        case .degraded: return .orange
        case .critical: return .red
        }
    }
}

#Preview {
    SystemHealthView()
}

import SwiftUI

/// System health dashboard with real-time status indicators (ENVI-0956..0960).
struct SystemHealthView: View {

    @State private var metrics: [SystemHealthMetric] = []
    @State private var isLoading = true
    @Environment(\.colorScheme) private var colorScheme

    private let repository = AdminRepositoryProvider.shared.repository

    private var overallStatus: HealthStatus {
        if metrics.contains(where: { $0.status == .critical }) { return .critical }
        if metrics.contains(where: { $0.status == .degraded }) { return .degraded }
        return .healthy
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                if isLoading {
                    ProgressView()
                        .padding(.top, ENVISpacing.xxl)
                } else {
                    overallBanner
                    metricsGrid
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await loadHealth() }
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
            Image(systemName: overallStatus.iconName)
                .font(.system(size: 28))
                .foregroundColor(statusColor(for: overallStatus))

            VStack(alignment: .leading, spacing: 2) {
                Text("Overall Status")
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Text(overallStatus.displayName.uppercased())
                    .font(.spaceMonoBold(18))
                    .foregroundColor(statusColor(for: overallStatus))
            }

            Spacer()

            Text("\(metrics.filter { $0.status == .healthy }.count)/\(metrics.count)")
                .font(.spaceMonoBold(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.lg)
        .background(statusColor(for: overallStatus).opacity(0.1))
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
            ForEach(metrics) { metric in
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

    // MARK: - Actions

    private func loadHealth() async {
        defer { isLoading = false }
        metrics = (try? await repository.fetchSystemHealth()) ?? []
    }
}

#Preview {
    SystemHealthView()
}

import SwiftUI

/// Dashboard showing usage meters per feature with progress bars,
/// overage warnings, and upgrade nudges.
struct UsageDashboardView: View {

    @ObservedObject var viewModel: BillingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            // Header
            Text("USAGE")
                .font(.spaceMonoBold(18))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            if viewModel.isLoadingUsage {
                HStack {
                    ProgressView()
                    Text("Loading usage data...")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .padding(.horizontal, ENVISpacing.xl)
            } else if viewModel.usageMeters.isEmpty {
                emptyState
            } else {
                // Tier badge
                tierBadge

                // Meters
                metersSection

                // Overage warnings
                overageWarnings

                // Reset info
                resetInfo
            }
        }
    }

    // MARK: - Tier Badge

    private var tierBadge: some View {
        HStack(spacing: ENVISpacing.md) {
            Circle()
                .fill(viewModel.isPaidUser ? ENVITheme.success : ENVITheme.warning)
                .frame(width: 8, height: 8)

            Text(viewModel.currentTier.displayName.uppercased())
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Spacer()

            if !viewModel.isPaidUser {
                Text("UPGRADE FOR MORE")
                    .font(.spaceMono(9))
                    .tracking(0.5)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Meters

    private var metersSection: some View {
        VStack(spacing: ENVISpacing.md) {
            ForEach(viewModel.usageMeters) { meter in
                usageMeterRow(meter)
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func usageMeterRow(_ meter: UsageMeter) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Image(systemName: meterIcon(for: meter.feature))
                    .font(.system(size: 12))
                    .foregroundColor(meterColor(for: meter))
                    .frame(width: 18)

                Text(meter.feature)
                    .font(.interMedium(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text("\(meter.used)/\(meter.limit)")
                    .font(.spaceMono(12))
                    .foregroundColor(meterColor(for: meter))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ENVITheme.surfaceHigh(for: colorScheme))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(meterColor(for: meter))
                        .frame(
                            width: geo.size.width * CGFloat(min(meter.usageFraction, 1.0)),
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            // Remaining text
            HStack {
                Text("\(meter.remaining) remaining")
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Text(String(format: "%.0f%%", meter.usageFraction * 100))
                    .font(.spaceMono(11))
                    .foregroundColor(meterColor(for: meter))
            }
        }
    }

    // MARK: - Overage Warnings

    @ViewBuilder
    private var overageWarnings: some View {
        let warnings = viewModel.usageMeters.filter { $0.isNearLimit }
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                ForEach(warnings) { meter in
                    HStack(spacing: ENVISpacing.sm) {
                        Image(systemName: meter.isOverLimit
                              ? "exclamationmark.triangle.fill"
                              : "exclamationmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(meter.isOverLimit ? ENVITheme.error : ENVITheme.warning)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(meter.isOverLimit
                                 ? "\(meter.feature) limit reached"
                                 : "\(meter.feature) almost at limit")
                                .font(.interMedium(12))
                                .foregroundColor(ENVITheme.text(for: colorScheme))

                            Text("Upgrade your plan for higher limits")
                                .font(.interRegular(11))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        }

                        Spacer()
                    }
                }
            }
            .padding(ENVISpacing.lg)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Reset Info

    @ViewBuilder
    private var resetInfo: some View {
        if let firstMeter = viewModel.usageMeters.first {
            let formatter = RelativeDateTimeFormatter()
            let resetText = formatter.localizedString(for: firstMeter.resetDate, relativeTo: Date())
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Text("Usage resets \(resetText)")
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "chart.bar")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No usage data available")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(ENVISpacing.xxxxl)
    }

    // MARK: - Helpers

    private func meterColor(for meter: UsageMeter) -> Color {
        if meter.isOverLimit { return ENVITheme.error }
        if meter.isNearLimit { return ENVITheme.warning }
        return ENVITheme.success
    }

    private func meterIcon(for feature: String) -> String {
        switch feature.lowercased() {
        case let f where f.contains("ai"):       return "sparkles"
        case let f where f.contains("storage"):  return "externaldrive"
        case let f where f.contains("post"):     return "paperplane"
        case let f where f.contains("seat"):     return "person.2"
        case let f where f.contains("schedule"): return "calendar"
        default:                                  return "gauge.medium"
        }
    }
}

#Preview {
    ScrollView {
        UsageDashboardView(viewModel: BillingViewModel())
    }
    .preferredColorScheme(.dark)
}

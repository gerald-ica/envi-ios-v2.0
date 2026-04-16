import SwiftUI

/// KPI card matching Sketch frame "16 - Analytics":
/// Green dot icon, label in SpaceMono 10, value in SpaceMonoBold 24, delta in green.
struct KPICardView: View {
    let kpi: AnalyticsData.KPI
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Green dot indicator
            Circle()
                .fill(ENVITheme.success)
                .frame(width: 8, height: 8)

            Text(kpi.label.uppercased())
                .font(.spaceMono(10))
                .tracking(0.80)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            Text(kpi.value)
                .font(.spaceMonoBold(24))
                .tracking(-1.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(kpi.change)
                .font(.spaceMono(11))
                .foregroundColor(kpi.isPositive ? ENVITheme.success : ENVITheme.error)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }
}

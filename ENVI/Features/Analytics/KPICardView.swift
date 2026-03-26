import SwiftUI

/// KPI card for reach, engagement, or rate.
struct KPICardView: View {
    let kpi: AnalyticsData.KPI
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text(kpi.label.uppercased())
                .font(.spaceMono(10))
                .tracking(0.80)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            Text(kpi.value)
                .font(.spaceMonoBold(22))
                .tracking(-1.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

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

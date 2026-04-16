import SwiftUI

/// KPI card matching Sketch frame "16 - Analytics":
/// Green dot icon, label in SpaceMono 10, value in SpaceMonoBold 24, delta in green.
struct KPICardView: View {
    let kpi: AnalyticsData.KPI
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(ENVITheme.success)
                    .frame(width: 8, height: 8)

                Text(kpi.label.uppercased())
                    .font(.spaceMonoBold(10))
                    .tracking(0.8)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    .lineLimit(1)
            }

            Text(kpi.value)
                .font(.spaceMonoBold(26))
                .tracking(-1.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(kpi.change)
                .font(.spaceMono(11))
                .foregroundColor(kpi.isPositive ? ENVITheme.success : ENVITheme.error)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

import SwiftUI
import Charts

/// Bar chart showing daily engagement using Swift Charts.
struct EngagementChartView: View {
    let data: [AnalyticsData.DailyMetric]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("ENGAGEMENT")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            Chart(data) { metric in
                BarMark(
                    x: .value("Day", metric.day),
                    y: .value("Engagement", metric.value)
                )
                .foregroundStyle(ENVITheme.primary(for: colorScheme).gradient)
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                        .foregroundStyle(ENVITheme.border(for: colorScheme))
                    AxisValueLabel()
                        .font(.spaceMono(9))
                        .foregroundStyle(ENVITheme.textLight(for: colorScheme))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.spaceMono(9))
                        .foregroundStyle(ENVITheme.textLight(for: colorScheme))
                }
            }
            .frame(height: 200)
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }
}

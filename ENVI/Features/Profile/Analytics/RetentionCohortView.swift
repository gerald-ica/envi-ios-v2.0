import SwiftUI
import Charts

/// Dashboard section displaying weekly retention cohort data as horizontal bars.
struct RetentionCohortView: View {
    let cohorts: [RetentionCohort]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("RETENTION COHORTS")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            Chart(cohorts) { cohort in
                BarMark(
                    x: .value("Retention", cohort.retainedPercent),
                    y: .value("Week", cohort.weekLabel)
                )
                .foregroundStyle(barColor(for: cohort.retainedPercent))
                .cornerRadius(4)
                .annotation(position: .trailing, spacing: 4) {
                    Text(String(format: "%.1f%%", cohort.retainedPercent))
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }
            }
            .chartXScale(domain: 0...110)
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisGridLine()
                        .foregroundStyle(ENVITheme.border(for: colorScheme))
                    AxisValueLabel()
                        .font(.spaceMono(9))
                        .foregroundStyle(ENVITheme.textLight(for: colorScheme))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.spaceMono(9))
                        .foregroundStyle(ENVITheme.textLight(for: colorScheme))
                }
            }
            .frame(height: 180)

            // Cohort size labels
            HStack(spacing: ENVISpacing.sm) {
                ForEach(cohorts) { cohort in
                    VStack(spacing: 2) {
                        Text(cohort.weekLabel)
                            .font(.interRegular(9))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        Text("\(cohort.cohortSize)")
                            .font(.spaceMono(10))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    private func barColor(for percent: Double) -> Color {
        switch percent {
        case 80...: return .green
        case 60...: return .yellow
        case 40...: return .orange
        default:    return .red
        }
    }
}

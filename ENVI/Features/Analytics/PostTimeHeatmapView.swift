import SwiftUI

/// 7x24 heatmap grid showing average engagement by day-of-week and hour, with "Best time to post" callout.
struct PostTimeHeatmapView: View {
    @ObservedObject var viewModel: AdvancedAnalyticsViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let displayHours = Array(stride(from: 6, through: 22, by: 2))

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("BEST TIMES TO POST")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            // Best time callout
            if let best = viewModel.bestPostTime {
                bestTimeCallout(best)
            }

            // Heatmap grid
            heatmapGrid

            // Legend
            heatmapLegend
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Best Time Callout

    @ViewBuilder
    private func bestTimeCallout(_ best: PostTimeAnalysis) -> some View {
        HStack(spacing: ENVISpacing.md) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ENVITheme.success)

            VStack(alignment: .leading, spacing: 2) {
                Text("Best time to post")
                    .font(.interMedium(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                Text("\(best.dayLabel) at \(formatHour(best.hour))")
                    .font(.spaceMonoBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Avg engagement")
                    .font(.interRegular(9))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                Text(formatCompact(best.avgEngagement))
                    .font(.spaceMonoBold(14))
                    .foregroundColor(ENVITheme.success)
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.success.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
    }

    // MARK: - Heatmap Grid

    private var heatmapGrid: some View {
        VStack(spacing: 2) {
            // Hour header row
            HStack(spacing: 2) {
                Text("")
                    .frame(width: 30)

                ForEach(displayHours, id: \.self) { hour in
                    Text(formatHourShort(hour))
                        .font(.spaceMono(7))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day rows
            ForEach(0..<7, id: \.self) { day in
                HStack(spacing: 2) {
                    Text(dayLabels[day])
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        .frame(width: 30, alignment: .leading)

                    ForEach(displayHours, id: \.self) { hour in
                        let engagement = engagementFor(day: day, hour: hour)
                        let intensity = viewModel.maxEngagement > 0 ? engagement / viewModel.maxEngagement : 0

                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatmapColor(intensity: intensity))
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Legend

    private var heatmapLegend: some View {
        HStack(spacing: ENVISpacing.sm) {
            Text("Low")
                .font(.interRegular(9))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            HStack(spacing: 2) {
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(intensity: intensity))
                        .frame(width: 14, height: 14)
                }
            }

            Text("High")
                .font(.interRegular(9))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            Spacer()

            if !viewModel.postTimeAnalysis.isEmpty {
                let totalPosts = viewModel.postTimeAnalysis.reduce(0) { $0 + $1.postCount }
                Text("\(totalPosts) posts analyzed")
                    .font(.interRegular(9))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            }
        }
    }

    // MARK: - Helpers

    private func engagementFor(day: Int, hour: Int) -> Double {
        viewModel.postTimeAnalysis
            .first(where: { $0.dayOfWeek == day && $0.hour == hour })?
            .avgEngagement ?? 0
    }

    private func heatmapColor(intensity: Double) -> Color {
        if intensity < 0.01 {
            return ENVITheme.surfaceHigh(for: colorScheme)
        }
        // Use the theme text color with varying opacity for monochromatic feel
        return ENVITheme.text(for: colorScheme).opacity(0.1 + intensity * 0.7)
    }

    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour):00 \(period)"
    }

    private func formatHourShort(_ hour: Int) -> String {
        let period = hour >= 12 ? "p" : "a"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour)\(period)"
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }
}

#Preview {
    ScrollView {
        PostTimeHeatmapView(viewModel: AdvancedAnalyticsViewModel())
            .padding(ENVISpacing.xl)
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}

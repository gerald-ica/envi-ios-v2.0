import SwiftUI

/// Individual metric card for the 2×2 thread response grid.
/// Border on all sides, no background fill — editorial data card style.
struct MetricCardView: View {
    let metric: ThreadMetric
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Trend Colors (matching React ChatPanel.tsx)
    private static let trendUpColor   = Color(hex: "#4EEAA8")
    private static let trendDownColor = Color(hex: "#FF6B7A")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label — SpaceMono 10pt uppercase, 0.15em tracking
            Text(metric.label.uppercased())
                .font(.spaceMono(10))
                .tracking(10 * 0.15) // 0.15em tracking
                .foregroundColor(ENVITheme.text(for: colorScheme).opacity(0.5))

            // Value
            Text(metric.value)
                .font(.interBold(24))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            // Change + trend color
            Text(metric.change)
                .font(.spaceMono(11))
                .foregroundColor(trendColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ENVISpacing.lg)
        .overlay(
            Rectangle()
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private var trendColor: Color {
        switch metric.trend {
        case .up:
            return Self.trendUpColor
        case .down:
            return Self.trendDownColor
        case .neutral:
            return ENVITheme.text(for: colorScheme).opacity(0.4)
        }
    }
}

#Preview {
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
    ], spacing: 0) {
        MetricCardView(metric: ThreadMetric(label: "Alignment", value: "87%", change: "+5%", trend: .up))
        MetricCardView(metric: ThreadMetric(label: "Connection", value: "High", change: "↑12%", trend: .up))
        MetricCardView(metric: ThreadMetric(label: "Creative", value: "4.2/5", change: "-0.1", trend: .down))
        MetricCardView(metric: ThreadMetric(label: "Optimal", value: "2–5 PM", change: "Today", trend: .neutral))
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}

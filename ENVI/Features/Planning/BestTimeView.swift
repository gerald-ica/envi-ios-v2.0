import SwiftUI

/// Heatmap-style view showing optimal posting times across days and hours.
struct BestTimeView: View {
    let bestTimes: [BestTimeSlot]
    let selectedPlatform: SocialPlatform?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var filterPlatform: SocialPlatform?

    private let hours = Array(6...22)
    private let days = [
        (1, "SUN"), (2, "MON"), (3, "TUE"), (4, "WED"),
        (5, "THU"), (6, "FRI"), (7, "SAT")
    ]

    init(bestTimes: [BestTimeSlot], selectedPlatform: SocialPlatform? = nil) {
        self.bestTimes = bestTimes
        self.selectedPlatform = selectedPlatform
        self._filterPlatform = State(initialValue: selectedPlatform)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                    // Description
                    Text("Tap an optimal time slot to schedule content when your audience is most active.")
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.xl)

                    // Platform filter chips
                    platformChips

                    // Heatmap
                    heatmapGrid

                    // Score legend
                    scoreLegend
                }
                .padding(.top, ENVISpacing.md)
                .padding(.bottom, ENVISpacing.xxxl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("BEST TIMES")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.interMedium(13))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            }
        }
    }

    // MARK: - Platform Chips

    private var platformChips: some View {
        ENVIPlatformFilterBar(selectedPlatform: $filterPlatform)
    }

    // MARK: - Heatmap Grid

    private var heatmapGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                // Hour headers
                HStack(spacing: 2) {
                    Color.clear.frame(width: 36, height: 20)
                    ForEach(hours, id: \.self) { hour in
                        Text(shortHourLabel(hour))
                            .font(.spaceMono(7))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                            .frame(width: 28, height: 20)
                    }
                }

                // Day rows
                ForEach(days, id: \.0) { dayOfWeek, dayLabel in
                    HStack(spacing: 2) {
                        Text(dayLabel)
                            .font(.spaceMono(8))
                            .tracking(0.5)
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                            .frame(width: 36, alignment: .leading)

                        ForEach(hours, id: \.self) { hour in
                            let score = bestScore(day: dayOfWeek, hour: hour)
                            heatmapCell(score: score)
                        }
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private func heatmapCell(score: Double) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(heatmapColor(score: score))
            .frame(width: 28, height: 28)
            .overlay {
                if score >= 0.85 {
                    Image(systemName: "star.fill")
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
    }

    // MARK: - Score Legend

    private var scoreLegend: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("ENGAGEMENT SCORE")
                .font(.spaceMono(9))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            HStack(spacing: ENVISpacing.sm) {
                Text("Low")
                    .font(.interRegular(10))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                HStack(spacing: 2) {
                    ForEach([0.0, 0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { score in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatmapColor(score: score))
                            .frame(width: 20, height: 12)
                    }
                }

                Text("High")
                    .font(.interRegular(10))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Helpers

    private var filteredTimes: [BestTimeSlot] {
        guard let platform = filterPlatform else { return bestTimes }
        return bestTimes.filter { $0.platform == platform }
    }

    private func bestScore(day: Int, hour: Int) -> Double {
        let matching = filteredTimes.filter { $0.dayOfWeek == day && $0.hour == hour }
        guard !matching.isEmpty else { return 0 }
        return matching.map(\.score).max() ?? 0
    }

    private func heatmapColor(score: Double) -> Color {
        if score <= 0 {
            return ENVITheme.surfaceLow(for: colorScheme)
        }
        // Gradient from subtle to vivid orange/amber
        let base = Color.orange
        return base.opacity(0.15 + (score * 0.75))
    }

    private func shortHourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "a" : "p"
        return "\(h)\(suffix)"
    }

}

#Preview {
    BestTimeView(bestTimes: BestTimeSlot.mock)
        .preferredColorScheme(.dark)
}

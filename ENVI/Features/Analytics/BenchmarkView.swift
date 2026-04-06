import SwiftUI

/// Benchmark cards comparing user metrics against industry averages and top performers.
struct BenchmarkView: View {
    @ObservedObject var viewModel: BenchmarkViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Header
            Text("BENCHMARKS")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            // Category picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(IndustryCategory.allCases) { category in
                        categoryChip(category)
                    }
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, ENVISpacing.xl)
            } else if viewModel.benchmarks.isEmpty {
                Text("No benchmark data available.")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, ENVISpacing.xl)
            } else {
                ForEach(viewModel.benchmarks) { benchmark in
                    benchmarkCard(benchmark)
                }
            }
        }
        .padding(ENVISpacing.lg)
    }

    // MARK: - Category Chip

    @ViewBuilder
    private func categoryChip(_ category: IndustryCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        Button {
            viewModel.changeCategory(category)
        } label: {
            Text(category.displayName)
                .font(.interMedium(11))
                .foregroundColor(isSelected ? ENVITheme.background(for: colorScheme) : ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.xs)
                .background(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.surfaceHigh(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }

    // MARK: - Benchmark Card

    @ViewBuilder
    private func benchmarkCard(_ benchmark: Benchmark) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Text(benchmark.metric)
                    .font(.interMedium(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                percentileBadge(benchmark.percentile)
            }

            // Comparison bars
            comparisonBar(label: "You", value: benchmark.userValue, maxValue: benchmark.topPerformer, color: ENVITheme.text(for: colorScheme))
            comparisonBar(label: "Industry Avg", value: benchmark.industryAvg, maxValue: benchmark.topPerformer, color: ENVITheme.textSecondary(for: colorScheme))
            comparisonBar(label: "Top Performer", value: benchmark.topPerformer, maxValue: benchmark.topPerformer, color: ENVITheme.accent(for: colorScheme))
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Comparison Bar

    @ViewBuilder
    private func comparisonBar(label: String, value: Double, maxValue: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.spaceMono(9))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                Spacer()
                Text(formattedValue(value))
                    .font(.spaceMono(9))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            GeometryReader { geo in
                let ratio = maxValue > 0 ? min(value / maxValue, 1.0) : 0
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * ratio)
            }
            .frame(height: 4)
            .background(ENVITheme.border(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    // MARK: - Percentile Badge

    @ViewBuilder
    private func percentileBadge(_ percentile: Int) -> some View {
        let color: Color = percentile >= 75 ? ENVITheme.success : (percentile >= 50 ? ENVITheme.warning : ENVITheme.error)
        Text("P\(percentile)")
            .font(.spaceMonoBold(10))
            .foregroundColor(.white)
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    // MARK: - Helpers

    private func formattedValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        BenchmarkView(viewModel: BenchmarkViewModel(repository: MockBenchmarkRepository()))
    }
}

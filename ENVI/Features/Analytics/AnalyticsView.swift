import SwiftUI

/// Main analytics dashboard screen.
struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                // Title row
                HStack {
                    Text("ANALYTICS")
                        .font(.spaceMonoBold(28))
                        .tracking(-1.5)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Spacer()

                    ENVIBadge(text: "Last 7 Days")
                }
                .padding(.horizontal, ENVISpacing.xl)

                // Date range
                Text(viewModel.dateRange)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xl)

                // Platform filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.sm) {
                        ForEach(viewModel.platforms, id: \.self) { platform in
                            ENVIChip(
                                title: viewModel.platformLabel(platform),
                                isSelected: viewModel.selectedPlatform == platform
                            ) {
                                viewModel.selectedPlatform = platform
                            }
                        }
                    }
                    .padding(.horizontal, ENVISpacing.xl)
                }

                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                        Text("Loading analytics...")
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }
                    .padding(.horizontal, ENVISpacing.xl)
                }

                if let error = viewModel.loadErrorMessage {
                    VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                        Text(error)
                            .font(.interMedium(13))
                            .foregroundColor(.red)
                        Button("Retry") {
                            Task { await viewModel.reload() }
                        }
                        .font(.interMedium(13))
                    }
                    .padding(.horizontal, ENVISpacing.xl)
                }

                // KPI Cards
                HStack(spacing: ENVISpacing.md) {
                    KPICardView(kpi: viewModel.data.reach)
                    KPICardView(kpi: viewModel.data.engagement)
                    KPICardView(kpi: viewModel.data.engagementRate)
                }
                .padding(.horizontal, ENVISpacing.xl)

                // Engagement Chart
                EngagementChartView(data: viewModel.data.dailyEngagement)
                    .padding(.horizontal, ENVISpacing.xl)

                CreatorGrowthSectionView(growth: viewModel.growth)
                    .padding(.horizontal, ENVISpacing.xl)

                RetentionCohortView(cohorts: viewModel.cohorts)
                    .padding(.horizontal, ENVISpacing.xl)

                SourceAttributionView(attributions: viewModel.attribution)
                    .padding(.horizontal, ENVISpacing.xl)

                // Content Calendar
                ContentCalendarView(days: viewModel.displayedCalendarDays)
                    .padding(.horizontal, ENVISpacing.xl)
            }
            .padding(.top, ENVISpacing.lg)
            .padding(.bottom, 100)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable {
            await viewModel.reload()
        }
    }
}

#Preview {
    AnalyticsView()
        .preferredColorScheme(.dark)
}

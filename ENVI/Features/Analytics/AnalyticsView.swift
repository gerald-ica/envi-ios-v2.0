import SwiftUI

/// Main analytics dashboard screen matching Sketch frame "16 - Analytics".
/// Now pushed from Profile (no longer a standalone tab).
struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @StateObject private var advancedViewModel = AdvancedAnalyticsViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                // MARK: - Title + Badge
                HStack(alignment: .center) {
                    Text("ANALYTICS")
                        .font(.spaceMonoBold(28))
                        .tracking(-1.5)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Spacer()

                    Text("LAST 7 DAYS")
                        .font(.spaceMonoBold(10))
                        .tracking(2.0)
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, ENVISpacing.xs)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
                .padding(.horizontal, ENVISpacing.xl)

                // Date range subtitle
                Text(viewModel.dateRange)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xl)

                // MARK: - Platform Filter Chips
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

                // Loading / Error
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

                // MARK: - KPI Cards (green dot + green delta)
                HStack(spacing: ENVISpacing.md) {
                    KPICardView(kpi: viewModel.data.reach)
                    KPICardView(kpi: viewModel.data.engagement)
                    KPICardView(kpi: viewModel.data.engagementRate)
                }
                .padding(.horizontal, ENVISpacing.xl)

                // MARK: - Engagement Bar Chart
                EngagementChartView(data: viewModel.data.dailyEngagement)
                    .padding(.horizontal, ENVISpacing.xl)

                // MARK: - Advanced Analytics (D20)
                PerformanceReportView(viewModel: advancedViewModel)
                    .padding(.horizontal, ENVISpacing.xl)

                AudienceDemographicsView(viewModel: advancedViewModel)
                    .padding(.horizontal, ENVISpacing.xl)

                ContentLeaderboardView(viewModel: advancedViewModel)
                    .padding(.horizontal, ENVISpacing.xl)

                PostTimeHeatmapView(viewModel: advancedViewModel)
                    .padding(.horizontal, ENVISpacing.xl)

                CreatorGrowthSectionView(growth: viewModel.growth)
                    .padding(.horizontal, ENVISpacing.xl)

                RetentionCohortView(cohorts: viewModel.cohorts)
                    .padding(.horizontal, ENVISpacing.xl)

                SourceAttributionView(attributions: viewModel.attribution)
                    .padding(.horizontal, ENVISpacing.xl)

                // MARK: - Content Calendar
                ContentCalendarView(days: viewModel.displayedCalendarDays)
                    .padding(.horizontal, ENVISpacing.xl)
            }
            .padding(.top, ENVISpacing.lg)
            .padding(.bottom, 100)
        }
        .background(ENVITheme.background(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.reload()
            await advancedViewModel.loadAll()
        }
    }
}

#Preview {
    NavigationStack {
        AnalyticsView()
    }
    .preferredColorScheme(.dark)
}

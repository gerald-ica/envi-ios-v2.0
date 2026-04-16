import SwiftUI

/// Main analytics dashboard screen matching Sketch frame "16 - Analytics".
/// Now pushed from Profile (no longer a standalone tab).
struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @StateObject private var advancedViewModel = AdvancedAnalyticsViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header

                platformChips

                if viewModel.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading analytics...")
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }
                    .padding(.horizontal, 24)
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
                    .padding(.horizontal, 24)
                }

                HStack(spacing: 8) {
                    KPICardView(kpi: viewModel.data.reach)
                    KPICardView(kpi: viewModel.data.engagement)
                    KPICardView(kpi: viewModel.data.engagementRate)
                }
                .padding(.horizontal, 24)

                EngagementChartView(data: viewModel.data.dailyEngagement)
                    .padding(.horizontal, 24)

                PerformanceReportView(viewModel: advancedViewModel)
                    .padding(.horizontal, 24)

                AudienceDemographicsView(viewModel: advancedViewModel)
                    .padding(.horizontal, 24)

                ContentLeaderboardView(viewModel: advancedViewModel)
                    .padding(.horizontal, 24)

                PostTimeHeatmapView(viewModel: advancedViewModel)
                    .padding(.horizontal, 24)

                CreatorGrowthSectionView(growth: viewModel.growth)
                    .padding(.horizontal, 24)

                RetentionCohortView(cohorts: viewModel.cohorts)
                    .padding(.horizontal, 24)

                SourceAttributionView(attributions: viewModel.attribution)
                    .padding(.horizontal, 24)

                ContentCalendarView(days: viewModel.displayedCalendarDays)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
        .background(AppBackground(imageName: "analytics-bg"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.reload()
            await advancedViewModel.loadAll()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ANALYTICS")
                        .font(.spaceMonoBold(34))
                        .tracking(-1.7)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(viewModel.dateRange)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }

                Spacer()

                Text("LAST 7 DAYS")
                    .font(.spaceMonoBold(10))
                    .tracking(1.8)
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.horizontal, 24)
    }

    private var platformChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.platforms, id: \.self) { platform in
                    ENVIChip(
                        title: viewModel.platformLabel(platform),
                        isSelected: viewModel.selectedPlatform == platform
                    ) {
                        viewModel.selectedPlatform = platform
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    NavigationStack {
        AnalyticsView()
    }
    .preferredColorScheme(.dark)
}

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
                    Text("Analytics")
                        .font(.interBlack(28))
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

                // Content Calendar
                ContentCalendarView(days: viewModel.data.calendarDays)
                    .padding(.horizontal, ENVISpacing.xl)
            }
            .padding(.top, ENVISpacing.lg)
            .padding(.bottom, 100)
        }
        .background(ENVITheme.background(for: colorScheme))
    }
}

#Preview {
    AnalyticsView()
        .preferredColorScheme(.dark)
}

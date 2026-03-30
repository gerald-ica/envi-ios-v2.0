import SwiftUI

/// Main analytics dashboard screen.
struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDatePickerAlert = false

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

                    Button {
                        showDatePickerAlert = true
                    } label: {
                        ENVIBadge(text: "Last 7 Days")
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)

                // Date range
                Text(viewModel.dateRange)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xl)

                // Error state
                if let error = viewModel.error {
                    Text(error)
                        .font(.interRegular(13))
                        .foregroundColor(.red)
                        .padding(.horizontal, ENVISpacing.xl)
                }

                // Loading state
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(ENVITheme.textLight(for: colorScheme))
                        Spacer()
                    }
                    .padding(.vertical, ENVISpacing.lg)
                }

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
                    KPICardView(kpi: viewModel.filteredData.reach)
                    KPICardView(kpi: viewModel.filteredData.engagement)
                    KPICardView(kpi: viewModel.filteredData.engagementRate)
                }
                .padding(.horizontal, ENVISpacing.xl)

                // Engagement Chart
                EngagementChartView(data: viewModel.filteredData.dailyEngagement)
                    .padding(.horizontal, ENVISpacing.xl)

                // Content Calendar
                ContentCalendarView(days: viewModel.filteredData.calendarDays)
                    .padding(.horizontal, ENVISpacing.xl)
            }
            .padding(.top, ENVISpacing.lg)
            .padding(.bottom, 100)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable { await viewModel.refresh() }
        .alert("Date Range", isPresented: $showDatePickerAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Custom date picker coming soon.")
        }
    }
}

#Preview {
    AnalyticsView()
        .preferredColorScheme(.dark)
}

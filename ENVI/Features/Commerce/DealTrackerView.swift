import SwiftUI

/// Sponsorship deal tracker with status pipeline and budget metrics (ENVI-0696..0705).
struct DealTrackerView: View {

    @StateObject private var viewModel = CommerceViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                pipelineMetrics
                statusFilter
                dealList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await viewModel.loadDeals() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("DEAL TRACKER")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Manage sponsorship deals and brand partnerships")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Pipeline Metrics

    private var pipelineMetrics: some View {
        HStack(spacing: ENVISpacing.lg) {
            metricCard(label: "PIPELINE", value: formattedPipeline)
            metricCard(label: "ACTIVE", value: "\(activeDealCount)")
            metricCard(label: "COMPLETED", value: "\(completedDealCount)")
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private var formattedPipeline: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: viewModel.pipelineValue as NSDecimalNumber) ?? "$0"
    }

    private var activeDealCount: Int {
        viewModel.deals.filter {
            $0.status != .completed && $0.status != .declined
        }.count
    }

    private var completedDealCount: Int {
        viewModel.deals.filter { $0.status == .completed }.count
    }

    private func metricCard(label: String, value: String) -> some View {
        VStack(spacing: ENVISpacing.xs) {
            Text(label)
                .font(.spaceMono(10))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Text(value)
                .font(.spaceMonoBold(18))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Status Filter

    private var statusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                filterChip(label: "ALL", status: nil)
                ForEach(DealStatus.allCases) { status in
                    filterChip(label: status.displayName.uppercased(), status: status)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private func filterChip(label: String, status: DealStatus?) -> some View {
        let isSelected = viewModel.selectedDealFilter == status
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedDealFilter = status
            }
        } label: {
            Text(label)
                .font(.spaceMonoBold(10))
                .tracking(0.88)
                .foregroundColor(isSelected
                    ? ENVITheme.background(for: colorScheme)
                    : ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(isSelected
                    ? ENVITheme.text(for: colorScheme)
                    : ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }

    // MARK: - Deal List

    private var dealList: some View {
        LazyVStack(spacing: ENVISpacing.md) {
            if viewModel.isLoadingDeals {
                ENVILoadingState()
            } else if viewModel.filteredDeals.isEmpty {
                Text("No deals match this filter.")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ForEach(viewModel.filteredDeals) { deal in
                    dealCard(deal)
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func dealCard(_ deal: SponsorshipDeal) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Top row: brand + status
            HStack {
                Text(deal.brandName)
                    .font(.spaceMonoBold(15))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                HStack(spacing: ENVISpacing.xs) {
                    Image(systemName: deal.status.iconName)
                        .font(.system(size: 10))
                    Text(deal.status.displayName.uppercased())
                        .font(.spaceMonoBold(9))
                        .tracking(0.88)
                }
                .foregroundColor(statusColor(deal.status))
                .padding(.horizontal, ENVISpacing.sm)
                .padding(.vertical, ENVISpacing.xs)
                .background(statusColor(deal.status).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            // Budget + deadline
            HStack(spacing: ENVISpacing.lg) {
                Label {
                    Text(deal.formattedBudget)
                        .font(.spaceMono(12))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                } icon: {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Label {
                    Text(deal.daysRemaining >= 0
                        ? "\(deal.daysRemaining)d left"
                        : "\(abs(deal.daysRemaining))d overdue")
                        .font(.spaceMono(12))
                        .foregroundColor(deal.daysRemaining < 0
                            ? ENVITheme.error
                            : ENVITheme.text(for: colorScheme))
                } icon: {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            // Deliverables
            HStack(spacing: ENVISpacing.xs) {
                ForEach(deal.deliverables, id: \.self) { item in
                    Text(item)
                        .font(.spaceMono(9))
                        .tracking(0.44)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, ENVISpacing.xs)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }

            // Pipeline progress bar
            pipelineBar(for: deal.status)
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func pipelineBar(for status: DealStatus) -> some View {
        let stages: [DealStatus] = [.inquiry, .negotiation, .accepted, .inProgress, .delivered, .completed]
        let currentIndex = stages.firstIndex(of: status) ?? 0
        return HStack(spacing: 2) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index <= currentIndex
                        ? ENVITheme.text(for: colorScheme)
                        : ENVITheme.surfaceHigh(for: colorScheme))
                    .frame(height: 3)
            }
        }
    }

    private func statusColor(_ status: DealStatus) -> Color {
        switch status {
        case .inquiry, .negotiation: return ENVITheme.info
        case .accepted, .inProgress: return ENVITheme.warning
        case .delivered, .completed: return ENVITheme.success
        case .declined:             return ENVITheme.error
        }
    }
}

#Preview {
    DealTrackerView()
        .preferredColorScheme(.dark)
}

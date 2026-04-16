import SwiftUI

/// Agency dashboard with KPI cards, client overview, and revenue chart.
struct AgencyDashboardView: View {
    @ObservedObject var viewModel: AgencyViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                kpiCards
                revenueChart
                clientOverview
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable { await viewModel.loadDashboard() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("AGENCY DASHBOARD")
                .font(.spaceMonoBold(17))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Multi-client overview")
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - KPI Cards

    private var kpiCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ENVISpacing.md) {
            kpiCard(
                title: "Total Clients",
                value: "\(viewModel.dashboard.totalClients)",
                icon: "person.3.fill",
                accent: ENVITheme.text(for: colorScheme)
            )
            kpiCard(
                title: "Active",
                value: "\(viewModel.dashboard.activeClients)",
                icon: "checkmark.circle.fill",
                accent: ENVITheme.success
            )
            kpiCard(
                title: "Revenue",
                value: viewModel.dashboard.formattedRevenue,
                icon: "dollarsign.circle.fill",
                accent: ENVITheme.info
            )
            kpiCard(
                title: "Pending",
                value: "\(viewModel.dashboard.pendingApprovals)",
                icon: "clock.fill",
                accent: ENVITheme.warning
            )
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func kpiCard(title: String, value: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(accent)

                Spacer()
            }

            Text(value)
                .font(.spaceMonoBold(22))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Revenue Chart

    private var revenueChart: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("REVENUE BY CLIENT")
                .font(.spaceMonoBold(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            VStack(spacing: ENVISpacing.sm) {
                let maxAmount = viewModel.revenueByClient.map(\.amount).max() ?? 1

                ForEach(Array(viewModel.revenueByClient.prefix(6).enumerated()), id: \.offset) { _, entry in
                    revenueBar(name: entry.name, amount: entry.amount, maxAmount: maxAmount)
                }
            }
            .padding(ENVISpacing.lg)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private func revenueBar(name: String, amount: Double, maxAmount: Double) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            HStack {
                Text(name)
                    .font(.interMedium(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)

                Spacer()

                Text(formattedCurrency(amount))
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .fill(ENVITheme.text(for: colorScheme).opacity(0.15))
                    .frame(width: geometry.size.width)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .fill(ENVITheme.text(for: colorScheme))
                            .frame(width: max(4, geometry.size.width * CGFloat(amount / maxAmount)))
                    }
            }
            .frame(height: 6)
        }
    }

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    // MARK: - Client Overview

    private var clientOverview: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                Text("CLIENT OVERVIEW")
                    .font(.spaceMonoBold(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                retentionBadge
            }
            .padding(.horizontal, ENVISpacing.xl)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.clients.prefix(5))) { client in
                    clientRow(client)

                    if client.id != viewModel.clients.prefix(5).last?.id {
                        Divider()
                            .background(ENVITheme.border(for: colorScheme))
                    }
                }
            }
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private var retentionBadge: some View {
        let rate = viewModel.dashboard.clientRetentionRate
        return HStack(spacing: ENVISpacing.xs) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 9))
            Text(String(format: "%.0f%% retention", rate))
                .font(.spaceMono(10))
        }
        .foregroundColor(rate >= 75 ? ENVITheme.success : ENVITheme.warning)
        .padding(.horizontal, ENVISpacing.sm)
        .padding(.vertical, ENVISpacing.xs)
        .background((rate >= 75 ? ENVITheme.success : ENVITheme.warning).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func clientRow(_ client: ClientAccount) -> some View {
        HStack(spacing: ENVISpacing.md) {
            // Avatar circle with initial
            Text(String(client.name.prefix(1)))
                .font(.interSemiBold(13))
                .foregroundColor(ENVITheme.background(for: colorScheme))
                .frame(width: 32, height: 32)
                .background(ENVITheme.text(for: colorScheme))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .font(.interMedium(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)

                Text(client.industry)
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            HStack(spacing: ENVISpacing.xs) {
                Circle()
                    .fill(clientStatusColor(client.status))
                    .frame(width: 6, height: 6)

                Text(client.status.displayName)
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
        .padding(.horizontal, ENVISpacing.lg)
        .padding(.vertical, ENVISpacing.md)
    }

    private func clientStatusColor(_ status: ClientStatus) -> Color {
        switch status {
        case .active:     return ENVITheme.success
        case .paused:     return ENVITheme.warning
        case .onboarding: return ENVITheme.info
        case .churned:    return ENVITheme.error
        }
    }
}

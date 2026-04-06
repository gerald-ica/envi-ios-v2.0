import SwiftUI

/// Client list with cards showing industry, platform badges, budget, and status.
struct ClientListView: View {
    @ObservedObject var viewModel: AgencyViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                searchBar
                statusFilterBar
                clientList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable { await viewModel.loadClients() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("CLIENTS")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.filteredClients.count) accounts")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: ENVISpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextField("Search clients…", text: $viewModel.clientSearchText)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.md)
        .padding(.vertical, ENVISpacing.sm + 2)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.md)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Status Filter

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                filterChip(title: "All", isSelected: viewModel.statusFilter == nil) {
                    viewModel.statusFilter = nil
                }
                ForEach(ClientStatus.allCases) { status in
                    filterChip(title: status.displayName, isSelected: viewModel.statusFilter == status) {
                        viewModel.statusFilter = status
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.interMedium(13))
                .foregroundColor(isSelected ? ENVITheme.background(for: colorScheme) : ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(isSelected ? Color.clear : ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
        }
    }

    // MARK: - Client List

    private var clientList: some View {
        LazyVStack(spacing: ENVISpacing.md) {
            if viewModel.isLoadingClients {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.filteredClients.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.filteredClients) { client in
                    NavigationLink(value: client.id) {
                        clientCard(client)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.error)
                    .padding(.horizontal, ENVISpacing.xl)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Client Card

    private func clientCard(_ client: ClientAccount) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Name & Status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    Text(client.name)
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .lineLimit(1)

                    Text(client.industry)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                statusBadge(client.status)
            }

            // Platform badges
            if !client.connectedPlatforms.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.xs) {
                        ForEach(client.connectedPlatforms) { platform in
                            platformBadge(platform)
                        }
                    }
                }
            }

            // Contact & Budget
            HStack(spacing: ENVISpacing.lg) {
                Label {
                    Text(client.contactName)
                        .font(.spaceMono(11))
                } icon: {
                    Image(systemName: "person")
                        .font(.system(size: 11))
                }
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Text(client.formattedBudget)
                    .font(.spaceMonoBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("/mo")
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Platform Badge

    private func platformBadge(_ platform: ConnectedPlatform) -> some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: platform.iconName)
                .font(.system(size: 10))
            Text(platform.displayName)
                .font(.spaceMono(10))
        }
        .foregroundColor(ENVITheme.text(for: colorScheme))
        .padding(.horizontal, ENVISpacing.sm)
        .padding(.vertical, ENVISpacing.xs)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: ClientStatus) -> some View {
        HStack(spacing: ENVISpacing.xs) {
            Image(systemName: status.iconName)
                .font(.system(size: 10))
            Text(status.displayName)
                .font(.spaceMono(10))
        }
        .foregroundColor(statusColor(status))
        .padding(.horizontal, ENVISpacing.sm)
        .padding(.vertical, ENVISpacing.xs)
        .background(statusColor(status).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func statusColor(_ status: ClientStatus) -> Color {
        switch status {
        case .active:     return ENVITheme.success
        case .paused:     return ENVITheme.warning
        case .onboarding: return ENVITheme.info
        case .churned:    return ENVITheme.error
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No clients found")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Add your first client to get started.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

import SwiftUI

/// Grid of available integrations by category with connect/disconnect (ENVI-0833..0840).
struct IntegrationMarketplaceView: View {

    @StateObject private var viewModel = IntegrationViewModel()
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: ENVISpacing.md),
        GridItem(.flexible(), spacing: ENVISpacing.md),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                statsBar
                searchBar
                categoryBar
                integrationGrid
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await viewModel.loadIntegrations() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("INTEGRATIONS")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Connect your favorite tools and services")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: ENVISpacing.md) {
            statPill(label: "CONNECTED", value: "\(viewModel.connectedCount)")
            statPill(label: "AVAILABLE", value: "\(viewModel.integrations.count)")
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: ENVISpacing.xs) {
            Text(value)
                .font(.spaceMonoBold(20))
                .foregroundColor(ENVITheme.text(for: colorScheme))
            Text(label)
                .font(.spaceMono(9))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: ENVISpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextField("Search integrations...", text: $viewModel.searchText)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                categoryChip(label: "ALL", icon: "square.grid.2x2", category: nil)
                ForEach(IntegrationCategory.allCases) { cat in
                    categoryChip(label: cat.displayName.uppercased(), icon: cat.iconName, category: cat)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private func categoryChip(label: String, icon: String, category: IntegrationCategory?) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedCategory = category
            }
        } label: {
            HStack(spacing: ENVISpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.spaceMonoBold(10))
                    .tracking(0.88)
            }
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

    // MARK: - Integration Grid

    private var integrationGrid: some View {
        Group {
            if viewModel.isLoadingIntegrations {
                ENVILoadingState(minHeight: 200)
            } else if viewModel.filteredIntegrations.isEmpty {
                ENVIEmptyState(
                    icon: "puzzlepiece.extension",
                    title: "No integrations found"
                )
            } else {
                LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
                    ForEach(viewModel.filteredIntegrations) { integration in
                        integrationCard(integration)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    private func integrationCard(_ integration: Integration) -> some View {
        VStack(spacing: ENVISpacing.sm) {
            // Icon
            ZStack {
                Circle()
                    .fill(ENVITheme.surfaceHigh(for: colorScheme))
                    .frame(width: 44, height: 44)
                Image(systemName: integration.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            // Name
            Text(integration.name)
                .font(.spaceMonoBold(12))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(1)

            // Category
            Text(integration.category.displayName.uppercased())
                .font(.spaceMono(8))
                .tracking(0.44)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            // Description
            Text(integration.description)
                .font(.interRegular(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Connect / Disconnect button
            connectButton(for: integration)
        }
        .padding(ENVISpacing.md)
        .frame(minHeight: 190)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(integration.status == .connected
                    ? ENVITheme.success.opacity(0.4)
                    : ENVITheme.border(for: colorScheme),
                    lineWidth: 1)
        )
    }

    private func connectButton(for integration: Integration) -> some View {
        Button {
            Task {
                if integration.status == .connected {
                    await viewModel.disconnect(integrationId: integration.id)
                } else {
                    await viewModel.connect(integrationId: integration.id)
                }
            }
        } label: {
            Text(integration.status == .connected ? "DISCONNECT" : "CONNECT")
                .font(.spaceMonoBold(10))
                .tracking(0.44)
                .foregroundColor(integration.status == .connected
                    ? ENVITheme.error
                    : ENVITheme.background(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.sm)
                .background(integration.status == .connected
                    ? ENVITheme.surfaceHigh(for: colorScheme)
                    : ENVITheme.text(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
        .disabled(viewModel.isConnecting)
    }
}

#Preview {
    IntegrationMarketplaceView()
        .preferredColorScheme(.dark)
}

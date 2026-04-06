import SwiftUI

/// Browsable creator marketplace grid with category filtering and search (ENVI-0706..0725).
struct MarketplaceView: View {

    @StateObject private var viewModel = CommerceViewModel()
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: ENVISpacing.md),
        GridItem(.flexible(), spacing: ENVISpacing.md),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                searchBar
                categoryBar
                listingGrid
                ugcSection
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task {
            async let m: () = viewModel.loadMarketplace()
            async let u: () = viewModel.loadUGCRequests()
            _ = await (m, u)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("MARKETPLACE")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Discover templates, presets, courses, and more")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: ENVISpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextField("Search marketplace...", text: $viewModel.marketplaceSearchText)
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
                ForEach(MarketplaceCategory.allCases) { cat in
                    categoryChip(label: cat.displayName.uppercased(), icon: cat.iconName, category: cat)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private func categoryChip(label: String, icon: String, category: MarketplaceCategory?) -> some View {
        let isSelected = viewModel.selectedMarketplaceCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedMarketplaceCategory = category
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

    // MARK: - Listing Grid

    private var listingGrid: some View {
        Group {
            if viewModel.isLoadingMarketplace {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if viewModel.filteredMarketplace.isEmpty {
                ENVIEmptyState(
                    icon: "tray",
                    title: "No listings found"
                )
            } else {
                LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
                    ForEach(viewModel.filteredMarketplace) { listing in
                        listingCard(listing)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    private func listingCard(_ listing: MarketplaceListing) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: ENVIRadius.md)
                    .fill(ENVITheme.surfaceHigh(for: colorScheme))
                    .aspectRatio(1.4, contentMode: .fit)
                Image(systemName: listing.category.iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            // Title
            Text(listing.title)
                .font(.spaceMonoBold(12))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Creator
            Text(listing.creatorName)
                .font(.interRegular(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .lineLimit(1)

            // Bottom row: price + rating + downloads
            HStack(spacing: ENVISpacing.xs) {
                Text(listing.formattedPrice)
                    .font(.spaceMonoBold(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(ENVITheme.warning)
                    Text(String(format: "%.1f", listing.rating))
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                HStack(spacing: 2) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 8))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    Text("\(listing.downloads)")
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - UGC Requests Section

    private var ugcSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("UGC OPPORTUNITIES")
                .font(.spaceMonoBold(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            if viewModel.isLoadingUGC {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                LazyVStack(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.ugcRequests) { request in
                        ugcCard(request)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    private func ugcCard(_ request: UGCRequest) -> some View {
        HStack(spacing: ENVISpacing.md) {
            // Brand initial avatar
            ZStack {
                Circle()
                    .fill(ENVITheme.surfaceHigh(for: colorScheme))
                    .frame(width: 40, height: 40)
                Text(String(request.brandName.prefix(1)).uppercased())
                    .font(.spaceMonoBold(16))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(request.brandName)
                    .font(.spaceMonoBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                Text(request.brief)
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(request.formattedCompensation)
                    .font(.spaceMonoBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(request.status.displayName.uppercased())
                    .font(.spaceMono(8))
                    .tracking(0.44)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xs)
                    .padding(.vertical, 2)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                if request.daysRemaining >= 0 {
                    Text("\(request.daysRemaining)d left")
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                } else {
                    Text("Overdue")
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.error)
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }
}

#Preview {
    MarketplaceView()
        .preferredColorScheme(.dark)
}

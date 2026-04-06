import SwiftUI

/// Product offer management dashboard with sales metrics and offer cards (ENVI-0676..0690).
struct OfferManagerView: View {

    @StateObject private var viewModel = CommerceViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                revenueStrip
                offerList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await viewModel.loadOffers() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("YOUR OFFERS")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Manage products, digital goods, and services")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Revenue Strip

    private var revenueStrip: some View {
        HStack(spacing: ENVISpacing.lg) {
            metricCard(label: "REVENUE", value: viewModel.formattedTotalRevenue)
            metricCard(label: "SALES", value: "\(viewModel.totalSales)")
            metricCard(label: "OFFERS", value: "\(viewModel.offers.count)")
        }
        .padding(.horizontal, ENVISpacing.xl)
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

    // MARK: - Offer List

    private var offerList: some View {
        LazyVStack(spacing: ENVISpacing.md) {
            if viewModel.isLoadingOffers {
                ENVILoadingState()
            } else {
                ForEach(viewModel.offers) { offer in
                    offerCard(offer)
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func offerCard(_ offer: ProductOffer) -> some View {
        HStack(spacing: ENVISpacing.lg) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: ENVIRadius.md)
                    .fill(ENVITheme.surfaceHigh(for: colorScheme))
                    .frame(width: 48, height: 48)
                Image(systemName: offer.type.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            // Details
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text(offer.name)
                    .font(.spaceMonoBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)

                HStack(spacing: ENVISpacing.sm) {
                    Text(offer.type.displayName.uppercased())
                        .font(.spaceMono(10))
                        .tracking(0.88)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Text("·")
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Text(offer.formattedPrice)
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            Spacer()

            // Sales count
            VStack(spacing: 2) {
                Text("\(offer.salesCount)")
                    .font(.spaceMonoBold(16))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                Text("SALES")
                    .font(.spaceMono(8))
                    .tracking(0.88)
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
}

#Preview {
    OfferManagerView()
        .preferredColorScheme(.dark)
}

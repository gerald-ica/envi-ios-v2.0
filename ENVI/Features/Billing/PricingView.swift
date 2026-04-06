import SwiftUI

/// Full pricing page with plan comparison cards, feature matrix,
/// monthly/annual toggle, and upgrade CTA.
struct PricingView: View {

    @StateObject private var viewModel = BillingViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: SubscriptionPlan?
    @State private var isPurchasing = false
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                intervalToggle
                planCards
                featureMatrix
                restoreButton
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await viewModel.loadAll() }
        .alert("Upgrade Successful", isPresented: $showSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Welcome to your new plan! All features are now unlocked.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("CHOOSE YOUR PLAN")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Scale your content creation with the right tools")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Interval Toggle

    private var intervalToggle: some View {
        HStack(spacing: 0) {
            intervalButton(label: "Monthly", interval: .monthly)
            intervalButton(label: "Annual", interval: .annual)
        }
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func intervalButton(label: String, interval: BillingInterval) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedInterval = interval
            }
        } label: {
            VStack(spacing: 2) {
                Text(label.uppercased())
                    .font(.spaceMono(12))
                    .tracking(0.88)

                if interval == .annual {
                    Text("Save 20%")
                        .font(.interRegular(10))
                        .foregroundColor(ENVITheme.success)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.md)
            .background(
                viewModel.selectedInterval == interval
                    ? ENVITheme.text(for: colorScheme)
                    : Color.clear
            )
            .foregroundColor(
                viewModel.selectedInterval == interval
                    ? ENVITheme.background(for: colorScheme)
                    : ENVITheme.textSecondary(for: colorScheme)
            )
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: ENVISpacing.lg) {
            if viewModel.isLoadingPlans {
                ENVILoadingState()
            } else {
                ForEach(viewModel.filteredPlans) { plan in
                    planCard(plan)
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func planCard(_ plan: SubscriptionPlan) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            // Title row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: ENVISpacing.sm) {
                        Text(plan.name.uppercased())
                            .font(.spaceMonoBold(16))
                            .tracking(-0.5)
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        if plan.isPopular {
                            Text("POPULAR")
                                .font(.spaceMono(9))
                                .tracking(0.5)
                                .padding(.horizontal, ENVISpacing.sm)
                                .padding(.vertical, 3)
                                .background(ENVITheme.text(for: colorScheme))
                                .foregroundColor(ENVITheme.background(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        }
                    }

                    Text(plan.formattedPrice)
                        .font(.spaceMonoBold(24))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }

                Spacer()

                if viewModel.isCurrentPlan(plan) {
                    Text("CURRENT")
                        .font(.spaceMono(10))
                        .tracking(0.88)
                        .padding(.horizontal, ENVISpacing.md)
                        .padding(.vertical, ENVISpacing.xs)
                        .overlay(
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .stroke(ENVITheme.success, lineWidth: 1)
                        )
                        .foregroundColor(ENVITheme.success)
                }
            }

            // Annual monthly equivalent
            if let monthly = plan.monthlyEquivalent {
                let formatted = NSDecimalNumber(decimal: monthly)
                    .description(withLocale: Locale(identifier: "en_US"))
                Text("$\(formatted)/mo billed annually")
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            // Features
            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack(spacing: ENVISpacing.sm) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ENVITheme.success)
                            .frame(width: 16)

                        Text(feature)
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                }
            }

            // CTA button
            if !viewModel.isCurrentPlan(plan) && plan.tier != .free {
                Button {
                    Task { await purchasePlan(plan) }
                } label: {
                    HStack {
                        if isPurchasing && selectedPlan == plan {
                            ProgressView()
                                .tint(ENVITheme.background(for: colorScheme))
                        }
                        Text(viewModel.ctaLabel(for: plan).uppercased())
                            .font(.spaceMonoBold(13))
                            .tracking(0.88)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ENVISpacing.md)
                    .background(
                        plan.isPopular
                            ? ENVITheme.text(for: colorScheme)
                            : Color.clear
                    )
                    .foregroundColor(
                        plan.isPopular
                            ? ENVITheme.background(for: colorScheme)
                            : ENVITheme.text(for: colorScheme)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .stroke(ENVITheme.border(for: colorScheme), lineWidth: plan.isPopular ? 0 : 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                }
                .disabled(isPurchasing)
            }
        }
        .padding(ENVISpacing.xl)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .stroke(
                    plan.isPopular ? ENVITheme.text(for: colorScheme) : Color.clear,
                    lineWidth: plan.isPopular ? 1.5 : 0
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Feature Matrix

    private var featureMatrix: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("COMPARE PLANS")
                .font(.spaceMonoBold(14))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            let features: [(String, [PricingTier])] = [
                ("Social Accounts",      [.free, .creator, .pro, .team]),
                ("Scheduled Posts",       [.free, .creator, .pro, .team]),
                ("Basic Analytics",       [.free, .creator, .pro, .team]),
                ("Advanced Analytics",    [.creator, .pro, .team]),
                ("AI Caption Generation", [.creator, .pro, .team]),
                ("Brand Kit",             [.pro, .team]),
                ("Content Calendar",      [.pro, .team]),
                ("Team Seats",            [.team]),
                ("Approval Workflows",    [.team]),
            ]

            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Feature")
                        .font(.interMedium(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach([PricingTier.free, .creator, .pro, .team], id: \.self) { tier in
                        Text(tier.displayName.prefix(4).uppercased())
                            .font(.spaceMono(9))
                            .tracking(0.5)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                            .frame(width: 44)
                    }
                }
                .padding(.vertical, ENVISpacing.sm)
                .padding(.horizontal, ENVISpacing.md)

                Divider().background(ENVITheme.border(for: colorScheme))

                // Feature rows
                ForEach(features, id: \.0) { feature, tiers in
                    HStack {
                        Text(feature)
                            .font(.interRegular(12))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach([PricingTier.free, .creator, .pro, .team], id: \.self) { tier in
                            if tiers.contains(tier) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(ENVITheme.success)
                                    .frame(width: 44)
                            } else {
                                Text("--")
                                    .font(.interRegular(10))
                                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                                    .frame(width: 44)
                            }
                        }
                    }
                    .padding(.vertical, ENVISpacing.sm)
                    .padding(.horizontal, ENVISpacing.md)

                    Divider().background(ENVITheme.border(for: colorScheme))
                }
            }
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task {
                let restored = await viewModel.restorePurchases()
                if restored { showSuccess = true }
            }
        } label: {
            Text("Restore Purchases")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.bottom, ENVISpacing.xxl)
    }

    // MARK: - Actions

    private func purchasePlan(_ plan: SubscriptionPlan) async {
        selectedPlan = plan
        isPurchasing = true
        let success = await viewModel.upgrade(to: plan)
        isPurchasing = false
        if success { showSuccess = true }
    }
}

#Preview {
    PricingView()
        .preferredColorScheme(.dark)
}

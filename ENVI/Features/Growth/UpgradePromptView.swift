import SwiftUI

/// Contextual upgrade prompt shown when a user hits a gated feature.
/// Displays what they need, a brief plan comparison, and an upgrade button.
struct UpgradePromptView: View {

    let feature: String
    let requiredTier: PricingTier
    let message: String

    @StateObject private var viewModel = BillingViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var showPricing = false
    @State private var isPurchasing = false

    var body: some View {
        VStack(spacing: ENVISpacing.xxl) {
            // Lock icon
            ZStack {
                Circle()
                    .fill(ENVITheme.surfaceHigh(for: colorScheme))
                    .frame(width: 72, height: 72)

                Image(systemName: "lock.fill")
                    .font(.system(size: 28))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }
            .padding(.top, ENVISpacing.xxxl)

            // Feature name
            Text(feature.uppercased())
                .font(.spaceMonoBold(16))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            // Message
            Text(message)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ENVISpacing.xxl)

            // Required tier card
            requiredTierCard

            // Quick upgrade button
            upgradeButton

            // See all plans link
            Button {
                showPricing = true
            } label: {
                Text("Compare all plans")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .underline()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(ENVITheme.background(for: colorScheme))
        .task { await viewModel.loadPlans() }
        .sheet(isPresented: $showPricing) {
            NavigationStack {
                PricingView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showPricing = false }
                                .font(.interRegular(14))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                        }
                    }
            }
        }
    }

    // MARK: - Required Tier Card

    private var requiredTierCard: some View {
        VStack(spacing: ENVISpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(requiredTier.displayName.uppercased())
                        .font(.spaceMonoBold(14))
                        .tracking(-0.5)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text("Required for \(feature)")
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                if let plan = matchingPlan {
                    Text(plan.formattedPrice)
                        .font(.spaceMonoBold(18))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            }

            // Key features of the required tier
            if let plan = matchingPlan {
                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    ForEach(plan.features.prefix(4), id: \.self) { feat in
                        HStack(spacing: ENVISpacing.sm) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(ENVITheme.success)
                                .frame(width: 16)

                            Text(feat)
                                .font(.interRegular(12))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                        }
                    }
                }
            }

            // Current vs required comparison
            HStack(spacing: ENVISpacing.xl) {
                tierComparison(
                    label: "YOUR PLAN",
                    tier: viewModel.currentTier,
                    isActive: true
                )

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                tierComparison(
                    label: "REQUIRED",
                    tier: requiredTier,
                    isActive: false
                )
            }
        }
        .padding(ENVISpacing.xl)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func tierComparison(label: String, tier: PricingTier, isActive: Bool) -> some View {
        VStack(spacing: ENVISpacing.xs) {
            Text(label)
                .font(.spaceMono(9))
                .tracking(0.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text(tier.displayName)
                .font(.spaceMonoBold(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Circle()
                .fill(isActive ? ENVITheme.warning : ENVITheme.success)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Upgrade Button

    private var upgradeButton: some View {
        Button {
            guard let plan = matchingPlan else { return }
            Task {
                isPurchasing = true
                let success = await viewModel.upgrade(to: plan)
                isPurchasing = false
                if success { dismiss() }
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(ENVITheme.background(for: colorScheme))
                }
                Text("UPGRADE TO \(requiredTier.displayName.uppercased())")
                    .font(.spaceMonoBold(14))
                    .tracking(0.88)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.lg)
            .background(ENVITheme.text(for: colorScheme))
            .foregroundColor(ENVITheme.background(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .disabled(isPurchasing)
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Helpers

    /// Find the monthly plan matching the required tier.
    private var matchingPlan: SubscriptionPlan? {
        viewModel.plans.first { $0.tier == requiredTier && $0.interval == .monthly }
    }
}

// MARK: - Convenience View Modifier

/// Presents an upgrade prompt sheet when triggered.
struct UpgradePromptModifier: ViewModifier {

    let prompt: UpgradePrompt?
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                if let prompt {
                    NavigationStack {
                        UpgradePromptView(
                            feature: prompt.feature,
                            requiredTier: prompt.requiredTier,
                            message: prompt.message
                        )
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { isPresented = false }
                            }
                        }
                    }
                    .presentationDetents([.large])
                }
            }
    }
}

extension View {

    /// Presents a contextual upgrade prompt when the binding is true.
    func upgradePrompt(_ prompt: UpgradePrompt?, isPresented: Binding<Bool>) -> some View {
        modifier(UpgradePromptModifier(prompt: prompt, isPresented: isPresented))
    }
}

#Preview {
    UpgradePromptView(
        feature: "Brand Kit",
        requiredTier: .pro,
        message: "Brand Kit is a Pro feature. Upgrade to save brand colors, fonts, and templates."
    )
    .preferredColorScheme(.dark)
}

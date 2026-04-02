import SwiftUI
import RevenueCat
import RevenueCatUI

/// Presents the RevenueCat remote paywall configured in the dashboard.
/// Falls back to a manual paywall if no remote template is configured.
struct ENVIPaywallView: View {

    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            PaywallView()
                .onPurchaseCompleted { customerInfo in
                    if customerInfo.entitlements[PurchaseConstants.auraEntitlementID]?.isActive == true {
                        dismiss()
                    }
                }
                .onRestoreCompleted { customerInfo in
                    if customerInfo.entitlements[PurchaseConstants.auraEntitlementID]?.isActive == true {
                        dismiss()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        }
                    }
                }
        }
    }
}

// MARK: - Manual Paywall Fallback

/// A hand-built paywall for when no remote RevenueCat paywall template is configured.
/// Uses the same ENVI design tokens so it feels native.
struct ManualPaywallView: View {

    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ENVISpacing.xxl) {
                    // Header
                    VStack(spacing: ENVISpacing.md) {
                        Text("AURA")
                            .font(.spaceMonoBold(32))
                            .tracking(-1.5)
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        Text("Unlock the full power of ENVI")
                            .font(.interRegular(16))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }
                    .padding(.top, ENVISpacing.xxxl)

                    // Feature list
                    VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                        FeatureRow(icon: "sparkles", text: "Unlimited AI content analysis")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced analytics & predictions")
                        FeatureRow(icon: "film.stack", text: "Priority export & rendering")
                        FeatureRow(icon: "brain.head.profile", text: "Full ENVI Brain access")
                        FeatureRow(icon: "infinity", text: "Unlimited content library storage")
                    }
                    .padding(.horizontal, ENVISpacing.xl)

                    // Packages
                    if let offering = purchaseManager.currentOffering {
                        VStack(spacing: ENVISpacing.md) {
                            ForEach(offering.availablePackages, id: \.identifier) { package in
                                PackageButton(package: package) {
                                    Task {
                                        let success = await purchaseManager.purchase(package)
                                        if success { dismiss() }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, ENVISpacing.xl)
                    } else {
                        ProgressView()
                            .tint(ENVITheme.text(for: colorScheme))
                            .task { await purchaseManager.fetchOfferings() }
                    }

                    // Restore
                    Button {
                        Task {
                            let restored = await purchaseManager.restorePurchases()
                            if restored { dismiss() }
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.interRegular(14))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }

                    // Error
                    if let error = purchaseManager.purchaseError {
                        Text(error)
                            .font(.interRegular(12))
                            .foregroundColor(ENVITheme.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, ENVISpacing.xl)
                    }

                    // Legal
                    HStack(spacing: ENVISpacing.md) {
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Text("·")
                        Link("Privacy Policy", destination: URL(string: "https://envi.app/privacy")!)
                    }
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    .padding(.bottom, ENVISpacing.xxxl)
                }
            }
            .background(ENVITheme.background(for: colorScheme))
            .overlay {
                if purchaseManager.isPurchasing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

private struct FeatureRow: View {
    let icon: String
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: ENVISpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ENVITheme.accent(for: colorScheme))
                .frame(width: 28)

            Text(text)
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
    }
}

private struct PackageButton: View {
    let package: Package
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(package.storeProduct.localizedTitle)
                    .font(.interSemiBold(16))
                    .foregroundColor(.white)

                Text(package.localizedPriceString)
                    .font(.spaceMono(13))
                    .foregroundColor(.white.opacity(0.8))

                if let intro = package.storeProduct.introductoryDiscount {
                    Text(introText(for: intro))
                        .font(.interRegular(11))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.lg)
            .background(ENVITheme.accent(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
    }

    private func introText(for discount: StoreProductDiscount) -> String {
        switch discount.paymentMode {
        case .freeTrial:
            return "Start free trial"
        case .payUpFront:
            return "Pay up front — \(discount.localizedPriceString)"
        case .payAsYouGo:
            return "Introductory price"
        @unknown default:
            return ""
        }
    }
}

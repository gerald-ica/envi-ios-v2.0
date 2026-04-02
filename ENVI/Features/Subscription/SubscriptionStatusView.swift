import SwiftUI
import RevenueCat

/// Compact card that shows the user's current subscription status.
/// Tap opens the paywall (if not subscribed) or Customer Center (if subscribed).
struct SubscriptionStatusView: View {

    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var showPaywall = false
    @State private var showCustomerCenter = false

    var body: some View {
        Button {
            if purchaseManager.isAuraActive {
                showCustomerCenter = true
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: ENVISpacing.md) {
                // Status indicator
                Circle()
                    .fill(purchaseManager.isAuraActive
                          ? ENVITheme.success
                          : ENVITheme.warning)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(purchaseManager.isAuraActive ? "AURA ACTIVE" : "FREE PLAN")
                        .font(.spaceMono(11))
                        .tracking(0.88)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(purchaseManager.isAuraActive
                         ? "Manage subscription"
                         : "Upgrade to unlock all features")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            }
            .padding(ENVISpacing.lg)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .sheet(isPresented: $showPaywall) {
            ENVIPaywallView()
        }
        .sheet(isPresented: $showCustomerCenter) {
            ENVICustomerCenterView()
        }
    }
}

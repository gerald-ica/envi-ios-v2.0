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
        MainAppSubscriptionRow(
            title: purchaseManager.isAuraActive ? "AURA ACTIVE" : "FREE PLAN",
            subtitle: purchaseManager.isAuraActive ? "Manage subscription" : "Upgrade to unlock all features",
            isActive: purchaseManager.isAuraActive
        ) {
            if purchaseManager.isAuraActive {
                showCustomerCenter = true
            } else {
                showPaywall = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            ENVIPaywallView()
        }
        .sheet(isPresented: $showCustomerCenter) {
            ENVICustomerCenterView()
        }
    }
}

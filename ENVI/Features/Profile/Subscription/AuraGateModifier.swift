import SwiftUI
import RevenueCatUI

/// View modifier that gates content behind the "Aura" entitlement.
/// When the user lacks Aura, the paywall is automatically presented.
///
/// Usage:
///   SomeView()
///       .requiresAura()
///
struct AuraGateModifier: ViewModifier {

    @ObservedObject private var purchaseManager = PurchaseManager.shared

    func body(content: Content) -> some View {
        content
            .presentPaywallIfNeeded(
                requiredEntitlementIdentifier: PurchaseConstants.auraEntitlementID,
                purchaseCompleted: { customerInfo in
                    Task { await PurchaseManager.shared.refreshCustomerInfo() }
                },
                restoreCompleted: { customerInfo in
                    Task { await PurchaseManager.shared.refreshCustomerInfo() }
                }
            )
    }
}

extension View {

    /// Presents the paywall automatically if the user does not have
    /// the "Aura" entitlement. Dismisses itself once the entitlement
    /// becomes active.
    func requiresAura() -> some View {
        modifier(AuraGateModifier())
    }
}

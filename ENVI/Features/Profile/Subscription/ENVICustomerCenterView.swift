import SwiftUI
import RevenueCatUI

/// Wraps RevenueCat's Customer Center in a sheet with ENVI event handling.
/// Customer Center lets subscribers manage their plan, request refunds,
/// and get support — all without leaving the app.
struct ENVICustomerCenterView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CustomerCenterView()
            .onCustomerCenterRestoreStarted {
                // Optional analytics hook
            }
            .onCustomerCenterRestoreCompleted { customerInfo in
                // Refresh local state after a restore
                Task { await PurchaseManager.shared.refreshCustomerInfo() }
            }
            .onCustomerCenterRestoreFailed { error in
                // Could show a toast here
            }
            .onCustomerCenterShowingManageSubscriptions {
                // User tapped "Manage" — Apple handles the rest
            }
            .onCustomerCenterRefundRequestStarted { productID in
                // Track refund intent for analytics
            }
            .onCustomerCenterRefundRequestCompleted { productID, status in
                // Track refund outcome
            }
            .onCustomerCenterFeedbackSurveyCompleted { optionID in
                // Forward to your analytics / support tooling
            }
    }
}

import SwiftUI

/// Entry point for the USM onboarding flow.
/// Provides a check and view builder for the new 4-screen coordinator.
@MainActor
public enum USMOnboardingEntry {

    /// Returns true when the USM onboarding coordinator should be preferred
    /// over the legacy flow. Call-site (SceneDelegate, after Gerald merges)
    /// will read this and swap the root view accordingly.
    public static var shouldUse: Bool {
        FeatureFlags.shared.usmEnabled && FeatureFlags.shared.usmOnboardingEnabled
    }

    /// Creates the USM onboarding coordinator view with the required dependencies.
    /// Call this from SceneDelegate when shouldUse is true.
    @ViewBuilder
    public static func makeView(
        userId: String,
        recomputeClient: USMRecomputeClientProtocol,
        citySearchClient: CitySearchClientProtocol,
        onComplete: @escaping () -> Void
    ) -> some View {
        USMOnboardingCoordinator(
            userId: userId,
            recomputeClient: recomputeClient,
            citySearchClient: citySearchClient,
            onComplete: onComplete
        )
    }
}

// MARK: - TODO(gerald)
// SceneDelegate needs a one-line change after merging this branch:
// Replace `OnboardingContainerView(...)` with:
//   if USMOnboardingEntry.shouldUse {
//       USMOnboardingEntry.makeView(
//           userId: currentUserId,
//           recomputeClient: recomputeClientInstance,
//           citySearchClient: citySearchClientInstance,
//           onComplete: { ... }
//       )
//   } else {
//       OnboardingContainerView(onComplete: { ... })
//   }

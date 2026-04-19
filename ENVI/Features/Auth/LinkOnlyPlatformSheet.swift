import SwiftUI

/// Explainer shown when the user taps Instagram or TikTok on the sign-in
/// screen. Those providers can't be used as Firebase identity providers yet
/// (needs a Cloud Function to mint custom tokens), so we surface what the
/// user CAN do: sign in another way, then link the account in Settings.
struct LinkOnlyPlatformSheet: View {
    let platform: SocialPlatform
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: ENVISpacing.xl) {
            Circle()
                .fill(platform.brandColor)
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: platform.iconName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                )
                .padding(.top, ENVISpacing.xxl)

            VStack(spacing: ENVISpacing.sm) {
                Text("Link \(platform.rawValue) after signing in")
                    .font(.spaceMonoBold(20))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .multilineTextAlignment(.center)

                Text("\(platform.rawValue) doesn't support signing into ENVI directly. Sign in with email, Apple, Google, Meta, or X — then connect \(platform.rawValue) on the next screen or anytime from Profile → Connected Platforms.")
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ENVISpacing.xl)
            }

            Spacer()

            ENVIButton("Got It", isEnabled: true) {
                dismiss()
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.bottom, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
    }
}

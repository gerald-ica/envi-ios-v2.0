import SwiftUI

/// Circular brand-colored sign-in button for a `SocialPlatform`.
/// Reuses `SocialPlatform.iconName` + `SocialPlatform.brandColor` so the
/// visual stays in sync with the rest of the app's platform chrome.
struct SocialSignInButton: View {
    let platform: SocialPlatform
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: platform.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(platform.brandColor)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sign in with \(platform.rawValue)")
    }
}

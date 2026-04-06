import SwiftUI

/// Step 7: Connect social platforms with toggles and optional OAuth connection.
struct OnboardingSocialsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    /// The platforms offered during onboarding (excludes YouTube).
    private let platforms: [SocialPlatform] = [
        .instagram, .tiktok, .x, .threads, .linkedin
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("CONNECT YOUR SOCIALS")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Pick the platforms you want ENVI to prioritize first. Connect now for instant analytics or toggle on and connect later.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            VStack(spacing: ENVISpacing.lg) {
                ForEach(platforms) { platform in
                    PlatformConnectRow(
                        platform: platform,
                        isOn: viewModel.isEnabled(for: platform),
                        isConnected: viewModel.isConnected(platform),
                        handle: viewModel.handleFor(platform),
                        isConnecting: viewModel.connectingPlatform == platform,
                        errorMessage: viewModel.connectionError(for: platform),
                        onConnect: {
                            viewModel.connectPlatform(platform)
                        }
                    )
                }
            }

            // Helper note
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))

                Text("You can connect accounts later in Profile > Connected Platforms")
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            }
            .padding(.top, ENVISpacing.xs)

            Spacer()
        }
    }
}

// MARK: - Platform Connect Row

private struct PlatformConnectRow: View {
    let platform: SocialPlatform
    @Binding var isOn: Bool
    let isConnected: Bool
    let handle: String?
    let isConnecting: Bool
    let errorMessage: String?
    let onConnect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack(spacing: ENVISpacing.lg) {
                // Platform icon
                ZStack {
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .fill(ENVITheme.surfaceLow(for: colorScheme))
                        .frame(width: 44, height: 44)

                    Image(systemName: platform.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(platform.brandColor)
                }

                // Platform name + status
                VStack(alignment: .leading, spacing: 2) {
                    Text(platform.rawValue)
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    if isConnected, let handle {
                        Text("@\(handle)")
                            .font(.interRegular(12))
                            .foregroundColor(platform.brandColor)
                    } else if isConnected {
                        Text("Connected")
                            .font(.interRegular(12))
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                // Connect button or status indicator
                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                } else if isConnecting {
                    ProgressView()
                        .tint(ENVITheme.textLight(for: colorScheme))
                } else if isOn {
                    Button(action: onConnect) {
                        Text("Connect")
                            .font(.spaceMonoBold(11))
                            .tracking(0.5)
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .padding(.horizontal, ENVISpacing.md)
                            .padding(.vertical, ENVISpacing.xs)
                            .background(platform.brandColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Toggle
                ENVIToggle(isOn: $isOn)
            }

            // Error message
            if let errorMessage {
                Text(errorMessage)
                    .font(.interRegular(11))
                    .foregroundColor(.red)
                    .padding(.leading, 44 + ENVISpacing.lg)
            }
        }
        .padding(.vertical, ENVISpacing.xs)
    }
}

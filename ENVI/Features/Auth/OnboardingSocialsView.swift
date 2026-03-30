import SwiftUI

/// Step 5: Connect social platforms with toggle switches.
struct OnboardingSocialsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            Text("CONNECT YOUR SOCIALS")
                .font(.spaceMonoBold(32))
                .tracking(-2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Pick the platforms you want ENVI to prioritize first. You can connect accounts and sync analytics later.")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            VStack(spacing: ENVISpacing.lg) {
                PlatformToggleRow(
                    platform: "Instagram",
                    icon: "camera",
                    color: Color(hex: "#E4405F"),
                    isOn: $viewModel.instagramEnabled
                )
                PlatformToggleRow(
                    platform: "TikTok",
                    icon: "music.note",
                    color: Color(hex: "#000000"),
                    isOn: $viewModel.tiktokEnabled
                )
                PlatformToggleRow(
                    platform: "X",
                    icon: "xmark",
                    color: Color(hex: "#1DA1F2"),
                    isOn: $viewModel.xEnabled
                )
                PlatformToggleRow(
                    platform: "Threads",
                    icon: "at",
                    color: Color.white,
                    isOn: $viewModel.threadsEnabled
                )
                PlatformToggleRow(
                    platform: "LinkedIn",
                    icon: "link",
                    color: Color(hex: "#0A66C2"),
                    isOn: $viewModel.linkedinEnabled
                )
            }

            Spacer()
        }
    }
}

// MARK: - Platform Toggle Row
private struct PlatformToggleRow: View {
    let platform: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: ENVISpacing.lg) {
            // Platform icon
            ZStack {
                RoundedRectangle(cornerRadius: ENVIRadius.md)
                    .fill(ENVITheme.surfaceLow(for: colorScheme))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }

            // Platform name
            Text(platform)
                .font(.interSemiBold(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Spacer()

            // Toggle
            ENVIToggle(isOn: $isOn)
        }
        .padding(.vertical, ENVISpacing.xs)
    }
}

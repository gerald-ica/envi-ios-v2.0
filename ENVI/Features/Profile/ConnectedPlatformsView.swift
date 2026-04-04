import SwiftUI

/// Shows connected social platforms with connection status.
struct ConnectedPlatformsView: View {
    let platforms: [PlatformConnection]
    var onConnectTap: ((SocialPlatform) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("CONNECTED PLATFORMS")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            ForEach(platforms) { connection in
                HStack(spacing: ENVISpacing.md) {
                    // Platform icon
                    Image(systemName: connection.platform.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(connection.platform.brandColor)
                        .frame(width: 36, height: 36)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(connection.platform.rawValue)
                            .font(.interSemiBold(15))
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        if let handle = connection.handle {
                            Text(handle)
                                .font(.interRegular(12))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        }
                    }

                    Spacer()

                    // Status badge
                    Button {
                        guard !connection.isConnected else { return }
                        onConnectTap?(connection.platform)
                    } label: {
                        ENVIBadge(
                            text: connection.isConnected ? "Connected" : "Connect",
                            color: connection.isConnected ? ENVITheme.success : ENVITheme.Dark.surfaceHigh
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, ENVISpacing.xs)
            }
        }
    }
}

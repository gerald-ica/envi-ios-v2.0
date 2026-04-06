import SwiftUI

/// Shows connected social platforms with connection status.
struct ConnectedPlatformsView: View {
    let connections: [PlatformConnection]
    var onConnectTap: ((SocialPlatform) -> Void)?
    var onDisconnectTap: ((SocialPlatform) -> Void)?
    var onRefreshTap: ((SocialPlatform) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("CONNECTED PLATFORMS")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            ForEach(allPlatformConnections) { connection in
                platformRow(for: connection)
                    .padding(.vertical, ENVISpacing.xs)
            }
        }
    }

    // MARK: - Computed

    /// Ensures every platform appears, using provided connections or a
    /// default disconnected state for missing platforms.
    private var allPlatformConnections: [PlatformConnection] {
        let existing = Dictionary(
            connections.map { ($0.platform, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return SocialPlatform.allCases.map { platform in
            existing[platform] ?? PlatformConnection(platform: platform)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func platformRow(for connection: PlatformConnection) -> some View {
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

                // Token expiry warning
                if connection.isConnected, connection.isTokenExpiringSoon {
                    tokenExpiryWarning(for: connection)
                }
            }

            Spacer()

            // Action buttons
            if connection.isConnected {
                HStack(spacing: ENVISpacing.xs) {
                    // Refresh button when token is expiring
                    if connection.isTokenExpiringSoon {
                        Button {
                            onRefreshTap?(connection.platform)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ENVITheme.warning)
                        }
                        .buttonStyle(.plain)
                    }

                    // Disconnect button
                    Button {
                        onDisconnectTap?(connection.platform)
                    } label: {
                        ENVIBadge(
                            text: "Disconnect",
                            color: ENVITheme.error
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    onConnectTap?(connection.platform)
                } label: {
                    ENVIBadge(
                        text: "Connect",
                        color: ENVITheme.Dark.surfaceHigh
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func tokenExpiryWarning(for connection: PlatformConnection) -> some View {
        if let expiresAt = connection.tokenExpiresAt {
            let daysLeft = Calendar.current.dateComponents(
                [.day], from: Date(), to: expiresAt
            ).day ?? 0

            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                Text(daysLeft <= 0 ? "Token expired" : "Expires in \(daysLeft)d")
                    .font(.spaceMono(10))
            }
            .foregroundColor(ENVITheme.warning)
        }
    }
}

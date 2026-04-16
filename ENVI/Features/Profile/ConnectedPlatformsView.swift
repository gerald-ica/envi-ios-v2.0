import SwiftUI

/// Shows connected social platforms with connection status.
struct ConnectedPlatformsView: View {
    let connections: [PlatformConnection]
    var onConnectTap: ((SocialPlatform) -> Void)?
    var onDisconnectTap: ((SocialPlatform) -> Void)?
    var onRefreshTap: ((SocialPlatform) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            VStack(spacing: 0) {
                ForEach(Array(allPlatformConnections.enumerated()), id: \.element.id) { index, connection in
                    platformRow(for: connection)

                    if index < allPlatformConnections.count - 1 {
                        Divider()
                            .overlay(ENVITheme.textLight(for: colorScheme).opacity(0.12))
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ENVITheme.textLight(for: colorScheme).opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private var sectionHeader: some View {
        MainAppMonoLabel(title: "CONNECTED PLATFORMS")
    }

    // MARK: - Subviews

    @ViewBuilder
    private func platformRow(for connection: PlatformConnection) -> some View {
        MainAppConnectionRow(
            icon: connection.platform.iconName,
            title: connection.platform.rawValue,
            badge: connection.isConnected ? "CONNECTED" : "CONNECT",
            badgeSelected: connection.isConnected
        ) {
            if connection.isConnected {
                if connection.isTokenExpiringSoon {
                    onRefreshTap?(connection.platform)
                } else {
                    onDisconnectTap?(connection.platform)
                }
            } else {
                onConnectTap?(connection.platform)
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

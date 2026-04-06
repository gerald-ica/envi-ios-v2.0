import SwiftUI

/// Profile screen with avatar, stats, platforms, subscription, settings, and appearance toggle.
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var onSignOut: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                // Avatar
                ZStack {
                    Circle()
                        .strokeBorder(
                            ENVITheme.text(for: colorScheme),
                            lineWidth: 3
                        )
                        .frame(width: 88, height: 88)

                    Text(viewModel.user.initials)
                        .font(.spaceMonoBold(28))
                        .tracking(-1.0)
                        .foregroundColor(.white)
                }

                // Name + Handle
                VStack(spacing: 4) {
                    Text(viewModel.user.fullName)
                        .font(.spaceMonoBold(22))
                        .tracking(-1.0)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(viewModel.user.handle)
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }

                // Stats
                HStack(spacing: ENVISpacing.xxxl) {
                    StatView(label: "Published", value: "\(viewModel.user.publishedCount)")
                    StatView(label: "Drafts", value: "\(viewModel.user.draftsCount)")
                    StatView(label: "Templates", value: "\(viewModel.user.templatesCount)")
                }

                Divider().background(ENVITheme.border(for: colorScheme))

                // Subscription Status
                SubscriptionStatusView()
                    .padding(.horizontal, ENVISpacing.xl)

                Divider().background(ENVITheme.border(for: colorScheme))

                // Connected Platforms
                ConnectedPlatformsView(
                    connections: viewModel.connections,
                    onConnectTap: { platform in
                        Task { await viewModel.connectPlatform(platform) }
                    },
                    onDisconnectTap: { platform in
                        Task { await viewModel.disconnectPlatform(platform) }
                    },
                    onRefreshTap: { platform in
                        Task { await viewModel.refreshPlatformToken(platform) }
                    }
                )
                    .padding(.horizontal, ENVISpacing.xl)

                if let message = viewModel.connectionErrorMessage {
                    Text(message)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.error)
                        .padding(.horizontal, ENVISpacing.xl)
                }

                Divider().background(ENVITheme.border(for: colorScheme))

                // Settings
                SettingsSection(items: viewModel.settingsItems)
                    .padding(.horizontal, ENVISpacing.xl)

                Divider().background(ENVITheme.border(for: colorScheme))

                // Appearance
                AppearanceToggle(themeManager: viewModel.themeManager)
                    .padding(.horizontal, ENVISpacing.xl)

                // Sign Out
                Button(action: {
                    viewModel.signOut()
                    Task { await PurchaseManager.shared.logOut() }
                    onSignOut?()
                }) {
                    Text("Sign Out")
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ENVISpacing.lg)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                }
                .padding(.horizontal, ENVISpacing.xl)
                .padding(.bottom, 100)
            }
            .padding(.top, ENVISpacing.xxl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .onAppear {
            viewModel.loadConnections()
        }
    }
}

private struct StatView: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.spaceMonoBold(20))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))
            Text(label.uppercased())
                .font(.spaceMonoBold(10))
                .tracking(0.80)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
}

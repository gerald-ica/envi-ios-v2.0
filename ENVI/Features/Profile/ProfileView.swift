import SwiftUI

/// Profile screen matching Sketch frame "17 - Profile".
/// Gradient banner, avatar, stats cards, subscription badge, connected platforms,
/// settings list with "View Analytics" navigation link.
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var onSignOut: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Gradient Banner + Avatar
                    bannerSection

                    // MARK: - Name + Handle
                    nameSection
                        .padding(.top, ENVISpacing.lg)

                    // MARK: - Stat Boxes
                    statsSection
                        .padding(.top, ENVISpacing.xxl)
                        .padding(.horizontal, ENVISpacing.xl)

                    // MARK: - Subscription Badge
                    subscriptionSection
                        .padding(.top, ENVISpacing.xxl)
                        .padding(.horizontal, ENVISpacing.xl)

                    // MARK: - Connected Platforms
                    connectedPlatformsSection
                        .padding(.top, ENVISpacing.xxl)
                        .padding(.horizontal, ENVISpacing.xl)

                    if let message = viewModel.connectionErrorMessage {
                        Text(message)
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.error)
                            .padding(.top, ENVISpacing.sm)
                            .padding(.horizontal, ENVISpacing.xl)
                    }

                    // MARK: - Settings List
                    settingsSection
                        .padding(.top, ENVISpacing.xxl)
                        .padding(.horizontal, ENVISpacing.xl)

                    // MARK: - Appearance
                    AppearanceToggle(themeManager: viewModel.themeManager)
                        .padding(.top, ENVISpacing.xxl)
                        .padding(.horizontal, ENVISpacing.xl)

                    // MARK: - Sign Out
                    signOutButton
                        .padding(.top, ENVISpacing.xxl)
                        .padding(.horizontal, ENVISpacing.xl)
                        .padding(.bottom, 100)
                }
            }
            .background(ENVITheme.background(for: colorScheme))
            .onAppear {
                viewModel.loadConnections()
            }
        }
    }

    // MARK: - Banner

    private var bannerSection: some View {
        ZStack(alignment: .bottom) {
            // Gradient banner
            LinearGradient(
                colors: [
                    Color(hex: "#0A0E27"),
                    Color(hex: "#1A1A3E"),
                    Color(hex: "#30217C").opacity(0.6),
                    Color(hex: "#1A2A4A")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 160)

            // Avatar overlapping bottom edge
            ZStack {
                Circle()
                    .fill(ENVITheme.surfaceLow(for: colorScheme))
                    .frame(width: 96, height: 96)

                Circle()
                    .strokeBorder(
                        ENVITheme.text(for: colorScheme),
                        lineWidth: 3
                    )
                    .frame(width: 96, height: 96)

                Text(viewModel.user.initials)
                    .font(.spaceMonoBold(32))
                    .tracking(-1.0)
                    .foregroundColor(.white)
            }
            .offset(y: 48)
        }
        .padding(.bottom, 48)
    }

    // MARK: - Name + Handle

    private var nameSection: some View {
        VStack(spacing: 4) {
            Text(viewModel.user.fullName)
                .font(.spaceMonoBold(24))
                .tracking(-1.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(viewModel.user.handle)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: ENVISpacing.md) {
            ProfileStatCard(
                value: "\(viewModel.user.publishedCount)",
                label: "PUBLISHED"
            )
            ProfileStatCard(
                value: "\(viewModel.user.draftsCount)",
                label: "DRAFTS"
            )
            ProfileStatCard(
                value: "\(viewModel.user.templatesCount)",
                label: "TEMPLATES"
            )
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        SubscriptionStatusView()
    }

    // MARK: - Connected Platforms

    private var connectedPlatformsSection: some View {
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
    }

    // MARK: - Settings

    private var settingsSection: some View {
        ProfileSettingsSection(items: viewModel.settingsItems)
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
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
    }
}

// MARK: - Profile Stat Card

/// Dark surface card for a single stat (e.g. "47 PUBLISHED").
private struct ProfileStatCard: View {
    let value: String
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: ENVISpacing.xs) {
            Text(value)
                .font(.spaceMonoBold(22))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(label)
                .font(.spaceMonoBold(9))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
}

import SwiftUI

/// Profile screen matching Sketch frame "17 - Profile".
/// Compact avatar/identity, equal stat cards, subscription card, connected
/// platforms, and flatter settings rows.
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var onSignOut: (() -> Void)?
    @State private var showAccountManagement = false
    @State private var showAnalytics = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                    statsSection
                        .padding(.top, 24)
                        .padding(.horizontal, 16)

                    sectionDivider
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    subscriptionSection
                        .padding(.top, 24)
                        .padding(.horizontal, 16)

                    sectionDivider
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    connectedPlatformsSection
                        .padding(.top, 24)
                        .padding(.horizontal, 16)

                    if let message = viewModel.connectionErrorMessage {
                        Text(message)
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.error)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                            .padding(.horizontal, 20)
                    }

                    sectionDivider
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    settingsSection
                        .padding(.top, 24)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                }
            }

            analyticsShortcut
                .padding(.top, 24)
                .padding(.trailing, 22)
        }
        .background(AppBackground(imageName: "profile-bg"))
        .onAppear {
            viewModel.loadConnections()
        }
        .sheet(isPresented: $showAccountManagement) {
            AccountManagementView()
        }
        .sheet(isPresented: $showAnalytics) {
            NavigationStack {
                AnalyticsView()
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Analytics top-right shortcut

    /// Sketch "17 - Profile" places an Analytics icon (~33×33) at the
    /// top-right of the page. Opens the Analytics sheet directly.
    private var analyticsShortcut: some View {
        Button { showAnalytics = true } label: {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 33, height: 33)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Sketch "17 - Profile" avatar — solid indigo-blue disc (#4A5FB2),
            // 88×88, no overlaid initials.
            Circle()
                .fill(Color(hex: "#4A5FB2"))
                .frame(width: 88, height: 88)

            VStack(spacing: 4) {
                Text(viewModel.user.fullName)
                    .font(.spaceMonoBold(23))
                    .tracking(-0.9)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(viewModel.user.handle)
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            MainAppProfileStatBox(value: "\(viewModel.user.publishedCount)", label: "PUBLISHED")
            MainAppProfileStatBox(value: "\(viewModel.user.draftsCount)", label: "DRAFTS")
            MainAppProfileStatBox(value: "\(viewModel.user.templatesCount)", label: "TEMPLATES")
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
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SETTINGS")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.settingsItems.enumerated()), id: \.element.id) { index, item in
                    Button {
                        if item.title == "Account Settings" {
                            showAccountManagement = true
                        }
                    } label: {
                        settingsRow(icon: item.icon, title: item.title)
                    }
                    .buttonStyle(.plain)

                    if index < viewModel.settingsItems.count - 1 {
                        Divider()
                            .overlay(ENVITheme.textLight(for: colorScheme).opacity(0.12))
                            .padding(.leading, 44)
                    }
                }

                Button {
                    showAnalytics = true
                } label: {
                    settingsRow(icon: "chart.bar.xaxis", title: "View Analytics")
                }
                .buttonStyle(.plain)
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

    private var sectionDivider: some View {
        Divider()
            .overlay(ENVITheme.textLight(for: colorScheme).opacity(0.12))
    }

    private func sectionHeader(_ title: String) -> some View {
        MainAppMonoLabel(title: title)
    }

    @ViewBuilder
    private func settingsRow(icon: String, title: String) -> some View {
        MainAppSettingsRow(icon: icon, title: title) {}
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
}

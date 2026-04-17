import SwiftUI

/// Profile screen matching Sketch frame "17 - Profile".
/// Compact avatar/identity, equal stat cards, subscription card, connected
/// platforms, and flatter settings rows.
///
/// Phase 15-02: injected with `@EnvironmentObject AppRouter` so
/// `router.sheet` / `router.fullScreen` attachments present at this root
/// whenever any child view (or deep-link) routes here. Profile's own
/// existing `.sheet(isPresented:)` bool-driven sheets stay as-is for
/// this plan — they'll move to the router in Phase 16 when Profile
/// sub-section modals (Notifications, Security, Billing, etc.) come
/// online from the same resolver.
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var router: AppRouter

    var onSignOut: (() -> Void)?
    @State private var showAccountManagement = false
    @State private var showAnalytics = false
    @State private var showSignOutConfirm = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    if let user = viewModel.user {
                        profileHeader(user: user)
                            .padding(.top, 24)
                            .padding(.horizontal, 24)

                        statsSection(user: user)
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
                    } else if viewModel.isLoadingProfile {
                        loadingState
                            .padding(.top, 120)
                    } else if let error = viewModel.profileLoadError {
                        errorState(message: error)
                            .padding(.top, 120)
                            .padding(.horizontal, 24)
                    }
                }
            }

            analyticsShortcut
                .padding(.top, 24)
                .padding(.trailing, 22)
        }
        .background(AppBackground(imageName: "profile-bg"))
        .task {
            await viewModel.loadProfile()
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
        // Router-driven sheet/full-screen for cross-tab destinations
        // that originate while Profile is active (Phase 16 will populate
        // more arms of the resolver).
        .sheet(item: $router.sheet) { destination in
            AppDestinationSheetResolver(destination: destination)
        }
        .fullScreenCover(item: $router.fullScreen) { destination in
            AppDestinationFullScreenResolver(destination: destination)
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

    private func profileHeader(user: User) -> some View {
        VStack(spacing: 12) {
            // Sketch "17 - Profile" avatar — solid indigo-blue disc (#4A5FB2),
            // 88×88, no overlaid initials.
            Circle()
                .fill(Color(hex: "#4A5FB2"))
                .frame(width: 88, height: 88)

            VStack(spacing: 4) {
                Text(user.fullName)
                    .font(.spaceMonoBold(23))
                    .tracking(-0.9)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(user.handle)
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
            }
        }
    }

    // MARK: - Stats

    private func statsSection(user: User) -> some View {
        HStack(spacing: 12) {
            MainAppProfileStatBox(value: "\(user.publishedCount)", label: "PUBLISHED")
            MainAppProfileStatBox(value: "\(user.draftsCount)", label: "DRAFTS")
            MainAppProfileStatBox(value: "\(user.templatesCount)", label: "TEMPLATES")
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
        VStack(alignment: .leading, spacing: 24) {
            // Existing Settings group (Account, View Analytics, etc.)
            baseSettingsGroup

            // Phase 16-02 — Creator Business entry points.
            // Agency / Teams / Commerce route via AppRouter so their
            // modal stacks are reachable from a single identity surface.
            routerSettingsGroup(
                title: "CREATOR BUSINESS",
                rows: [
                    SettingsEntryRow(icon: "briefcase.fill",   title: "Agency",     destination: .agency),
                    SettingsEntryRow(icon: "person.3.fill",    title: "Teams",      destination: .teams),
                    SettingsEntryRow(icon: "bag.fill",         title: "Commerce",   destination: .commerce),
                ]
            )

            // Phase 16-02 — Analytics & Experiments group.
            routerSettingsGroup(
                title: "ANALYTICS",
                rows: [
                    SettingsEntryRow(icon: "flask.fill", title: "Experiments", destination: .experiments),
                ]
            )

            // Phase 16-02 — Account-scoped entry points (Security,
            // Notifications). These live next to Account Settings
            // conceptually; using a dedicated sub-group keeps the
            // existing Settings rows untouched.
            routerSettingsGroup(
                title: "ACCOUNT",
                rows: [
                    SettingsEntryRow(icon: "lock.shield.fill", title: "Security",      destination: .security),
                    SettingsEntryRow(icon: "bell.fill",        title: "Notifications", destination: .notifications),
                ]
            )

            signOutGroup
        }
        .confirmationDialog(
            "Sign Out?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                onSignOut?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your content.")
        }
    }

    /// Destructive sign-out row. Bubbles to `AppCoordinator.onSignOut` via the
    /// `onSignOut` closure so Firebase, RevenueCat, telemetry, and deep-link
    /// state all tear down together and the user lands back on SignIn.
    private var signOutGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SESSION")

            Button {
                showSignOutConfirm = true
            } label: {
                HStack(spacing: ENVISpacing.md) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ENVITheme.error)
                        .frame(width: 24)

                    Text("Sign Out")
                        .font(.interMedium(15))
                        .foregroundColor(ENVITheme.error)

                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ENVITheme.error.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    /// The pre-existing Settings card (Account Settings, View Analytics).
    /// Kept as-is so Phase 16-02 doesn't touch any row that already works.
    private var baseSettingsGroup: some View {
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

    /// A router-driven settings group. Each row taps through
    /// `router.present(destination)` — no inline `.sheet` bools.
    private func routerSettingsGroup(title: String, rows: [SettingsEntryRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    Button {
                        router.present(row.destination)
                    } label: {
                        settingsRow(icon: row.icon, title: row.title)
                    }
                    .buttonStyle(.plain)

                    if index < rows.count - 1 {
                        Divider()
                            .overlay(ENVITheme.textLight(for: colorScheme).opacity(0.12))
                            .padding(.leading, 44)
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

    // MARK: - Loading / Error

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(ENVITheme.text(for: colorScheme))
            Text("Loading profile...")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(ENVITheme.error)

            Text(message)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.loadProfile() }
            } label: {
                Text("Retry")
                    .font(.interMedium(14))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(ENVITheme.textLight(for: colorScheme).opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
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

// MARK: - Phase 16-02 settings entry row model

/// A single Settings row that routes through AppRouter when tapped.
/// Grouped into sections by `ProfileView.routerSettingsGroup(...)`.
struct SettingsEntryRow: Identifiable {
    let id = UUID()
    let icon: String           // SF Symbol name
    let title: String
    let destination: AppDestination
}

#Preview {
    ProfileView()
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
}

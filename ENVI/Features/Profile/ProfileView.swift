import SwiftUI

/// Profile screen with avatar, stats, platforms, settings, and appearance toggle.
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.colorScheme) private var colorScheme

    @State private var showStatAlert = false
    @State private var tappedStat: String = ""

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
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }

                // Name + Handle + Bio
                VStack(spacing: 4) {
                    Text(viewModel.user.fullName)
                        .font(.spaceMonoBold(22))
                        .tracking(-1.0)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(viewModel.user.handle)
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))

                    if let bio = viewModel.user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.interRegular(14))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }

                // Edit Profile
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    Text("Edit Profile")
                        .font(.interSemiBold(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ENVISpacing.sm)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                }
                .padding(.horizontal, ENVISpacing.xl)

                // Stats
                HStack(spacing: ENVISpacing.xxxl) {
                    StatView(label: "Published", value: "\(viewModel.user.publishedCount)") {
                        tappedStat = "Published"
                        showStatAlert = true
                    }
                    StatView(label: "Drafts", value: "\(viewModel.user.draftsCount)") {
                        tappedStat = "Drafts"
                        showStatAlert = true
                    }
                    StatView(label: "Templates", value: "\(viewModel.user.templatesCount)") {
                        tappedStat = "Templates"
                        showStatAlert = true
                    }
                }

                Divider().background(ENVITheme.border(for: colorScheme))

                // Connected Platforms
                ConnectedPlatformsView(platforms: viewModel.user.connectedPlatforms)
                    .padding(.horizontal, ENVISpacing.xl)

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
            }
            .padding(.top, ENVISpacing.xxl)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .background(ENVITheme.background(for: colorScheme))
        .alert("Stats", isPresented: $showStatAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(tappedStat) details coming soon.")
        }
    }
}

private struct StatView: View {
    let label: String
    let value: String
    var onTap: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onTap()
        }) {
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
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
}

import SwiftUI

// MARK: - Content Library Settings View

/// A sheet/modal presented from the plus menu for configuring content sources,
/// connected accounts, and content type filters.
struct ContentLibrarySettingsView: View {

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var contentSource: SourceOption = .contentLibrary
    @State private var autoCreateContent: Bool = true
    @State private var showPhotos: Bool = true
    @State private var showVideos: Bool = true
    @State private var showCarousels: Bool = true
    @State private var showStories: Bool = true
    @State private var showReels: Bool = true

    // MARK: - Connect-row state (Phase 18-02)
    //
    // Drives the YouTube / X / LinkedIn CONNECT buttons that used to be
    // `Button {} label: { ... }` no-ops. Mirrors the `inFlight` +
    // `connectedPlatforms` pattern from `ConnectedAccountsViewModel`
    // without reaching for a full VM — the settings sheet only needs
    // per-row booleans, not the wider Connected-Accounts dashboard state.

    /// Platform currently undergoing a connect. Drives the "CONNECTING…"
    /// label flip and disables the button while in-flight.
    @State private var connectingPlatform: SocialPlatform?

    /// Platforms we believe are connected. Seeded with Instagram + TikTok
    /// to match the current design's mock state, updated when a successful
    /// connect returns. Kept as a `Set<SocialPlatform>` so the row builder
    /// can ask `connectedPlatforms.contains(.x)` without a lookup table.
    @State private var connectedPlatforms: Set<SocialPlatform> = [.instagram, .tiktok]

    /// Most recent connect error — surfaced under the Connected Accounts
    /// section. Cleared on the next successful connect.
    @State private var connectErrorMessage: String?

    /// Injected OAuth entry point. Defaults to `SocialOAuthManager.shared`
    /// (the same instance `ConnectedAccountsViewModel` uses); tests swap
    /// in a recording subclass.
    var oauth: SocialOAuthManager = .shared

    /// Local picker option — maps to ContentSource without shadowing it.
    enum SourceOption: String, CaseIterable {
        case photoLibrary = "Photo Library"
        case contentLibrary = "Content Timeline"

        var description: String {
            switch self {
            case .photoLibrary:
                return "Access your camera roll directly. ENVI will scan and organize your photos and videos."
            case .contentLibrary:
                return "ENVI's curated timeline of already-edited content pieces assembled from your camera roll."
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: - Content Source Section
                    sectionHeader("CONTENT SOURCE")

                    VStack(spacing: ENVISpacing.sm) {
                        ForEach(SourceOption.allCases, id: \.rawValue) { source in
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    contentSource = source
                                }
                            } label: {
                                HStack(spacing: ENVISpacing.md) {
                                    Image(systemName: source == .photoLibrary ? "photo.on.rectangle" : "square.stack.3d.up")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(contentSource == source ? .white : .white.opacity(0.4))
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(source.rawValue.uppercased())
                                            .font(.spaceMonoBold(11))
                                            .tracking(2.0)
                                            .foregroundColor(contentSource == source ? .white : .white.opacity(0.5))

                                        Text(source.description)
                                            .font(.spaceMono(10))
                                            .foregroundColor(.white.opacity(0.3))
                                            .lineSpacing(2)
                                    }

                                    Spacer()

                                    if contentSource == source {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(ENVITheme.Dark.accent)
                                    }
                                }
                                .padding(ENVISpacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                                        .fill(contentSource == source
                                            ? Color.white.opacity(0.05)
                                            : Color.clear
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                                        .strokeBorder(
                                            contentSource == source
                                                ? Color.white.opacity(0.15)
                                                : Color.white.opacity(0.05),
                                            lineWidth: 0.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, ENVISpacing.xxl)

                    // Info text
                    Text("Content pieces are assembled from your camera roll. ENVI automatically edits and creates short-form media from your photos and videos.")
                        .font(.spaceMono(10))
                        .foregroundColor(.white.opacity(0.3))
                        .lineSpacing(3)
                        .padding(.bottom, ENVISpacing.xxxl)

                    divider

                    // MARK: - Auto-Create Toggle
                    sectionHeader("AUTO-CREATE")

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AUTO-CREATE CONTENT")
                                .font(.spaceMonoBold(11))
                                .tracking(2.0)
                                .foregroundColor(.white.opacity(0.7))
                            Text("ENVI will automatically generate short-form content from new camera roll items")
                                .font(.spaceMono(10))
                                .foregroundColor(.white.opacity(0.3))
                                .lineSpacing(2)
                        }
                        Spacer()
                        Toggle("", isOn: $autoCreateContent)
                            .labelsHidden()
                            .tint(ENVITheme.Dark.accent)
                    }
                    .padding(ENVISpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .fill(Color.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
                    )
                    .padding(.bottom, ENVISpacing.xxxl)

                    divider

                    // MARK: - Connected Accounts
                    sectionHeader("CONNECTED ACCOUNTS")

                    VStack(spacing: ENVISpacing.sm) {
                        connectedAccountRow(
                            platform: .instagram,
                            label: "Instagram",
                            icon: "camera"
                        )
                        connectedAccountRow(
                            platform: .tiktok,
                            label: "TikTok",
                            icon: "music.note"
                        )
                        connectedAccountRow(
                            platform: .youtube,
                            label: "YouTube",
                            icon: "play.rectangle"
                        )
                        connectedAccountRow(
                            platform: .x,
                            label: "X / Twitter",
                            icon: "bubble.left"
                        )
                        connectedAccountRow(
                            platform: .linkedin,
                            label: "LinkedIn",
                            icon: "briefcase"
                        )

                        if let error = connectErrorMessage {
                            Text(error)
                                .font(.spaceMono(10))
                                .foregroundColor(Color(hex: "#F87171").opacity(0.9))
                                .padding(.top, ENVISpacing.xs)
                        }
                    }
                    .padding(.bottom, ENVISpacing.xxxl)

                    divider

                    // MARK: - Content Types
                    sectionHeader("CONTENT TYPES")

                    Text("Choose which content types to display in the explorer")
                        .font(.spaceMono(10))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.bottom, ENVISpacing.md)

                    VStack(spacing: ENVISpacing.sm) {
                        contentTypeToggle(label: "PHOTO", isOn: $showPhotos)
                        contentTypeToggle(label: "VIDEO", isOn: $showVideos)
                        contentTypeToggle(label: "CAROUSEL", isOn: $showCarousels)
                        contentTypeToggle(label: "STORY", isOn: $showStories)
                        contentTypeToggle(label: "REEL", isOn: $showReels)
                    }
                    .padding(.bottom, ENVISpacing.xxxl)
                }
                .padding(.horizontal, ENVISpacing.xxl)
                .padding(.vertical, ENVISpacing.xl)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS")
                        .font(.spaceMonoBold(12))
                        .tracking(2.5)
                        .foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(.spaceMonoBold(11))
                            .tracking(2.0)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: ENVISpacing.md) {
            Text(title)
                .font(.spaceMonoBold(10))
                .tracking(2.5)
                .foregroundColor(.white.opacity(0.35))
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 0.5)
        }
        .padding(.bottom, ENVISpacing.lg)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.bottom, ENVISpacing.xxl)
    }

    /// Single row in the Connected Accounts section. Drives the connection
    /// state machine off `connectedPlatforms` + `connectingPlatform` and
    /// routes CONNECT taps through `SocialOAuthManager.connect(platform:)`
    /// — the same entry point `ConnectedAccountsViewModel` uses for the
    /// Settings > Connected Accounts dashboard.
    private func connectedAccountRow(
        platform: SocialPlatform,
        label: String,
        icon: String
    ) -> some View {
        let connected = connectedPlatforms.contains(platform)
        let isConnecting = connectingPlatform == platform

        return HStack(spacing: ENVISpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(connected ? .white.opacity(0.7) : .white.opacity(0.3))
                .frame(width: 20)

            Text(label.uppercased())
                .font(.spaceMonoBold(11))
                .tracking(2.0)
                .foregroundColor(connected ? .white.opacity(0.7) : .white.opacity(0.4))

            Spacer()

            if connected {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#4ADE80"))
                        .frame(width: 6, height: 6)
                    Text("CONNECTED")
                        .font(.spaceMono(9))
                        .tracking(1.0)
                        .foregroundColor(Color(hex: "#4ADE80").opacity(0.7))
                }
            } else {
                Button {
                    connect(platform)
                } label: {
                    Text(isConnecting ? "CONNECTING…" : "CONNECT")
                        .font(.spaceMonoBold(9))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(isConnecting ? 0.3 : 0.5))
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, ENVISpacing.xs)
                        .overlay(
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                }
                .disabled(connectingPlatform != nil)
                .accessibilityLabel("Connect \(label)")
            }
        }
        .padding(.vertical, ENVISpacing.md)
        .padding(.horizontal, ENVISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
        )
    }

    /// Kick off an OAuth connect via `SocialOAuthManager`. Mirrors
    /// `ConnectedAccountsViewModel.connect(_:)` with a single in-flight
    /// platform slot. On success the row flips to CONNECTED; on failure
    /// the row reverts and the error surfaces in-section.
    func connect(_ platform: SocialPlatform) {
        guard connectingPlatform == nil else { return }
        connectingPlatform = platform
        connectErrorMessage = nil

        Task { @MainActor in
            defer { connectingPlatform = nil }
            do {
                let connection = try await oauth.connect(platform: platform)
                if connection.isConnected {
                    connectedPlatforms.insert(platform)
                }
            } catch {
                connectErrorMessage =
                    (error as? LocalizedError)?.errorDescription
                    ?? "Couldn't connect \(platform.rawValue). Try again."
            }
        }
    }

    private func contentTypeToggle(label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.spaceMonoBold(11))
                .tracking(2.0)
                .foregroundColor(isOn.wrappedValue ? .white.opacity(0.7) : .white.opacity(0.3))

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ENVITheme.Dark.accent)
        }
        .padding(.vertical, ENVISpacing.sm)
        .padding(.horizontal, ENVISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
        )
    }
}

#if DEBUG
struct ContentLibrarySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ContentLibrarySettingsView()
    }
}
#endif

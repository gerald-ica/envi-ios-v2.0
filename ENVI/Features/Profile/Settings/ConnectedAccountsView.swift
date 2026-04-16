import SwiftUI

/// Full-screen Settings destination showing all social platforms with the
/// Phase 12 badge state machine:
///
///   1. `revokedAt != nil`                          → red   RECONNECT
///   2. `isTokenExpiringSoon && revokedAt == nil`   → amber EXPIRING SOON
///   3. `isConnected && !isTokenExpiringSoon`       → green CONNECTED
///   4. `!isConnected`                              → surface CONNECT
///
/// Destructive actions use a confirmation sheet matching the
/// `ENVICustomerCenterView` pattern (see Phase 12 PLAN.md critical details).
struct ConnectedAccountsView: View {
    @StateObject private var viewModel = ConnectedAccountsViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var pendingDisconnect: PlatformConnection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                VStack(spacing: 8) {
                    ForEach(viewModel.connections) { connection in
                        row(for: connection)
                    }
                }
                .padding(.horizontal, 16)

                footer
            }
            .padding(.vertical, 20)
        }
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Connected Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .confirmationDialog(
            pendingDisconnect.map {
                "Disconnect \($0.platform.rawValue)?"
            } ?? "",
            isPresented: Binding(
                get: { pendingDisconnect != nil },
                set: { if !$0 { pendingDisconnect = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                if let connection = pendingDisconnect {
                    Task { await viewModel.disconnect(connection.platform) }
                }
                pendingDisconnect = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDisconnect = nil
            }
        } message: {
            Text(
                pendingDisconnect.map {
                    "ENVI will revoke access to \($0.platform.rawValue). You can reconnect at any time."
                } ?? ""
            )
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            MainAppMonoLabel(title: "SOCIAL CONNECTIONS")

            Text("Manage which platforms ENVI can publish to on your behalf. Disconnecting revokes the stored access token immediately.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tokens refresh automatically every 24 hours.")
                .font(.spaceMono(10))
                .tracking(0.4)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(message)
                .font(.interRegular(13))
            Spacer()
        }
        .foregroundColor(ENVITheme.warning)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ENVITheme.warning.opacity(0.12))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Row + state machine

    @ViewBuilder
    private func row(for connection: PlatformConnection) -> some View {
        let state = BadgeState.derive(from: connection)
        let isBusy = viewModel.inFlight.contains(connection.platform.apiSlug)

        Button {
            handleTap(connection: connection, state: state)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: connection.platform.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.platform.rawValue)
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    if let subtitle = subtitle(for: connection) {
                        Text(subtitle)
                            .font(.spaceMono(10))
                            .tracking(0.4)
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }
                }

                Spacer()

                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    badge(for: state)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private func subtitle(for connection: PlatformConnection) -> String? {
        if let handle = connection.handle, !handle.isEmpty {
            if let lastSync = connection.lastSyncAt {
                return "\(handle) \u{00B7} Last sync: \(relativeLabel(for: lastSync))"
            }
            return handle
        }
        if let lastSync = connection.lastSyncAt {
            return "Last sync: \(relativeLabel(for: lastSync))"
        }
        return nil
    }

    private func relativeLabel(for date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86400))d ago"
    }

    private func handleTap(connection: PlatformConnection, state: BadgeState) {
        switch state {
        case .reconnect:
            Task { await viewModel.reconnect(connection.platform) }
        case .expiring:
            Task { await viewModel.refresh(connection.platform) }
        case .connected:
            pendingDisconnect = connection
        case .connect:
            Task { await viewModel.connect(connection.platform) }
        }
    }

    @ViewBuilder
    private func badge(for state: BadgeState) -> some View {
        Text(state.label)
            .font(.spaceMonoBold(10))
            .tracking(0.8)
            .foregroundColor(state.foreground(for: colorScheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(state.background(for: colorScheme))
            .clipShape(Capsule())
    }
}

// MARK: - Badge state

/// Four-state machine for the badge pill. Priority order (top wins) matches
/// PLAN.md 12-06:
///   1. revoked          → reconnect
///   2. expiring soon    → refresh affordance
///   3. connected        → disconnect affordance
///   4. fully disconnected → connect affordance
private enum BadgeState {
    case reconnect
    case expiring
    case connected
    case connect

    static func derive(from connection: PlatformConnection) -> BadgeState {
        if connection.revokedAt != nil {
            return .reconnect
        }
        if connection.isConnected && connection.isTokenExpiringSoon {
            return .expiring
        }
        if connection.isConnected {
            return .connected
        }
        return .connect
    }

    var label: String {
        switch self {
        case .reconnect: return "RECONNECT"
        case .expiring:  return "EXPIRING SOON"
        case .connected: return "CONNECTED"
        case .connect:   return "CONNECT"
        }
    }

    func foreground(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .reconnect: return .white
        case .expiring:  return .black
        case .connected: return .black
        case .connect:   return ENVITheme.text(for: colorScheme)
        }
    }

    func background(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .reconnect: return Color(red: 0.82, green: 0.2, blue: 0.2)
        case .expiring:  return Color(red: 0.98, green: 0.78, blue: 0.24)
        case .connected: return .white
        case .connect:   return ENVITheme.surfaceHigh(for: colorScheme)
        }
    }
}

// MARK: - Preview fixtures

extension ConnectedAccountsView {
    /// Static fixtures exercising all four badge states. Used by SwiftUI
    /// previews and ViewInspector-style UI tests.
    static var previewFixtures: [PlatformConnection] {
        [
            // 1. RECONNECT — revoked connection
            PlatformConnection(
                platform: .instagram,
                isConnected: false,
                handle: "envi_studio",
                tokenExpiresAt: Date().addingTimeInterval(-3600),
                scopes: ["instagram_basic"],
                revokedAt: Date().addingTimeInterval(-86400),
                lastSyncAt: Date().addingTimeInterval(-86400 * 2)
            ),
            // 2. EXPIRING SOON — connected but token expires in 3 days
            PlatformConnection(
                platform: .facebook,
                isConnected: true,
                handle: "ENVI Studio",
                followerCount: 1280,
                tokenExpiresAt: Date().addingTimeInterval(86400 * 3),
                lastRefreshedAt: Date().addingTimeInterval(-86400 * 30),
                scopes: ["pages_show_list"],
                lastSyncAt: Date().addingTimeInterval(-3600 * 5)
            ),
            // 3. CONNECTED — healthy green state
            PlatformConnection(
                platform: .tiktok,
                isConnected: true,
                handle: "envi_creator",
                followerCount: 42100,
                tokenExpiresAt: Date().addingTimeInterval(86400 * 45),
                lastRefreshedAt: Date().addingTimeInterval(-3600),
                scopes: ["user.info.basic", "video.publish"],
                lastSyncAt: Date().addingTimeInterval(-60 * 12)
            ),
            // 4. CONNECT — never linked
            PlatformConnection(platform: .linkedin)
        ]
    }
}

// MARK: - Previews

#Preview("Connected Accounts") {
    NavigationStack {
        ConnectedAccountsView()
    }
    .preferredColorScheme(.dark)
}

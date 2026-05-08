import SwiftUI

// MARK: - ViewModel

@MainActor
final class AccountManagementViewModel: ObservableObject {
    @Published var sessions: [DeviceSession] = []
    @Published var loginHistory: [LoginActivity] = []
    @Published var consents: [ConsentRecord] = []
    @Published var suspiciousLoginAlertsEnabled = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var exportRequested = false
    @Published var showDeleteConfirmation = false
    @Published var showReauthAlert = false

    private nonisolated(unsafe) let repository: AccountRepository

    init(repository: AccountRepository = AccountRepositoryProvider.shared.repository) {
        self.repository = repository
    }

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let s = repository.fetchSessions()
        async let l = repository.fetchLoginHistory()
        async let c = repository.fetchConsents()

        do {
            let (fetchedSessions, fetchedHistory, fetchedConsents) = try await (s, l, c)
            sessions = fetchedSessions
            loginHistory = fetchedHistory
            consents = fetchedConsents
        } catch {
            errorMessage = "Failed to load account data."
        }
    }

    func revokeSession(_ session: DeviceSession) async {
        do {
            try await repository.revokeSession(id: session.id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = "Failed to revoke session."
        }
    }

    func requestDataExport() async {
        do {
            _ = try await repository.requestDataExport()
            exportRequested = true
        } catch {
            errorMessage = "Failed to request data export."
        }
    }

    func deleteAccount() async {
        do {
            try await AuthManager.shared.deleteAccount()
            await PurchaseManager.shared.logOut()
        } catch let error as AuthManager.AuthError where error == .reauthenticationRequired {
            showReauthAlert = true
        } catch {
            errorMessage = "Failed to delete account. Please try again."
        }
    }
}

// MARK: - View

/// Account management settings sub-view.
/// Covers ENVI-0008, ENVI-0010, ENVI-0018, ENVI-0019, ENVI-0020, ENVI-0021.
struct AccountManagementView: View {
    @StateObject private var viewModel = AccountManagementViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header

                if viewModel.isLoading {
                    ENVILoadingState()
                } else {
                    // ENVI-0008 Active Sessions
                    activeSessionsSection

                    sectionDivider

                    // ENVI-0010 Suspicious Login Alerts
                    suspiciousLoginAlertsSection

                    sectionDivider

                    // ENVI-0020 Login Activity
                    loginActivitySection

                    sectionDivider

                    // ENVI-0019 Consent Ledger
                    consentLedgerSection

                    sectionDivider

                    // ENVI-0021 Data Export
                    dataExportSection

                    sectionDivider

                    // ENVI-0018 Delete Account
                    deleteAccountSection
                }
            }
            .padding(.top, ENVISpacing.xxl)
            .padding(.bottom, 100)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await viewModel.loadAll() }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Re-authentication Required", isPresented: $viewModel.showReauthAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please sign out and sign back in, then try again.")
        }
        .alert("Export Requested", isPresented: $viewModel.exportRequested) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your data export has been queued. You will receive an email when it is ready.")
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete My Account", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            Spacer()

            Text("ACCOUNT")
                .font(.spaceMonoBold(15))
                .tracking(2.0)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Spacer()

            // Balance the back button
            Color.clear.frame(width: 16, height: 16)
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - ENVI-0008 Active Sessions

    private var activeSessionsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionHeader("ACTIVE DEVICES")

            ForEach(viewModel.sessions) { session in
                HStack(spacing: ENVISpacing.md) {
                    Image(systemName: session.isCurrent ? "iphone" : "desktopcomputer")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: ENVISpacing.sm) {
                            Text(session.deviceName)
                                .font(.interSemiBold(14))
                                .foregroundColor(ENVITheme.text(for: colorScheme))

                            if session.isCurrent {
                                Text("CURRENT")
                                    .font(.spaceMonoBold(9))
                                    .tracking(1.5)
                                    .foregroundColor(ENVITheme.success)
                            }
                        }

                        Text("\(session.location) \u{2022} \(session.lastActive.relativeDescription)")
                            .font(.interRegular(12))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    if !session.isCurrent {
                        Button(action: {
                            Task { await viewModel.revokeSession(session) }
                        }) {
                            Text("REVOKE")
                                .font(.spaceMonoBold(10))
                                .tracking(1.5)
                                .foregroundColor(ENVITheme.error)
                        }
                    }
                }
                .padding(.vertical, ENVISpacing.sm)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - ENVI-0010 Suspicious Login Alerts

    private var suspiciousLoginAlertsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionHeader("SECURITY ALERTS")

            Toggle(isOn: $viewModel.suspiciousLoginAlertsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suspicious Login Alerts")
                        .font(.interSemiBold(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text("Get notified when a login occurs from an unrecognized device or location.")
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
            .tint(ENVITheme.text(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - ENVI-0020 Login Activity

    private var loginActivitySection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionHeader("LOGIN ACTIVITY")

            ForEach(viewModel.loginHistory) { activity in
                HStack(spacing: ENVISpacing.md) {
                    Circle()
                        .fill(statusColor(for: activity.status))
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.device)
                            .font(.interSemiBold(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        Text("\(activity.location) \u{2022} \(activity.timestamp.relativeDescription)")
                            .font(.interRegular(12))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Text(activity.status.rawValue.uppercased())
                        .font(.spaceMonoBold(9))
                        .tracking(1.5)
                        .foregroundColor(statusColor(for: activity.status))
                }
                .padding(.vertical, ENVISpacing.xs)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - ENVI-0019 Consent Ledger

    private var consentLedgerSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionHeader("CONSENT HISTORY")

            ForEach(viewModel.consents) { consent in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(consent.consentType)
                            .font(.interSemiBold(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        Text("v\(consent.version) \u{2022} \(consent.grantedAt.relativeDescription)")
                            .font(.interRegular(12))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ENVITheme.success)
                }
                .padding(.vertical, ENVISpacing.xs)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - ENVI-0021 Data Export

    private var dataExportSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionHeader("YOUR DATA")

            Button(action: {
                Task { await viewModel.requestDataExport() }
            }) {
                HStack {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text("Request Data Export")
                        .font(.interSemiBold(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .padding(ENVISpacing.lg)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - ENVI-0018 Delete Account

    private var deleteAccountSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionHeader("DANGER ZONE")

            Button(action: {
                viewModel.showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))

                    Text("Delete Account")
                        .font(.interSemiBold(14))

                    Spacer()
                }
                .foregroundColor(ENVITheme.error)
                .padding(ENVISpacing.lg)
                .background(ENVITheme.error.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Helpers

    private var sectionDivider: some View {
        Divider()
            .background(ENVITheme.border(for: colorScheme))
            .padding(.horizontal, ENVISpacing.xl)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.spaceMonoBold(11))
            .tracking(2.0)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }

    private func statusColor(for status: LoginActivity.LoginStatus) -> Color {
        switch status {
        case .success: return ENVITheme.success
        case .failed: return ENVITheme.warning
        case .blocked: return ENVITheme.error
        }
    }
}

// MARK: - Date Extension

private extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    AccountManagementView()
        .preferredColorScheme(.dark)
}

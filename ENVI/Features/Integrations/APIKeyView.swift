import SwiftUI

/// API key management with create, revoke, and copy (ENVI-0846..0850).
struct APIKeyView: View {

    @StateObject private var viewModel = IntegrationViewModel()
    @Environment(\.colorScheme) private var colorScheme

    @State private var showCreateSheet = false
    @State private var newKeyName = ""
    @State private var selectedPermissions: Set<APIKeyPermission> = []
    @State private var copiedKeyId: String?

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                statsRow
                createButton
                keyList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(isPresented: $showCreateSheet) { createSheet }
        .alert("API Key Created", isPresented: .init(
            get: { viewModel.newlyCreatedKey != nil },
            set: { if !$0 { viewModel.dismissNewKeyAlert() } }
        )) {
            Button("Copy Key") {
                if let key = viewModel.newlyCreatedKey {
                    UIPasteboard.general.string = key.key
                    copiedKeyId = key.id
                }
                viewModel.dismissNewKeyAlert()
            }
            Button("Dismiss", role: .cancel) {
                viewModel.dismissNewKeyAlert()
            }
        } message: {
            if let key = viewModel.newlyCreatedKey {
                Text("Copy your key now. It will not be shown again.\n\n\(key.key)")
            }
        }
        .task { await viewModel.loadAPIKeys() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("API KEYS")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Manage programmatic access to your account")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: ENVISpacing.md) {
            miniStat(label: "TOTAL", value: "\(viewModel.apiKeys.count)")
            miniStat(label: "ACTIVE", value: "\(viewModel.activeAPIKeyCount)")
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: ENVISpacing.xs) {
            Text(value)
                .font(.spaceMonoBold(18))
                .foregroundColor(ENVITheme.text(for: colorScheme))
            Text(label)
                .font(.spaceMono(9))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            showCreateSheet = true
        } label: {
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("NEW API KEY")
                    .font(.spaceMonoBold(12))
                    .tracking(0.44)
            }
            .foregroundColor(ENVITheme.background(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.md)
            .background(ENVITheme.text(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Key List

    private var keyList: some View {
        Group {
            if viewModel.isLoadingAPIKeys {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.apiKeys.isEmpty {
                VStack(spacing: ENVISpacing.sm) {
                    Image(systemName: "key")
                        .font(.system(size: 28))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    Text("No API keys created")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                LazyVStack(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.apiKeys) { apiKey in
                        apiKeyCard(apiKey)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    private func apiKeyCard(_ apiKey: APIKey) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Name + status
            HStack {
                Text(apiKey.name)
                    .font(.spaceMonoBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text(apiKey.isActive ? "ACTIVE" : "REVOKED")
                    .font(.spaceMono(8))
                    .tracking(0.44)
                    .foregroundColor(apiKey.isActive ? ENVITheme.success : ENVITheme.error)
                    .padding(.horizontal, ENVISpacing.xs)
                    .padding(.vertical, 2)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            // Key (masked)
            HStack(spacing: ENVISpacing.xs) {
                Text(apiKey.maskedKey)
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(1)

                if apiKey.isActive {
                    Button {
                        UIPasteboard.general.string = apiKey.key
                        copiedKeyId = apiKey.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if copiedKeyId == apiKey.id { copiedKeyId = nil }
                        }
                    } label: {
                        Image(systemName: copiedKeyId == apiKey.id ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(copiedKeyId == apiKey.id
                                ? ENVITheme.success
                                : ENVITheme.textSecondary(for: colorScheme))
                    }
                }
            }

            // Permissions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.xs) {
                    ForEach(apiKey.permissions) { perm in
                        Text(perm.displayName)
                            .font(.spaceMono(9))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                            .padding(.horizontal, ENVISpacing.sm)
                            .padding(.vertical, 3)
                            .background(ENVITheme.surfaceHigh(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    }
                }
            }

            // Dates + revoke
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Created: \(apiKey.createdAt, style: .date)")
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    if let lastUsed = apiKey.lastUsedAt {
                        Text("Last used: \(lastUsed, style: .relative) ago")
                            .font(.spaceMono(9))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    } else {
                        Text("Never used")
                            .font(.spaceMono(9))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }

                Spacer()

                if apiKey.isActive {
                    Button {
                        Task { await viewModel.revokeAPIKey(id: apiKey.id) }
                    } label: {
                        HStack(spacing: ENVISpacing.xs) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 10))
                            Text("REVOKE")
                                .font(.spaceMonoBold(10))
                                .tracking(0.44)
                        }
                        .foregroundColor(ENVITheme.error)
                        .padding(.horizontal, ENVISpacing.md)
                        .padding(.vertical, ENVISpacing.sm)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    }
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
        .opacity(apiKey.isActive ? 1.0 : 0.6)
    }

    // MARK: - Create Sheet

    private var createSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    // Name input
                    VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                        Text("KEY NAME")
                            .font(.spaceMonoBold(11))
                            .tracking(0.88)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        TextField("e.g. Production App", text: $newKeyName)
                            .font(.interRegular(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .padding(ENVISpacing.md)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    }

                    // Permission selector
                    VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                        Text("PERMISSIONS")
                            .font(.spaceMonoBold(11))
                            .tracking(0.88)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        LazyVStack(spacing: ENVISpacing.xs) {
                            ForEach(APIKeyPermission.allCases) { perm in
                                permissionRow(perm)
                            }
                        }
                    }
                }
                .padding(ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("New API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateSheet = false }
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createAPIKey(
                                name: newKeyName,
                                permissions: Array(selectedPermissions)
                            )
                            newKeyName = ""
                            selectedPermissions = []
                            showCreateSheet = false
                        }
                    }
                    .font(.spaceMonoBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .disabled(newKeyName.isEmpty || selectedPermissions.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func permissionRow(_ perm: APIKeyPermission) -> some View {
        let isSelected = selectedPermissions.contains(perm)
        return Button {
            if isSelected {
                selectedPermissions.remove(perm)
            } else {
                selectedPermissions.insert(perm)
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme))

                Text(perm.displayName)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text(perm.rawValue)
                    .font(.spaceMono(9))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            .padding(ENVISpacing.sm)
            .background(isSelected ? ENVITheme.surfaceLow(for: colorScheme) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }
}

#Preview {
    APIKeyView()
        .preferredColorScheme(.dark)
}

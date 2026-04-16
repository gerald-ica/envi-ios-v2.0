import SwiftUI

/// Enterprise SSO provider setup with domain mapping and SAML metadata (ENVI-0976..0978).
struct SSOConfigView: View {

    @Environment(\.colorScheme) private var colorScheme
    @State private var config: SSOConfig = .mock
    @State private var scimConfig: SCIMConfig = .mock
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var newMetaKey = ""
    @State private var newMetaValue = ""

    private let repository: EnterpriseRepository = EnterpriseRepositoryProvider.shared.repository

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                providerSection
                domainSection
                metadataSection
                scimSection
                saveButton
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await loadConfig() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("SSO CONFIGURATION")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Manage single sign-on and SCIM provisioning")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Provider Picker

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionLabel("IDENTITY PROVIDER")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(SSOProvider.allCases) { provider in
                        providerChip(provider)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    private func providerChip(_ provider: SSOProvider) -> some View {
        Button {
            config.provider = provider
        } label: {
            HStack(spacing: ENVISpacing.xs) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 12))
                Text(provider.displayName)
                    .font(.interMedium(13))
            }
            .padding(.horizontal, ENVISpacing.md)
            .padding(.vertical, ENVISpacing.sm)
            .background(
                config.provider == provider
                    ? ENVITheme.text(for: colorScheme)
                    : ENVITheme.surfaceLow(for: colorScheme)
            )
            .foregroundColor(
                config.provider == provider
                    ? ENVITheme.background(for: colorScheme)
                    : ENVITheme.textSecondary(for: colorScheme)
            )
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }

    // MARK: - Domain

    private var domainSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionLabel("DOMAIN")

            HStack(spacing: ENVISpacing.sm) {
                TextField("e.g. acme.com", text: $config.domain)
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Toggle("", isOn: $config.isEnabled)
                    .labelsHidden()
                    .tint(ENVITheme.success)
            }
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionLabel("SAML METADATA")

            ForEach(Array(config.metadata.keys.sorted()), id: \.self) { key in
                metadataRow(key: key, value: config.metadata[key] ?? "")
            }

            HStack(spacing: ENVISpacing.sm) {
                TextField("Key", text: $newMetaKey)
                    .font(.interRegular(13))
                TextField("Value", text: $newMetaValue)
                    .font(.interRegular(13))

                Button {
                    guard !newMetaKey.isEmpty else { return }
                    config.metadata[newMetaKey] = newMetaValue
                    newMetaKey = ""
                    newMetaValue = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            }
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func metadataRow(key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.spaceMono(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Spacer()
            Text(value)
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(1)
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    // MARK: - SCIM

    private var scimSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            sectionLabel("SCIM PROVISIONING")

            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                HStack {
                    Text("Endpoint")
                        .font(.interMedium(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    Spacer()
                    Text(scimConfig.endpoint)
                        .font(.spaceMono(11))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .lineLimit(1)
                }

                HStack {
                    Text("Sync Enabled")
                        .font(.interMedium(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    Spacer()
                    Toggle("", isOn: $scimConfig.syncEnabled)
                        .labelsHidden()
                        .tint(ENVITheme.success)
                }
            }
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            Task { await saveConfig() }
        } label: {
            HStack(spacing: ENVISpacing.sm) {
                if isSaving {
                    ProgressView()
                        .tint(ENVITheme.background(for: colorScheme))
                }
                Text(isSaving ? "SAVING..." : "SAVE CONFIGURATION")
                    .font(.spaceMonoBold(14))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.md)
            .background(ENVITheme.text(for: colorScheme))
            .foregroundColor(ENVITheme.background(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .disabled(isSaving)
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.spaceMono(11))
            .tracking(1)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            .padding(.horizontal, ENVISpacing.xl)
    }

    private func loadConfig() async {
        do {
            async let sso = repository.fetchSSOConfig()
            async let scim = repository.fetchSCIMConfig()
            config = try await sso
            scimConfig = try await scim
        } catch {}
        isLoading = false
    }

    private func saveConfig() async {
        isSaving = true
        _ = try? await repository.updateSSOConfig(config)
        isSaving = false
    }
}

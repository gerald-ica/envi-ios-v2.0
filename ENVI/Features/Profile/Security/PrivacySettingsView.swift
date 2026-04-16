import SwiftUI

/// Toggle-based privacy controls with explanations for each setting.
struct PrivacySettingsView: View {
    @ObservedObject var viewModel: SecurityViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                privacyToggles
                retentionSection
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable {
            async let p: () = viewModel.loadPrivacy()
            async let r: () = viewModel.loadRetention()
            _ = await (p, r)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("PRIVACY SETTINGS")
                .font(.spaceMonoBold(17))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Control how your data is collected and used")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Privacy Toggles

    private var privacyToggles: some View {
        VStack(spacing: ENVISpacing.sm) {
            privacyToggle(
                title: "Data Collection",
                description: "Allow ENVI to collect usage data to improve the experience. No personal content is accessed.",
                icon: "chart.bar.fill",
                isOn: $viewModel.privacySettings.dataCollection
            )

            privacyToggle(
                title: "Ad Tracking",
                description: "Enable personalized advertising across partner networks. You can opt out at any time.",
                icon: "megaphone.fill",
                isOn: $viewModel.privacySettings.adTracking
            )

            privacyToggle(
                title: "Analytics Opt-In",
                description: "Share anonymized analytics to help us understand feature usage and prioritize improvements.",
                icon: "waveform.path.ecg",
                isOn: $viewModel.privacySettings.analyticsOptIn
            )

            privacyToggle(
                title: "Location Sharing",
                description: "Allow location-based features such as geo-tagged content insights and local trending data.",
                icon: "location.fill",
                isOn: $viewModel.privacySettings.locationSharing
            )
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func privacyToggle(title: String, description: String, icon: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack(spacing: ENVISpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.spaceMonoBold(13))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(description)
                        .font(.interRegular(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(ENVITheme.text(for: colorScheme))
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await viewModel.savePrivacy() }
        } label: {
            HStack(spacing: ENVISpacing.sm) {
                if viewModel.isSavingPrivacy {
                    ProgressView()
                        .tint(ENVITheme.background(for: colorScheme))
                }
                Text(viewModel.privacySaved ? "Saved" : "Save Changes")
                    .font(.interMedium(14))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.md)
            .foregroundColor(ENVITheme.background(for: colorScheme))
            .background(ENVITheme.text(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .disabled(viewModel.isSavingPrivacy)
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Retention Section

    private var retentionSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("DATA RETENTION")
                .font(.spaceMonoBold(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            if viewModel.isLoadingRetention {
                ENVILoadingState(minHeight: 80)
            } else {
                VStack(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.retentionPolicies) { policy in
                        retentionRow(policy)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }

            saveButton
        }
    }

    private func retentionRow(_ policy: DataRetentionPolicy) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(policy.dataType)
                    .font(.spaceMonoBold(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("Retained for \(policy.formattedRetention)")
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            if policy.autoDeleteEnabled {
                Text("AUTO-DELETE")
                    .font(.spaceMono(8))
                    .tracking(0.44)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, 3)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    PrivacySettingsView(viewModel: SecurityViewModel())
}

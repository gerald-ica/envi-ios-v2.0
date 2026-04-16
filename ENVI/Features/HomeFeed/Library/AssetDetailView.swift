import SwiftUI

/// Detail view for a single asset showing version history, usage rights,
/// publishing history, storage info, and platform readiness badges.
struct AssetDetailView: View {
    let assetID: UUID
    let assetTitle: String

    @StateObject private var viewModel = LibraryDAMViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                // Platform Readiness
                platformReadinessSection

                // Version History
                versionHistorySection

                // Usage Rights
                usageRightsSection

                // Storage Info
                storageInfoSection
            }
            .padding(.top, ENVISpacing.lg)
            .padding(.bottom, 100)
        }
        .background(ENVITheme.background(for: colorScheme))
        .navigationTitle(assetTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadVersionHistory(for: assetID)
            await viewModel.loadUsageRights(for: assetID)
            await viewModel.loadPlatformReadiness(for: assetID)
            await viewModel.loadStorageQuota()
        }
    }

    // MARK: - Platform Readiness

    @ViewBuilder
    private var platformReadinessSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("PLATFORM READINESS")
                .font(.spaceMonoBold(14))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.platformReadiness) { result in
                        PlatformReadinessBadge(result: result, colorScheme: colorScheme)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    // MARK: - Version History

    @ViewBuilder
    private var versionHistorySection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("VERSION HISTORY")
                .font(.spaceMonoBold(14))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            if viewModel.isLoadingVersions {
                HStack {
                    ProgressView()
                    Text("Loading versions...")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .padding(.horizontal, ENVISpacing.xl)
            } else if viewModel.versionHistory.isEmpty {
                Text("No version history available")
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xl)
            } else {
                // Timeline
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.versionHistory.enumerated()), id: \.element.id) { index, version in
                        VersionTimelineRow(
                            version: version,
                            isLast: index == viewModel.versionHistory.count - 1,
                            colorScheme: colorScheme
                        )
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    // MARK: - Usage Rights

    @ViewBuilder
    private var usageRightsSection: some View {
        if let rights = viewModel.usageRights {
            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                Text("USAGE RIGHTS")
                    .font(.spaceMonoBold(14))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    if let license = rights.license {
                        UsageRightsRow(label: "License", value: license, colorScheme: colorScheme)
                    }

                    if let attribution = rights.attribution {
                        UsageRightsRow(label: "Attribution", value: attribution, colorScheme: colorScheme)
                    }

                    if let expiresAt = rights.expiresAt {
                        let formatter = Self.dateFormatter
                        let isExpired = rights.isExpired
                        HStack {
                            Text("Expires")
                                .font(.interRegular(13))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                            Spacer()
                            Text(formatter.string(from: expiresAt))
                                .font(.interMedium(13))
                                .foregroundColor(isExpired ? ENVITheme.error : ENVITheme.text(for: colorScheme))
                        }
                    }

                    if !rights.restrictions.isEmpty {
                        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                            Text("Restrictions")
                                .font(.interRegular(13))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                            ForEach(rights.restrictions, id: \.self) { restriction in
                                HStack(alignment: .top, spacing: ENVISpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(ENVITheme.warning)
                                        .padding(.top, 3)
                                    Text(restriction)
                                        .font(.interRegular(13))
                                        .foregroundColor(ENVITheme.text(for: colorScheme))
                                }
                            }
                        }
                    }
                }
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Storage Info

    @ViewBuilder
    private var storageInfoSection: some View {
        if let quota = viewModel.storageQuota {
            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                Text("STORAGE")
                    .font(.spaceMonoBold(14))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                VStack(spacing: ENVISpacing.sm) {
                    HStack {
                        Text("\(quota.formattedUsed) of \(quota.formattedTotal)")
                            .font(.interMedium(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        Spacer()
                        Text(String(format: "%.0f%%", quota.usagePercent))
                            .font(.spaceMono(13))
                            .foregroundColor(quotaColor(for: quota))
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ENVITheme.surfaceHigh(for: colorScheme))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(quotaColor(for: quota))
                                .frame(width: geo.size.width * CGFloat(min(quota.usagePercent, 100) / 100), height: 6)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("\(quota.assetCount) assets")
                            .font(.interRegular(12))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        Spacer()
                    }
                }
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Helpers

    private func quotaColor(for quota: StorageQuota) -> Color {
        if quota.usagePercent >= 90 { return ENVITheme.error }
        if quota.usagePercent >= 70 { return ENVITheme.warning }
        return ENVITheme.success
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

// MARK: - Platform Readiness Badge

private struct PlatformReadinessBadge: View {
    let result: PlatformReadinessResult
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: ENVISpacing.xs) {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: result.platform.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(badgeColor)
            }

            Text(result.platform.rawValue)
                .font(.interRegular(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Circle()
                .fill(badgeColor)
                .frame(width: 8, height: 8)
        }
        .frame(width: 64)
        .help(result.notes)
    }

    private var badgeColor: Color {
        switch result.status {
        case .ready: return ENVITheme.success
        case .warning: return ENVITheme.warning
        case .notReady: return ENVITheme.error
        }
    }
}

// MARK: - Version Timeline Row

private struct VersionTimelineRow: View {
    let version: AssetVersion
    let isLast: Bool
    let colorScheme: ColorScheme

    private static let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: ENVISpacing.md) {
            // Timeline connector
            VStack(spacing: 0) {
                Circle()
                    .fill(ENVITheme.text(for: colorScheme))
                    .frame(width: 8, height: 8)

                if !isLast {
                    Rectangle()
                        .fill(ENVITheme.border(for: colorScheme))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 8)

            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                HStack {
                    Text("v\(version.versionNumber)")
                        .font(.spaceMonoBold(13))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Spacer()

                    Text(Self.timeFormatter.localizedString(for: version.createdAt, relativeTo: Date()))
                        .font(.interRegular(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Text(version.changeDescription)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("by \(version.createdBy)")
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            .padding(.bottom, isLast ? 0 : ENVISpacing.lg)
        }
    }
}

// MARK: - Usage Rights Row

private struct UsageRightsRow: View {
    let label: String
    let value: String
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            Text(label)
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Spacer()
            Text(value)
                .font(.interMedium(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        AssetDetailView(assetID: UUID(), assetTitle: "Desert Road")
    }
    .preferredColorScheme(.dark)
}

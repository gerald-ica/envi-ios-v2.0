import SwiftUI

/// Full storage quota view with usage breakdown by type and archive suggestions.
struct StorageQuotaView: View {
    @ObservedObject var viewModel: LibraryDAMViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            // Header
            Text("STORAGE")
                .font(.spaceMonoBold(18))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            if viewModel.isLoadingQuota {
                HStack {
                    ProgressView()
                    Text("Loading storage info...")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .padding(.horizontal, ENVISpacing.xl)
            } else if let quota = viewModel.storageQuota {
                // Overall usage card
                overallUsageCard(quota: quota)

                // Breakdown by type
                breakdownSection(quota: quota)

                // Archive suggestions
                if quota.usagePercent >= 60 {
                    archiveSuggestions(quota: quota)
                }
            }
        }
    }

    // MARK: - Overall Usage

    @ViewBuilder
    private func overallUsageCard(quota: StorageQuota) -> some View {
        VStack(spacing: ENVISpacing.lg) {
            // Circular gauge
            ZStack {
                Circle()
                    .stroke(ENVITheme.surfaceHigh(for: colorScheme), lineWidth: 10)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(min(quota.usagePercent, 100) / 100))
                    .stroke(
                        quotaColor(for: quota),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", quota.usagePercent))
                        .font(.spaceMonoBold(24))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text("used")
                        .font(.interRegular(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            HStack(spacing: ENVISpacing.xxl) {
                StatColumn(
                    label: "Used",
                    value: quota.formattedUsed,
                    colorScheme: colorScheme
                )
                StatColumn(
                    label: "Total",
                    value: quota.formattedTotal,
                    colorScheme: colorScheme
                )
                StatColumn(
                    label: "Assets",
                    value: "\(quota.assetCount)",
                    colorScheme: colorScheme
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ENVISpacing.xl)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Breakdown

    @ViewBuilder
    private func breakdownSection(quota: StorageQuota) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("BREAKDOWN")
                .font(.spaceMonoBold(14))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            VStack(spacing: ENVISpacing.sm) {
                BreakdownRow(
                    icon: "photo.fill",
                    label: "Photos",
                    bytes: quota.formattedPhotos,
                    fraction: safeFraction(quota.photoBytes, of: quota.usedBytes),
                    color: ENVITheme.info,
                    colorScheme: colorScheme
                )

                BreakdownRow(
                    icon: "video.fill",
                    label: "Videos",
                    bytes: quota.formattedVideos,
                    fraction: safeFraction(quota.videoBytes, of: quota.usedBytes),
                    color: ENVITheme.warning,
                    colorScheme: colorScheme
                )

                BreakdownRow(
                    icon: "doc.text.fill",
                    label: "Drafts",
                    bytes: quota.formattedDrafts,
                    fraction: safeFraction(quota.draftBytes, of: quota.usedBytes),
                    color: ENVITheme.success,
                    colorScheme: colorScheme
                )
            }
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Archive Suggestions

    @ViewBuilder
    private func archiveSuggestions(quota: StorageQuota) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("SUGGESTIONS")
                .font(.spaceMonoBold(14))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                if quota.usagePercent >= 90 {
                    SuggestionRow(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: ENVITheme.error,
                        text: "Storage nearly full. Archive unused assets to free space.",
                        colorScheme: colorScheme
                    )
                }

                if quota.videoBytes > quota.photoBytes {
                    SuggestionRow(
                        icon: "video.fill",
                        iconColor: ENVITheme.warning,
                        text: "Videos account for most usage. Consider archiving older video content.",
                        colorScheme: colorScheme
                    )
                }

                if quota.draftBytes > 0 {
                    SuggestionRow(
                        icon: "doc.text.fill",
                        iconColor: ENVITheme.info,
                        text: "Review drafts and discard unneeded ones to reclaim \(quota.formattedDrafts).",
                        colorScheme: colorScheme
                    )
                }

                if quota.usagePercent >= 60, quota.usagePercent < 90 {
                    SuggestionRow(
                        icon: "archivebox.fill",
                        iconColor: ENVITheme.textSecondary(for: colorScheme),
                        text: "Archive content older than 90 days that is no longer in active use.",
                        colorScheme: colorScheme
                    )
                }
            }
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Helpers

    private func quotaColor(for quota: StorageQuota) -> Color {
        if quota.usagePercent >= 90 { return ENVITheme.error }
        if quota.usagePercent >= 70 { return ENVITheme.warning }
        return ENVITheme.success
    }

    private func safeFraction(_ part: Int64, of total: Int64) -> Double {
        guard total > 0 else { return 0 }
        return Double(part) / Double(total)
    }
}

// MARK: - Stat Column

private struct StatColumn: View {
    let label: String
    let value: String
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.spaceMonoBold(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))
            Text(label)
                .font(.interRegular(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }
}

// MARK: - Breakdown Row

private struct BreakdownRow: View {
    let icon: String
    let label: String
    let bytes: String
    let fraction: Double
    let color: Color
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: ENVISpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                    .frame(width: 20)

                Text(label)
                    .font(.interMedium(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text(bytes)
                    .font(.spaceMono(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Text(String(format: "%.0f%%", fraction * 100))
                    .font(.spaceMono(12))
                    .foregroundColor(color)
                    .frame(width: 40, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ENVITheme.surfaceHigh(for: colorScheme))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(fraction, 1.0)), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Suggestion Row

private struct SuggestionRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: ENVISpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(iconColor)
                .padding(.top, 2)

            Text(text)
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ScrollView {
        StorageQuotaView(viewModel: LibraryDAMViewModel())
    }
    .preferredColorScheme(.dark)
}

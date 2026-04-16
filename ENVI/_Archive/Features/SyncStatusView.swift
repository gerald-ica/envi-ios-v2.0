import SwiftUI

/// Displays sync status, pending changes, offline drafts, and performance metrics.
struct SyncStatusView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var syncManager = SyncManager.shared

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                header
                syncStatusCard
                offlineDraftsSection
                performanceSection
                cachePolicySection
            }
            .padding(ENVISpacing.lg)
        }
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
        .task {
            syncManager.loadMockData()
            await syncManager.loadPerformanceMetrics()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SYNC & DATA")
                    .font(.spaceMono(22))
                    .tracking(-1)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("Manage offline data and sync status")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Button {
                Task { await syncManager.forceSync() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .rotationEffect(.degrees(syncManager.isSyncing ? 360 : 0))
                    .animation(
                        syncManager.isSyncing
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: syncManager.isSyncing
                    )
            }
        }
    }

    // MARK: - Sync Status Card

    private var syncStatusCard: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                Image(systemName: syncManager.syncStatus.state.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(syncStateColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text(syncManager.syncStatus.state.displayName.uppercased())
                        .font(.spaceMono(13))
                        .tracking(0.5)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    if let lastSync = syncManager.syncStatus.lastSync {
                        Text("Last synced \(lastSync, style: .relative) ago")
                            .font(.interRegular(11))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }

                Spacer()

                if syncManager.syncStatus.hasPendingChanges {
                    Text("\(syncManager.syncStatus.pendingChanges)")
                        .font(.spaceMono(11))
                        .tracking(1)
                        .foregroundColor(ENVITheme.background(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, ENVISpacing.xs)
                        .background(ENVITheme.warning)
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }

            // Conflicts
            if syncManager.syncStatus.hasConflicts {
                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    Text("CONFLICTS")
                        .font(.spaceMono(10))
                        .tracking(1.5)
                        .foregroundColor(ENVITheme.error)

                    ForEach(syncManager.syncStatus.conflicts) { conflict in
                        conflictRow(conflict)
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
    }

    private func conflictRow(_ conflict: SyncConflict) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(conflict.fieldName.uppercased())
                    .font(.spaceMono(10))
                    .tracking(1)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("Content: \(conflict.contentID)")
                    .font(.interRegular(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            if conflict.isResolved {
                Text("RESOLVED")
                    .font(.spaceMono(9))
                    .tracking(1)
                    .foregroundColor(ENVITheme.success)
            } else {
                HStack(spacing: ENVISpacing.xs) {
                    Button {
                        syncManager.resolveConflict(id: conflict.id, resolution: .keepLocal)
                    } label: {
                        Text("LOCAL")
                            .font(.spaceMono(9))
                            .tracking(1)
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .padding(.horizontal, ENVISpacing.sm)
                            .padding(.vertical, ENVISpacing.xs)
                            .background(ENVITheme.surfaceHigh(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    }

                    Button {
                        syncManager.resolveConflict(id: conflict.id, resolution: .keepRemote)
                    } label: {
                        Text("REMOTE")
                            .font(.spaceMono(9))
                            .tracking(1)
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .padding(.horizontal, ENVISpacing.sm)
                            .padding(.vertical, ENVISpacing.xs)
                            .background(ENVITheme.surfaceHigh(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    }
                }
            }
        }
        .padding(ENVISpacing.sm)
        .background(ENVITheme.surfaceHigh(for: colorScheme).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private var syncStateColor: Color {
        switch syncManager.syncStatus.state {
        case .synced:   return ENVITheme.success
        case .syncing:  return ENVITheme.warning
        case .conflict: return ENVITheme.error
        case .error:    return ENVITheme.error
        case .idle:     return ENVITheme.textSecondary(for: colorScheme)
        }
    }

    // MARK: - Offline Drafts

    private var offlineDraftsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("OFFLINE DRAFTS")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            if syncManager.offlineDrafts.isEmpty {
                Text("No offline drafts")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, ENVISpacing.lg)
            } else {
                ForEach(syncManager.offlineDrafts) { draft in
                    draftRow(draft)
                }
            }
        }
    }

    private func draftRow(_ draft: OfflineDraft) -> some View {
        HStack {
            Image(systemName: draft.syncStatus.iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(draftStatusColor(draft.syncStatus))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(draft.title)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)

                Text(draft.modifiedAt, style: .relative)
                    .font(.interRegular(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Text(draft.syncStatus.displayName.uppercased())
                .font(.spaceMono(9))
                .tracking(1)
                .foregroundColor(draftStatusColor(draft.syncStatus))

            if draft.syncStatus == .failed {
                Button {
                    Task { await syncManager.retryDraft(id: draft.id) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
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
    }

    private func draftStatusColor(_ status: OfflineDraft.DraftSyncStatus) -> Color {
        switch status {
        case .synced:    return ENVITheme.success
        case .uploading: return ENVITheme.warning
        case .pending:   return ENVITheme.textSecondary(for: colorScheme)
        case .failed:    return ENVITheme.error
        }
    }

    // MARK: - Performance

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("PERFORMANCE")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            ForEach(syncManager.performanceMetrics) { metric in
                metricRow(metric)
            }
        }
    }

    private func metricRow(_ metric: PerformanceMetric) -> some View {
        HStack {
            Image(systemName: metric.status.iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(metricStatusColor(metric.status))
                .frame(width: 24)

            Text(metric.name)
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Spacer()

            Text("\(Int(metric.value))ms")
                .font(.spaceMono(12))
                .foregroundColor(metricStatusColor(metric.status))

            Text("/ \(Int(metric.threshold))ms")
                .font(.interRegular(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func metricStatusColor(_ status: PerformanceMetric.Status) -> Color {
        switch status {
        case .healthy:  return ENVITheme.success
        case .degraded: return ENVITheme.warning
        case .critical: return ENVITheme.error
        }
    }

    // MARK: - Cache Policy

    private var cachePolicySection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("CACHE POLICY")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            VStack(spacing: ENVISpacing.sm) {
                cacheRow(label: "MAX AGE", value: syncManager.cachePolicy.maxAgeDescription)
                cacheRow(label: "MAX SIZE", value: syncManager.cachePolicy.maxSizeDescription)
                cacheRow(label: "EVICTION", value: syncManager.cachePolicy.evictionStrategy.displayName)
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

    private func cacheRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.spaceMono(10))
                .tracking(1)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Spacer()

            Text(value)
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
    }
}

#Preview {
    SyncStatusView()
        .preferredColorScheme(.dark)
}

import SwiftUI

/// Filterable audit trail showing actor, action, resource, and timestamp.
struct AuditLogView: View {
    @ObservedObject var viewModel: SecurityViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                searchBar
                actionFilterBar
                logList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable { await viewModel.loadAuditLog() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("AUDIT LOG")
                .font(.spaceMonoBold(17))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("\(viewModel.filteredAuditLog.count) entries")
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: ENVISpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextField("Search by actor, action, or resource...", text: $viewModel.auditSearchText)
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Action Filter

    private var actionFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ENVIFilterChip(title: "All", isSelected: viewModel.auditActionFilter == nil) {
                    viewModel.auditActionFilter = nil
                }
                ForEach(viewModel.uniqueActions, id: \.self) { action in
                    ENVIFilterChip(title: action, isSelected: viewModel.auditActionFilter == action) {
                        viewModel.auditActionFilter = action
                    }
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Log List

    private var logList: some View {
        LazyVStack(spacing: ENVISpacing.sm) {
            if viewModel.isLoadingAuditLog {
                ENVILoadingState()
            } else if viewModel.filteredAuditLog.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.filteredAuditLog) { entry in
                    logRow(entry)
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private var emptyState: some View {
        ENVIEmptyState(
            icon: "doc.text.magnifyingglass",
            title: "No log entries found"
        )
    }

    private func logRow(_ entry: AuditLogEntry) -> some View {
        HStack(alignment: .top, spacing: ENVISpacing.md) {
            // Actor avatar
            ZStack {
                Circle()
                    .fill(ENVITheme.surfaceHigh(for: colorScheme))
                    .frame(width: 36, height: 36)
                Text(String(entry.actor.prefix(1)).uppercased())
                    .font(.spaceMonoBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.actor)
                    .font(.spaceMonoBold(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(entry.action)
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                HStack(spacing: ENVISpacing.sm) {
                    Text(entry.resource)
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.xs)
                        .padding(.vertical, 2)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                    Text(entry.ipAddress)
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            Spacer()

            Text(timeFormatter.localizedString(for: entry.timestamp, relativeTo: Date()))
                .font(.spaceMono(10))
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
}

// MARK: - Preview

#Preview {
    AuditLogView(viewModel: SecurityViewModel())
}

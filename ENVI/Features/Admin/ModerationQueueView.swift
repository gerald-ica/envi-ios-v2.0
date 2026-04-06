import SwiftUI

/// Content moderation queue with approve/reject actions (ENVI-0941..0950).
struct ModerationQueueView: View {

    @State private var items: [ModerationItem] = []
    @State private var isLoading = true
    @State private var selectedFilter: ModerationStatus? = .pending
    @Environment(\.colorScheme) private var colorScheme

    private let repository = AdminRepositoryProvider.shared.repository

    private var filteredItems: [ModerationItem] {
        guard let filter = selectedFilter else { return items }
        return items.filter { $0.status == filter }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                filterBar
                if isLoading {
                    ProgressView()
                        .padding(.top, ENVISpacing.xxl)
                } else if filteredItems.isEmpty {
                    emptyState
                } else {
                    queueList
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await loadQueue() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("MODERATION QUEUE")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            let pendingCount = items.filter { $0.status == .pending }.count
            Text("\(pendingCount) items pending review")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                filterChip(label: "ALL", filter: nil)
                ForEach(ModerationStatus.allCases) { status in
                    filterChip(label: status.displayName.uppercased(), filter: status)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private func filterChip(label: String, filter: ModerationStatus?) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            selectedFilter = filter
        } label: {
            Text(label)
                .font(.spaceMonoBold(10))
                .tracking(0.5)
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.xs)
                .foregroundColor(isSelected
                    ? ENVITheme.background(for: colorScheme)
                    : ENVITheme.text(for: colorScheme))
                .background(isSelected
                    ? ENVITheme.text(for: colorScheme)
                    : ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }

    // MARK: - Queue List

    private var queueList: some View {
        VStack(spacing: ENVISpacing.md) {
            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { _, item in
                moderationRow(item)
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func moderationRow(_ item: ModerationItem) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Top row: content type + status badge
            HStack {
                Label(item.contentType, systemImage: contentIcon(for: item.contentType))
                    .font(.spaceMonoBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Label(item.status.displayName, systemImage: item.status.iconName)
                    .font(.interRegular(11))
                    .foregroundColor(statusColor(for: item.status))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, 2)
                    .background(statusColor(for: item.status).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            // Reason
            Text(item.reportReason)
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            // Time + actions
            HStack {
                Text(item.reportedAt, style: .relative)
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                if item.status == .pending || item.status == .escalated {
                    actionButtons(for: item)
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
    }

    private func actionButtons(for item: ModerationItem) -> some View {
        HStack(spacing: ENVISpacing.sm) {
            Button {
                Task { await moderate(item: item, status: .approved) }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(ENVISpacing.xs)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Circle())
            }

            Button {
                Task { await moderate(item: item, status: .rejected) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(ENVISpacing.xs)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 40))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("Queue is clear")
                .font(.spaceMonoBold(16))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("No items matching this filter")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.top, ENVISpacing.xxl)
    }

    // MARK: - Helpers

    private func contentIcon(for type: String) -> String {
        switch type.lowercased() {
        case "post":    return "doc.text"
        case "comment": return "text.bubble"
        case "profile": return "person.circle"
        case "story":   return "camera.circle"
        default:        return "questionmark.circle"
        }
    }

    private func statusColor(for status: ModerationStatus) -> Color {
        switch status {
        case .pending:   return .orange
        case .approved:  return .green
        case .rejected:  return .red
        case .escalated: return .yellow
        }
    }

    // MARK: - Actions

    private func loadQueue() async {
        defer { isLoading = false }
        items = (try? await repository.fetchModerationQueue()) ?? []
    }

    private func moderate(item: ModerationItem, status: ModerationStatus) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if let updated = try? await repository.moderateItem(id: item.id, status: status) {
            items[index] = updated
        }
    }
}

#Preview {
    ModerationQueueView()
}

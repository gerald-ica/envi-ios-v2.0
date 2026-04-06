import SwiftUI

struct ContentPlanningSectionView: View {
    @Binding var items: [ContentPlanItem]
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onAdd: () -> Void
    let onEdit: (ContentPlanItem) -> Void
    let onDelete: (ContentPlanItem) -> Void
    let onStatusToggle: (ContentPlanItem) -> Void
    let onMove: (IndexSet, Int) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Header
            HStack {
                Text("CONTENT PLAN")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            }

            if let errorMessage {
                HStack {
                    Text(errorMessage)
                        .font(.interRegular(12))
                        .foregroundColor(.red)
                    Spacer()
                    Button("Retry", action: onRetry)
                        .font(.interMedium(12))
                }
                .padding(.vertical, ENVISpacing.xs)
            }

            // Items list with move support
            ForEach(items.prefix(5)) { item in
                HStack(spacing: ENVISpacing.sm) {
                    Circle()
                        .fill(item.platform.brandColor)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.interMedium(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        Text(scheduleLabel(for: item))
                            .font(.interRegular(11))
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    }

                    Spacer()

                    // Tappable status chip
                    Button {
                        onStatusToggle(item)
                    } label: {
                        Text(item.status.rawValue.uppercased())
                            .font(.spaceMono(9))
                            .foregroundColor(statusColor(for: item.status))
                            .padding(.horizontal, ENVISpacing.sm)
                            .padding(.vertical, 4)
                            .background(statusColor(for: item.status).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, ENVISpacing.xs)
                .contentShape(Rectangle())
                .onTapGesture { onEdit(item) }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        onDelete(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onMove(perform: onMove)
        }
    }

    private func scheduleLabel(for item: ContentPlanItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return "\(item.platform.rawValue) • \(formatter.string(from: item.scheduledAt))"
    }

    private func statusColor(for status: ContentPlanItem.Status) -> Color {
        switch status {
        case .draft: return ENVITheme.textLight(for: colorScheme)
        case .ready: return .green
        case .scheduled: return .blue
        }
    }
}

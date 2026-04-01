import SwiftUI

/// Timeline view showing content organized by date with filter and platform chips.
struct ContentTimelineView: View {
    @StateObject private var dataSource = ContentTimelineDataSource()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            // Status filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(ContentTimelineDataSource.TimelineFilter.allCases, id: \.self) { filter in
                        ENVIChip(
                            title: filter.rawValue,
                            isSelected: dataSource.activeFilter == filter
                        ) {
                            dataSource.setFilter(filter)
                        }
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }

            // Platform filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    // "All Platforms" chip
                    ENVIChip(
                        title: "All",
                        isSelected: dataSource.platformFilter == nil
                    ) {
                        dataSource.setPlatformFilter(nil)
                    }

                    ForEach(SocialPlatform.allCases) { platform in
                        ENVIChip(
                            title: platform.rawValue,
                            isSelected: dataSource.platformFilter == platform
                        ) {
                            dataSource.setPlatformFilter(platform)
                        }
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }

            // Content
            if dataSource.sections.isEmpty {
                ENVIEmptyState(
                    icon: "calendar.badge.clock",
                    title: "No Content",
                    subtitle: "Nothing matches your current filters. Try adjusting the filter or platform selection."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                        ForEach(dataSource.sections) { section in
                            timelineSectionView(section)
                        }
                    }
                    .padding(.bottom, 100) // space for tab bar
                }
            }
        }
    }

    // MARK: - Section

    @ViewBuilder
    private func timelineSectionView(_ section: TimelineSection) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text(section.title)
                .font(.spaceMonoBold(12))
                .tracking(2)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            VStack(spacing: ENVISpacing.xs) {
                ForEach(section.items) { item in
                    timelineRowView(item)
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func timelineRowView(_ item: TimelineItem) -> some View {
        HStack(spacing: ENVISpacing.md) {
            // Thumbnail
            Image(item.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

            // Title + meta
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text(item.title)
                    .font(.interMedium(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)

                HStack(spacing: ENVISpacing.xs) {
                    if let platform = item.platform {
                        Image(systemName: platform.iconName)
                            .font(.system(size: 10))
                            .foregroundColor(platform.brandColor)
                    }

                    Text(item.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                }
            }

            Spacer()

            // Status badge
            statusBadge(for: item.status)
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.vertical, ENVISpacing.sm)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private func statusBadge(for status: TimelineItem.TimelineStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon(for: status))
                .font(.system(size: 10, weight: .semibold))

            Text(status.rawValue.uppercased())
                .font(.spaceMonoBold(9))
                .tracking(1)
        }
        .foregroundColor(statusColor(for: status))
        .padding(.horizontal, ENVISpacing.sm)
        .padding(.vertical, ENVISpacing.xs)
        .background(statusColor(for: status).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    private func statusIcon(for status: TimelineItem.TimelineStatus) -> String {
        switch status {
        case .posted:     return "checkmark.circle.fill"
        case .scheduled:  return "calendar"
        case .draft:      return "pencil"
        case .cameraRoll: return "photo"
        }
    }

    private func statusColor(for status: TimelineItem.TimelineStatus) -> Color {
        switch status {
        case .posted:     return .green
        case .scheduled:  return .blue
        case .draft:      return .gray
        case .cameraRoll: return .orange
        }
    }
}

#Preview {
    ContentTimelineView()
        .preferredColorScheme(.dark)
}

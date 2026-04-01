import Foundation
import Combine

/// Represents an item in the unified content timeline.
struct TimelineItem: Identifiable, Codable {
    let id: String
    let title: String
    let imageName: String
    let date: Date
    let platform: SocialPlatform?
    let status: TimelineStatus
    let source: TimelineSource

    enum TimelineStatus: String, Codable {
        case cameraRoll = "Camera Roll"
        case draft = "Draft"
        case scheduled = "Scheduled"
        case posted = "Posted"
    }

    enum TimelineSource: String, Codable {
        case cameraRoll
        case library
        case scheduled
    }
}

/// Groups timeline items by date section for display.
struct TimelineSection: Identifiable {
    let id: String
    let title: String
    let items: [TimelineItem]
}

/// Unified data source merging camera roll, posted, and scheduled content.
class ContentTimelineDataSource: ObservableObject {
    @Published var sections: [TimelineSection] = []
    @Published var activeFilter: TimelineFilter = .all
    @Published var platformFilter: SocialPlatform? = nil

    private var cancellables = Set<AnyCancellable>()
    private let store = ApprovedMediaLibraryStore.shared

    enum TimelineFilter: String, CaseIterable {
        case cameraRoll = "Camera Roll"
        case posted = "Posted"
        case scheduled = "Scheduled"
        case all = "All"
    }

    init() {
        // Subscribe to store changes and rebuild when approved items change
        store.$approvedItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuild()
            }
            .store(in: &cancellables)

        rebuild()
    }

    func rebuild() {
        var items: [TimelineItem] = []

        // Content pieces from the sample library (treated as "posted")
        if activeFilter == .all || activeFilter == .posted {
            for piece in ContentPiece.pastPieces {
                let platform = mapContentPlatformToSocial(piece.platform)
                items.append(TimelineItem(
                    id: piece.id,
                    title: piece.title,
                    imageName: piece.imageName,
                    date: piece.createdAt,
                    platform: platform,
                    status: .posted,
                    source: .library
                ))
            }
        }

        // Scheduled / future content pieces
        if activeFilter == .all || activeFilter == .scheduled {
            for piece in ContentPiece.futurePieces {
                let platform = mapContentPlatformToSocial(piece.platform)
                items.append(TimelineItem(
                    id: piece.id,
                    title: piece.title,
                    imageName: piece.imageName,
                    date: piece.createdAt,
                    platform: platform,
                    status: .scheduled,
                    source: .scheduled
                ))
            }
        }

        // Approved library items (from For You feed approvals)
        if activeFilter == .all || activeFilter == .posted {
            for libItem in store.approvedItems {
                // Avoid duplicates with content pieces
                guard !items.contains(where: { $0.id == libItem.id }) else { continue }
                items.append(TimelineItem(
                    id: libItem.id,
                    title: libItem.title,
                    imageName: libItem.imageName,
                    date: Date(),
                    platform: nil,
                    status: .posted,
                    source: .library
                ))
            }
        }

        // Filter by platform if set
        if let platform = platformFilter {
            items = items.filter { $0.platform == platform }
        }

        // Sort by date descending
        items.sort { $0.date > $1.date }

        // Group into sections
        sections = groupIntoSections(items)
    }

    private func groupIntoSections(_ items: [TimelineItem]) -> [TimelineSection] {
        let calendar = Calendar.current
        let now = Date()

        var todayItems: [TimelineItem] = []
        var yesterdayItems: [TimelineItem] = []
        var thisWeekItems: [TimelineItem] = []
        var thisMonthItems: [TimelineItem] = []
        var olderItems: [TimelineItem] = []
        var futureItems: [TimelineItem] = []

        for item in items {
            if item.date > now {
                futureItems.append(item)
            } else if calendar.isDateInToday(item.date) {
                todayItems.append(item)
            } else if calendar.isDateInYesterday(item.date) {
                yesterdayItems.append(item)
            } else if calendar.isDate(item.date, equalTo: now, toGranularity: .weekOfYear) {
                thisWeekItems.append(item)
            } else if calendar.isDate(item.date, equalTo: now, toGranularity: .month) {
                thisMonthItems.append(item)
            } else {
                olderItems.append(item)
            }
        }

        var sections: [TimelineSection] = []
        if !futureItems.isEmpty { sections.append(TimelineSection(id: "future", title: "UPCOMING", items: futureItems)) }
        if !todayItems.isEmpty { sections.append(TimelineSection(id: "today", title: "TODAY", items: todayItems)) }
        if !yesterdayItems.isEmpty { sections.append(TimelineSection(id: "yesterday", title: "YESTERDAY", items: yesterdayItems)) }
        if !thisWeekItems.isEmpty { sections.append(TimelineSection(id: "week", title: "THIS WEEK", items: thisWeekItems)) }
        if !thisMonthItems.isEmpty { sections.append(TimelineSection(id: "month", title: "THIS MONTH", items: thisMonthItems)) }
        if !olderItems.isEmpty { sections.append(TimelineSection(id: "older", title: "OLDER", items: olderItems)) }
        return sections
    }

    func setFilter(_ filter: TimelineFilter) {
        activeFilter = filter
        rebuild()
    }

    func setPlatformFilter(_ platform: SocialPlatform?) {
        platformFilter = platform
        rebuild()
    }

    // MARK: - Helpers

    /// Maps ContentPlatform (content piece domain) to SocialPlatform (account domain).
    private func mapContentPlatformToSocial(_ cp: ContentPlatform) -> SocialPlatform {
        switch cp {
        case .instagram: return .instagram
        case .tiktok:    return .tiktok
        case .youtube:   return .youtube
        case .twitter:   return .x
        case .linkedin:  return .linkedin
        }
    }
}

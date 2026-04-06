import Foundation

// MARK: - Search Query

/// Encapsulates a search request with text, filters, and sort criteria.
struct SearchQuery: Codable, Equatable {
    var text: String
    var filters: [SearchFilter]
    var sortBy: SearchSortOption

    init(
        text: String = "",
        filters: [SearchFilter] = [],
        sortBy: SearchSortOption = .relevance
    ) {
        self.text = text
        self.filters = filters
        self.sortBy = sortBy
    }

    /// True when the query carries no meaningful search intent.
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filters.isEmpty
    }
}

// MARK: - Sort Option

enum SearchSortOption: String, Codable, CaseIterable, Identifiable {
    case relevance
    case dateDesc = "date_desc"
    case dateAsc  = "date_asc"
    case engagement
    case alphabetical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .relevance:    return "Relevance"
        case .dateDesc:     return "Newest"
        case .dateAsc:      return "Oldest"
        case .engagement:   return "Engagement"
        case .alphabetical: return "A-Z"
        }
    }
}

// MARK: - Search Result

/// A single item returned by any search endpoint.
struct SearchResult: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let thumbnailURL: URL?
    let platform: String
    let matchType: SearchMatchType
    let relevanceScore: Double
    let publishedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        thumbnailURL: URL? = nil,
        platform: String = "instagram",
        matchType: SearchMatchType = .keyword,
        relevanceScore: Double = 1.0,
        publishedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.platform = platform
        self.matchType = matchType
        self.relevanceScore = relevanceScore
        self.publishedAt = publishedAt
    }
}

// MARK: - Match Type

enum SearchMatchType: String, Codable, CaseIterable {
    case keyword
    case semantic
    case visual
    case tag
    case caption
}

// MARK: - Search Filter

/// A field-operator-value predicate for filtering search results.
struct SearchFilter: Identifiable, Codable, Equatable {
    let id: UUID
    var field: String
    var op: FilterOperator
    var value: String

    init(
        id: UUID = UUID(),
        field: String,
        op: FilterOperator = .equals,
        value: String
    ) {
        self.id = id
        self.field = field
        self.op = op
        self.value = value
    }
}

enum FilterOperator: String, Codable, CaseIterable {
    case equals
    case notEquals   = "not_equals"
    case contains
    case greaterThan = "gt"
    case lessThan    = "lt"
    case between

    var displayName: String {
        switch self {
        case .equals:      return "is"
        case .notEquals:   return "is not"
        case .contains:    return "contains"
        case .greaterThan: return "greater than"
        case .lessThan:    return "less than"
        case .between:     return "between"
        }
    }
}

// MARK: - Saved Search

/// A user-saved search that can optionally trigger alerts on new matches.
struct SavedSearch: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var query: SearchQuery
    var alertEnabled: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        query: SearchQuery = SearchQuery(),
        alertEnabled: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.query = query
        self.alertEnabled = alertEnabled
        self.createdAt = createdAt
    }
}

// MARK: - Search Facet

/// A dimension with bucketed counts (e.g., platform: instagram=42, tiktok=18).
struct SearchFacet: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let values: [String]
    let counts: [Int]

    init(
        id: UUID = UUID(),
        name: String,
        values: [String] = [],
        counts: [Int] = []
    ) {
        self.id = id
        self.name = name
        self.values = values
        self.counts = counts
    }
}

// MARK: - Hidden Gem

/// A resurfaced piece of content that may deserve another look.
struct HiddenGem: Identifiable, Codable, Equatable {
    let id: UUID
    let assetID: UUID
    let title: String
    let thumbnailURL: URL?
    let reason: String
    let lastPublished: Date?

    init(
        id: UUID = UUID(),
        assetID: UUID = UUID(),
        title: String = "",
        thumbnailURL: URL? = nil,
        reason: String = "",
        lastPublished: Date? = nil
    ) {
        self.id = id
        self.assetID = assetID
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.reason = reason
        self.lastPublished = lastPublished
    }
}

// MARK: - Seasonal Resurfacing

/// Content suggested for seasonal re-posting.
struct SeasonalSuggestion: Identifiable, Codable, Equatable {
    let id: UUID
    let assetID: UUID
    let title: String
    let season: String
    let reason: String

    init(
        id: UUID = UUID(),
        assetID: UUID = UUID(),
        title: String = "",
        season: String = "",
        reason: String = ""
    ) {
        self.id = id
        self.assetID = assetID
        self.title = title
        self.season = season
        self.reason = reason
    }
}

// MARK: - Mock Data

extension SearchResult {
    static let mockResults: [SearchResult] = [
        SearchResult(title: "Summer Campaign Reel", platform: "instagram", matchType: .keyword, relevanceScore: 0.95, publishedAt: Date().addingTimeInterval(-86400 * 3)),
        SearchResult(title: "Product Launch Thread", platform: "twitter", matchType: .semantic, relevanceScore: 0.88, publishedAt: Date().addingTimeInterval(-86400 * 7)),
        SearchResult(title: "BTS Photography Set", platform: "tiktok", matchType: .visual, relevanceScore: 0.82, publishedAt: Date().addingTimeInterval(-86400 * 14)),
        SearchResult(title: "Holiday Gift Guide", platform: "youtube", matchType: .tag, relevanceScore: 0.79, publishedAt: Date().addingTimeInterval(-86400 * 30)),
        SearchResult(title: "Brand Story Carousel", platform: "instagram", matchType: .caption, relevanceScore: 0.75, publishedAt: Date().addingTimeInterval(-86400 * 45)),
        SearchResult(title: "Q4 Promo Video", platform: "tiktok", matchType: .keyword, relevanceScore: 0.71, publishedAt: Date().addingTimeInterval(-86400 * 60)),
    ]
}

extension SavedSearch {
    static let mockSavedSearches: [SavedSearch] = [
        SavedSearch(name: "Top Performing Reels", query: SearchQuery(text: "reels engagement:high"), alertEnabled: true, createdAt: Date().addingTimeInterval(-86400 * 10)),
        SavedSearch(name: "Unused B-Roll", query: SearchQuery(text: "b-roll unpublished"), alertEnabled: false, createdAt: Date().addingTimeInterval(-86400 * 20)),
        SavedSearch(name: "Brand Collabs", query: SearchQuery(text: "collaboration partner"), alertEnabled: true, createdAt: Date().addingTimeInterval(-86400 * 5)),
    ]
}

extension SearchFacet {
    static let mockFacets: [SearchFacet] = [
        SearchFacet(name: "Platform", values: ["instagram", "tiktok", "youtube", "twitter"], counts: [42, 28, 15, 11]),
        SearchFacet(name: "Content Type", values: ["image", "video", "carousel", "story"], counts: [35, 30, 18, 13]),
        SearchFacet(name: "Status", values: ["published", "draft", "archived"], counts: [55, 25, 16]),
    ]
}

extension HiddenGem {
    static let mockGems: [HiddenGem] = [
        HiddenGem(title: "Sunset Time-lapse", reason: "90th-percentile engagement but not reposted in 6 months", lastPublished: Date().addingTimeInterval(-86400 * 180)),
        HiddenGem(title: "Behind the Scenes Q&A", reason: "High save-rate among followers; never cross-posted", lastPublished: Date().addingTimeInterval(-86400 * 120)),
        HiddenGem(title: "Tutorial: Quick Edits", reason: "Trending topic match with low competition", lastPublished: Date().addingTimeInterval(-86400 * 90)),
    ]
}

extension SeasonalSuggestion {
    static let mockSeasonal: [SeasonalSuggestion] = [
        SeasonalSuggestion(title: "Valentine's Day Lookbook", season: "Spring", reason: "Performed well last Feb; repost window opening"),
        SeasonalSuggestion(title: "Summer Vibes Playlist", season: "Summer", reason: "Seasonal engagement spike expected"),
    ]
}

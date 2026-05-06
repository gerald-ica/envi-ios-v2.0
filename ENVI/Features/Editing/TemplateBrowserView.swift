import SwiftUI
import SwiftData

// MARK: - Template Browser View
/// Grid-based explorer for all 474 ENVI templates.
/// Filter by format, style, niche, difficulty, platform.
@MainActor
public struct TemplateBrowserView: View {
    @State private var selectedFormat: ContentFormatFilter = .all
    @State private var searchQuery: String = ""
    @State private var selectedStyle: VisualStyle?
    @State private var selectedNiche: ContentNiche?
    @State private var selectedDifficulty: DifficultyFilter = .all
    @State private var showFavoritesOnly: Bool = false
    @State private var templateRegistry: TemplateRegistry = .shared
    @State private var displayedTemplates: [TemplateRegistry.TemplateDefinition] = []
    @State private var isSearching: Bool = false
    @State private var categoryFilter: CategoryFilter = .trending

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(query: $searchQuery, onSearch: performSearch)

                // Format filter tabs
                FormatFilterBar(selected: $selectedFormat)

                // Category pills
                CategoryFilterBar(selected: $categoryFilter)

                // Active filters
                if hasActiveFilters {
                    ActiveFilterBar(
                        format: selectedFormat,
                        style: selectedStyle,
                        niche: selectedNiche,
                        difficulty: selectedDifficulty,
                        onClear: clearFilters
                    )
                }

                // Template grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(displayedTemplates.prefix(50), id: \.id) { template in
                            TemplateCard(template: template)
                                .onTapGesture {
                                    tryTemplate(template)
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showFavoritesOnly.toggle() }) {
                        Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                            .foregroundStyle(showFavoritesOnly ? .red : .primary)
                    }
                }
            }
        }
        .task {
            await loadTemplates()
        }
        .onChange(of: selectedFormat) { _, _ in
            Task { await filterTemplates() }
        }
        .onChange(of: selectedStyle) { _, _ in
            Task { await filterTemplates() }
        }
        .onChange(of: selectedNiche) { _, _ in
            Task { await filterTemplates() }
        }
        .onChange(of: selectedDifficulty) { _, _ in
            Task { await filterTemplates() }
        }
        .onChange(of: searchQuery) { _, _ in
            Task { await filterTemplates() }
        }
    }

    // MARK: - Data Loading

    private func loadTemplates() async {
        let all = await templateRegistry.query(limit: 1000)
        displayedTemplates = all
    }

    private func performSearch() {
        Task { await filterTemplates() }
    }

    private func filterTemplates() async {
        isSearching = true
        defer { isSearching = false }

        let format: ContentFormat? = selectedFormat == .all ? nil : selectedFormat.toContentFormat()
        let style = selectedStyle
        let niche = selectedNiche

        var results = await templateRegistry.query(
            archetypes: nil,
            styles: style.map { [$0] },
            niches: niche.map { [$0] },
            platform: nil,
            maxComplexity: selectedDifficulty.maxComplexity,
            limit: 200
        )

        if let format = format {
            results = results.filter { $0.archetype.format == format }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            results = results.filter {
                $0.metadata?.name.lowercased().contains(query) == true ||
                $0.style.rawValue.lowercased().contains(query) == true ||
                $0.archetype.displayName.lowercased().contains(query) == true ||
                $0.niche.rawValue.lowercased().contains(query) == true
            }
        }

        // Apply category filter
        results = applyCategoryFilter(results)

        await MainActor.run {
            self.displayedTemplates = results
        }
    }

    private func applyCategoryFilter(_ templates: [TemplateRegistry.TemplateDefinition]) -> [TemplateRegistry.TemplateDefinition] {
        switch categoryFilter {
        case .trending:
            // Sort by recency/popularity heuristic
            return templates.sorted { $0.metadata?.name ?? "" > $1.metadata?.name ?? "" }
        case .popular:
            return templates.shuffled() // Placeholder
        case .new:
            return templates.filter { $0.metadata?.isAIGenerated == true }
        case .favorites:
            return templates // Placeholder: filter by user favorites
        case .recentlyUsed:
            return templates // Placeholder: filter by history
        }
    }

    private var hasActiveFilters: Bool {
        selectedFormat != .all || selectedStyle != nil || selectedNiche != nil || selectedDifficulty != .all
    }

    private func clearFilters() {
        selectedFormat = .all
        selectedStyle = nil
        selectedNiche = nil
        selectedDifficulty = .all
    }

    private func tryTemplate(_ template: TemplateRegistry.TemplateDefinition) {
        // Trigger reverse editing flow with this template
        // In production: present pipeline with pre-selected template
    }
}

// MARK: - Filter Types

enum ContentFormatFilter: String, CaseIterable {
    case all = "All"
    case photo = "Photos"
    case video = "Videos"
    case carousel = "Carousels"
    case story = "Stories"
    case newFormat = "New"

    func toContentFormat() -> ContentFormat? {
        switch self {
        case .all: return nil
        case .photo: return .photo
        case .video: return .video
        case .carousel: return .carousel
        case .story: return .story
        case .newFormat: return .newFormat
        }
    }
}

enum DifficultyFilter: String, CaseIterable {
    case all = "All"
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var maxComplexity: Double? {
        switch self {
        case .all: return nil
        case .easy: return 0.3
        case .medium: return 0.6
        case .hard: return 1.0
        }
    }
}

enum CategoryFilter: String, CaseIterable {
    case trending = "Trending"
    case popular = "Popular"
    case new = "New"
    case favorites = "Favorites"
    case recentlyUsed = "Recent"
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var query: String
    let onSearch: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search templates...", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Format Filter Bar

struct FormatFilterBar: View {
    @Binding var selected: ContentFormatFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ContentFormatFilter.allCases, id: \.self) { format in
                    FormatPill(
                        format: format,
                        isSelected: selected == format,
                        action: { selected = format }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct FormatPill: View {
    let format: ContentFormatFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(format.rawValue)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: 0x7A56C4) : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Category Filter Bar

struct CategoryFilterBar: View {
    @Binding var selected: CategoryFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CategoryFilter.allCases, id: \.self) { category in
                    CategoryPill(
                        category: category,
                        isSelected: selected == category,
                        action: { selected = category }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
    }
}

struct CategoryPill: View {
    let category: CategoryFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color(hex: 0x7A56C4).opacity(0.15) : Color.clear)
            .foregroundStyle(isSelected ? Color(hex: 0x7A56C4) : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(hex: 0x7A56C4) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var icon: String {
        switch category {
        case .trending: return "flame"
        case .popular: return "chart.bar"
        case .new: return "sparkles"
        case .favorites: return "heart"
        case .recentlyUsed: return "clock"
        }
    }
}

// MARK: - Active Filter Bar

struct ActiveFilterBar: View {
    let format: ContentFormatFilter
    let style: VisualStyle?
    let niche: ContentNiche?
    let difficulty: DifficultyFilter
    let onClear: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if format != .all {
                    FilterChip(text: format.rawValue, onRemove: onClear)
                }
                if let style = style {
                    FilterChip(text: style.rawValue, onRemove: onClear)
                }
                if let niche = niche {
                    FilterChip(text: niche.rawValue, onRemove: onClear)
                }
                if difficulty != .all {
                    FilterChip(text: difficulty.rawValue, onRemove: onClear)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(hex: 0x7A56C4).opacity(0.1))
        .foregroundStyle(Color(hex: 0x7A56C4))
        .clipShape(Capsule())
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: TemplateRegistry.TemplateDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(systemName: template.archetype.format.iconName)
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                )
                .overlay(
                    // Difficulty badge
                    Alignment(alignment: .topTrailing) {
                        DifficultyBadge(complexity: template.complexityScore)
                    }
                    .padding(8)
                )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(template.metadata?.name ?? template.style.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack {
                    Text(template.archetype.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(template.niche.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                HStack {
                    TagView(text: template.style.family.rawValue, color: .purple)
                    if let ops = template.metadata?.operationsApplied {
                        TagView(text: "\(ops.count) ops", color: .blue)
                    }
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct DifficultyBadge: View {
    let complexity: Double

    var body: some View {
        Text(difficultyLabel)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(difficultyColor.opacity(0.2))
            .foregroundStyle(difficultyColor)
            .clipShape(Capsule())
    }

    private var difficultyLabel: String {
        if complexity < 0.3 { return "Easy" }
        if complexity < 0.6 { return "Med" }
        return "Hard"
    }

    private var difficultyColor: Color {
        if complexity < 0.3 { return .green }
        if complexity < 0.6 { return .orange }
        return .red
    }
}

// MARK: - Preview

#Preview {
    TemplateBrowserView()
}

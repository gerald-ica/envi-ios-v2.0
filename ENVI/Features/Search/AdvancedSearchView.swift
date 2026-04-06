import SwiftUI

/// Full-featured search view with facet sidebar, filter builder, result grid,
/// sort options, and a natural-language query bar.
struct AdvancedSearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSortPicker = false
    @State private var saveSearchName = ""
    @State private var showSaveAlert = false

    var body: some View {
        VStack(spacing: 0) {
            queryBar
            filterChips
            sortBar

            if viewModel.isSearching {
                Spacer()
                ProgressView()
                    .tint(ENVITheme.primary(for: colorScheme))
                Spacer()
            } else if let error = viewModel.errorMessage {
                errorBanner(error)
            } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                emptyState
            } else {
                contentBody
            }
        }
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
        .sheet(isPresented: $viewModel.isShowingFilterBuilder) { filterBuilderSheet }
        .sheet(isPresented: $viewModel.isShowingSavedSearches) {
            SavedSearchesView(viewModel: viewModel)
        }
        .alert("Save Search", isPresented: $showSaveAlert) {
            TextField("Name", text: $saveSearchName)
            Button("Save") {
                viewModel.saveCurrentSearch(name: saveSearchName)
                saveSearchName = ""
            }
            Button("Cancel", role: .cancel) { saveSearchName = "" }
        } message: {
            Text("Give this search a name to find it later.")
        }
    }

    // MARK: - Query Bar

    private var queryBar: some View {
        HStack(spacing: ENVISpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextField("Search or ask a question...", text: $viewModel.query.text)
                .font(.spaceMono(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .submitLabel(.search)
                .onSubmit {
                    viewModel.performSearch()
                }

            if !viewModel.query.text.isEmpty {
                Button {
                    viewModel.query.text = ""
                    viewModel.results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            Menu {
                Button { viewModel.isShowingFilterBuilder = true } label: {
                    Label("Add Filter", systemImage: "line.3.horizontal.decrease")
                }
                Button { viewModel.isShowingSavedSearches = true } label: {
                    Label("Saved Searches", systemImage: "bookmark")
                }
                Button { showSaveAlert = true } label: {
                    Label("Save This Search", systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(ENVITheme.primary(for: colorScheme))
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .padding(.horizontal, ENVISpacing.lg)
        .padding(.top, ENVISpacing.md)
    }

    // MARK: - Filter Chips

    @ViewBuilder
    private var filterChips: some View {
        if !viewModel.activeFilters.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.activeFilters) { filter in
                        filterChip(filter)
                    }

                    Button {
                        viewModel.clearFilters()
                    } label: {
                        Text("Clear All")
                            .font(.spaceMono(10))
                            .foregroundColor(ENVITheme.error)
                    }
                }
                .padding(.horizontal, ENVISpacing.lg)
            }
            .padding(.top, ENVISpacing.sm)
        }
    }

    private func filterChip(_ filter: SearchFilter) -> some View {
        HStack(spacing: ENVISpacing.xs) {
            Text("\(filter.field) \(filter.op.displayName) \(filter.value)")
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Button {
                viewModel.removeFilter(filter)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
        .padding(.horizontal, ENVISpacing.sm)
        .padding(.vertical, ENVISpacing.xs)
        .background(ENVITheme.surfaceHigh(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        HStack {
            if !viewModel.results.isEmpty {
                Text("\(viewModel.results.count) results")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Menu {
                ForEach(SearchSortOption.allCases) { option in
                    Button {
                        viewModel.updateSort(option)
                    } label: {
                        HStack {
                            Text(option.displayName)
                            if viewModel.query.sortBy == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: ENVISpacing.xs) {
                    Text(viewModel.query.sortBy.displayName.uppercased())
                        .font(.spaceMono(10))
                        .tracking(0.5)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
        .padding(.horizontal, ENVISpacing.lg)
        .padding(.vertical, ENVISpacing.sm)
    }

    // MARK: - Content Body (Facets + Results)

    private var contentBody: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.lg) {
                // Facet sidebar (horizontal on mobile)
                if !viewModel.facets.isEmpty {
                    facetSection
                }

                // Result grid
                resultGrid
            }
            .padding(.horizontal, ENVISpacing.lg)
            .padding(.bottom, ENVISpacing.xxxl)
        }
    }

    // MARK: - Facet Section

    private var facetSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("REFINE")
                .font(.spaceMonoBold(10))
                .tracking(0.8)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            ForEach(viewModel.facets) { facet in
                facetRow(facet)
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    private func facetRow(_ facet: SearchFacet) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text(facet.name.uppercased())
                .font(.spaceMono(10))
                .tracking(0.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            FlowLayout(spacing: ENVISpacing.xs) {
                ForEach(Array(zip(facet.values, facet.counts)), id: \.0) { value, count in
                    Button {
                        viewModel.addFilter(field: facet.name, op: .equals, value: value)
                    } label: {
                        HStack(spacing: ENVISpacing.xs) {
                            Text(value)
                                .font(.spaceMono(10))
                            Text("\(count)")
                                .font(.spaceMono(9))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        }
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, ENVISpacing.xs)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Result Grid

    private var resultGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: ENVISpacing.sm),
                GridItem(.flexible(), spacing: ENVISpacing.sm)
            ],
            spacing: ENVISpacing.sm
        ) {
            ForEach(viewModel.results) { result in
                resultCard(result)
            }
        }
    }

    private func resultCard(_ result: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: ENVIRadius.md)
                .fill(ENVITheme.surfaceHigh(for: colorScheme))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(systemName: iconForPlatform(result.platform))
                        .font(.system(size: 24))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                )

            Text(result.title)
                .font(.spaceMonoBold(12))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(2)

            HStack(spacing: ENVISpacing.xs) {
                Text(result.matchType.rawValue.uppercased())
                    .font(.spaceMono(9))
                    .tracking(0.3)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xs)
                    .padding(.vertical, 2)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                Text(String(format: "%.0f%%", result.relevanceScore * 100))
                    .font(.spaceMono(9))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
        .padding(ENVISpacing.sm)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Filter Builder Sheet

    private var filterBuilderSheet: some View {
        FilterBuilderView(onAdd: { field, op, value in
            viewModel.addFilter(field: field, op: op, value: value)
            viewModel.isShowingFilterBuilder = false
        }, onDismiss: {
            viewModel.isShowingFilterBuilder = false
        })
    }

    // MARK: - Empty / Error States

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.lg) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Text("No results found")
                .font(.spaceMonoBold(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
            Text("Try different keywords or remove some filters.")
                .font(.spaceMono(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(ENVISpacing.lg)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.spaceMono(12))
                .foregroundColor(ENVITheme.error)
                .padding(ENVISpacing.md)
                .frame(maxWidth: .infinity)
                .background(ENVITheme.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .padding(.horizontal, ENVISpacing.lg)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func iconForPlatform(_ platform: String) -> String {
        switch platform.lowercased() {
        case "instagram": return "camera"
        case "tiktok":    return "play.rectangle"
        case "youtube":   return "play.circle"
        case "twitter":   return "bubble.left"
        default:          return "photo"
        }
    }
}

// MARK: - Flow Layout (simple horizontal wrap)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for row in rows {
            height += row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        }
        height += CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

// MARK: - Filter Builder View

private struct FilterBuilderView: View {
    let onAdd: (String, FilterOperator, String) -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var field = "platform"
    @State private var op: FilterOperator = .equals
    @State private var value = ""

    private let fields = ["platform", "content_type", "status", "engagement", "date", "tag"]

    var body: some View {
        NavigationView {
            VStack(spacing: ENVISpacing.lg) {
                // Field
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    Text("FIELD")
                        .font(.spaceMonoBold(10))
                        .tracking(0.8)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    Picker("Field", selection: $field) {
                        ForEach(fields, id: \.self) { f in
                            Text(f).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Operator
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    Text("CONDITION")
                        .font(.spaceMonoBold(10))
                        .tracking(0.8)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    Picker("Operator", selection: $op) {
                        ForEach(FilterOperator.allCases, id: \.self) { o in
                            Text(o.displayName).tag(o)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Value
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    Text("VALUE")
                        .font(.spaceMonoBold(10))
                        .tracking(0.8)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    TextField("Enter value", text: $value)
                        .font(.spaceMono(14))
                        .padding(ENVISpacing.md)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                }

                Spacer()

                Button {
                    guard !value.isEmpty else { return }
                    onAdd(field, op, value)
                } label: {
                    Text("ADD FILTER")
                        .font(.spaceMonoBold(13))
                        .tracking(0.5)
                        .frame(maxWidth: .infinity)
                        .padding(ENVISpacing.md)
                        .background(ENVITheme.primary(for: colorScheme))
                        .foregroundColor(ENVITheme.background(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                }
            }
            .padding(ENVISpacing.lg)
            .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Add Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }
}

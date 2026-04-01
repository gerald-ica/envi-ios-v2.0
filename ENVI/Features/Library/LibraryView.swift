import SwiftUI

/// Main library screen with filter chips, template carousel, and masonry grid.
struct LibraryView: View {
    enum ViewMode: String {
        case grid, timeline
    }

    @StateObject private var viewModel = LibraryViewModel()
    @State private var showAddFlowAlert = false
    @State private var searchText = ""
    @State private var selectedItem: LibraryItem?
    @State private var viewMode: ViewMode = .grid
    @Environment(\.colorScheme) private var colorScheme

    private var searchFilteredItems: [LibraryItem] {
        let items = viewModel.filteredItems
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    // Title + view mode toggle
                    HStack {
                        Text("LIBRARY")
                            .font(.spaceMonoBold(28))
                            .tracking(-1.5)
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewMode = viewMode == .grid ? .timeline : .grid
                            }
                        } label: {
                            Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                                .frame(width: 36, height: 36)
                                .background(ENVITheme.surfaceLow(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        }
                    }
                    .padding(.horizontal, ENVISpacing.xl)

                    if viewMode == .timeline {
                        // Timeline view
                        ContentTimelineView()
                    } else {
                        // Search bar
                        HStack(spacing: ENVISpacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                            TextField("Search library...", text: $searchText)
                                .font(.interRegular(15))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(ENVITheme.textLight(for: colorScheme))
                                }
                            }
                        }
                        .padding(.horizontal, ENVISpacing.lg)
                        .padding(.vertical, ENVISpacing.md)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                        .padding(.horizontal, ENVISpacing.xl)

                        // Filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: ENVISpacing.sm) {
                                ForEach(LibraryViewModel.FilterType.allCases, id: \.self) { filter in
                                    ENVIChip(
                                        title: filter.rawValue,
                                        isSelected: viewModel.selectedFilter == filter
                                    ) {
                                        viewModel.selectedFilter = filter
                                    }
                                }
                            }
                            .padding(.horizontal, ENVISpacing.xl)
                        }

                        if searchFilteredItems.isEmpty {
                            ENVIEmptyState(
                                icon: "photo.on.rectangle",
                                title: "No Content Yet",
                                subtitle: "Import photos and videos to build your content library"
                            )
                        } else {
                            // Templates
                            TemplateCarousel(templates: viewModel.templates)

                            // Masonry grid
                            MasonryGridView(items: searchFilteredItems, onTap: { item in
                                selectedItem = item
                            })
                            .padding(.horizontal, ENVISpacing.xl)
                        }
                    }
                }
                .padding(.top, ENVISpacing.lg)
                .padding(.bottom, 100) // space for tab bar
            }
            .refreshable {
                // Trigger a refresh of library items
                await Task.yield()
            }

            // FAB
            Button(action: { showAddFlowAlert = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 56, height: 56)
                    .background(Color.white)
                    .clipShape(Circle())
                    .enviElevatedShadow()
            }
            .padding(.trailing, ENVISpacing.xl)
            .padding(.bottom, 90)
        }
        .background(ENVITheme.background(for: colorScheme))
        .alert("Add to Library", isPresented: $showAddFlowAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Import and create flows are not wired yet. This should open a real add/import sheet in the next pass.")
        }
        .sheet(item: $selectedItem) { item in
            LibraryDetailView(item: item, allItems: viewModel.filteredItems)
        }
    }
}

#Preview {
    LibraryView()
        .preferredColorScheme(.dark)
}

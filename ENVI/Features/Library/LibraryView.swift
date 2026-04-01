import SwiftUI

/// Main library screen with filter chips, template carousel, and masonry grid.
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showAddSheet = false
    @State private var searchText = ""
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
                    // Title
                    Text("LIBRARY")
                        .font(.spaceMonoBold(28))
                        .tracking(-1.5)
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.xl)

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

                    // Filter chips (animated on selection change)
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
                    .animation(.easeInOut, value: viewModel.selectedFilter)

                    if searchFilteredItems.isEmpty && viewModel.templates.isEmpty {
                        ENVIEmptyState(
                            icon: "photo.on.rectangle",
                            title: "No Content Yet",
                            subtitle: "Approve content from your For You feed to build your library"
                        )
                    } else {
                        // Templates
                        TemplateCarousel(templates: viewModel.templates)

                        // Masonry grid
                        MasonryGridView(items: searchFilteredItems)
                            .padding(.horizontal, ENVISpacing.xl)
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
            Button(action: { showAddSheet = true }) {
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
        .confirmationDialog("Add to Library", isPresented: $showAddSheet, titleVisibility: .visible) {
            Button {
                // TODO: Wire up photo picker
            } label: {
                Label("Photos", systemImage: "photo.on.rectangle")
            }
            Button {
                // TODO: Wire up camera capture
            } label: {
                Label("Camera", systemImage: "camera")
            }
            Button {
                // TODO: Wire up file import
            } label: {
                Label("Files", systemImage: "folder")
            }
            Button {
                // TODO: Wire up template browser
            } label: {
                Label("Templates", systemImage: "doc.text")
            }
            Button {
                // TODO: Wire up save template flow
            } label: {
                Label("Save Template", systemImage: "square.and.arrow.down")
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

#Preview {
    LibraryView()
        .preferredColorScheme(.dark)
}

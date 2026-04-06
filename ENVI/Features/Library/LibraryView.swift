import SwiftUI

/// Main library screen with filter chips, template carousel, and masonry grid.
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showAddFlowAlert = false
    @Environment(\.colorScheme) private var colorScheme

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

                    // Search
                    HStack(spacing: ENVISpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        TextField("Search library", text: $viewModel.searchQuery)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    .padding(.horizontal, ENVISpacing.xl)

                    // Templates
                    TemplateCarousel(templates: viewModel.templates)

                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading library...")
                                .font(.interRegular(13))
                                .foregroundColor(ENVITheme.textLight(for: colorScheme))
                        }
                        .padding(.horizontal, ENVISpacing.xl)
                    }

                    if let error = viewModel.loadErrorMessage {
                        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                            Text(error)
                                .font(.interMedium(13))
                                .foregroundColor(.red)
                            Button("Retry") {
                                Task { await viewModel.reloadLibrary() }
                            }
                            .font(.interMedium(13))
                        }
                        .padding(.horizontal, ENVISpacing.xl)
                    }

                    // Masonry grid
                    MasonryGridView(items: viewModel.filteredItems)
                        .padding(.horizontal, ENVISpacing.xl)
                }
                .padding(.top, ENVISpacing.lg)
                .padding(.bottom, 100) // space for tab bar
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
    }
}

#Preview {
    LibraryView()
        .preferredColorScheme(.dark)
}

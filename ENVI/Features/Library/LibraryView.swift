import SwiftUI

/// Main library screen with filter chips, template carousel, and masonry grid.
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    // Title
                    Text("Library")
                        .font(.interBlack(28))
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

                    // Templates
                    TemplateCarousel(templates: viewModel.templates)

                    // Masonry grid
                    MasonryGridView(items: viewModel.filteredItems)
                        .padding(.horizontal, ENVISpacing.xl)
                }
                .padding(.top, ENVISpacing.lg)
                .padding(.bottom, 100) // space for tab bar
            }

            // FAB
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(ENVITheme.primary(for: colorScheme))
                    .clipShape(Circle())
                    .enviElevatedShadow()
            }
            .padding(.trailing, ENVISpacing.xl)
            .padding(.bottom, 90)
        }
        .background(ENVITheme.background(for: colorScheme))
    }
}

#Preview {
    LibraryView()
        .preferredColorScheme(.dark)
}

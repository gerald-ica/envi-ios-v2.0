import SwiftUI

/// Masonry grid view for the "Gallery" segment — the Social Media Arsenal.
///
/// Shows approved content in a 2-column masonry layout with a search bar
/// and a FAB (+) button for creating new content.
struct GalleryGridView: View {

    @ObservedObject var viewModel: ForYouGalleryViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showMediaPicker = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                    // Search bar
                    searchBar

                    // Section header
                    Text("SOCIAL MEDIA ARSENAL")
                        .font(.spaceMonoBold(13))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, ENVISpacing.xl)

                    // Grid
                    if viewModel.filteredGalleryItems.isEmpty {
                        galleryEmptyState
                    } else {
                        galleryMasonryGrid
                            .padding(.horizontal, ENVISpacing.xl)
                    }
                }
                .padding(.top, ENVISpacing.lg)
                .padding(.bottom, 100) // Space for tab bar
            }

            // FAB
            fabButton
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: ENVISpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
            TextField("Search arsenal", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundColor(.white)
        }
        .padding(.horizontal, ENVISpacing.md)
        .padding(.vertical, ENVISpacing.sm)
        .background(ENVITheme.Dark.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Masonry Grid

    private var galleryMasonryGrid: some View {
        let items = viewModel.filteredGalleryItems
        let columns = distributeColumns(items)

        return HStack(alignment: .top, spacing: ENVISpacing.md) {
            ForEach(0..<2, id: \.self) { colIndex in
                LazyVStack(spacing: ENVISpacing.md) {
                    ForEach(columns[colIndex]) { item in
                        GalleryItemView(item: item)
                    }
                }
            }
        }
    }

    private func distributeColumns(_ items: [LibraryItem]) -> [[LibraryItem]] {
        var col1: [LibraryItem] = []
        var col2: [LibraryItem] = []
        var height1: CGFloat = 0
        var height2: CGFloat = 0

        for item in items {
            if height1 <= height2 {
                col1.append(item)
                height1 += item.height
            } else {
                col2.append(item)
                height2 += item.height
            }
        }
        return [col1, col2]
    }

    // MARK: - Empty State

    private var galleryEmptyState: some View {
        VStack(spacing: ENVISpacing.lg) {
            Spacer().frame(height: 80)

            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.2))

            Text("Your Social Media Arsenal is empty")
                .font(.interMedium(15))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Text("Swipe right on content in For You to approve it here")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ENVISpacing.xxxl)
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            showMediaPicker = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 56, height: 56)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.trailing, ENVISpacing.xl)
        .padding(.bottom, 90)
        .sheet(isPresented: $showMediaPicker) {
            MediaPickerView { assetIdentifiers in
                guard !assetIdentifiers.isEmpty else { return }
                ContentPieceAssembler.shared.enqueueForAssembly(mediaIDs: assetIdentifiers)
            }
        }
    }
}

// MARK: - Gallery Item View

private struct GalleryItemView: View {
    let item: LibraryItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(item.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: item.height)
                .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            Text(item.title.uppercased())
                .font(.spaceMonoBold(11))
                .tracking(1.5)
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(ENVISpacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
    }
}

import SwiftUI

/// Masonry grid view for the "Gallery" segment — the Social Media Arsenal.
///
/// Shows approved content in a 2-column masonry layout with saved
/// template treatment and a floating add button.
struct GalleryGridView: View {

    @ObservedObject var viewModel: ForYouGalleryViewModel
    @State private var showMediaPicker = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: ENVISpacing.xl) {
                    searchBar
                        .padding(.top, ENVISpacing.sm)

                    savedTemplatesSection

                    sectionHeader(
                        title: "SOCIAL MEDIA ARSENAL",
                        subtitle: "Approved content ready for reuse and remixing."
                    )

                    if viewModel.filteredGalleryItems.isEmpty {
                        galleryEmptyState
                            .padding(.top, ENVISpacing.sm)
                    } else {
                        galleryMasonryGrid
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
                .padding(.bottom, 136)
            }

            fabButton
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        MainAppSearchBar(
            placeholder: "Try \"OOTD short form\"",
            text: $viewModel.searchQuery
        )
    }

    // MARK: - Saved Templates

    private var savedTemplatesSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionHeader(
                title: "SAVED TEMPLATES",
                subtitle: "Quick-start formats pulled from the current library."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.md) {
                    ForEach(TemplateItem.mockTemplates) { template in
                        TemplateRailCard(template: template)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.spaceMonoBold(12))
                .tracking(1.7)
                .foregroundColor(.white.opacity(0.5))

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.interRegular(13))
                    .foregroundColor(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
            Spacer().frame(height: 48)

            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.2))

            Text("Your Social Media Arsenal is empty")
                .font(.spaceMonoBold(15))
                .tracking(0.6)
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)

            Text("Swipe right on content in For You to approve it here.")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.38))
                .multilineTextAlignment(.center)

            Spacer().frame(height: 32)
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
                .shadow(color: .black.opacity(0.34), radius: 10, y: 4)
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

            LinearGradient(
                colors: [.clear, .black.opacity(0.66)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(item.type.rawValue.uppercased())
                    .font(.spaceMonoBold(9))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.72))

                Text(item.title.uppercased())
                    .font(.spaceMonoBold(11))
                    .tracking(1.4)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(ENVISpacing.md)
        }
        .frame(maxWidth: .infinity)
        .background(ENVITheme.Dark.surfaceLow.opacity(0.9))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - Template Rail Card

private struct TemplateRailCard: View {
    let template: TemplateItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(template.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 188, height: 132)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.74)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(template.category.uppercased())
                    .font(.spaceMonoBold(9))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.7))

                Text(template.title.uppercased())
                    .font(.spaceMonoBold(12))
                    .tracking(1.3)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(template.captionTemplate)
                    .font(.interRegular(11))
                    .foregroundColor(.white.opacity(0.64))
                    .lineLimit(2)
            }
            .padding(ENVISpacing.md)
        }
        .frame(width: 188, height: 132)
        .background(ENVITheme.Dark.surfaceLow.opacity(0.9))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

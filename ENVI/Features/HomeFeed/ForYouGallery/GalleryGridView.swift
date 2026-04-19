import SwiftUI

/// Gallery grid — Sketch artboard "10 - Gallery page" (402×874).
///
/// Sections (top to bottom):
///  - Search pill (placeholder `Try "OOTD short form"`)
///  - SAVED TEMPLATES — horizontal row of compact 122×205 template cards
///  - SOCIAL MEDIA ARSENAL — 2-column masonry of approved content
///  - Floating round "+" FAB (bottom-right, 56×56) opens MediaPickerView
///    which enqueues media for `ContentPieceAssembler`.
struct GalleryGridView: View {

    @ObservedObject var viewModel: ForYouGalleryViewModel
    @State private var showMediaPicker = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 28) {
                    searchBar
                        .padding(.top, 6)

                    savedTemplatesSection

                    arsenalHeader

                    if viewModel.filteredGalleryItems.isEmpty {
                        galleryEmptyState
                            .padding(.top, ENVISpacing.sm)
                    } else {
                        galleryMasonryGrid
                            // Extra horizontal inset on the masonry only so
                            // Social Media Arsenal tiles read as narrower
                            // cards inside the section, while the section
                            // headers and saved-template rail keep their
                            // 16pt gutter flush to the rest of the feed.
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 160)
            }
            .refreshable {
                await viewModel.refreshGallery()
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

    // MARK: - Saved Templates — horizontal row of compact cards

    private var savedTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "SAVED TEMPLATES",
                subtitle: "Template suggestions now come from your approved content."
            )

            // Sketch layout: 3 saved-template cards, 122×205 each, 8pt gutter.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(savedTemplatePreviews) { template in
                        savedTemplateCard(template: template)
                    }
                }
            }
        }
    }

    /// Saved templates rail — up to 3 tiles. Prefers the user's own approved
    /// pieces; backfills from live camera-roll suggestions so the rail always
    /// shows real content whenever the library has ANY media reachable.
    /// Ghost placeholders only render as a last resort when BOTH approved
    /// items and camera-roll suggestions are empty (no photo-library access,
    /// or an empty device).
    private var savedTemplatePreviews: [SavedTemplatePreview] {
        let items = viewModel.savedTemplatePreviewItems
        if items.isEmpty {
            return makePlaceholderPreviews()
        }

        let approvedIDs = Set(viewModel.galleryItems.map(\.id))

        return items.map { item in
            let isApproved = approvedIDs.contains(item.id)
            let subtitle = isApproved
                ? "APPROVED · \(item.type.rawValue.uppercased())"
                : "FROM YOUR ROLL · \(item.type.rawValue.uppercased())"
            return SavedTemplatePreview(
                id: item.id,
                title: item.title,
                subtitle: subtitle,
                imageName: item.imageName,
                assetLocalIdentifier: item.assetLocalIdentifier,
                isPlaceholder: false
            )
        }
    }

    private func makePlaceholderPreviews() -> [SavedTemplatePreview] {
        (0..<3).map { index in
            SavedTemplatePreview(
                id: "placeholder-\(index)",
                title: "Grant photos access",
                subtitle: "Unlock suggestions",
                imageName: nil,
                assetLocalIdentifier: nil,
                isPlaceholder: true
            )
        }
    }

    private func savedTemplateCard(template: SavedTemplatePreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image area — 122×164, radius 10.
            ZStack {
                if !template.isPlaceholder {
                    if let assetID = template.assetLocalIdentifier {
                        ForYouAssetThumbnailView(
                            assetLocalIdentifier: assetID,
                            fallbackImageName: template.imageName,
                            contentMode: .fill
                        )
                    } else if let imageName = template.imageName {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                } else {
                    LinearGradient(
                        colors: [
                            Color(hex: "#3E3E3E"),
                            Color(hex: "#232223")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.18))
                }
            }
            .frame(width: 122, height: 164)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            // Two-line label stack beneath the thumbnail.
            VStack(alignment: .leading, spacing: 2) {
                Text(template.title.uppercased())
                    .font(.spaceMonoBold(10))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                Text(template.subtitle)
                    .font(.interRegular(10))
                    .foregroundColor(.white.opacity(0.46))
                    .lineLimit(1)
            }
        }
        .frame(width: 122, height: 205, alignment: .topLeading)
    }

    // MARK: - Section Headers

    private var arsenalHeader: some View {
        sectionHeader(
            title: "SOCIAL MEDIA ARSENAL",
            subtitle: "Approved content ready for reuse and remixing."
        )
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.spaceMonoBold(12))
                .tracking(1.7)
                .foregroundColor(.white.opacity(0.55))

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.interRegular(13))
                    .foregroundColor(.white.opacity(0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Masonry Grid

    private var galleryMasonryGrid: some View {
        let items = viewModel.filteredGalleryItems
        let columns = distributeColumns(items)

        // Slightly wider column gutter (14) so the two tile stacks read as
        // distinctly separate cards rather than a flush 2-up grid.
        return HStack(alignment: .top, spacing: 14) {
            ForEach(0..<2, id: \.self) { colIndex in
                LazyVStack(spacing: 14) {
                    ForEach(columns[colIndex]) { item in
                        GalleryItemView(item: item)
                    }
                }
                .frame(maxWidth: .infinity)
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
        VStack(spacing: 16) {
            Spacer().frame(height: 36)

            Image(systemName: "photo.stack")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.22))

            Text("Your Social Media Arsenal is empty")
                .font(.spaceMonoBold(14))
                .tracking(0.6)
                .foregroundColor(.white.opacity(0.58))
                .multilineTextAlignment(.center)

            Text("Enable photos access in Settings or swipe right on For You content to fill your arsenal.")
                .font(.interRegular(13))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)

            Spacer().frame(height: 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ENVISpacing.xxxl)
    }

    // MARK: - FAB

    /// Upload FAB — Sketch spec: 56×56 circular glass pill with the custom
    /// `+ icon.png` bitmap (rendered as white template) centered on top of a
    /// translucent blurred base. Matches the `ENVITabBar` aesthetic so the
    /// upload action reads as part of the same floating chrome family.
    private var fabButton: some View {
        Button {
            showMediaPicker = true
        } label: {
            ZStack {
                // Glass base: blur + subtle white tint + 1pt white rim.
                Circle()
                    .fill(.ultraThinMaterial)
                Circle()
                    .fill(Color.white.opacity(0.12))
                Circle()
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                // Inner top highlight — mimics the luminous aura on the tab pill.
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .rotationEffect(.degrees(180))
                    .padding(1)

                Image("plus-icon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)
            .shadow(color: .black.opacity(0.42), radius: 14, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100)
        .sheet(isPresented: $showMediaPicker) {
            MediaPickerView { assetIdentifiers in
                guard !assetIdentifiers.isEmpty else { return }
                ContentPieceAssembler.shared.enqueueForAssembly(mediaIDs: assetIdentifiers)
            }
        }
    }
}

// MARK: - Saved Template Preview Model

private struct SavedTemplatePreview: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let imageName: String?
    let assetLocalIdentifier: String?
    let isPlaceholder: Bool
}

// MARK: - Gallery Item View

private struct GalleryItemView: View {
    let item: LibraryItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image fills the cell's full width. Without an explicit max-width
            // + clipped() the .aspectRatio(.fill) image can resolve wider than
            // the column and push past the 18pt clip, which is what was
            // causing tiles to bleed past the Social Media Arsenal borders.
            Group {
                if let assetID = item.assetLocalIdentifier {
                    ForYouAssetThumbnailView(
                        assetLocalIdentifier: assetID,
                        fallbackImageName: item.imageName,
                        contentMode: .fill
                    )
                } else {
                    Image(item.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.type.rawValue.uppercased())
                    .font(.spaceMonoBold(9))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.72))

                Text(item.title.uppercased())
                    .font(.spaceMonoBold(11))
                    .tracking(1.2)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: item.height)
        .background(Color(hex: "#3E3E3E").opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

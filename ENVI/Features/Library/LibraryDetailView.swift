import SwiftUI

/// Full-screen detail view for a library item.
/// Shows rich content preview with Schedule Post and Edit Further CTAs.
struct LibraryDetailView: View {
    let item: LibraryItem
    let allItems: [LibraryItem] // For swipe navigation
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showExportSheet = false
    @State private var showEditor = false
    @State private var currentIndex: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                    // Hero Image
                    heroImage

                    // Metadata Bar
                    metadataBar

                    // Info Section
                    infoSection

                    Spacer(minLength: ENVISpacing.xxl)
                }
            }
            .background(ENVITheme.background(for: colorScheme))
            .safeAreaInset(edge: .bottom) {
                ctaButtons
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("CONTENT DETAIL")
                        .font(.spaceMonoBold(14))
                        .tracking(2.0)
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportSheetView(composer: ExportComposerFactory.make(contentItem: nil, contentPiece: nil))
            }
            .fullScreenCover(isPresented: $showEditor) {
                EditorContainerView(contentPiece: ContentPiece(
                    id: item.id,
                    title: item.title,
                    type: item.type == .videos ? .video : .photo,
                    platform: .instagram,
                    description: item.bodyText ?? "",
                    aiScore: item.aiScore ?? 70,
                    createdAt: Date(),
                    tags: [],
                    metrics: nil,
                    aiSuggestion: nil,
                    imageName: item.imageName,
                    source: .contentLibrary
                ))
            }
        }
    }

    // MARK: - Hero Image
    private var heroImage: some View {
        ZStack(alignment: .topTrailing) {
            Image(item.imageName)
                .resizable()
                .aspectRatio(4 / 5, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()

            // Type badge
            HStack(spacing: 4) {
                Image(systemName: item.type == .videos ? "video.fill" : "photo.fill")
                    .font(.system(size: 10))
                Text(item.type.rawValue.uppercased())
                    .font(.spaceMonoBold(10))
                    .tracking(1.0)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            .padding(ENVISpacing.md)
        }
    }

    // MARK: - Metadata Bar
    private var metadataBar: some View {
        HStack(spacing: ENVISpacing.md) {
            Text(item.title.uppercased())
                .font(.spaceMonoBold(16))
                .tracking(1.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Spacer()

            Text(item.type.rawValue)
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.lg)
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("DETAILS")
                .font(.spaceMonoBold(11))
                .tracking(2.0)
                .foregroundColor(ENVITheme.textLight(for: colorScheme))

            HStack {
                Label(item.type.rawValue, systemImage: "doc.fill")
                Spacer()
                Label(item.imageName, systemImage: "photo")
            }
            .font(.interRegular(14))
            .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .padding(.horizontal, ENVISpacing.lg)
    }

    // MARK: - CTA Buttons
    private var ctaButtons: some View {
        HStack(spacing: ENVISpacing.md) {
            Button {
                showExportSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                    Text("SCHEDULE POST")
                        .font(.spaceMonoBold(13))
                        .tracking(1.0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ENVITheme.primary(for: colorScheme))
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            }

            Button {
                showEditor = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("EDIT")
                        .font(.spaceMonoBold(13))
                        .tracking(1.0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ENVITheme.surfaceHigh(for: colorScheme))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            }
        }
        .padding(.horizontal, ENVISpacing.lg)
        .padding(.vertical, ENVISpacing.md)
        .background(.ultraThinMaterial)
    }
}

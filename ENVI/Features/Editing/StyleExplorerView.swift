import SwiftUI
import PhotosUI

// MARK: - Style Explorer View
/// Browse 406 visual styles by family with live preview capability.
@MainActor
public struct StyleExplorerView: View {
    @State private var selectedFamily: VisualStyleFamily = .CleanAndMinimal
    @State private var selectedStyle: VisualStyle?
    @State private var sampleImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var isProcessing: Bool = false
    @State private var showBeforeAfter: Bool = false
    @State private var beforeAfterPosition: CGFloat = 0.5
    @State private var favoriteStyles: Set<String> = []
    @State private var trendingStyles: [VisualStyle] = []
    @State private var showPhotoPicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let families = VisualStyleFamily.allCases

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Family selector
                FamilyScrollBar(selected: $selectedFamily)

                // Sample photo area
                SamplePhotoArea(
                    image: sampleImage,
                    processedImage: processedImage,
                    isProcessing: isProcessing,
                    showBeforeAfter: $showBeforeAfter,
                    beforeAfterPosition: $beforeAfterPosition,
                    onSelectPhoto: { showPhotoPicker = true }
                )

                // Style grid for selected family
                StyleGrid(
                    family: selectedFamily,
                    selectedStyle: $selectedStyle,
                    favoriteStyles: $favoriteStyles,
                    trendingStyles: trendingStyles,
                    onStyleTap: applyStyle
                )
            }
            .navigationTitle("Style Explorer")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showBeforeAfter.toggle() }) {
                        Image(systemName: showBeforeAfter ? "slider.horizontal.below.rectangle" : "slider.horizontal.below.rectangle")
                            .foregroundStyle(showBeforeAfter ? Color(hex: 0x7A56C4) : .primary)
                    }
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task { await loadPhoto(from: newItem) }
            }
            .task {
                await loadTrendingStyles()
            }
        }
    }

    // MARK: - Actions

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        await MainActor.run {
            self.sampleImage = image
            self.processedImage = nil
        }
    }

    private func applyStyle(_ style: VisualStyle) async {
        guard sampleImage != nil else { return }

        await MainActor.run {
            selectedStyle = style
            isProcessing = true
        }

        // Simulate processing delay
        try? await Task.sleep(for: .milliseconds(300))

        // In production: apply style via CoreImage filter chain or Metal kernel
        await MainActor.run {
            processedImage = sampleImage // Placeholder
            isProcessing = false
        }
    }

    private func loadTrendingStyles() async {
        // In production: fetch from analytics service
        trendingStyles = Array(VisualStyle.allCases.prefix(20))
    }

    private func toggleFavorite(_ style: VisualStyle) {
        if favoriteStyles.contains(style.rawValue) {
            favoriteStyles.remove(style.rawValue)
        } else {
            favoriteStyles.insert(style.rawValue)
        }
    }
}

// MARK: - Family Scroll Bar

struct FamilyScrollBar: View {
    @Binding var selected: VisualStyleFamily

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(VisualStyleFamily.allCases, id: \.self) { family in
                    FamilyPill(
                        family: family,
                        isSelected: selected == family,
                        action: { selected = family }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct FamilyPill: View {
    let family: VisualStyleFamily
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(family.displayName)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: 0x7A56C4) : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Sample Photo Area

struct SamplePhotoArea: View {
    let image: UIImage?
    let processedImage: UIImage?
    let isProcessing: Bool
    @Binding var showBeforeAfter: Bool
    @Binding var beforeAfterPosition: CGFloat
    let onSelectPhoto: () -> Void

    var body: some View {
        ZStack {
            if let image = image {
                if showBeforeAfter, let processed = processedImage {
                    BeforeAfterView(
                        before: image,
                        after: processed,
                        position: $beforeAfterPosition
                    )
                } else if let processed = processedImage {
                    Image(uiImage: processed)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Tap to select a photo")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Preview any style on your own image")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if isProcessing {
                ProcessingOverlay()
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
        .onTapGesture {
            if image == nil {
                onSelectPhoto()
            }
        }
    }
}

// MARK: - Before/After View

struct BeforeAfterView: View {
    let before: UIImage
    let after: UIImage
    @Binding var position: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: before)
                    .resizable()
                    .aspectRatio(contentMode: .fill)

                Image(uiImage: after)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .mask(
                        HStack {
                            Rectangle()
                                .frame(width: geometry.size.width * position)
                            Spacer(minLength: 0)
                        }
                    )

                // Slider line
                Rectangle()
                    .fill(.white)
                    .frame(width: 2)
                    .offset(x: geometry.size.width * position - geometry.size.width / 2)

                // Slider handle
                Circle()
                    .fill(.white)
                    .frame(width: 32, height: 32)
                    .shadow(radius: 4)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.black)
                    )
                    .offset(x: geometry.size.width * position - geometry.size.width / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPosition = value.location.x / geometry.size.width
                                position = max(0, min(1, newPosition))
                            }
                    )
            }
        }
    }
}

// MARK: - Processing Overlay

struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Applying style...")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Style Grid

struct StyleGrid: View {
    let family: VisualStyleFamily
    @Binding var selectedStyle: VisualStyle?
    @Binding var favoriteStyles: Set<String>
    let trendingStyles: [VisualStyle]
    let onStyleTap: (VisualStyle) async -> Void

    private var stylesInFamily: [VisualStyle] {
        VisualStyle.allCases.filter { $0.family == family }
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(stylesInFamily, id: \.self) { style in
                    StyleCell(
                        style: style,
                        isSelected: selectedStyle == style,
                        isFavorite: favoriteStyles.contains(style.rawValue),
                        isTrending: trendingStyles.contains(style),
                        onTap: { Task { await onStyleTap(style) } },
                        onFavoriteToggle: { toggleFavorite(style) }
                    )
                }
            }
            .padding()
        }
    }

    private func toggleFavorite(_ style: VisualStyle) {
        if favoriteStyles.contains(style.rawValue) {
            favoriteStyles.remove(style.rawValue)
        } else {
            favoriteStyles.insert(style.rawValue)
        }
    }
}

// MARK: - Style Cell

struct StyleCell: View {
    let style: VisualStyle
    let isSelected: Bool
    let isFavorite: Bool
    let isTrending: Bool
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Style preview thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(stylePreviewColor)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        ZStack(alignment: .topTrailing) {
                            if isTrending {
                                Image(systemName: "flame.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .padding(4)
                            }
                        }
                    )

                HStack {
                    Text(style.rawValue)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? Color(hex: 0x7A56C4) : .primary)

                    Spacer(minLength: 0)

                    Button(action: onFavoriteToggle) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.caption2)
                            .foregroundStyle(isFavorite ? .red : .secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(isSelected ? Color(hex: 0x7A56C4).opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(hex: 0x7A56C4) : Color.clear, lineWidth: 2)
        )
    }

    private var stylePreviewColor: Color {
        // Deterministic color from style name hash
        let hash = abs(style.rawValue.hash)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.9)
    }
}

// MARK: - Preview

#Preview {
    StyleExplorerView()
}

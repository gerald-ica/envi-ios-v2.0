//
//  TemplateCardView.swift
//  ENVI
//
//  Phase 5 — Template Tab v1 (Task 2).
//
//  The core visual unit on the Template tab: a populated template
//  rendered as a 2x2 thumbnail grid of the user's real media plus a
//  slot-fill indicator, name, and category. Thumbnails are fetched
//  from Photos via `AssetThumbnailLoader` (PHImageManager-backed
//  actor with in-memory cache) — the `envi-asset://` custom scheme
//  used by the Lynx WebView (Phase 4) does NOT resolve outside the
//  WebView, so we go straight to PHImageManager for Swift-native
//  rendering.
//

import SwiftUI
import UIKit
import Photos

// MARK: - AssetThumbnailLoader

/// Actor-backed thumbnail loader that maps a `ClassifiedAsset.localIdentifier`
/// to a `UIImage` via `PHImageManager`. Results are cached in-memory keyed
/// by `"\(localIdentifier)@\(width)x\(height)"` so scrolling a LazyHStack
/// does not re-request the same thumbnail repeatedly.
actor AssetThumbnailLoader {
    static let shared = AssetThumbnailLoader()

    private var cache: [String: UIImage] = [:]
    private let imageManager: PHImageManager

    init(imageManager: PHImageManager = .default()) {
        self.imageManager = imageManager
    }

    /// Fetch a thumbnail for the given local identifier.
    /// Returns nil if the asset is unavailable or Photos denies access.
    func thumbnail(for localIdentifier: String, size: CGSize) async -> UIImage? {
        let key = Self.cacheKey(localIdentifier: localIdentifier, size: size)
        if let cached = cache[key] { return cached }

        let fetch = PHAsset.fetchAssets(
            withLocalIdentifiers: [localIdentifier],
            options: nil
        )
        guard let asset = fetch.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let image: UIImage? = await withCheckedContinuation { continuation in
            var didResume = false
            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { result, info in
                // PHImageManager may invoke the callback multiple times
                // (degraded + final). Only resume once; prefer the
                // non-degraded image if we get it.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if didResume { return }
                if isDegraded && result != nil {
                    // Wait for the high-quality version unless it's the
                    // only thing we'll ever get.
                    return
                }
                didResume = true
                continuation.resume(returning: result)
            }
        }

        if let image {
            cache[key] = image
        }
        return image
    }

    /// Drop everything. Useful for memory warnings or manual invalidation.
    func purge() {
        cache.removeAll()
    }

    private static func cacheKey(localIdentifier: String, size: CGSize) -> String {
        "\(localIdentifier)@\(Int(size.width))x\(Int(size.height))"
    }
}

// MARK: - TemplateCardView

/// A card that renders a `PopulatedTemplate` with the user's real media
/// thumbnails in a 2x2 (or hero) layout, slot-fill pill, name, and
/// category. Tap → `onTap`, context menu exposes duplicate/hide hooks.
struct TemplateCardView: View {
    let populated: PopulatedTemplate
    let onTap: () -> Void
    let onDuplicate: () -> Void
    let onHide: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: Layout constants

    /// Card outer width. Kept modest so iPhone SE shows ~1.7 cards at a
    /// time and iPhone 16 Pro Max shows ~2.2. Height is derived from
    /// the thumbnail square + text block so the card scales with its
    /// own content rather than the screen.
    private static let cardWidth: CGFloat = 180
    private static let thumbSize: CGFloat = 180

    // MARK: Derived

    private var filledCount: Int {
        populated.filledSlots.reduce(0) { $0 + ($1.matchedAsset == nil ? 0 : 1) }
    }

    private var totalSlots: Int { populated.filledSlots.count }

    private var fillPillText: String {
        guard totalSlots > 0 else { return "0/0" }
        if filledCount == totalSlots {
            return "\(filledCount)/\(totalSlots) \u{2713}" // ✓
        }
        return "\(filledCount)/\(totalSlots)"
    }

    /// Green when 100% filled, amber when partial, subtle gray when empty.
    private var fillPillBackground: Color {
        guard totalSlots > 0 else { return Color.white.opacity(0.15) }
        let rate = Double(filledCount) / Double(totalSlots)
        if rate >= 1.0 { return ENVITheme.success.opacity(0.9) }
        if rate >= 0.5 { return ENVITheme.warning.opacity(0.9) }
        return Color.white.opacity(0.15)
    }

    private var fillPillForeground: Color {
        guard totalSlots > 0 else {
            return colorScheme == .dark ? .white : .black
        }
        let rate = Double(filledCount) / Double(totalSlots)
        return rate >= 0.5 ? .black : (colorScheme == .dark ? .white : .black)
    }

    private var durationText: String? {
        guard let d = populated.template.duration else { return nil }
        if d < 60 { return "\(Int(d.rounded()))s" }
        let m = Int(d) / 60
        let s = Int(d) % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            thumbnailStack
                .frame(width: Self.thumbSize, height: Self.thumbSize)
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                .overlay(alignment: .topTrailing) { fillPill.padding(ENVISpacing.sm) }
                .overlay(alignment: .bottomLeading) {
                    if let durationText {
                        ENVIBadge(text: durationText, style: .inverted)
                            .padding(ENVISpacing.sm)
                    }
                }

            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text(populated.template.name)
                    .font(.interSemiBold(14))
                    .lineLimit(1)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(populated.template.category.displayName.uppercased())
                    .font(.spaceMono(10))
                    .tracking(1.5)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            .frame(maxWidth: Self.thumbSize, alignment: .leading)
        }
        .frame(width: Self.cardWidth, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("Use Template", systemImage: "play.fill")
            }

            Button {
                onDuplicate()
            } label: {
                Label("Find Similar Content", systemImage: "sparkles")
            }

            Button(role: .destructive) {
                onHide()
            } label: {
                Label("Hide This Template", systemImage: "eye.slash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(populated.template.name), \(populated.template.category.displayName), \(filledCount) of \(totalSlots) slots filled"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Thumbnail composition

    @ViewBuilder
    private var thumbnailStack: some View {
        let slots = populated.filledSlots
        switch slots.count {
        case 0:
            placeholderTile
        case 1:
            slotTile(slots[0], size: CGSize(width: Self.thumbSize, height: Self.thumbSize))
        case 2:
            HStack(spacing: 2) {
                slotTile(slots[0], size: CGSize(width: Self.thumbSize / 2, height: Self.thumbSize))
                slotTile(slots[1], size: CGSize(width: Self.thumbSize / 2, height: Self.thumbSize))
            }
        case 3:
            VStack(spacing: 2) {
                slotTile(slots[0], size: CGSize(width: Self.thumbSize, height: Self.thumbSize / 2))
                HStack(spacing: 2) {
                    slotTile(slots[1], size: CGSize(width: Self.thumbSize / 2, height: Self.thumbSize / 2))
                    slotTile(slots[2], size: CGSize(width: Self.thumbSize / 2, height: Self.thumbSize / 2))
                }
            }
        default:
            // 2x2 grid of the first four filled slots.
            let tile = CGSize(width: Self.thumbSize / 2, height: Self.thumbSize / 2)
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    slotTile(slots[0], size: tile)
                    slotTile(slots[1], size: tile)
                }
                HStack(spacing: 2) {
                    slotTile(slots[2], size: tile)
                    slotTile(slots[3], size: tile)
                }
            }
        }
    }

    @ViewBuilder
    private func slotTile(_ slot: FilledSlot, size: CGSize) -> some View {
        if let identifier = slot.matchedAsset?.localIdentifier {
            AssetThumbnailView(localIdentifier: identifier, size: size)
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            placeholderTile
                .frame(width: size.width, height: size.height)
        }
    }

    private var placeholderTile: some View {
        ZStack {
            ENVITheme.surfaceHigh(for: colorScheme)
            Image(systemName: "photo.fill")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme).opacity(0.5))
        }
    }

    // MARK: Fill pill

    private var fillPill: some View {
        Text(fillPillText)
            .font(.spaceMonoBold(10))
            .tracking(1.5)
            .foregroundColor(fillPillForeground)
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .background(fillPillBackground)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }
}

// MARK: - AssetThumbnailView

/// Loads a single PHAsset thumbnail via `AssetThumbnailLoader` and
/// shows a shimmer placeholder until the image is available. Re-loads
/// if the identifier or size changes.
private struct AssetThumbnailView: View {
    let localIdentifier: String
    let size: CGSize

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?
    @State private var didFail: Bool = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if didFail {
                ZStack {
                    ENVITheme.surfaceHigh(for: colorScheme)
                    Image(systemName: "photo.fill")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme).opacity(0.5))
                }
            } else {
                ShimmerTile()
            }
        }
        .task(id: cacheBustKey) {
            await load()
        }
    }

    private var cacheBustKey: String {
        "\(localIdentifier)@\(Int(size.width))x\(Int(size.height))"
    }

    private func load() async {
        // Request with pixel dimensions. 2x scale is plenty for card-sized tiles.
        let pixelSize = CGSize(width: size.width * 2, height: size.height * 2)
        let loaded = await AssetThumbnailLoader.shared.thumbnail(
            for: localIdentifier,
            size: pixelSize
        )
        await MainActor.run {
            if let loaded {
                self.image = loaded
                self.didFail = false
            } else {
                self.image = nil
                self.didFail = true
            }
        }
    }
}

// MARK: - ShimmerTile

/// Lightweight skeleton shimmer while a thumbnail loads. Pure SwiftUI,
/// no dependencies. Uses the surface tokens so it adapts to light/dark.
private struct ShimmerTile: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ENVITheme.surfaceHigh(for: colorScheme)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25), location: 0.5),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 1.5)
                .offset(x: phase * geo.size.width)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
private struct TemplateCardView_Previews: View {
    var body: some View {
        let template = VideoTemplate.mockLibrary[0]
        let filled = template.slots.map { FilledSlot(slot: $0, matchedAsset: nil) }
        let populated = PopulatedTemplate(
            template: template,
            filledSlots: filled,
            fillRate: 0.0,
            overallScore: 0.0
        )

        TemplateCardView(
            populated: populated,
            onTap: {},
            onDuplicate: {},
            onHide: {}
        )
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}

private struct TemplateCardView_PartialFill_Previews: View {
    var body: some View {
        let template = VideoTemplate.mockLibrary[2] // OOTD, 4 slots
        // Simulate 2/4 filled by passing matchedAsset=nil for half of them.
        // Real matched assets require a live Photos library, so the preview
        // still renders placeholder tiles — the fill pill + text still exercise.
        let filled = template.slots.enumerated().map { idx, slot in
            FilledSlot(slot: slot, matchedAsset: nil)
        }
        let populated = PopulatedTemplate(
            template: template,
            filledSlots: filled,
            fillRate: 0.5,
            overallScore: 0.5
        )

        TemplateCardView(
            populated: populated,
            onTap: {},
            onDuplicate: {},
            onHide: {}
        )
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
#endif

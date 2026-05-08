//
//  TemplatePlayerView.swift
//  ENVI
//
//  Phase 5 — Task 3b: Live playback surface for a PopulatedTemplate.
//
//  Two render paths:
//   1. Photo-only templates → SwiftUI crossfade slideshow, driven by a
//      per-slot Timer that advances `currentSlotIndex`.
//   2. Any-video template → AVPlayer + AVMutableComposition stitching
//      slot assets in order, wrapped in a UIViewRepresentable so we can
//      reuse the player layer on swap instead of reallocating it.
//
//  Composition work runs off the main actor inside a `.task` and the
//  composed `AVPlayerItem` is swapped into the existing `AVPlayer` via
//  `replaceCurrentItem(with:)`. Rebuilt only when `populated.id` or a
//  slot's matched-asset identifier changes.
//
//  Text overlays from `populated.template.textOverlays` are rendered as
//  SwiftUI `Text` in a ZStack on top of the video/photo surface — they
//  do not participate in AVComposition so there's no transcode cost and
//  typography stays crisp at any scale.
//
//  Audio policy: we configure `AVAudioSession.ambient` on first appear
//  so the preview never overrides the user's music / silent switch.
//

import SwiftUI
import AVFoundation
import AVKit
import Photos
import UIKit

struct TemplatePlayerView: View {

    let populated: PopulatedTemplate
    @Binding var isPlaying: Bool

    @Environment(\.colorScheme) private var colorScheme

    // Slideshow state (photo path)
    @State private var currentSlotIndex: Int = 0
    @State private var slideshowTimerStart: Date = Date()

    // Video state (video path)
    @State private var composedPlayer: AVPlayer? = nil
    @State private var isComposing: Bool = false
    @State private var compositionError: String? = nil

    // Signature of the currently-composed timeline. If this changes
    // (swap, new template) we rebuild.
    @State private var loadedSignature: String = ""

    private var isVideoTemplate: Bool {
        populated.filledSlots.contains { slot in
            guard let asset = slot.matchedAsset else { return false }
            return asset.mediaType == PHAssetMediaType.video.rawValue
        }
    }

    // A stable string describing the current slot lineup — used to
    // decide whether a rebuild is required.
    private var timelineSignature: String {
        populated.filledSlots
            .sorted(by: { $0.slot.order < $1.slot.order })
            .map { "\($0.slot.id.uuidString):\($0.matchedAsset?.localIdentifier ?? "-")" }
            .joined(separator: "|")
    }

    var body: some View {
        ZStack {
            // Background — monochrome canvas behind media
            Color.black

            if isVideoTemplate {
                videoLayer
            } else {
                photoLayer
            }

            // Template-level text overlays (not per-slot)
            ForEach(populated.template.textOverlays) { overlay in
                overlayText(overlay)
            }

            // Current slot's per-slot caption (if any)
            if let caption = currentSlotCaption {
                VStack {
                    Spacer()
                    Text(caption)
                        .font(.spaceMonoBold(20))
                        .tracking(1.0)
                        .foregroundColor(.white)
                        .padding(.horizontal, ENVISpacing.md)
                        .padding(.vertical, ENVISpacing.sm)
                        .background(Color.black.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        .padding(.bottom, ENVISpacing.xxxl)
                }
            }

            // Spinner while composition is building
            if isComposing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.3)
            }

            if let err = compositionError {
                Text(err)
                    .font(.interRegular(12))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(ENVISpacing.lg)
            }
        }
        .aspectRatio(aspectRatioValue, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .contentShape(Rectangle())
        .onTapGesture {
            isPlaying.toggle()
        }
        .onAppear {
            configureAudioSessionAmbient()
            slideshowTimerStart = Date()
        }
        .onChange(of: timelineSignature) { _, newValue in
            // Rebuild composition / reset slideshow when slots change.
            currentSlotIndex = 0
            slideshowTimerStart = Date()
            if isVideoTemplate {
                Task { await rebuildCompositionIfNeeded(for: newValue) }
            }
        }
        .task(id: timelineSignature) {
            if isVideoTemplate {
                await rebuildCompositionIfNeeded(for: timelineSignature)
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if isVideoTemplate {
                if playing { composedPlayer?.play() } else { composedPlayer?.pause() }
            } else {
                if playing { slideshowTimerStart = Date() }
            }
        }
    }

    // MARK: - Aspect ratio

    private var aspectRatioValue: CGFloat {
        switch populated.template.aspectRatio {
        case .portrait9x16: return 9.0 / 16.0
        case .square:       return 1.0
        case .landscape16x9: return 16.0 / 9.0
        case .portrait4x5:  return 4.0 / 5.0
        }
    }

    // MARK: - Photo layer (crossfade slideshow)

    @ViewBuilder
    private var photoLayer: some View {
        let orderedSlots = populated.filledSlots.sorted(by: { $0.slot.order < $1.slot.order })
        let idx = min(currentSlotIndex, max(0, orderedSlots.count - 1))

        ZStack {
            if !orderedSlots.isEmpty {
                let active = orderedSlots[idx]
                TemplateSlotImageView(
                    assetIdentifier: active.matchedAsset?.localIdentifier,
                    targetSize: CGSize(width: 1080, height: 1920)
                )
                .id(active.id)
                .transition(.opacity)
            } else {
                Color.black
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentSlotIndex)
        .onAppear {
            advanceSlideshowLoop(total: orderedSlots.count, slots: orderedSlots)
        }
    }

    private func advanceSlideshowLoop(total: Int, slots: [FilledSlot]) {
        guard total > 0 else { return }
        // Simple per-slot timer. Uses Task rather than Timer to stay
        // in the SwiftUI lifecycle and auto-cancel when the view dies.
        Task { @MainActor in
            while !Task.isCancelled {
                let slot = slots[currentSlotIndex]
                let d = max(0.5, slot.slot.duration)
                try? await Task.sleep(nanoseconds: UInt64(d * 1_000_000_000))
                if !isPlaying { continue }
                currentSlotIndex = (currentSlotIndex + 1) % total
            }
        }
    }

    private var currentSlotCaption: String? {
        let ordered = populated.filledSlots.sorted(by: { $0.slot.order < $1.slot.order })
        let idx = min(currentSlotIndex, max(0, ordered.count - 1))
        guard !ordered.isEmpty else { return nil }
        return ordered[idx].slot.textOverlay
    }

    // MARK: - Video layer (AVPlayer)

    @ViewBuilder
    private var videoLayer: some View {
        if let player = composedPlayer {
            AVPlayerLayerView(player: player)
        } else {
            Color.black
        }
    }

    private func rebuildCompositionIfNeeded(for signature: String) async {
        guard loadedSignature != signature else { return }
        isComposing = true
        compositionError = nil
        defer { isComposing = false }

        do {
            let item = try await buildPlayerItem()
            loadedSignature = signature
            if let player = composedPlayer {
                player.replaceCurrentItem(with: item)
            } else {
                let p = AVPlayer(playerItem: item)
                p.isMuted = false
                composedPlayer = p
            }
            // Loop on end
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak player = composedPlayer] _ in
                player?.seek(to: .zero)
                player?.play()
            }
            if isPlaying {
                composedPlayer?.play()
            }
        } catch {
            compositionError = "Preview unavailable"
        }
    }

    // MARK: - Composition builder

    private func buildPlayerItem() async throws -> AVPlayerItem {
        let ordered = populated.filledSlots.sorted(by: { $0.slot.order < $1.slot.order })
        let composition = AVMutableComposition()
        guard
            let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            throw NSError(domain: "TemplatePlayerView", code: -1)
        }

        var cursor: CMTime = .zero

        for slot in ordered {
            let slotDuration = CMTime(seconds: max(0.5, slot.slot.duration), preferredTimescale: 600)

            guard let matched = slot.matchedAsset else {
                cursor = CMTimeAdd(cursor, slotDuration)
                continue
            }

            // Only real PHAssets contribute to the composition; photos are
            // skipped here (rare — photo-only templates take the slideshow
            // path). Leaving a gap would produce black; we let AVPlayer
            // handle that silently.
            guard matched.mediaType == PHAssetMediaType.video.rawValue else {
                cursor = CMTimeAdd(cursor, slotDuration)
                continue
            }

            if let avAsset = try? await loadAVAsset(localIdentifier: matched.localIdentifier) {
                let tracks = try? await avAsset.loadTracks(withMediaType: .video)
                if let srcTrack = tracks?.first {
                    let clipDuration: CMTime
                    if let full = try? await avAsset.load(.duration), full.seconds > 0 {
                        clipDuration = CMTimeMinimum(slotDuration, full)
                    } else {
                        clipDuration = slotDuration
                    }
                    let range = CMTimeRangeMake(start: .zero, duration: clipDuration)
                    try? videoTrack.insertTimeRange(range, of: srcTrack, at: cursor)
                    cursor = CMTimeAdd(cursor, clipDuration)
                    continue
                }
            }
            // Fallback — reserve the slot's time with no media.
            cursor = CMTimeAdd(cursor, slotDuration)
        }

        return AVPlayerItem(asset: composition)
    }

    private func loadAVAsset(localIdentifier: String) async throws -> AVAsset? {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let phAsset = fetch.firstObject else { return nil }
        return try await withCheckedThrowingContinuation { cont in
            let opts = PHVideoRequestOptions()
            opts.version = .current
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: opts) { asset, _, _ in
                let safe = _SendableAsset(asset)
                cont.resume(returning: safe.value)
            }
        }
    }

    // MARK: - Overlay rendering

    @ViewBuilder
    private func overlayText(_ overlay: VideoTemplate.TextOverlay) -> some View {
        let alignment = alignment(for: overlay.placement)
        VStack {
            HStack {
                Text(overlay.text)
                    .font(.custom(overlay.style.fontName, size: overlay.style.fontSize))
                    .tracking(0.5)
                    .foregroundColor(color(hex: overlay.style.colorHex))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, ENVISpacing.xs)
                    .background(
                        overlay.style.backgroundHex.map { color(hex: $0) } ?? Color.clear
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .padding(ENVISpacing.lg)
        .allowsHitTesting(false)
    }

    private func alignment(for placement: VideoTemplate.TextOverlay.Placement) -> Alignment {
        switch placement {
        case .topLeft:      return .topLeading
        case .topCenter:    return .top
        case .topRight:     return .topTrailing
        case .middleLeft:   return .leading
        case .middleCenter: return .center
        case .middleRight:  return .trailing
        case .bottomLeft:   return .bottomLeading
        case .bottomCenter: return .bottom
        case .bottomRight:  return .bottomTrailing
        }
    }

    private func color(hex: String) -> Color {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        guard let v = UInt32(h, radix: 16) else { return .white }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Audio session

    private func configureAudioSessionAmbient() {
        // `.ambient` mixes with other audio and respects the silent
        // switch — appropriate for a preview surface.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }
}

// MARK: - AVPlayerLayerView (UIViewRepresentable)

/// A minimal player host whose layer resizes with SwiftUI layout.
/// We pass the AVPlayer in from SwiftUI state so `replaceCurrentItem`
/// calls on that player reflect here without re-creating the view.
struct AVPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let v = PlayerContainerView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect
        return v
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    final class PlayerContainerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as? AVPlayerLayer ?? AVPlayerLayer() }
    }
}

// MARK: - TemplateSlotImageView (PHImageManager thumbnail)

/// Lightweight PHImageManager-backed image view scoped to the preview.
/// Lives alongside the player so Task 3 is self-contained — Task 2's
/// AssetThumbnailLoader will supersede this once it lands.
struct TemplateSlotImageView: View {
    let assetIdentifier: String?
    let targetSize: CGSize

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(white: 0.1)
            }
        }
        .clipped()
        .task(id: assetIdentifier) {
            await load()
        }
    }

    private func load() async {
        guard let id = assetIdentifier else { image = nil; return }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetch.firstObject else { image = nil; return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.resizeMode = .exact
        opts.isNetworkAccessAllowed = true
        let size = targetSize
        let img: UIImage? = await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: opts
            ) { image, _ in
                cont.resume(returning: image)
            }
        }
        self.image = img
    }
}

// MARK: - Sendable wrapper for AVAsset (PHImageManager callback)
private final class _SendableAsset: @unchecked Sendable {
    let value: AVAsset?
    init(_ v: AVAsset?) { self.value = v }
}

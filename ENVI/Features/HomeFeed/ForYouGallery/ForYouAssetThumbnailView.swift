import SwiftUI
import Photos

/// Renders a camera-roll thumbnail for a PHAsset local identifier.
struct ForYouAssetThumbnailView: View {
    let assetLocalIdentifier: String
    let fallbackImageName: String?
    let contentMode: ContentMode

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let fallbackImageName {
                Image(fallbackImageName)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                LinearGradient(
                    colors: [ENVITheme.Dark.surfaceLow, Color.black.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .task(id: assetLocalIdentifier) {
            await loadImage()
        }
    }

    private func loadImage() async {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalIdentifier], options: nil)
        guard let asset = fetch.firstObject else { return }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

        let target = CGSize(width: 1200, height: 1200)
        let loaded: UIImage? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: target,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
        self.image = loaded
    }
}

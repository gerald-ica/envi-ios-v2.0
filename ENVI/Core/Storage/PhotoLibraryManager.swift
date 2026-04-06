import Foundation
import Photos
import Combine

// MARK: - PhotoLibraryManager
/// Manages access to the user's photo library via PHPhotoLibrary.
///
/// In production, this manager feeds the content piece assembly pipeline:
///   1. User grants Photos access during onboarding
///   2. PhotoLibraryManager fetches recent photos and videos from the camera roll
///   3. Media is passed to ContentPieceAssembler for backend processing
///   4. Assembled content pieces are displayed in the World Explorer 3D helix
///
/// Observes real-time photo library changes via `PHPhotoLibraryChangeObserver`
/// and notifies delegates when the library is updated.

// MARK: - PhotoLibraryChangeDelegate

/// Delegate protocol for receiving photo library change notifications.
protocol PhotoLibraryChangeDelegate: AnyObject {
    /// Called when the photo library contents have changed.
    func photoLibraryDidChange(insertedCount: Int, removedCount: Int, updatedCount: Int)
}

final class PhotoLibraryManager: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {

    // MARK: - Authorization Status

    /// Represents the current photo library authorization state.
    enum AuthorizationStatus: Equatable {
        case notDetermined
        case authorized
        case limited
        case denied
        case restricted

        /// Maps from PHAuthorizationStatus to our local enum.
        init(phStatus: PHAuthorizationStatus) {
            switch phStatus {
            case .notDetermined:
                self = .notDetermined
            case .authorized:
                self = .authorized
            case .limited:
                self = .limited
            case .denied:
                self = .denied
            case .restricted:
                self = .restricted
            @unknown default:
                self = .denied
            }
        }

        var isAuthorized: Bool {
            self == .authorized || self == .limited
        }

        var isFullyAuthorized: Bool {
            self == .authorized
        }
    }

    // MARK: - Published Properties

    /// Current authorization status, published for SwiftUI observation.
    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    /// Number of media items available in the user's library.
    @Published private(set) var availableMediaCount: Int = 0

    /// Delegate for receiving library change events.
    weak var changeDelegate: PhotoLibraryChangeDelegate?

    /// Cached fetch result for change observer diffing.
    private var cachedFetchResult: PHFetchResult<PHAsset>?

    // MARK: - Singleton

    static let shared = PhotoLibraryManager()

    private override init() {
        super.init()
        refreshAuthorizationStatus()
        startObservingChanges()
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - Authorization

    /// Requests photo library authorization from the user.
    /// Call this during onboarding to prompt the system permission dialog.
    /// - Returns: The resulting authorization status.
    @MainActor
    static func requestAuthorization() async -> AuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let mapped = AuthorizationStatus(phStatus: status)
        PhotoLibraryManager.shared.authorizationStatus = mapped
        return mapped
    }

    func refreshAuthorizationStatus() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = AuthorizationStatus(phStatus: currentStatus)
    }

    // MARK: - Fetching Media

    /// Fetches recent photos and videos from the user's camera roll.
    ///
    /// In production, this feeds into the ContentPieceAssembler pipeline.
    /// The fetched assets are sent to the backend for processing into
    /// content pieces (edited short-form media).
    ///
    /// - Parameters:
    ///   - limit: Maximum number of assets to fetch. Defaults to 100.
    ///   - mediaTypes: Which media types to include. Defaults to images and videos.
    /// - Returns: An array of PHAsset references for further processing.
    func fetchRecentMedia(
        limit: Int = 100,
        mediaTypes: [PHAssetMediaType] = [.image, .video]
    ) -> [PHAsset] {
        guard authorizationStatus.isAuthorized else {
            return []
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = limit

        // Build predicate for requested media types
        let predicates = mediaTypes.map { type in
            NSPredicate(format: "mediaType == %d", type.rawValue)
        }
        fetchOptions.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

        let results = PHAsset.fetchAssets(with: fetchOptions)
        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        availableMediaCount = assets.count
        return assets
    }

    /// Fetches a count of all media in the user's library.
    /// Useful for displaying stats in the profile or onboarding flow.
    func totalMediaCount() -> Int {
        guard authorizationStatus.isAuthorized else {
            return 0
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        return PHAsset.fetchAssets(with: fetchOptions).count
    }

    // MARK: - Photo Library Change Observation

    /// Registers as a photo library change observer for real-time sync.
    private func startObservingChanges() {
        guard authorizationStatus.isAuthorized else { return }
        PHPhotoLibrary.shared().register(self)

        // Perform an initial fetch to seed the cached result for diffing
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        cachedFetchResult = PHAsset.fetchAssets(with: fetchOptions)
        availableMediaCount = cachedFetchResult?.count ?? 0
    }

    /// Called by the Photos framework when the library changes.
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let previousResult = cachedFetchResult else { return }
        guard let changeDetails = changeInstance.changeDetails(for: previousResult) else { return }

        let inserted = changeDetails.insertedObjects.count
        let removed = changeDetails.removedObjects.count
        let updated = changeDetails.changedObjects.count

        // Update cached result on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cachedFetchResult = changeDetails.fetchResultAfterChanges
            self.availableMediaCount = changeDetails.fetchResultAfterChanges.count

            self.changeDelegate?.photoLibraryDidChange(
                insertedCount: inserted,
                removedCount: removed,
                updatedCount: updated
            )
        }
    }
}

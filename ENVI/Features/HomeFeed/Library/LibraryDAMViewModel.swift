import SwiftUI
import Combine

/// ViewModel for DAM (Digital Asset Management) features in the Library.
///
/// Phase 19 Plan 03 note: this VM is NOT orphan (as the plan originally
/// assumed) — `AssetDetailView`, `FolderBrowserView`, `SmartCollectionView`,
/// and `StorageQuotaView` all bind to it. It is complementary to
/// `LibraryViewModel` (which handles library items / templates / content
/// plan), not a duplicate. A future consolidation could merge the two
/// if the DAM surfaces are folded into the main Library view, but that's
/// a v1.3+ refactor, not a hygiene fix.
final class LibraryDAMViewModel: ObservableObject {

    // MARK: - Published State

    @Published var folders: [ContentFolder] = []
    @Published var smartCollections: [SmartCollection] = []
    @Published var versionHistory: [AssetVersion] = []
    @Published var usageRights: UsageRights?
    @Published var storageQuota: StorageQuota?
    @Published var platformReadiness: [PlatformReadinessResult] = []

    @Published var isLoadingFolders = false
    @Published var isLoadingCollections = false
    @Published var isLoadingVersions = false
    @Published var isLoadingQuota = false

    @Published var errorMessage: String?

    // Folder creation / rename sheet state
    @Published var isShowingCreateFolder = false
    @Published var folderToRename: ContentFolder?

    // Smart collection creation
    @Published var isShowingCreateCollection = false

    // Bulk selection
    @Published var selectedAssetIDs: Set<UUID> = []
    @Published var isBulkMode = false

    private let repository: LibraryDAMRepository

    // MARK: - Init

    init(repository: LibraryDAMRepository = LibraryDAMRepositoryProvider.shared.repository) {
        self.repository = repository
        Task {
            await loadFolders()
            await loadSmartCollections()
            await loadStorageQuota()
        }
    }

    // MARK: - Computed

    /// Pinned folders sorted first, then alphabetically.
    var sortedFolders: [ContentFolder] {
        folders.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Folders that are children of a given parent (nil = root).
    func childFolders(of parentID: UUID?) -> [ContentFolder] {
        sortedFolders.filter { $0.parentID == parentID }
    }

    // MARK: - Folder CRUD

    @MainActor
    func loadFolders() async {
        isLoadingFolders = true
        errorMessage = nil
        do {
            folders = try await repository.fetchFolders()
        } catch {
            if AppEnvironment.current == .dev {
                folders = ContentFolder.mockFolders
            } else {
                errorMessage = "Unable to load folders."
            }
        }
        isLoadingFolders = false
    }

    @MainActor
    func createFolder(name: String, parentID: UUID? = nil) async {
        errorMessage = nil
        do {
            let folder = try await repository.createFolder(name: name, parentID: parentID)
            folders.append(folder)
        } catch {
            errorMessage = "Could not create folder."
        }
    }

    @MainActor
    func renameFolder(_ folder: ContentFolder, to name: String) async {
        errorMessage = nil
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        let snapshot = folders[index]

        // Optimistic
        folders[index].name = name

        do {
            _ = try await repository.renameFolder(id: folder.id, name: name)
        } catch {
            folders[index] = snapshot
            errorMessage = "Could not rename folder."
        }
    }

    @MainActor
    func deleteFolder(_ folder: ContentFolder) async {
        errorMessage = nil
        let snapshot = folders
        folders.removeAll { $0.id == folder.id }

        do {
            try await repository.deleteFolder(id: folder.id)
        } catch {
            folders = snapshot
            errorMessage = "Could not delete folder."
        }
    }

    @MainActor
    func togglePin(_ folder: ContentFolder) async {
        errorMessage = nil
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        let newPinned = !folders[index].isPinned
        let snapshot = folders[index]

        // Optimistic
        folders[index].isPinned = newPinned

        do {
            _ = try await repository.pinFolder(id: folder.id, pinned: newPinned)
        } catch {
            folders[index] = snapshot
            errorMessage = "Could not update pin."
        }
    }

    // MARK: - Smart Collections

    @MainActor
    func loadSmartCollections() async {
        isLoadingCollections = true
        errorMessage = nil
        do {
            smartCollections = try await repository.fetchSmartCollections()
        } catch {
            if AppEnvironment.current == .dev {
                smartCollections = SmartCollection.mockCollections
            } else {
                errorMessage = "Unable to load smart collections."
            }
        }
        isLoadingCollections = false
    }

    @MainActor
    func createSmartCollection(name: String, rules: [FilterRule]) async {
        errorMessage = nil
        do {
            let collection = try await repository.createSmartCollection(name: name, rules: rules)
            smartCollections.append(collection)
        } catch {
            errorMessage = "Could not create smart collection."
        }
    }

    @MainActor
    func deleteSmartCollection(_ collection: SmartCollection) async {
        errorMessage = nil
        let snapshot = smartCollections
        smartCollections.removeAll { $0.id == collection.id }

        do {
            try await repository.deleteSmartCollection(id: collection.id)
        } catch {
            smartCollections = snapshot
            errorMessage = "Could not delete collection."
        }
    }

    // MARK: - Version History

    @MainActor
    func loadVersionHistory(for assetID: UUID) async {
        isLoadingVersions = true
        errorMessage = nil
        do {
            versionHistory = try await repository.fetchVersionHistory(assetID: assetID)
        } catch {
            if AppEnvironment.current == .dev {
                versionHistory = AssetVersion.mockVersions(for: assetID)
            } else {
                errorMessage = "Unable to load version history."
            }
        }
        isLoadingVersions = false
    }

    // MARK: - Usage Rights

    @MainActor
    func loadUsageRights(for assetID: UUID) async {
        do {
            usageRights = try await repository.fetchUsageRights(assetID: assetID)
        } catch {
            if AppEnvironment.current == .dev {
                usageRights = UsageRights.mockRights
            }
        }
    }

    // MARK: - Platform Readiness

    @MainActor
    func loadPlatformReadiness(for assetID: UUID) async {
        do {
            platformReadiness = try await repository.fetchPlatformReadiness(assetID: assetID)
        } catch {
            if AppEnvironment.current == .dev {
                platformReadiness = PlatformReadinessResult.mockReadiness
            }
        }
    }

    // MARK: - Storage Quota

    @MainActor
    func loadStorageQuota() async {
        isLoadingQuota = true
        do {
            storageQuota = try await repository.fetchStorageQuota()
        } catch {
            if AppEnvironment.current == .dev {
                storageQuota = StorageQuota.mockQuota
            }
        }
        isLoadingQuota = false
    }

    // MARK: - Bulk Actions

    @MainActor
    func archiveSelected() async {
        guard !selectedAssetIDs.isEmpty else { return }
        errorMessage = nil
        do {
            try await repository.archiveAssets(ids: Array(selectedAssetIDs))
            selectedAssetIDs.removeAll()
            isBulkMode = false
        } catch {
            errorMessage = "Could not archive selected assets."
        }
    }

    @MainActor
    func restoreSelected() async {
        guard !selectedAssetIDs.isEmpty else { return }
        errorMessage = nil
        do {
            try await repository.restoreAssets(ids: Array(selectedAssetIDs))
            selectedAssetIDs.removeAll()
            isBulkMode = false
        } catch {
            errorMessage = "Could not restore selected assets."
        }
    }

    @MainActor
    func performBulkAction(_ action: BulkAssetAction) async {
        guard !selectedAssetIDs.isEmpty else { return }
        errorMessage = nil
        do {
            try await repository.bulkAction(ids: Array(selectedAssetIDs), action: action)
            selectedAssetIDs.removeAll()
            isBulkMode = false
        } catch {
            errorMessage = "Bulk action failed."
        }
    }

    func toggleAssetSelection(_ id: UUID) {
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
    }
}

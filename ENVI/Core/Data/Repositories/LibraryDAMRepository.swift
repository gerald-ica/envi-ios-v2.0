import Foundation

// MARK: - Protocol

protocol LibraryDAMRepository {
    func fetchFolders() async throws -> [ContentFolder]
    func createFolder(name: String, parentID: UUID?) async throws -> ContentFolder
    func renameFolder(id: UUID, name: String) async throws -> ContentFolder
    func deleteFolder(id: UUID) async throws
    func pinFolder(id: UUID, pinned: Bool) async throws -> ContentFolder

    func fetchSmartCollections() async throws -> [SmartCollection]
    func createSmartCollection(name: String, rules: [FilterRule]) async throws -> SmartCollection
    func deleteSmartCollection(id: UUID) async throws

    func fetchVersionHistory(assetID: UUID) async throws -> [AssetVersion]
    func fetchUsageRights(assetID: UUID) async throws -> UsageRights
    func fetchStorageQuota() async throws -> StorageQuota
    func fetchPlatformReadiness(assetID: UUID) async throws -> [PlatformReadinessResult]

    func archiveAssets(ids: [UUID]) async throws
    func restoreAssets(ids: [UUID]) async throws
    func bulkAction(ids: [UUID], action: BulkAssetAction) async throws
}

// MARK: - Mock Implementation

final class MockLibraryDAMRepository: LibraryDAMRepository {
    private var folders: [ContentFolder] = ContentFolder.mockFolders
    private var collections: [SmartCollection] = SmartCollection.mockCollections

    func fetchFolders() async throws -> [ContentFolder] {
        folders
    }

    func createFolder(name: String, parentID: UUID?) async throws -> ContentFolder {
        let folder = ContentFolder(name: name, parentID: parentID)
        folders.append(folder)
        return folder
    }

    func renameFolder(id: UUID, name: String) async throws -> ContentFolder {
        guard let index = folders.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "MockLibraryDAMRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Folder not found."])
        }
        folders[index].name = name
        return folders[index]
    }

    func deleteFolder(id: UUID) async throws {
        folders.removeAll { $0.id == id }
    }

    func pinFolder(id: UUID, pinned: Bool) async throws -> ContentFolder {
        guard let index = folders.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "MockLibraryDAMRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Folder not found."])
        }
        folders[index].isPinned = pinned
        return folders[index]
    }

    func fetchSmartCollections() async throws -> [SmartCollection] {
        collections
    }

    func createSmartCollection(name: String, rules: [FilterRule]) async throws -> SmartCollection {
        let collection = SmartCollection(name: name, rules: rules)
        collections.append(collection)
        return collection
    }

    func deleteSmartCollection(id: UUID) async throws {
        collections.removeAll { $0.id == id }
    }

    func fetchVersionHistory(assetID: UUID) async throws -> [AssetVersion] {
        AssetVersion.mockVersions(for: assetID)
    }

    func fetchUsageRights(assetID: UUID) async throws -> UsageRights {
        UsageRights.mockRights
    }

    func fetchStorageQuota() async throws -> StorageQuota {
        StorageQuota.mockQuota
    }

    func fetchPlatformReadiness(assetID: UUID) async throws -> [PlatformReadinessResult] {
        PlatformReadinessResult.mockReadiness
    }

    func archiveAssets(ids: [UUID]) async throws {
        // Mock no-op
    }

    func restoreAssets(ids: [UUID]) async throws {
        // Mock no-op
    }

    func bulkAction(ids: [UUID], action: BulkAssetAction) async throws {
        // Mock no-op
    }
}

// MARK: - API Implementation

final class APILibraryDAMRepository: LibraryDAMRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchFolders() async throws -> [ContentFolder] {
        try await apiClient.request(endpoint: "dam/folders", method: .get, requiresAuth: true)
    }

    func createFolder(name: String, parentID: UUID?) async throws -> ContentFolder {
        let body = CreateFolderBody(name: name, parentID: parentID?.uuidString)
        return try await apiClient.request(endpoint: "dam/folders", method: .post, body: body, requiresAuth: true)
    }

    func renameFolder(id: UUID, name: String) async throws -> ContentFolder {
        let body = RenameFolderBody(name: name)
        return try await apiClient.request(endpoint: "dam/folders/\(id.uuidString)", method: .patch, body: body, requiresAuth: true)
    }

    func deleteFolder(id: UUID) async throws {
        try await apiClient.requestVoid(endpoint: "dam/folders/\(id.uuidString)", method: .delete, requiresAuth: true)
    }

    func pinFolder(id: UUID, pinned: Bool) async throws -> ContentFolder {
        let body = PinFolderBody(isPinned: pinned)
        return try await apiClient.request(endpoint: "dam/folders/\(id.uuidString)/pin", method: .patch, body: body, requiresAuth: true)
    }

    func fetchSmartCollections() async throws -> [SmartCollection] {
        try await apiClient.request(endpoint: "dam/collections", method: .get, requiresAuth: true)
    }

    func createSmartCollection(name: String, rules: [FilterRule]) async throws -> SmartCollection {
        let body = CreateCollectionBody(name: name, rules: rules)
        return try await apiClient.request(endpoint: "dam/collections", method: .post, body: body, requiresAuth: true)
    }

    func deleteSmartCollection(id: UUID) async throws {
        try await apiClient.requestVoid(endpoint: "dam/collections/\(id.uuidString)", method: .delete, requiresAuth: true)
    }

    func fetchVersionHistory(assetID: UUID) async throws -> [AssetVersion] {
        try await apiClient.request(endpoint: "dam/assets/\(assetID.uuidString)/versions", method: .get, requiresAuth: true)
    }

    func fetchUsageRights(assetID: UUID) async throws -> UsageRights {
        try await apiClient.request(endpoint: "dam/assets/\(assetID.uuidString)/rights", method: .get, requiresAuth: true)
    }

    func fetchStorageQuota() async throws -> StorageQuota {
        try await apiClient.request(endpoint: "dam/storage/quota", method: .get, requiresAuth: true)
    }

    func fetchPlatformReadiness(assetID: UUID) async throws -> [PlatformReadinessResult] {
        // PlatformReadinessResult is not Decodable by design (uses SocialPlatform enum);
        // decode a response DTO and map.
        let dtos: [PlatformReadinessDTO] = try await apiClient.request(
            endpoint: "dam/assets/\(assetID.uuidString)/readiness",
            method: .get,
            requiresAuth: true
        )
        return dtos.compactMap { $0.toDomain() }
    }

    func archiveAssets(ids: [UUID]) async throws {
        let body = AssetIDsBody(ids: ids.map(\.uuidString))
        try await apiClient.requestVoid(endpoint: "dam/assets/archive", method: .post, body: body, requiresAuth: true)
    }

    func restoreAssets(ids: [UUID]) async throws {
        let body = AssetIDsBody(ids: ids.map(\.uuidString))
        try await apiClient.requestVoid(endpoint: "dam/assets/restore", method: .post, body: body, requiresAuth: true)
    }

    func bulkAction(ids: [UUID], action: BulkAssetAction) async throws {
        let body = BulkActionBody(ids: ids.map(\.uuidString), action: action.rawValue)
        try await apiClient.requestVoid(endpoint: "dam/assets/bulk", method: .post, body: body, requiresAuth: true)
    }
}

// MARK: - Provider

enum LibraryDAMRepositoryProvider {
    static var shared = RepositoryProvider<LibraryDAMRepository>(
        dev: MockLibraryDAMRepository(),
        api: APILibraryDAMRepository()
    )
}

// MARK: - Request Bodies

private struct CreateFolderBody: Encodable {
    let name: String
    let parentID: String?
}

private struct RenameFolderBody: Encodable {
    let name: String
}

private struct PinFolderBody: Encodable {
    let isPinned: Bool
}

private struct CreateCollectionBody: Encodable {
    let name: String
    let rules: [FilterRule]
}

private struct AssetIDsBody: Encodable {
    let ids: [String]
}

private struct BulkActionBody: Encodable {
    let ids: [String]
    let action: String
}

// MARK: - Response DTOs

private struct PlatformReadinessDTO: Decodable {
    let platform: String
    let status: String
    let notes: String

    func toDomain() -> PlatformReadinessResult? {
        guard let p = SocialPlatform(rawValue: platform),
              let s = PlatformReadiness(rawValue: status) else { return nil }
        return PlatformReadinessResult(platform: p, status: s, notes: notes)
    }
}

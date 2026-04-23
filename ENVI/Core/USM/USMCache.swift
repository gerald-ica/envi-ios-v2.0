//
//  USMCache.swift
//  ENVI
//
//  Local persistence for the User Self-Model. Stores the latest encrypted
//  envelope + decoded snapshot + per-block version vector so USMSyncActor
//  can do block-level last-writer-wins reconciliation against the server.
//
//  Part of USM Sprint 1 — Task 1.6.
//

import Foundation
import SwiftData

/// Errors surfaced by USMCache.
public enum USMCacheError: Error {
    case containerUnavailable(Error)
    case fetchFailed(Error)
    case writeFailed(Error)
    case decodeFailed(Error)
    case encodeFailed(Error)
}

// MARK: - @Model

/// SwiftData record for the current user's User Self-Model snapshot.
///
/// Mirrors the server row in `oracle_users.user_self_model` but stores the
/// decoded JSON locally. The server remains the source of truth; this cache
/// exists so the iOS app can render instantly on cold start, survive offline
/// scenarios, and give `USMSyncActor` a base version for LWW merges.
@Model
public final class USMCacheRecord {
    /// Unique primary key (userId + schemaVersion).
    @Attribute(.unique) public var id: String

    /// UUID of the user that owns this self-model.
    public var userId: String

    /// Schema version of the stored payload. Used to gate `upgrade()` calls.
    public var schemaVersion: Int

    /// Monotonically-increasing model version returned by the server.
    public var modelVersion: Int

    /// JSON-encoded `UserSelfModel` payload (plaintext; iOS-only). The
    /// system keychain encrypts the SwiftData store at rest.
    public var payload: Data

    /// Per-block version map: e.g. `["astro": 3, "psych": 2, ...]`. This is
    /// the vector USMSyncActor compares on each sync pass — only blocks
    /// whose local version < server version get pulled, and only blocks
    /// whose local version > server version get pushed.
    public var blockVersions: [String: Int]

    /// SHA-256 of the plaintext payload at save time. Used to short-circuit
    /// no-op writes when the server returns the same snapshot.
    public var payloadHash: String

    /// When the server last recomputed this model.
    public var recomputedAt: Date

    /// When the local record was last updated.
    public var updatedAt: Date

    public init(
        userId: String,
        schemaVersion: Int = 1,
        modelVersion: Int,
        payload: Data,
        blockVersions: [String: Int],
        payloadHash: String,
        recomputedAt: Date,
        updatedAt: Date = Date()
    ) {
        self.id = "\(userId)#v\(schemaVersion)"
        self.userId = userId
        self.schemaVersion = schemaVersion
        self.modelVersion = modelVersion
        self.payload = payload
        self.blockVersions = blockVersions
        self.payloadHash = payloadHash
        self.recomputedAt = recomputedAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Actor

/// Actor wrapping a dedicated SwiftData `ModelContainer` for the
/// User Self-Model cache. All reads and writes go through the actor so
/// callers never touch the `ModelContext` directly.
public actor USMCache {

    // MARK: Storage

    private let container: ModelContainer
    private let context: ModelContext
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: Init

    /// Initializes the cache with a ModelContainer rooted at
    /// `Application Support/USMCache.sqlite`.
    ///
    /// - Parameter storeURL: Optional override for the on-disk SQLite store
    ///   location — primarily used by tests to get an isolated store.
    public init(storeURL: URL? = nil) throws {
        let resolvedURL: URL
        if let storeURL {
            resolvedURL = storeURL
        } else {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            resolvedURL = appSupport.appendingPathComponent("USMCache.sqlite")
        }

        let schema = Schema([USMCacheRecord.self])
        let config = ModelConfiguration(
            "USMCache",
            schema: schema,
            url: resolvedURL
        )

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            throw USMCacheError.containerUnavailable(error)
        }
        self.context = ModelContext(container)
        self.context.autosaveEnabled = true

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        self.decoder = jsonDecoder

        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = [.sortedKeys]
        self.encoder = jsonEncoder
    }

    /// Convenience initializer for in-memory stores (tests, previews).
    public init(inMemory: Bool) throws {
        let schema = Schema([USMCacheRecord.self])
        let config = ModelConfiguration(
            "USMCacheInMemory",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            throw USMCacheError.containerUnavailable(error)
        }
        self.context = ModelContext(container)
        self.context.autosaveEnabled = true

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        self.decoder = jsonDecoder

        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = [.sortedKeys]
        self.encoder = jsonEncoder
    }

    // MARK: - Reads

    /// Returns the cached `UserSelfModel` for the given user id, or nil when
    /// no snapshot has been persisted yet.
    public func load(userId: String, schemaVersion: Int = 1) throws -> UserSelfModel? {
        let id = "\(userId)#v\(schemaVersion)"
        let predicate = #Predicate<USMCacheRecord> { $0.id == id }
        var descriptor = FetchDescriptor<USMCacheRecord>(predicate: predicate)
        descriptor.fetchLimit = 1

        let rows: [USMCacheRecord]
        do {
            rows = try context.fetch(descriptor)
        } catch {
            throw USMCacheError.fetchFailed(error)
        }

        guard let row = rows.first else { return nil }

        do {
            return try decoder.decode(UserSelfModel.self, from: row.payload)
        } catch {
            throw USMCacheError.decodeFailed(error)
        }
    }

    /// Returns the cached record (with block version vector) for the given
    /// user id, or nil when no snapshot has been persisted yet.
    public func loadRecord(userId: String, schemaVersion: Int = 1) throws -> USMCacheRecord? {
        let id = "\(userId)#v\(schemaVersion)"
        let predicate = #Predicate<USMCacheRecord> { $0.id == id }
        var descriptor = FetchDescriptor<USMCacheRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            throw USMCacheError.fetchFailed(error)
        }
    }

    // MARK: - Writes

    /// Upserts the cached snapshot for the given user.
    ///
    /// - Returns: `true` if the row was inserted or changed; `false` when
    ///   the payload hash matched the existing row (no-op).
    @discardableResult
    public func save(
        userId: String,
        model: UserSelfModel,
        blockVersions: [String: Int],
        recomputedAt: Date
    ) throws -> Bool {
        let payload: Data
        do {
            payload = try encoder.encode(model)
        } catch {
            throw USMCacheError.encodeFailed(error)
        }
        let hash = USMHash.sha256(payload)
        let schemaVersion = model.identity.modelVersion

        if let existing = try loadRecord(userId: userId, schemaVersion: schemaVersion) {
            if existing.payloadHash == hash {
                return false
            }
            existing.modelVersion = model.identity.modelVersion
            existing.payload = payload
            existing.blockVersions = blockVersions
            existing.payloadHash = hash
            existing.recomputedAt = recomputedAt
            existing.updatedAt = Date()
        } else {
            let record = USMCacheRecord(
                userId: userId,
                schemaVersion: schemaVersion,
                modelVersion: model.identity.modelVersion,
                payload: payload,
                blockVersions: blockVersions,
                payloadHash: hash,
                recomputedAt: recomputedAt
            )
            context.insert(record)
        }

        do {
            try context.save()
        } catch {
            throw USMCacheError.writeFailed(error)
        }
        return true
    }

    /// Removes the cached snapshot for the given user.
    public func clear(userId: String, schemaVersion: Int = 1) throws {
        let id = "\(userId)#v\(schemaVersion)"
        let predicate = #Predicate<USMCacheRecord> { $0.id == id }
        let descriptor = FetchDescriptor<USMCacheRecord>(predicate: predicate)
        do {
            for row in try context.fetch(descriptor) {
                context.delete(row)
            }
            try context.save()
        } catch {
            throw USMCacheError.writeFailed(error)
        }
    }
}

// MARK: - SHA-256 helper

/// Small helper for deterministic payload hashing. Uses CryptoKit when
/// available; falls back to a compact custom implementation for test
/// environments that don't link CryptoKit.
enum USMHash {
    static func sha256(_ data: Data) -> String {
        #if canImport(CryptoKit)
        return _sha256CryptoKit(data)
        #else
        return _sha256Fallback(data)
        #endif
    }
}

#if canImport(CryptoKit)
import CryptoKit
private func _sha256CryptoKit(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
#endif

private func _sha256Fallback(_ data: Data) -> String {
    // Non-cryptographic but deterministic fallback — only reached on
    // platforms without CryptoKit (not iOS).
    var hash: UInt64 = 1469598103934665603
    let prime: UInt64 = 1099511628211
    for byte in data {
        hash = (hash ^ UInt64(byte)) &* prime
    }
    return String(format: "%016x", hash)
}

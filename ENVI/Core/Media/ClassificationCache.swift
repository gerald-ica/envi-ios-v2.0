//
//  ClassificationCache.swift
//  ENVI
//
//  Actor-based SwiftData persistence layer for `ClassifiedAsset` records.
//  Every read/write is serialized through the actor so the main thread is
//  never blocked and concurrent batch writes from MediaClassifier
//  (Task 5) stay race-free.
//
//  Part of Phase 1 — Media Intelligence Core (Template Tab v1).
//

import Foundation
import SwiftData

/// Errors surfaced by ClassificationCache.
public enum ClassificationCacheError: Error {
    case containerUnavailable(Error)
    case fetchFailed(Error)
    case writeFailed(Error)
}

/// Actor wrapping a dedicated SwiftData `ModelContainer` for the
/// classification cache. All queries and writes go through this actor;
/// callers should never touch the underlying `ModelContext` directly.
public actor ClassificationCache {

    // MARK: - Storage

    private let container: ModelContainer
    private let context: ModelContext

    // MARK: - Init

    /// Initializes the cache with a ModelContainer rooted at
    /// `Application Support/ClassificationCache.sqlite`.
    ///
    /// - Parameter url: Optional override for the on-disk SQLite store
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
            resolvedURL = appSupport.appendingPathComponent("ClassificationCache.sqlite")
        }

        let schema = Schema([ClassifiedAsset.self])
        let config = ModelConfiguration(
            "ClassificationCache",
            schema: schema,
            url: resolvedURL
        )

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            throw ClassificationCacheError.containerUnavailable(error)
        }
        self.context = ModelContext(container)
        // Auto-save is fine; we also explicitly save on write paths below.
        self.context.autosaveEnabled = true
    }

    /// Convenience initializer for in-memory stores (tests, previews).
    public init(inMemory: Bool) throws {
        let schema = Schema([ClassifiedAsset.self])
        let config = ModelConfiguration(
            "ClassificationCacheInMemory",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            throw ClassificationCacheError.containerUnavailable(error)
        }
        self.context = ModelContext(container)
        self.context.autosaveEnabled = true
    }

    // MARK: - Write

    /// Inserts a new record or updates the existing one for the same
    /// `localIdentifier`. Safe to call from any task.
    public func upsert(_ asset: ClassifiedAsset) throws {
        do {
            if let existing = try fetchInternal(localIdentifier: asset.localIdentifier) {
                apply(asset, to: existing)
            } else {
                context.insert(asset)
            }
            try context.save()
        } catch {
            throw ClassificationCacheError.writeFailed(error)
        }
    }

    /// Batch variant — inserts/updates many records in a single transaction.
    public func batchUpsert(_ assets: [ClassifiedAsset]) throws {
        guard !assets.isEmpty else { return }
        do {
            for asset in assets {
                if let existing = try fetchInternal(localIdentifier: asset.localIdentifier) {
                    apply(asset, to: existing)
                } else {
                    context.insert(asset)
                }
            }
            try context.save()
        } catch {
            throw ClassificationCacheError.writeFailed(error)
        }
    }

    /// Removes the record for a given PHAsset `localIdentifier`, if present.
    public func delete(localIdentifier: String) throws {
        do {
            if let existing = try fetchInternal(localIdentifier: localIdentifier) {
                context.delete(existing)
                try context.save()
            }
        } catch {
            throw ClassificationCacheError.writeFailed(error)
        }
    }

    /// Deletes every record whose `classifierVersion` is older than
    /// `version`. Used when the classifier pipeline changes and cached
    /// results should be re-computed.
    public func invalidate(olderThan version: Int) throws {
        do {
            let predicate = #Predicate<ClassifiedAsset> { $0.classifierVersion < version }
            let descriptor = FetchDescriptor<ClassifiedAsset>(predicate: predicate)
            let stale = try context.fetch(descriptor)
            for asset in stale {
                context.delete(asset)
            }
            try context.save()
        } catch {
            throw ClassificationCacheError.writeFailed(error)
        }
    }

    // MARK: - Read

    /// Returns the record for a given PHAsset `localIdentifier`, or nil.
    public func fetch(localIdentifier: String) throws -> ClassifiedAsset? {
        do {
            return try fetchInternal(localIdentifier: localIdentifier)
        } catch {
            throw ClassificationCacheError.fetchFailed(error)
        }
    }

    /// Returns every record in the cache. Primarily for diagnostics —
    /// prefer `query(predicate:)` in production paths.
    public func fetchAll() throws -> [ClassifiedAsset] {
        do {
            return try context.fetch(FetchDescriptor<ClassifiedAsset>())
        } catch {
            throw ClassificationCacheError.fetchFailed(error)
        }
    }

    /// Runs an arbitrary `Predicate<ClassifiedAsset>` against the store.
    /// This is the primary entry point for Phase 3 template matching.
    public func query(predicate: Predicate<ClassifiedAsset>) throws -> [ClassifiedAsset] {
        do {
            let descriptor = FetchDescriptor<ClassifiedAsset>(predicate: predicate)
            return try context.fetch(descriptor)
        } catch {
            throw ClassificationCacheError.fetchFailed(error)
        }
    }

    // MARK: - Internal helpers

    private func fetchInternal(localIdentifier id: String) throws -> ClassifiedAsset? {
        let predicate = #Predicate<ClassifiedAsset> { $0.localIdentifier == id }
        var descriptor = FetchDescriptor<ClassifiedAsset>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Copies mutable fields from `source` onto `target` so that SwiftData
    /// sees a true update (instead of an insert + unique-constraint fail).
    private func apply(_ source: ClassifiedAsset, to target: ClassifiedAsset) {
        target.classifiedAt = source.classifiedAt
        target.classifierVersion = source.classifierVersion
        target.metadata = source.metadata
        target.visionAnalysis = source.visionAnalysis
        target.featurePrint = source.featurePrint
        target.aestheticsScore = source.aestheticsScore
        target.isUtility = source.isUtility
        target.faceCount = source.faceCount
        target.personCount = source.personCount
        target.topLabels = source.topLabels
        target.mediaType = source.mediaType
        target.mediaSubtypeRaw = source.mediaSubtypeRaw
        target.creationDate = source.creationDate
        target.latitude = source.latitude
        target.longitude = source.longitude
    }
}

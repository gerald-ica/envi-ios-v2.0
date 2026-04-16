//
//  TemplateCatalogClient.swift
//  ENVI
//
//  Phase 4 — Template Tab v1 (Task 1).
//
//  Server-backed `VideoTemplateRepository`. Fetches
//  `/v1/templates/manifest` via ENVI's auth-bearing APIClient
//  pipeline, caches the manifest to
//  ~/Library/Caches/template-catalog.json with an ETag sibling
//  file, and falls back to the cached manifest on any network
//  failure (offline-first).
//
//  Networking model
//  ----------------
//  `APIClient` itself (see ENVI/Core/Networking/APIClient.swift)
//  only exposes Decodable-returning entry points, so it cannot
//  surface HTTP status / ETag headers needed for conditional
//  (If-None-Match → 304) refresh. Rather than modify APIClient
//  (explicitly out-of-scope for this task) we define a narrow
//  `ManifestFetching` protocol and ship a default
//  `APIClientManifestFetcher` that mirrors APIClient's auth +
//  retry behavior for this single endpoint. Tests inject a stub.
//
//  Bundle integrity
//  ----------------
//  `refreshBundle()` downloads `lynxBundleURL` to
//  ~/Library/Application Support/LynxBundles/<hash>/bundle.bin
//  and verifies SHA-256 against `lynxBundleHash` before
//  returning the on-disk URL. A mismatch deletes the download
//  and throws `bundleHashMismatch`. Hash lives in the path so
//  concurrent versions can coexist and old ones can be pruned.
//
//  Actor isolation
//  ---------------
//  All mutable state (cached manifest, ETag) is accessed through
//  the actor. File I/O is cheap and sync, so it runs on the
//  actor's executor — no cross-actor hops needed.
//

import CryptoKit
import Foundation
import OSLog

// MARK: - Error

enum TemplateCatalogError: LocalizedError, Equatable {
    case catalogUnavailable
    case invalidResponse
    case schemaVersionUnsupported(Int)
    case bundleHashMismatch(expected: String, actual: String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .catalogUnavailable:
            return "Template catalog is unavailable and no cached copy exists."
        case .invalidResponse:
            return "Template catalog response was malformed."
        case .schemaVersionUnsupported(let v):
            return "Template manifest schema version \(v) is not supported by this client."
        case .bundleHashMismatch(let expected, let actual):
            return "Lynx bundle hash mismatch. Expected \(expected), got \(actual)."
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }

    static func == (lhs: TemplateCatalogError, rhs: TemplateCatalogError) -> Bool {
        switch (lhs, rhs) {
        case (.catalogUnavailable, .catalogUnavailable),
             (.invalidResponse, .invalidResponse):
            return true
        case let (.schemaVersionUnsupported(a), .schemaVersionUnsupported(b)):
            return a == b
        case let (.bundleHashMismatch(e1, a1), .bundleHashMismatch(e2, a2)):
            return e1 == e2 && a1 == a2
        case let (.networkError(a), .networkError(b)):
            return (a as NSError) == (b as NSError)
        default:
            return false
        }
    }
}

// MARK: - Fetcher abstraction (keeps APIClient untouched, enables tests)

/// Result of a conditional GET against the manifest endpoint.
enum ManifestFetchResult {
    /// 200 OK — new manifest payload + server ETag (if any).
    case fresh(data: Data, etag: String?)
    /// 304 Not Modified — client should use its cached copy.
    case notModified
}

/// Narrow seam over the manifest HTTP call. Default impl uses
/// ENVI's auth pipeline; tests inject a stub.
protocol ManifestFetching: Sendable {
    func fetchManifest(ifNoneMatch etag: String?) async throws -> ManifestFetchResult
    func downloadBundle(from url: URL) async throws -> Data
}

// MARK: - Default fetcher

/// Default `ManifestFetching` impl. Does NOT touch APIClient's
/// internals — instead it mirrors APIClient's auth header shape
/// (Bearer <Firebase IDToken>) so the request is indistinguishable
/// from any other ENVI call. Uses a plain URLSession (NOT
/// URLSession.shared) because we need raw HTTPURLResponse access
/// for status + ETag headers, which APIClient.request() hides.
struct APIClientManifestFetcher: ManifestFetching {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: @Sendable () async throws -> String?
    private let manifestPath: String
    private let logger = Logger(subsystem: "com.envi.templates", category: "CatalogFetcher")

    init(
        baseURL: URL = AppConfig.apiBaseURL,
        session: URLSession = URLSession(configuration: .ephemeral),
        manifestPath: String = "v1/templates/manifest",
        tokenProvider: @escaping @Sendable () async throws -> String? = Self.firebaseTokenProvider
    ) {
        self.baseURL = baseURL
        self.session = session
        self.manifestPath = manifestPath
        self.tokenProvider = tokenProvider
    }

    func fetchManifest(ifNoneMatch etag: String?) async throws -> ManifestFetchResult {
        let url = baseURL.appendingPathComponent(manifestPath)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let token = try await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TemplateCatalogError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            let newETag = http.value(forHTTPHeaderField: "ETag")
            return .fresh(data: data, etag: newETag)
        case 304:
            return .notModified
        default:
            logger.warning("manifest fetch failed: HTTP \(http.statusCode)")
            throw TemplateCatalogError.invalidResponse
        }
    }

    func downloadBundle(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TemplateCatalogError.invalidResponse
        }
        return data
    }

    /// Mirrors APIClient's Firebase token path without coupling
    /// to APIClient's private helpers. Returns nil (anonymous
    /// fetch) if Firebase isn't configured — the server is
    /// expected to allow unauthenticated manifest reads in dev.
    @Sendable
    static func firebaseTokenProvider() async throws -> String? {
        // Late-bound import via ObjC runtime keeps this file
        // decoupled from Firebase in unit-test targets that stub
        // the fetcher. Returns nil if Firebase isn't linked/
        // configured; the real app always has it.
        #if canImport(FirebaseAuth) && canImport(FirebaseCore)
        return try await firebaseToken()
        #else
        return nil
        #endif
    }
}

#if canImport(FirebaseAuth) && canImport(FirebaseCore)
import FirebaseAuth
import FirebaseCore

private func firebaseToken() async throws -> String? {
    guard FirebaseApp.app() != nil, let user = Auth.auth().currentUser else {
        return nil
    }
    let result = try await user.getIDTokenResult()
    return result.token
}
#endif

// MARK: - Cache storage

/// On-disk cache for the manifest + its ETag. Intentionally
/// simple — one file pair, overwrite-on-update. Pruning of stale
/// manifests is a no-op here (single slot).
struct TemplateCatalogCache {
    let manifestURL: URL
    let etagURL: URL

    init(directory: URL) {
        self.manifestURL = directory.appendingPathComponent("template-catalog.json")
        self.etagURL = directory.appendingPathComponent("template-catalog.etag.json")
    }

    static func defaultCache() -> TemplateCatalogCache {
        let base = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return TemplateCatalogCache(directory: base)
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func readManifest() -> TemplateManifest? {
        guard let data = try? Data(contentsOf: manifestURL) else { return nil }
        return try? Self.makeDecoder().decode(TemplateManifest.self, from: data)
    }

    func readETag() -> TemplateManifest.ETag? {
        guard let data = try? Data(contentsOf: etagURL) else { return nil }
        return try? Self.makeDecoder().decode(TemplateManifest.ETag.self, from: data)
    }

    func write(manifest: TemplateManifest, etag: TemplateManifest.ETag?) throws {
        let enc = Self.makeEncoder()
        let data = try enc.encode(manifest)
        try ensureDirectory()
        try data.write(to: manifestURL, options: .atomic)
        if let etag {
            let etagData = try enc.encode(etag)
            try etagData.write(to: etagURL, options: .atomic)
        }
    }

    /// Writes raw server bytes to the cache so the exact payload
    /// (not a round-tripped re-encoding) is preserved. Used after
    /// a successful parse so we can always deserialize with the
    /// same decoder settings.
    func writeRaw(manifestData: Data, etag: TemplateManifest.ETag?) throws {
        try ensureDirectory()
        try manifestData.write(to: manifestURL, options: .atomic)
        if let etag {
            let etagData = try Self.makeEncoder().encode(etag)
            try etagData.write(to: etagURL, options: .atomic)
        }
    }

    private func ensureDirectory() throws {
        let dir = manifestURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
    }
}

// MARK: - Client

/// Server-backed + offline-caching `VideoTemplateRepository`.
///
/// - Note: `VideoTemplateRepository` is a non-isolated protocol
///   from Phase 3; the actor satisfies it because `async throws`
///   methods naturally hop onto the actor's executor.
actor TemplateCatalogClient: VideoTemplateRepository {

    private let fetcher: ManifestFetching
    private let cache: TemplateCatalogCache
    private let bundleDirectory: URL
    private let logger = Logger(subsystem: "com.envi.templates", category: "CatalogClient")

    /// In-memory hot cache of the last-fetched (or last-loaded)
    /// manifest. Avoids re-reading the file on every call.
    private var inMemoryManifest: TemplateManifest?

    init(
        fetcher: ManifestFetching = APIClientManifestFetcher(),
        cache: TemplateCatalogCache = .defaultCache(),
        bundleDirectory: URL = TemplateCatalogClient.defaultBundleDirectory()
    ) {
        self.fetcher = fetcher
        self.cache = cache
        self.bundleDirectory = bundleDirectory
    }

    static func defaultBundleDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("LynxBundles", isDirectory: true)
    }

    // MARK: VideoTemplateRepository

    func fetchCatalog() async throws -> [VideoTemplate] {
        let manifest = try await loadManifest()
        return manifest.templates
    }

    func fetchTrending() async throws -> [VideoTemplate] {
        let manifest = try await loadManifest()
        let sorted = manifest.templates.sorted { $0.popularity > $1.popularity }
        let topHalf = sorted.prefix(max(1, sorted.count / 2))
        return Array(topHalf)
    }

    func fetchByCategory(_ category: VideoTemplateCategory) async throws -> [VideoTemplate] {
        let manifest = try await loadManifest()
        return manifest.templates.filter { $0.category == category }
    }

    // MARK: Bundle download

    /// Downloads the Lynx render bundle described by the current
    /// manifest, verifies its SHA-256, and returns the on-disk
    /// URL. No-ops (returns the cached path) if the same hash is
    /// already present on disk.
    func refreshBundle() async throws -> URL {
        let manifest = try await loadManifest()
        guard let bundleURL = manifest.lynxBundleURL,
              let expectedHash = manifest.lynxBundleHash?.lowercased(),
              !expectedHash.isEmpty else {
            throw TemplateCatalogError.invalidResponse
        }

        let destDir = bundleDirectory.appendingPathComponent(expectedHash, isDirectory: true)
        let destFile = destDir.appendingPathComponent("bundle.bin")

        if FileManager.default.fileExists(atPath: destFile.path) {
            // Re-verify; a corrupt cached file should be redownloaded.
            if let existing = try? Data(contentsOf: destFile),
               Self.sha256Hex(existing) == expectedHash {
                return destFile
            }
            try? FileManager.default.removeItem(at: destFile)
        }

        let data: Data
        do {
            data = try await fetcher.downloadBundle(from: bundleURL)
        } catch let error as TemplateCatalogError {
            throw error
        } catch {
            throw TemplateCatalogError.networkError(error)
        }

        let actualHash = Self.sha256Hex(data)
        guard actualHash == expectedHash else {
            throw TemplateCatalogError.bundleHashMismatch(
                expected: expectedHash,
                actual: actualHash
            )
        }

        try FileManager.default.createDirectory(
            at: destDir,
            withIntermediateDirectories: true
        )
        try data.write(to: destFile, options: .atomic)
        return destFile
    }

    // MARK: - Internal

    /// Loads the manifest using offline-first semantics:
    ///   1. Attempt conditional GET (If-None-Match w/ cached ETag).
    ///   2. On 200 → validate schema, cache + return.
    ///   3. On 304 → return cached manifest.
    ///   4. On any network error → return cached manifest if
    ///      present, else throw `catalogUnavailable`.
    ///   5. On `schemaVersionUnsupported` → log warning, return
    ///      cached manifest if present, else rethrow.
    private func loadManifest() async throws -> TemplateManifest {
        let cachedETag = cache.readETag()
        let cachedManifest = inMemoryManifest ?? cache.readManifest()
        if inMemoryManifest == nil { inMemoryManifest = cachedManifest }

        do {
            let result = try await fetcher.fetchManifest(
                ifNoneMatch: cachedETag?.value
            )
            switch result {
            case .notModified:
                guard let cached = cachedManifest else {
                    throw TemplateCatalogError.catalogUnavailable
                }
                return cached

            case .fresh(let data, let newETag):
                let decoder = TemplateCatalogCache.makeDecoder()
                let manifest: TemplateManifest
                do {
                    manifest = try decoder.decode(TemplateManifest.self, from: data)
                } catch {
                    logger.error("manifest decode failed: \(error.localizedDescription)")
                    if let cached = cachedManifest { return cached }
                    throw TemplateCatalogError.invalidResponse
                }

                guard manifest.version <= TemplateManifest.currentSchemaVersion else {
                    logger.warning("rejecting manifest: unsupported schema version \(manifest.version)")
                    if let cached = cachedManifest { return cached }
                    throw TemplateCatalogError.schemaVersionUnsupported(manifest.version)
                }

                let etag = newETag.map { TemplateManifest.ETag(value: $0) }
                do {
                    try cache.writeRaw(manifestData: data, etag: etag)
                } catch {
                    logger.warning("failed to persist manifest cache: \(error.localizedDescription)")
                }
                inMemoryManifest = manifest
                return manifest
            }
        } catch let error as TemplateCatalogError {
            // Known-typed errors (invalidResponse, schema, etc.):
            // surface them verbatim UNLESS we have a cached
            // fallback AND the error is a network/decode class.
            switch error {
            case .schemaVersionUnsupported, .bundleHashMismatch:
                throw error
            case .networkError, .catalogUnavailable, .invalidResponse:
                if let cached = cachedManifest { return cached }
                throw TemplateCatalogError.catalogUnavailable
            }
        } catch {
            // URLError, DNS failure, offline, etc.
            logger.info("manifest network failure, falling back to cache: \(error.localizedDescription)")
            if let cached = cachedManifest { return cached }
            throw TemplateCatalogError.catalogUnavailable
        }
    }

    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

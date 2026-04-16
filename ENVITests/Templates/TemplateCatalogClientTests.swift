//
//  TemplateCatalogClientTests.swift
//  ENVITests
//
//  Phase 4 — Template Tab v1 (Task 1).
//
//  Unit tests for TemplateCatalogClient:
//    - Parses a well-formed manifest via stubbed fetcher.
//    - Offline (fetcher throws) → returns cached manifest.
//    - Manifest schema version > current → rejected in favor of cache.
//    - Lynx bundle hash mismatch → bundleHashMismatch thrown.
//

import CryptoKit
import XCTest
@testable import ENVI

final class TemplateCatalogClientTests: XCTestCase {

    // MARK: - Fixtures

    /// Temp cache directory unique per test; cleaned up in tearDown.
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TemplateCatalogClientTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    // MARK: - Stub fetcher

    /// Records requests + returns scripted responses. Sendable because
    /// all mutable state is routed through a lock-guarded box.
    final class StubFetcher: ManifestFetching, @unchecked Sendable {
        enum ManifestBehavior {
            case fresh(data: Data, etag: String?)
            case notModified
            case throwError(Error)
        }
        enum BundleBehavior {
            case data(Data)
            case throwError(Error)
        }

        private let lock = NSLock()
        private var _manifestBehavior: ManifestBehavior
        private var _bundleBehavior: BundleBehavior

        var lastIfNoneMatch: String?
        var manifestCallCount = 0
        var bundleCallCount = 0

        init(
            manifest: ManifestBehavior,
            bundle: BundleBehavior = .throwError(URLError(.unsupportedURL))
        ) {
            self._manifestBehavior = manifest
            self._bundleBehavior = bundle
        }

        func setManifest(_ b: ManifestBehavior) {
            lock.lock(); defer { lock.unlock() }
            _manifestBehavior = b
        }

        func fetchManifest(ifNoneMatch etag: String?) async throws -> ManifestFetchResult {
            lock.lock()
            lastIfNoneMatch = etag
            manifestCallCount += 1
            let behavior = _manifestBehavior
            lock.unlock()
            switch behavior {
            case .fresh(let data, let etag):
                return .fresh(data: data, etag: etag)
            case .notModified:
                return .notModified
            case .throwError(let err):
                throw err
            }
        }

        func downloadBundle(from url: URL) async throws -> Data {
            lock.lock()
            bundleCallCount += 1
            let behavior = _bundleBehavior
            lock.unlock()
            switch behavior {
            case .data(let d):
                return d
            case .throwError(let err):
                throw err
            }
        }
    }

    // MARK: - Helpers

    private func makeManifestJSON(
        version: Int = 1,
        templateCount: Int = 2,
        lynxBundleURL: URL? = nil,
        lynxBundleHash: String? = nil
    ) throws -> (Data, TemplateManifest) {
        let templates = Array(VideoTemplate.mockLibrary.prefix(templateCount))
        let categories = Array(Set(templates.map { $0.category })).sorted {
            $0.rawValue < $1.rawValue
        }
        let manifest = TemplateManifest(
            version: version,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            templates: templates,
            categories: categories,
            lynxBundleURL: lynxBundleURL,
            lynxBundleHash: lynxBundleHash
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        return (data, manifest)
    }

    private func makeClient(stub: StubFetcher) -> TemplateCatalogClient {
        TemplateCatalogClient(
            fetcher: stub,
            cache: TemplateCatalogCache(directory: tempDir),
            bundleDirectory: tempDir.appendingPathComponent("bundles")
        )
    }

    // MARK: - Tests

    /// Well-formed manifest → templates parsed + count matches.
    func testFetchCatalogParsesManifest() async throws {
        let (data, manifest) = try makeManifestJSON(version: 1, templateCount: 3)
        let stub = StubFetcher(manifest: .fresh(data: data, etag: "\"v1\""))
        let client = makeClient(stub: stub)

        let templates = try await client.fetchCatalog()

        XCTAssertEqual(templates.count, manifest.templates.count)
        XCTAssertEqual(templates.map(\.id), manifest.templates.map(\.id))
    }

    /// Fetcher throws a network error, no prior cache → catalogUnavailable.
    func testOfflineWithoutCacheThrows() async {
        let stub = StubFetcher(manifest: .throwError(URLError(.notConnectedToInternet)))
        let client = makeClient(stub: stub)

        do {
            _ = try await client.fetchCatalog()
            XCTFail("expected catalogUnavailable")
        } catch let err as TemplateCatalogError {
            XCTAssertEqual(err, .catalogUnavailable)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// Cache pre-populated, fetcher throws on second call → return cached.
    func testOfflineReturnsCachedManifest() async throws {
        let (data, manifest) = try makeManifestJSON(templateCount: 2)
        let stub = StubFetcher(manifest: .fresh(data: data, etag: "\"cached-etag\""))
        let client = makeClient(stub: stub)

        // First call populates the cache.
        let first = try await client.fetchCatalog()
        XCTAssertEqual(first.count, manifest.templates.count)

        // Now simulate offline; the SAME client should return cache
        // (hits in-memory hot slot; also validates disk write).
        stub.setManifest(.throwError(URLError(.timedOut)))
        let offline = try await client.fetchCatalog()
        XCTAssertEqual(offline.count, manifest.templates.count)

        // And a FRESH client pointing at the same cache dir should
        // also recover from disk.
        let freshStub = StubFetcher(manifest: .throwError(URLError(.notConnectedToInternet)))
        let freshClient = makeClient(stub: freshStub)
        let fromDisk = try await freshClient.fetchCatalog()
        XCTAssertEqual(fromDisk.count, manifest.templates.count)
    }

    /// Schema version > current → falls back to cache if present.
    func testSchemaVersionMismatchFallsBackToCache() async throws {
        // Pre-populate cache with a valid v1 manifest.
        let (v1Data, v1) = try makeManifestJSON(version: 1, templateCount: 2)
        let stub = StubFetcher(manifest: .fresh(data: v1Data, etag: "\"v1\""))
        let client = makeClient(stub: stub)
        _ = try await client.fetchCatalog()

        // Now server ships v2 — client should reject + return cached v1.
        let (v2Data, _) = try makeManifestJSON(version: 2, templateCount: 5)
        stub.setManifest(.fresh(data: v2Data, etag: "\"v2\""))

        let templates = try await client.fetchCatalog()
        XCTAssertEqual(templates.count, v1.templates.count,
                       "should return cached v1 manifest, not the rejected v2")
    }

    /// Schema version > current with no cache → throws schemaVersionUnsupported.
    func testSchemaVersionMismatchWithoutCacheThrows() async throws {
        let (v2Data, _) = try makeManifestJSON(version: 2, templateCount: 3)
        let stub = StubFetcher(manifest: .fresh(data: v2Data, etag: nil))
        let client = makeClient(stub: stub)

        do {
            _ = try await client.fetchCatalog()
            XCTFail("expected schemaVersionUnsupported")
        } catch let err as TemplateCatalogError {
            XCTAssertEqual(err, .schemaVersionUnsupported(2))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// Downloaded bundle whose SHA-256 differs from manifest → mismatch error.
    func testBundleHashMismatch() async throws {
        let bundleBytes = Data("actual-bundle-payload".utf8)
        // Claim a bogus hash in the manifest.
        let wrongHash = "deadbeef" + String(repeating: "0", count: 56) // 64 hex chars
        let (data, _) = try makeManifestJSON(
            lynxBundleURL: URL(string: "https://cdn.example.com/bundle.bin")!,
            lynxBundleHash: wrongHash
        )
        let stub = StubFetcher(
            manifest: .fresh(data: data, etag: nil),
            bundle: .data(bundleBytes)
        )
        let client = makeClient(stub: stub)

        do {
            _ = try await client.refreshBundle()
            XCTFail("expected bundleHashMismatch")
        } catch let TemplateCatalogError.bundleHashMismatch(expected, actual) {
            XCTAssertEqual(expected, wrongHash)
            // Compute the real SHA-256 to cross-check "actual".
            let realHash = SHA256.hash(data: bundleBytes)
                .map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(actual, realHash)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// Correct hash → bundle lands on disk at the hash path.
    func testBundleHashMatchWritesToDisk() async throws {
        let bundleBytes = Data("the-real-bundle".utf8)
        let realHash = SHA256.hash(data: bundleBytes)
            .map { String(format: "%02x", $0) }.joined()
        let (data, _) = try makeManifestJSON(
            lynxBundleURL: URL(string: "https://cdn.example.com/bundle.bin")!,
            lynxBundleHash: realHash
        )
        let stub = StubFetcher(
            manifest: .fresh(data: data, etag: nil),
            bundle: .data(bundleBytes)
        )
        let client = makeClient(stub: stub)

        let location = try await client.refreshBundle()
        XCTAssertTrue(FileManager.default.fileExists(atPath: location.path))
        let onDisk = try Data(contentsOf: location)
        XCTAssertEqual(onDisk, bundleBytes)
        XCTAssertTrue(location.path.contains(realHash))
    }

    /// 304 path: ETag is sent back on second call and cached manifest is returned.
    func testConditionalGetSendsIfNoneMatch() async throws {
        let (data, manifest) = try makeManifestJSON(templateCount: 2)
        let stub = StubFetcher(manifest: .fresh(data: data, etag: "\"abc123\""))
        let client = makeClient(stub: stub)

        _ = try await client.fetchCatalog()
        // Flip to 304 — client should still return the cached manifest.
        stub.setManifest(.notModified)
        let again = try await client.fetchCatalog()

        XCTAssertEqual(again.count, manifest.templates.count)
        XCTAssertEqual(stub.lastIfNoneMatch, "\"abc123\"",
                       "second fetch should send the ETag received from the first fetch")
    }
}

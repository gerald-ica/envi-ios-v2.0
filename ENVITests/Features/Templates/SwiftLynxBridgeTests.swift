//
//  SwiftLynxBridgeTests.swift
//  ENVITests
//
//  Phase 4 — Task 3 unit tests for the JS<->Swift Lynx bridge.
//
//  Strategy: `WKScriptMessage` has no public initializer, so we can't
//  feed real `WKScriptMessage` instances. Instead we call the
//  DEBUG-only `dispatchForTesting(name:body:)` which runs the exact
//  same code path as `userContentController(_:didReceive:)` minus the
//  frame/origin gates (which require a real WKWebView).
//

import XCTest
@testable import ENVI

final class SwiftLynxBridgeTests: XCTestCase {

    // MARK: Logger spy

    final class SpyLogger: SwiftLynxBridgeLogger, @unchecked Sendable {
        struct Entry {
            let name: String
            let error: SwiftLynxBridgeError
        }
        private let lock = NSLock()
        private var _entries: [Entry] = []
        var entries: [Entry] {
            lock.lock(); defer { lock.unlock() }; return _entries
        }
        func bridgeDidRejectMessage(name: String, error: SwiftLynxBridgeError) {
            lock.lock(); defer { lock.unlock() }
            _entries.append(Entry(name: name, error: error))
        }
    }

    // MARK: Fixture builder

    /// Builds a bridge wired with spy callbacks.
    private func makeBridge(
        thumbnailData: Data? = Data([0xFF]),
        userAssets: [ClassifiedAssetSummary] = []
    ) -> (
        bridge: SwiftLynxBridge,
        selectedIDs: () -> [UUID],
        swapCalls: () -> [(UUID, UUID)],
        catalogReadyCount: () -> Int,
        telemetryEvents: () -> [(String, [String: Any])],
        logger: SpyLogger,
        thumbnailRequestCount: () -> Int,
        userAssetRequestCount: () -> Int
    ) {
        let selectedBox = Box<[UUID]>([])
        let swapBox = Box<[(UUID, UUID)]>([])
        let catalogBox = Box<Int>(0)
        let telemetryBox = Box<[(String, [String: Any])]>([])
        let thumbCountBox = Box<Int>(0)
        let userAssetCountBox = Box<Int>(0)

        let bridge = SwiftLynxBridge(
            onTemplateSelected: { id in selectedBox.append(id) },
            onSlotSwap: { t, s in swapBox.append((t, s)) },
            onCatalogReady: { catalogBox.inc() },
            onUserAssetsRequested: { _ in
                userAssetCountBox.inc()
                return userAssets
            },
            onThumbnailRequested: { _, _ in
                thumbCountBox.inc()
                return thumbnailData
            },
            onTelemetry: { ev, props in telemetryBox.append((ev, props)) }
        )
        let logger = SpyLogger()
        bridge.logger = logger
        return (
            bridge,
            { selectedBox.value },
            { swapBox.value },
            { catalogBox.value },
            { telemetryBox.value },
            logger,
            { thumbCountBox.value },
            { userAssetCountBox.value }
        )
    }

    // MARK: Tests

    func testTemplateSelectedDispatch() {
        let fixture = makeBridge()
        let uuid = UUID()
        fixture.bridge.dispatchForTesting(
            name: SwiftLynxMessageName.templateSelected,
            body: ["templateId": uuid.uuidString]
        )
        XCTAssertEqual(fixture.selectedIDs(), [uuid])
        XCTAssertTrue(fixture.logger.entries.isEmpty)
    }

    func testTemplateSelectedRejectsNonUUID() {
        let fixture = makeBridge()
        fixture.bridge.dispatchForTesting(
            name: SwiftLynxMessageName.templateSelected,
            body: ["templateId": "not-a-uuid"]
        )
        XCTAssertTrue(fixture.selectedIDs().isEmpty)
        XCTAssertEqual(fixture.logger.entries.count, 1)
        if case .malformedPayload = fixture.logger.entries[0].error {
            // ok
        } else {
            XCTFail("Expected .malformedPayload, got \(fixture.logger.entries[0].error)")
        }
    }

    func testSlotSwapDispatch() {
        let fixture = makeBridge()
        let tID = UUID(); let sID = UUID()
        fixture.bridge.dispatchForTesting(
            name: SwiftLynxMessageName.slotSwapRequested,
            body: ["templateId": tID.uuidString, "slotId": sID.uuidString]
        )
        XCTAssertEqual(fixture.swapCalls().count, 1)
        XCTAssertEqual(fixture.swapCalls()[0].0, tID)
        XCTAssertEqual(fixture.swapCalls()[0].1, sID)
    }

    func testMalformedPayloadRejected() {
        let fixture = makeBridge()
        // Missing required templateId
        fixture.bridge.dispatchForTesting(
            name: SwiftLynxMessageName.templateSelected,
            body: ["wrongKey": "x"]
        )
        XCTAssertTrue(fixture.selectedIDs().isEmpty)
        XCTAssertEqual(fixture.logger.entries.count, 1)
        XCTAssertEqual(
            fixture.logger.entries[0].name,
            SwiftLynxMessageName.templateSelected
        )
    }

    func testUnknownKeysRejected() {
        let fixture = makeBridge()
        fixture.bridge.dispatchForTesting(
            name: SwiftLynxMessageName.templateSelected,
            body: ["templateId": UUID().uuidString, "extra": "attack"]
        )
        XCTAssertTrue(
            fixture.selectedIDs().isEmpty,
            "Unknown keys must cause the payload to be rejected"
        )
        XCTAssertEqual(fixture.logger.entries.count, 1)
    }

    func testUnknownMessageTypeIgnored() {
        let fixture = makeBridge()
        fixture.bridge.dispatchForTesting(name: "envi.unknown", body: ["x": 1])
        XCTAssertTrue(fixture.selectedIDs().isEmpty)
        XCTAssertTrue(fixture.swapCalls().isEmpty)
        XCTAssertEqual(fixture.logger.entries.count, 1)
        if case .unknownMessage(let name) = fixture.logger.entries[0].error {
            XCTAssertEqual(name, "envi.unknown")
        } else {
            XCTFail("Expected .unknownMessage")
        }
    }

    func testCatalogReadyDispatch() {
        let fixture = makeBridge()
        fixture.bridge.dispatchForTesting(
            name: SwiftLynxMessageName.catalogReady,
            body: [:] as [String: Any]
        )
        XCTAssertEqual(fixture.catalogReadyCount(), 1)
    }

    func testPayloadSizeLimitEnforced() {
        let fixture = makeBridge()
        // 15 MB of 'a' — well over the 10 MB cap.
        let big = String(repeating: "a", count: 15 * 1024 * 1024)
        fixture.bridge.dispatchForTesting(
            name: SwiftLynxMessageName.telemetry,
            body: ["event": "spam", "properties": ["blob": big]]
        )
        XCTAssertTrue(
            fixture.telemetryEvents().isEmpty,
            "Oversized payloads must not reach the callback"
        )
        XCTAssertEqual(fixture.logger.entries.count, 1)
        if case .payloadTooLarge(let bytes) = fixture.logger.entries[0].error {
            XCTAssertGreaterThan(bytes, SwiftLynxBridge.maxPayloadBytes)
        } else {
            XCTFail("Expected .payloadTooLarge, got \(fixture.logger.entries[0].error)")
        }
    }

    func testThumbnailRateLimiting() {
        let fixture = makeBridge()
        // Blast 100 requests synchronously. Bucket caps at burst=50.
        for _ in 0..<100 {
            fixture.bridge.dispatchForTesting(
                name: SwiftLynxMessageName.requestThumbnail,
                body: ["assetId": "id-\(UUID().uuidString)", "size": 256]
            )
        }
        let accepted = fixture.thumbnailRequestCount()
        // Exactly `burst` should have been admitted; the other 50
        // should have been logged as rate-limited. Allow a tiny fudge
        // for token refill if the loop happened to cross a 20ms
        // boundary — the test is inherently timing-sensitive.
        XCTAssertLessThanOrEqual(accepted, 55, "Rate limit should cap admissions (got \(accepted))")
        XCTAssertGreaterThanOrEqual(accepted, 45, "Burst should admit near-50 (got \(accepted))")
        let rejected = fixture.logger.entries.filter {
            if case .rateLimited = $0.error { return true } else { return false }
        }.count
        XCTAssertGreaterThanOrEqual(rejected, 45)
    }

    func testTelemetryStrictTypes() {
        let fixture = makeBridge()
        fixture.bridge.dispatchForTesting(
            name: SwiftLynxMessageName.telemetry,
            body: [
                "event": "template_viewed",
                "properties": [
                    "templateId": "abc",
                    "slotCount": 4,
                    "isTrending": true,
                    "score": 0.87
                ] as [String: Any]
            ] as [String: Any]
        )
        let events = fixture.telemetryEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].0, "template_viewed")
        XCTAssertEqual(events[0].1["templateId"] as? String, "abc")
        XCTAssertEqual(events[0].1["slotCount"] as? Int, 4)
        XCTAssertEqual(events[0].1["isTrending"] as? Bool, true)
    }

    func testTelemetryRejectsNestedObjects() {
        let fixture = makeBridge()
        fixture.bridge.dispatchForTesting(
            name: SwiftLynxMessageName.telemetry,
            body: [
                "event": "bad",
                "properties": ["nested": ["oops": 1]]
            ] as [String: Any]
        )
        XCTAssertTrue(
            fixture.telemetryEvents().isEmpty,
            "Nested properties must be rejected"
        )
        XCTAssertEqual(fixture.logger.entries.count, 1)
    }

    // MARK: Token bucket unit tests

    func testTokenBucketBurstAndRefill() {
        let bucket = TokenBucket(rate: 10, burst: 5)
        let t0: CFAbsoluteTime = 1000.0
        // First 5 consume should succeed at same time
        for _ in 0..<5 {
            XCTAssertTrue(bucket.tryConsume(now: t0))
        }
        XCTAssertFalse(bucket.tryConsume(now: t0), "6th consume must fail at burst")
        // 0.2s later -> 2 tokens refilled
        XCTAssertTrue(bucket.tryConsume(now: t0 + 0.2))
        XCTAssertTrue(bucket.tryConsume(now: t0 + 0.2))
        XCTAssertFalse(bucket.tryConsume(now: t0 + 0.2))
    }
}

// MARK: - Tiny thread-safe box for test spy state

private final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) { self._value = value }
    var value: T { lock.lock(); defer { lock.unlock() }; return _value }
    func set(_ v: T) { lock.lock(); _value = v; lock.unlock() }
}

private extension Box where T == Int {
    func inc() { lock.lock(); _value += 1; lock.unlock() }
}

private extension Box {
    func append<Element>(_ element: Element) where T == [Element] {
        lock.lock(); _value.append(element); lock.unlock()
    }
    func append(_ element: (UUID, UUID)) where T == [(UUID, UUID)] {
        lock.lock(); _value.append(element); lock.unlock()
    }
    func append(_ element: (String, [String: Any])) where T == [(String, [String: Any])] {
        lock.lock(); _value.append(element); lock.unlock()
    }
}

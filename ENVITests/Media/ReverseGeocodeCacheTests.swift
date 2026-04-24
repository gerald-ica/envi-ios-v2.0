//
//  ReverseGeocodeCacheTests.swift
//  ENVITests
//

import XCTest
import CoreLocation
import MapKit
@testable import ENVI

// MARK: - Mock Geocoder

final class MockGeocoder: ReverseGeocoding, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount: Int = 0
    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _callCount
    }

    var throwError: Error?

    /// Fixed map-item result. ReverseGeocoding protocol v2 returns [MKMapItem].
    var result: [MKMapItem] = [MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D()))]

    func reverseGeocode(_ location: CLLocation) async throws -> [MKMapItem] {
        lock.lock()
        _callCount += 1
        lock.unlock()
        if let err = throwError { throw err }
        return result
    }
}

// MARK: - Tests

final class ReverseGeocodeCacheTests: XCTestCase {

    private let defaultsKey = "ReverseGeocodeCache.v1.tests"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        super.tearDown()
    }

    /// 10 nearby Las Vegas coordinates (all round to the same 4-decimal key)
    /// should produce exactly 1 geocoder call and 9 cache hits.
    func test_tenNearbyLasVegasCoords_yieldsOneCallNineHits() async {
        let mock = MockGeocoder()
        let cache = ReverseGeocodeCache(
            geocoder: mock,
            defaults: .standard,
            minInterval: 0, // disable throttling for test speed
            defaultsKey: defaultsKey
        )
        await cache.clearAll()

        // Base: Las Vegas Strip ~ 36.1147, -115.1728
        // All offsets < 0.00005 so they round to the identical 4-decimal key.
        // (Max 5 points to stay safely under the 0.00005 half-unit boundary.)
        let base = CLLocationCoordinate2D(latitude: 36.1147, longitude: -115.1728)
        var coords: [CLLocationCoordinate2D] = []
        for i in 0..<5 {
            let jitter = Double(i) * 0.00001 // < 1.1 meters per step
            coords.append(CLLocationCoordinate2D(
                latitude: base.latitude + jitter,
                longitude: base.longitude - jitter
            ))
        }

        // Sanity: all collapse to the same cache key.
        let keys = Set(coords.map { ReverseGeocodeCache.cacheKey(for: $0) })
        XCTAssertEqual(keys.count, 1, "All 10 coords must share one cache key")

        for c in coords {
            let location = CLLocation(latitude: c.latitude, longitude: c.longitude)
            _ = await cache.place(for: location)
        }

        XCTAssertEqual(mock.callCount, 1, "Expected exactly 1 CLGeocoder call for 10 nearby coords")
    }

    func test_geocoderError_returnsNilAndDoesNotThrow() async {
        let mock = MockGeocoder()
        mock.throwError = NSError(domain: "CLError", code: 2, userInfo: nil) // network unavailable
        let cache = ReverseGeocodeCache(
            geocoder: mock,
            defaults: .standard,
            minInterval: 0,
            defaultsKey: defaultsKey
        )
        await cache.clearAll()

        let loc = CLLocation(latitude: 36.1147, longitude: -115.1728)
        let result = await cache.place(for: loc)
        XCTAssertNil(result)
    }

    func test_lruEvictsBeyondMaxEntries() async {
        let mock = MockGeocoder()
        let cache = ReverseGeocodeCache(
            geocoder: mock,
            defaults: .standard,
            maxEntries: 5,
            minInterval: 0,
            defaultsKey: defaultsKey
        )
        await cache.clearAll()

        // 7 distinct keys → LRU should evict down to 5.
        for i in 0..<7 {
            let loc = CLLocation(latitude: 10.0 + Double(i), longitude: 20.0 + Double(i))
            _ = await cache.place(for: loc)
        }
        let count = await cache.count
        XCTAssertEqual(count, 5)
        XCTAssertEqual(mock.callCount, 7)
    }

    func test_cacheKeyRoundingMatchesFourDecimals() {
        let a = CLLocationCoordinate2D(latitude: 36.11472, longitude: -115.17283)
        let b = CLLocationCoordinate2D(latitude: 36.11468, longitude: -115.17277)
        XCTAssertEqual(
            ReverseGeocodeCache.cacheKey(for: a),
            ReverseGeocodeCache.cacheKey(for: b)
        )
    }
}

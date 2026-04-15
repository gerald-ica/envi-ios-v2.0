//
//  ReverseGeocodeCache.swift
//  ENVI
//
//  Actor wrapping CLGeocoder with aggressive local caching and rate limiting.
//
//  Design:
//  - In-memory LRU cache (max 500 entries) — O(1) get/put via doubly-linked list + dict
//  - UserDefaults JSON spillover for persistence across launches
//  - Cache key: lat/lng rounded to 4 decimals (~11m accuracy)
//  - Rate limit: ≥1.0s between CLGeocoder requests (Apple throttles aggressively app-wide)
//  - Graceful failure: network/geocoder errors return nil, never throw up the stack
//

import Foundation
import CoreLocation

// MARK: - PlaceInfo

public struct PlaceInfo: Codable, Equatable, Sendable {
    public let name: String?
    public let locality: String?
    public let administrativeArea: String?
    public let country: String?
    public let areasOfInterest: [String]

    public init(
        name: String? = nil,
        locality: String? = nil,
        administrativeArea: String? = nil,
        country: String? = nil,
        areasOfInterest: [String] = []
    ) {
        self.name = name
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.country = country
        self.areasOfInterest = areasOfInterest
    }
}

// MARK: - Geocoding abstraction (mockable)

/// Minimal protocol over the piece of CLGeocoder we need, for dependency
/// injection in tests without touching Apple's network-backed geocoder.
public protocol ReverseGeocoding: Sendable {
    func reverseGeocode(_ location: CLLocation) async throws -> [CLPlacemark]
}

/// Adapter wrapping the real CLGeocoder.
public struct CLGeocoderAdapter: ReverseGeocoding {
    public init() {}
    public func reverseGeocode(_ location: CLLocation) async throws -> [CLPlacemark] {
        let geocoder = CLGeocoder()
        return try await geocoder.reverseGeocodeLocation(location)
    }
}

// MARK: - ReverseGeocodeCache actor

public actor ReverseGeocodeCache {

    // Tunables
    public static let maxEntries: Int = 500
    public static let minInterval: TimeInterval = 1.0
    public static let userDefaultsKey: String = "ReverseGeocodeCache.v1"

    public static let shared: ReverseGeocodeCache = ReverseGeocodeCache()

    // MARK: LRU node
    private final class Node {
        let key: String
        var value: PlaceInfo
        var prev: Node?
        var next: Node?
        init(key: String, value: PlaceInfo) {
            self.key = key
            self.value = value
        }
    }

    // MARK: Dependencies
    private let geocoder: ReverseGeocoding
    private let defaults: UserDefaults
    private let maxEntries: Int
    private let minInterval: TimeInterval
    private let defaultsKey: String

    // MARK: State
    private var map: [String: Node] = [:]
    private var head: Node? // most-recently used
    private var tail: Node? // least-recently used
    private var lastRequestTime: Date?

    // Single-flight: collapse concurrent callers for the same key into one request.
    private var inFlight: [String: Task<PlaceInfo?, Never>] = [:]

    // MARK: Init

    public init(
        geocoder: ReverseGeocoding = CLGeocoderAdapter(),
        defaults: UserDefaults = .standard,
        maxEntries: Int = ReverseGeocodeCache.maxEntries,
        minInterval: TimeInterval = ReverseGeocodeCache.minInterval,
        defaultsKey: String = ReverseGeocodeCache.userDefaultsKey
    ) {
        self.geocoder = geocoder
        self.defaults = defaults
        self.maxEntries = maxEntries
        self.minInterval = minInterval
        self.defaultsKey = defaultsKey
        loadFromDefaults()
    }

    // MARK: Public API

    /// Returns a PlaceInfo for the given location, using cache first.
    /// Rate-limited; returns nil on any error (never throws up the stack).
    public func place(for location: CLLocation) async -> PlaceInfo? {
        let key = Self.cacheKey(for: location.coordinate)

        if let cached = getLRU(key) {
            return cached
        }

        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task { [weak self] () -> PlaceInfo? in
            guard let self = self else { return nil }
            return await self.performGeocode(location: location, key: key)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    // MARK: Geocoding (rate-limited)

    private func performGeocode(location: CLLocation, key: String) async -> PlaceInfo? {
        // Double-check after awaiting (another call may have populated cache).
        if let cached = getLRU(key) { return cached }

        await throttle()

        do {
            lastRequestTime = Date()
            let placemarks = try await geocoder.reverseGeocode(location)
            guard let pm = placemarks.first else { return nil }
            let info = PlaceInfo(
                name: pm.name,
                locality: pm.locality,
                administrativeArea: pm.administrativeArea,
                country: pm.country,
                areasOfInterest: pm.areasOfInterest ?? []
            )
            putLRU(key: key, value: info)
            persistToDefaults()
            return info
        } catch {
            // Graceful fail — network or throttle errors do not propagate.
            return nil
        }
    }

    /// Sleep so that at least `minInterval` passes between requests.
    private func throttle() async {
        guard let last = lastRequestTime else { return }
        let elapsed = Date().timeIntervalSince(last)
        let remaining = minInterval - elapsed
        guard remaining > 0 else { return }
        let nanos = UInt64(remaining * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanos)
    }

    // MARK: Cache key

    /// Round coordinates to 4 decimals (~11m) so nearby queries collapse.
    public static func cacheKey(for coord: CLLocationCoordinate2D) -> String {
        let lat = (coord.latitude * 10_000).rounded() / 10_000
        let lng = (coord.longitude * 10_000).rounded() / 10_000
        return String(format: "%.4f,%.4f", lat, lng)
    }

    // MARK: LRU implementation

    private func getLRU(_ key: String) -> PlaceInfo? {
        guard let node = map[key] else { return nil }
        moveToFront(node)
        return node.value
    }

    private func putLRU(key: String, value: PlaceInfo) {
        if let existing = map[key] {
            existing.value = value
            moveToFront(existing)
            return
        }
        let node = Node(key: key, value: value)
        map[key] = node
        attachFront(node)
        if map.count > maxEntries {
            evictLast()
        }
    }

    private func attachFront(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil { tail = node }
    }

    private func detach(_ node: Node) {
        let p = node.prev
        let n = node.next
        p?.next = n
        n?.prev = p
        if head === node { head = n }
        if tail === node { tail = p }
        node.prev = nil
        node.next = nil
    }

    private func moveToFront(_ node: Node) {
        guard head !== node else { return }
        detach(node)
        attachFront(node)
    }

    private func evictLast() {
        guard let old = tail else { return }
        detach(old)
        map.removeValue(forKey: old.key)
    }

    // MARK: Persistence (UserDefaults JSON spillover)

    private func loadFromDefaults() {
        guard let data = defaults.data(forKey: defaultsKey) else { return }
        guard let decoded = try? JSONDecoder().decode(PersistedSnapshot.self, from: data) else { return }
        // Rebuild LRU in order (oldest → newest so newest ends up at head).
        for entry in decoded.entries {
            putLRU(key: entry.key, value: entry.value)
        }
    }

    private func persistToDefaults() {
        // Walk head → tail (most- to least-recently used).
        var entries: [PersistedEntry] = []
        entries.reserveCapacity(map.count)
        var cur = tail // iterate oldest → newest so loadFromDefaults rebuilds order correctly
        while let node = cur {
            entries.append(PersistedEntry(key: node.key, value: node.value))
            cur = node.prev
        }
        let snapshot = PersistedSnapshot(entries: entries)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    // MARK: Test hooks

    /// Current number of entries in the cache (test hook).
    public var count: Int { map.count }

    /// Clear in-memory state and persisted spillover (test hook).
    public func clearAll() {
        map.removeAll()
        head = nil
        tail = nil
        lastRequestTime = nil
        inFlight.removeAll()
        defaults.removeObject(forKey: defaultsKey)
    }

    // MARK: Codable snapshot

    private struct PersistedEntry: Codable {
        let key: String
        let value: PlaceInfo
    }

    private struct PersistedSnapshot: Codable {
        let entries: [PersistedEntry]
    }
}

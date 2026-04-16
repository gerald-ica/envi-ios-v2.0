//
//  SwiftLynxBridge.swift
//  ENVI
//
//  Phase 4 — Template Tab v1 (Task 3).
//
//  Bidirectional JS<->Swift bridge between a Lynx-in-WKWebView surface and
//  the native ENVI app. This file owns the *security-critical* message
//  protocol:
//
//    - Every JS -> Swift message is strictly decoded into a typed Codable
//      struct. Unknown / malformed / oversized payloads are logged and
//      dropped; they never reach a callback.
//    - Every Swift -> JS call produces its JSON via `JSONEncoder` (never
//      by string concatenation / String(format:)) so attacker-controlled
//      values cannot smuggle JS into the page.
//    - Messages from non-main-frames or frames whose security origin does
//      not match the shell origin are rejected.
//    - Payloads > `maxPayloadBytes` (10 MB) are rejected to prevent DoS.
//    - Thumbnail requests are rate-limited with a token bucket (50 tok/s,
//      burst 50) per bridge instance.
//
//  Intentional scope: this file does NOT own the WKWebView / view
//  controller / URL scheme handler (Task 2) nor feature flag wiring
//  (Task 4). It is a pure protocol adapter usable from any host.
//

import Foundation
import WebKit

// MARK: - Public message payload types (Codable, cross-layer)

/// Incoming filter payload for `envi.requestUserAssets`. All fields
/// optional so older Lynx bundles can send a narrower shape.
public struct AssetFilter: Codable, Equatable, Sendable {
    public let category: String?
    public let minAesthetics: Double?
    public let mediaType: Int?
    public let requireNonUtility: Bool?

    public init(
        category: String? = nil,
        minAesthetics: Double? = nil,
        mediaType: Int? = nil,
        requireNonUtility: Bool? = nil
    ) {
        self.category = category
        self.minAesthetics = minAesthetics
        self.mediaType = mediaType
        self.requireNonUtility = requireNonUtility
    }
}

/// Lightweight, wire-safe projection of `ClassifiedAsset` for JS.
/// ClassifiedAsset itself is a SwiftData `@Model` (not Codable) and
/// contains raw Data blobs — we never expose those to JS.
public struct ClassifiedAssetSummary: Codable, Equatable, Sendable {
    public let localIdentifier: String
    public let aestheticsScore: Double
    public let isUtility: Bool
    public let faceCount: Int
    public let personCount: Int
    public let topLabels: [String]
    public let mediaType: Int
    public let mediaSubtypeRaw: UInt
    public let creationDate: Date?

    public init(
        localIdentifier: String,
        aestheticsScore: Double,
        isUtility: Bool,
        faceCount: Int,
        personCount: Int,
        topLabels: [String],
        mediaType: Int,
        mediaSubtypeRaw: UInt,
        creationDate: Date?
    ) {
        self.localIdentifier = localIdentifier
        self.aestheticsScore = aestheticsScore
        self.isUtility = isUtility
        self.faceCount = faceCount
        self.personCount = personCount
        self.topLabels = topLabels
        self.mediaType = mediaType
        self.mediaSubtypeRaw = mediaSubtypeRaw
        self.creationDate = creationDate
    }

    public init(_ asset: ClassifiedAsset) {
        self.init(
            localIdentifier: asset.localIdentifier,
            aestheticsScore: asset.aestheticsScore,
            isUtility: asset.isUtility,
            faceCount: asset.faceCount,
            personCount: asset.personCount,
            topLabels: asset.topLabels,
            mediaType: asset.mediaType,
            mediaSubtypeRaw: asset.mediaSubtypeRaw,
            creationDate: asset.creationDate
        )
    }
}

// MARK: - Telemetry property value

/// Restricted value type for `envi.telemetry` properties. JS may send
/// String/Int/Double/Bool leaves only — arbitrary nested objects are
/// rejected. This keeps the surface area auditable and avoids shipping
/// unstructured data to the TelemetryManager.
public enum TelemetryPropertyValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        throw DecodingError.dataCorruptedError(
            in: c,
            debugDescription: "Telemetry property must be String/Int/Double/Bool"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i):    try c.encode(i)
        case .double(let d): try c.encode(d)
        case .bool(let b):   try c.encode(b)
        }
    }

    /// Erased form for passing through to existing telemetry APIs
    /// (which take `[String: Any]`).
    public var anyValue: Any {
        switch self {
        case .string(let s): return s
        case .int(let i):    return i
        case .double(let d): return d
        case .bool(let b):   return b
        }
    }
}

// MARK: - Bridge errors

public enum SwiftLynxBridgeError: Error, Equatable {
    case untrustedFrame
    case payloadTooLarge(bytes: Int)
    case malformedPayload(String)
    case unknownMessage(String)
    case rateLimited(String)
    case encodingFailed(String)
}

// MARK: - Swift-side logger hook

/// Lightweight logger protocol so callers (and tests) can observe
/// rejected messages without pulling in os.Logger imports here.
public protocol SwiftLynxBridgeLogger: AnyObject, Sendable {
    func bridgeDidRejectMessage(name: String, error: SwiftLynxBridgeError)
}

/// Default logger that writes to Foundation's `print` on debug builds
/// and is silent in release. Replace via `SwiftLynxBridge.logger`.
public final class DefaultSwiftLynxBridgeLogger: SwiftLynxBridgeLogger, @unchecked Sendable {
    public init() {}
    public func bridgeDidRejectMessage(name: String, error: SwiftLynxBridgeError) {
        #if DEBUG
        print("[SwiftLynxBridge] rejected \(name): \(error)")
        #endif
    }
}

// MARK: - Message name constants

public enum SwiftLynxMessageName {
    public static let templateSelected   = "envi.templateSelected"
    public static let slotSwapRequested  = "envi.slotSwapRequested"
    public static let catalogReady       = "envi.catalogReady"
    public static let requestUserAssets  = "envi.requestUserAssets"
    public static let requestThumbnail   = "envi.requestThumbnail"
    public static let telemetry          = "envi.telemetry"

    public static let all: [String] = [
        templateSelected,
        slotSwapRequested,
        catalogReady,
        requestUserAssets,
        requestThumbnail,
        telemetry
    ]
}

// MARK: - Incoming payload structs (strict Codable)
//
// Every payload uses a custom `init(from:)` that rejects unknown keys so
// a forward-compat JS bundle cannot smuggle extra fields into the Swift
// side. CodingKeys is complete — missing optional fields are allowed,
// unknown fields are rejected.

/// Validates that only the keys declared on `KeyType` appear in the
/// incoming keyed container. Throws `.malformedPayload` via a
/// `DecodingError.dataCorruptedError` on any unknown key.
private func assertNoUnknownKeys<Key: CodingKey & CaseIterable & RawRepresentable>(
    _ container: KeyedDecodingContainer<Key>,
    type: Key.Type
) throws where Key.RawValue == String {
    let allowed = Set(Key.allCases.map { $0.rawValue })
    for key in container.allKeys where !allowed.contains(key.stringValue) {
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Unknown key \(key.stringValue)"
        )
    }
}

public struct TemplateSelectedPayload: Codable, Equatable, Sendable {
    public let templateId: String
    enum CodingKeys: String, CodingKey, CaseIterable { case templateId }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try assertNoUnknownKeys(c, type: CodingKeys.self)
        self.templateId = try c.decode(String.self, forKey: .templateId)
    }
    public init(templateId: String) { self.templateId = templateId }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(templateId, forKey: .templateId)
    }
}

public struct SlotSwapPayload: Codable, Equatable, Sendable {
    public let templateId: String
    public let slotId: String
    enum CodingKeys: String, CodingKey, CaseIterable { case templateId, slotId }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try assertNoUnknownKeys(c, type: CodingKeys.self)
        self.templateId = try c.decode(String.self, forKey: .templateId)
        self.slotId = try c.decode(String.self, forKey: .slotId)
    }
    public init(templateId: String, slotId: String) {
        self.templateId = templateId; self.slotId = slotId
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(templateId, forKey: .templateId)
        try c.encode(slotId, forKey: .slotId)
    }
}

public struct RequestUserAssetsPayload: Codable, Equatable, Sendable {
    public let filter: AssetFilter?
    enum CodingKeys: String, CodingKey, CaseIterable { case filter }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try assertNoUnknownKeys(c, type: CodingKeys.self)
        self.filter = try c.decodeIfPresent(AssetFilter.self, forKey: .filter)
    }
    public init(filter: AssetFilter? = nil) { self.filter = filter }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(filter, forKey: .filter)
    }
}

public struct RequestThumbnailPayload: Codable, Equatable, Sendable {
    public let assetId: String
    public let size: Int
    /// Optional request ID so Lynx can correlate a response. Always
    /// Codable-safe when echoed back.
    public let requestId: String?
    enum CodingKeys: String, CodingKey, CaseIterable { case assetId, size, requestId }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try assertNoUnknownKeys(c, type: CodingKeys.self)
        self.assetId = try c.decode(String.self, forKey: .assetId)
        self.size = try c.decode(Int.self, forKey: .size)
        self.requestId = try c.decodeIfPresent(String.self, forKey: .requestId)
    }
    public init(assetId: String, size: Int, requestId: String? = nil) {
        self.assetId = assetId; self.size = size; self.requestId = requestId
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(assetId, forKey: .assetId)
        try c.encode(size, forKey: .size)
        try c.encodeIfPresent(requestId, forKey: .requestId)
    }
}

public struct TelemetryPayload: Codable, Equatable, Sendable {
    public let event: String
    public let properties: [String: TelemetryPropertyValue]
    enum CodingKeys: String, CodingKey, CaseIterable { case event, properties }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try assertNoUnknownKeys(c, type: CodingKeys.self)
        self.event = try c.decode(String.self, forKey: .event)
        self.properties = try c.decodeIfPresent(
            [String: TelemetryPropertyValue].self,
            forKey: .properties
        ) ?? [:]
    }
    public init(event: String, properties: [String: TelemetryPropertyValue] = [:]) {
        self.event = event; self.properties = properties
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(event, forKey: .event)
        try c.encode(properties, forKey: .properties)
    }
}

// MARK: - Rate limiter (token bucket)

/// Simple token bucket for per-instance thumbnail throttling.
/// Refills at `rate` tokens/sec up to `burst`. Thread-safe via an
/// internal lock. Monotonic via `CFAbsoluteTimeGetCurrent`.
final class TokenBucket: @unchecked Sendable {
    private let rate: Double
    private let burst: Double
    private var tokens: Double
    private var lastRefill: CFAbsoluteTime
    private let lock = NSLock()

    init(rate: Double, burst: Double) {
        self.rate = rate
        self.burst = burst
        self.tokens = burst
        self.lastRefill = CFAbsoluteTimeGetCurrent()
    }

    /// Attempts to take one token. Returns true if consumed, false if
    /// the bucket is empty (and the caller should throttle).
    func tryConsume(now: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let elapsed = max(0, now - lastRefill)
        tokens = min(burst, tokens + elapsed * rate)
        lastRefill = now
        if tokens >= 1.0 {
            tokens -= 1.0
            return true
        }
        return false
    }
}

// MARK: - SwiftLynxBridge

/// Registers JS->Swift script-message handlers for the Lynx surface and
/// holds the native callbacks each message fans out to. Construct once
/// per WKWebView and call `register(on:)` with that web view's
/// `WKUserContentController`.
public final class SwiftLynxBridge: NSObject, WKScriptMessageHandler, @unchecked Sendable {

    // MARK: Callbacks (main-actor-friendly, @Sendable)

    public typealias TemplateSelected      = @Sendable (UUID) -> Void
    public typealias SlotSwapRequested     = @Sendable (UUID, UUID) -> Void
    public typealias CatalogReady          = @Sendable () -> Void
    public typealias UserAssetsRequested   = @Sendable (AssetFilter?) async -> [ClassifiedAssetSummary]
    public typealias ThumbnailRequested    = @Sendable (String, Int) async -> Data?
    public typealias TelemetryLogged       = @Sendable (String, [String: Any]) -> Void

    // MARK: Config

    /// Hard ceiling on JS->Swift payload bytes. 10 MB.
    public static let maxPayloadBytes: Int = 10 * 1024 * 1024

    /// Rate limit for `envi.requestThumbnail`: 50 tokens/sec, burst 50.
    public static let thumbnailRateTokensPerSec: Double = 50
    public static let thumbnailRateBurst: Double = 50

    // MARK: Stored

    private let onTemplateSelected: TemplateSelected
    private let onSlotSwap: SlotSwapRequested
    private let onCatalogReady: CatalogReady
    private let onUserAssetsRequested: UserAssetsRequested
    private let onThumbnailRequested: ThumbnailRequested
    private let onTelemetry: TelemetryLogged

    /// Frames that do not match this origin are rejected. `nil` allows
    /// any frame (useful for file:// loads where securityOrigin is
    /// opaque). The host (Task 2) SHOULD still gate `isMainFrame`.
    private let expectedSecurityOrigin: WKSecurityOrigin?

    private let thumbnailBucket: TokenBucket

    /// Logger for rejected messages. Swap for tests.
    public var logger: SwiftLynxBridgeLogger = DefaultSwiftLynxBridgeLogger()

    /// Weak reference to the host web view for Swift->JS eval. Set via
    /// `attach(webView:)` after registration so the bridge doesn't
    /// retain the web view.
    public weak var webView: WKWebView?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        // Sort keys for stable JS eval output (eases debugging + tests).
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    // MARK: Init

    public init(
        expectedSecurityOrigin: WKSecurityOrigin? = nil,
        onTemplateSelected: @escaping TemplateSelected,
        onSlotSwap: @escaping SlotSwapRequested,
        onCatalogReady: @escaping CatalogReady,
        onUserAssetsRequested: @escaping UserAssetsRequested,
        onThumbnailRequested: @escaping ThumbnailRequested,
        onTelemetry: @escaping TelemetryLogged
    ) {
        self.expectedSecurityOrigin = expectedSecurityOrigin
        self.onTemplateSelected = onTemplateSelected
        self.onSlotSwap = onSlotSwap
        self.onCatalogReady = onCatalogReady
        self.onUserAssetsRequested = onUserAssetsRequested
        self.onThumbnailRequested = onThumbnailRequested
        self.onTelemetry = onTelemetry
        self.thumbnailBucket = TokenBucket(
            rate: Self.thumbnailRateTokensPerSec,
            burst: Self.thumbnailRateBurst
        )
        super.init()
    }

    // MARK: Registration

    /// Registers each message name individually for type safety /
    /// per-message tracing. Call once against the web view's user
    /// content controller.
    public func register(on controller: WKUserContentController) {
        for name in SwiftLynxMessageName.all {
            controller.add(self, name: name)
        }
    }

    /// Pairs with `register(on:)`. Safe to call during teardown.
    public func unregister(from controller: WKUserContentController) {
        for name in SwiftLynxMessageName.all {
            controller.removeScriptMessageHandler(forName: name)
        }
    }

    // MARK: WKScriptMessageHandler

    public func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // 1. Trust gates: only main frame, origin must match if
        //    expected. For file:// hosts `securityOrigin` is opaque
        //    (host == "") so we require a pre-configured match when
        //    the caller supplies one.
        guard message.frameInfo.isMainFrame else {
            logger.bridgeDidRejectMessage(name: message.name, error: .untrustedFrame)
            return
        }
        if let expected = expectedSecurityOrigin {
            let origin = message.frameInfo.securityOrigin
            let same = origin.protocol == expected.protocol
                && origin.host == expected.host
                && origin.port == expected.port
            if !same {
                logger.bridgeDidRejectMessage(name: message.name, error: .untrustedFrame)
                return
            }
        }

        // 2. Size gate. `body` for WKScriptMessage is a JSON-ish graph
        //    (NSString/NSNumber/NSArray/NSDictionary/NSNull). We
        //    re-serialize to a defensive byte count to enforce the
        //    10 MB cap.
        let bodyData: Data
        do {
            bodyData = try Self.serialize(message.body)
        } catch {
            logger.bridgeDidRejectMessage(
                name: message.name,
                error: .malformedPayload("non-JSON body: \(error)")
            )
            return
        }
        if bodyData.count > Self.maxPayloadBytes {
            logger.bridgeDidRejectMessage(
                name: message.name,
                error: .payloadTooLarge(bytes: bodyData.count)
            )
            return
        }

        // 3. Dispatch by name. Unknown names are logged + dropped.
        switch message.name {
        case SwiftLynxMessageName.templateSelected:
            handleTemplateSelected(bodyData)
        case SwiftLynxMessageName.slotSwapRequested:
            handleSlotSwap(bodyData)
        case SwiftLynxMessageName.catalogReady:
            // Empty / arbitrary body tolerated — just notify.
            onCatalogReady()
        case SwiftLynxMessageName.requestUserAssets:
            handleRequestUserAssets(bodyData)
        case SwiftLynxMessageName.requestThumbnail:
            handleRequestThumbnail(bodyData)
        case SwiftLynxMessageName.telemetry:
            handleTelemetry(bodyData)
        default:
            logger.bridgeDidRejectMessage(
                name: message.name,
                error: .unknownMessage(message.name)
            )
        }
    }

    // MARK: Test hooks
    //
    // Tests drive the bridge by simulating the validated `body -> Data`
    // pipeline without constructing a real `WKScriptMessage` (which is
    // impossible — no public initializer). `dispatchForTesting` runs
    // the exact same code path as `userContentController(_:didReceive:)`
    // after the frame/origin checks.

    #if DEBUG
    /// Test-only dispatch mirroring `userContentController(_:didReceive:)`
    /// minus the frame/origin gates. Applies size-limit enforcement and
    /// per-message routing.
    internal func dispatchForTesting(name: String, body: Any) {
        let bodyData: Data
        do {
            bodyData = try Self.serialize(body)
        } catch {
            logger.bridgeDidRejectMessage(
                name: name,
                error: .malformedPayload("non-JSON body: \(error)")
            )
            return
        }
        if bodyData.count > Self.maxPayloadBytes {
            logger.bridgeDidRejectMessage(
                name: name,
                error: .payloadTooLarge(bytes: bodyData.count)
            )
            return
        }
        switch name {
        case SwiftLynxMessageName.templateSelected: handleTemplateSelected(bodyData)
        case SwiftLynxMessageName.slotSwapRequested: handleSlotSwap(bodyData)
        case SwiftLynxMessageName.catalogReady:      onCatalogReady()
        case SwiftLynxMessageName.requestUserAssets: handleRequestUserAssets(bodyData)
        case SwiftLynxMessageName.requestThumbnail:  handleRequestThumbnail(bodyData)
        case SwiftLynxMessageName.telemetry:         handleTelemetry(bodyData)
        default:
            logger.bridgeDidRejectMessage(name: name, error: .unknownMessage(name))
        }
    }
    #endif

    // MARK: Per-message handlers

    private func handleTemplateSelected(_ data: Data) {
        do {
            let payload = try decoder.decode(TemplateSelectedPayload.self, from: data)
            guard let uuid = UUID(uuidString: payload.templateId) else {
                logger.bridgeDidRejectMessage(
                    name: SwiftLynxMessageName.templateSelected,
                    error: .malformedPayload("templateId not a UUID")
                )
                return
            }
            onTemplateSelected(uuid)
        } catch {
            logger.bridgeDidRejectMessage(
                name: SwiftLynxMessageName.templateSelected,
                error: .malformedPayload("\(error)")
            )
        }
    }

    private func handleSlotSwap(_ data: Data) {
        do {
            let payload = try decoder.decode(SlotSwapPayload.self, from: data)
            guard
                let templateUUID = UUID(uuidString: payload.templateId),
                let slotUUID = UUID(uuidString: payload.slotId)
            else {
                logger.bridgeDidRejectMessage(
                    name: SwiftLynxMessageName.slotSwapRequested,
                    error: .malformedPayload("ids not UUIDs")
                )
                return
            }
            onSlotSwap(templateUUID, slotUUID)
        } catch {
            logger.bridgeDidRejectMessage(
                name: SwiftLynxMessageName.slotSwapRequested,
                error: .malformedPayload("\(error)")
            )
        }
    }

    private func handleRequestUserAssets(_ data: Data) {
        // Accept either an empty message body or a structured one with
        // an optional filter.
        let payload: RequestUserAssetsPayload
        do {
            if data.isEmpty || data == Data("{}".utf8) {
                payload = RequestUserAssetsPayload(filter: nil)
            } else {
                payload = try decoder.decode(RequestUserAssetsPayload.self, from: data)
            }
        } catch {
            logger.bridgeDidRejectMessage(
                name: SwiftLynxMessageName.requestUserAssets,
                error: .malformedPayload("\(error)")
            )
            return
        }
        let userCallback = self.onUserAssetsRequested
        let webView = self.webView
        let encoder = self.encoder
        Task { [weak self] in
            let assets = await userCallback(payload.filter)
            guard let webView = webView else { return }
            do {
                let json = try encoder.encode(assets)
                await Self.evalEnvi(webView: webView, method: "setUserAssets", jsonArg: json)
            } catch {
                self?.logger.bridgeDidRejectMessage(
                    name: SwiftLynxMessageName.requestUserAssets,
                    error: .encodingFailed("\(error)")
                )
            }
        }
    }

    private func handleRequestThumbnail(_ data: Data) {
        do {
            let payload = try decoder.decode(RequestThumbnailPayload.self, from: data)
            guard thumbnailBucket.tryConsume() else {
                logger.bridgeDidRejectMessage(
                    name: SwiftLynxMessageName.requestThumbnail,
                    error: .rateLimited("thumbnail bucket empty")
                )
                return
            }
            let thumbCallback = self.onThumbnailRequested
            let webView = self.webView
            Task { [weak self] in
                let data = await thumbCallback(payload.assetId, payload.size)
                guard let webView = webView, let data = data else { return }
                let b64 = data.base64EncodedString()
                let response = ThumbnailResponse(
                    requestId: payload.requestId,
                    assetId: payload.assetId,
                    size: payload.size,
                    jpegBase64: b64
                )
                await self?.send(method: "setThumbnail", payload: response, on: webView)
            }
        } catch {
            logger.bridgeDidRejectMessage(
                name: SwiftLynxMessageName.requestThumbnail,
                error: .malformedPayload("\(error)")
            )
        }
    }

    private func handleTelemetry(_ data: Data) {
        do {
            let payload = try decoder.decode(TelemetryPayload.self, from: data)
            let anyProps = payload.properties.mapValues { $0.anyValue }
            onTelemetry(payload.event, anyProps)
        } catch {
            logger.bridgeDidRejectMessage(
                name: SwiftLynxMessageName.telemetry,
                error: .malformedPayload("\(error)")
            )
        }
    }

    // MARK: Helpers

    /// Re-serializes a `WKScriptMessage.body` into Data for size +
    /// decoding. Uses `JSONSerialization` since the body is guaranteed
    /// JSON-like by WebKit.
    static func serialize(_ body: Any) throws -> Data {
        if let s = body as? String, let d = s.data(using: .utf8) {
            return d
        }
        if body is NSNull {
            return Data("null".utf8)
        }
        if JSONSerialization.isValidJSONObject(body) {
            return try JSONSerialization.data(withJSONObject: body, options: [])
        }
        // Scalars (Bool/Int/Double) come wrapped in NSNumber — wrap in
        // a 1-element array to make JSONSerialization happy, then strip.
        let wrapped = try JSONSerialization.data(withJSONObject: [body], options: [])
        return wrapped
    }

    /// Performs a Swift->JS call via `evaluateJavaScript`. The JSON
    /// argument MUST be produced by `JSONEncoder`/`JSONSerialization` —
    /// never by string interpolation of attacker-controlled data.
    @MainActor
    static func evalEnvi(webView: WKWebView, method: String, jsonArg: Data) async {
        guard let jsonString = String(data: jsonArg, encoding: .utf8) else { return }
        // `method` is a compile-time constant from this file, never
        // user input, so interpolating it is safe.
        let js = "window.envi && typeof window.envi.\(method) === 'function' && window.envi.\(method)(\(jsonString));"
        _ = try? await webView.evaluateJavaScript(js)
    }

    /// Convenience: encode + eval in one shot.
    @MainActor
    func send<T: Encodable>(method: String, payload: T, on webView: WKWebView) async {
        do {
            let data = try encoder.encode(payload)
            await Self.evalEnvi(webView: webView, method: method, jsonArg: data)
        } catch {
            logger.bridgeDidRejectMessage(
                name: "envi.\(method)",
                error: .encodingFailed("\(error)")
            )
        }
    }
}

// MARK: - Outbound payload types (Swift -> JS)

/// Progress update passed to `window.envi.updateScanProgress`.
public struct ScanProgressPayload: Codable, Equatable, Sendable {
    public let done: Int
    public let total: Int
    public init(done: Int, total: Int) { self.done = done; self.total = total }
}

/// Error message passed to `window.envi.notifyError`.
public struct NotifyErrorPayload: Codable, Equatable, Sendable {
    public let message: String
    public init(message: String) { self.message = message }
}

/// Thumbnail response (reply to `envi.requestThumbnail`).
public struct ThumbnailResponse: Codable, Equatable, Sendable {
    public let requestId: String?
    public let assetId: String
    public let size: Int
    public let jpegBase64: String
    public init(requestId: String?, assetId: String, size: Int, jpegBase64: String) {
        self.requestId = requestId
        self.assetId = assetId
        self.size = size
        self.jpegBase64 = jpegBase64
    }
}

/// Generic async-response envelope for `envi.sendResponse`.
public struct ResponseEnvelope<Payload: Encodable>: Encodable {
    public let requestId: String
    public let payload: Payload
    public init(requestId: String, payload: Payload) {
        self.requestId = requestId
        self.payload = payload
    }
}

// MARK: - WKWebView helpers (Swift -> JS)

extension WKWebView {

    /// Push a full catalog to the Lynx surface. Always JSON-encoded via
    /// `JSONEncoder` — no string interpolation.
    @MainActor
    func enviSetCatalog(_ manifest: TemplateManifest) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(manifest) else { return }
        await SwiftLynxBridge.evalEnvi(webView: self, method: "setCatalog", jsonArg: data)
    }

    @MainActor
    func enviSetUserAssets(_ assets: [ClassifiedAssetSummary]) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(assets) else { return }
        await SwiftLynxBridge.evalEnvi(webView: self, method: "setUserAssets", jsonArg: data)
    }

    @MainActor
    func enviUpdateScanProgress(done: Int, total: Int) async {
        let encoder = JSONEncoder()
        let payload = ScanProgressPayload(done: done, total: total)
        guard let data = try? encoder.encode(payload) else { return }
        await SwiftLynxBridge.evalEnvi(webView: self, method: "updateScanProgress", jsonArg: data)
    }

    @MainActor
    func enviNotifyError(_ message: String) async {
        let encoder = JSONEncoder()
        let payload = NotifyErrorPayload(message: message)
        guard let data = try? encoder.encode(payload) else { return }
        await SwiftLynxBridge.evalEnvi(webView: self, method: "notifyError", jsonArg: data)
    }

    /// Reply to an async JS->Swift request by `requestId`. The
    /// `payload` must be Encodable so its JSON is produced safely.
    @MainActor
    func enviSendResponse<P: Encodable>(requestId: String, payload: P) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let envelope = ResponseEnvelope(requestId: requestId, payload: payload)
        guard let data = try? encoder.encode(envelope) else { return }
        await SwiftLynxBridge.evalEnvi(webView: self, method: "sendResponse", jsonArg: data)
    }
}

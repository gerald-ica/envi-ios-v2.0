//
//  USMSyncActor.swift
//  ENVI
//
//  Client-side sync pipeline for the User Self-Model. Runs as a serial
//  actor so concurrent push/pull attempts don't race. Implements:
//    * exponential backoff retry (0.5s → 2.0s → 8.0s, ±20% jitter) on
//      transport failures and 5xx responses,
//    * block-level last-writer-wins merge using `block_versions`,
//    * cache-first reads so the UI can paint immediately.
//
//  Part of USM Sprint 1 — Task 1.7.
//

import Foundation

/// Errors surfaced by USMSyncActor.
public enum USMSyncError: Error, Equatable {
    case invalidURL
    case notAuthenticated
    case retryExhausted
    case http(statusCode: Int)
    case decodingFailed
    case encodingFailed
    case transport(message: String)
}

/// Dependency contract for token retrieval. Pulls the Firebase ID token
/// so the actor doesn't take a hard dependency on FirebaseAuth and can
/// be exercised in unit tests with a mock provider.
public protocol USMAuthTokenProvider: Sendable {
    func idToken() async throws -> String
}

/// Dependency contract for HTTP transport so tests can inject a stub.
public protocol USMSyncTransport: Sendable {
    func send(
        request: URLRequest
    ) async throws -> (Data, HTTPURLResponse)
}

/// Default URLSession-based transport.
public struct USMDefaultTransport: USMSyncTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw USMSyncError.transport(message: "Non-HTTP response")
        }
        return (data, httpResponse)
    }
}

/// Actor that owns the push/pull lifecycle for the User Self-Model.
public actor USMSyncActor {

    // MARK: - Configuration

    /// Tunable retry and timing parameters.
    public struct Configuration: Sendable {
        public let maxAttempts: Int
        public let baseDelay: TimeInterval
        public let maxDelay: TimeInterval
        public let jitterFactor: Double
        public let schemaVersion: Int

        public init(
            maxAttempts: Int = 3,
            baseDelay: TimeInterval = 0.5,
            maxDelay: TimeInterval = 8.0,
            jitterFactor: Double = 0.2,
            schemaVersion: Int = 1
        ) {
            self.maxAttempts = maxAttempts
            self.baseDelay = baseDelay
            self.maxDelay = maxDelay
            self.jitterFactor = jitterFactor
            self.schemaVersion = schemaVersion
        }

        public static let `default` = Configuration()
    }

    // MARK: - State

    private let baseURL: URL
    private let cache: USMCache
    private let transport: USMSyncTransport
    private let tokenProvider: USMAuthTokenProvider
    private let configuration: Configuration
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var inFlight: Task<UserSelfModel, Error>?

    // MARK: - Init

    public init(
        baseURL: URL,
        cache: USMCache,
        tokenProvider: USMAuthTokenProvider,
        transport: USMSyncTransport = USMDefaultTransport(),
        configuration: Configuration = .default
    ) {
        self.baseURL = baseURL
        self.cache = cache
        self.tokenProvider = tokenProvider
        self.transport = transport
        self.configuration = configuration

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        self.decoder = jsonDecoder

        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = [.sortedKeys]
        self.encoder = jsonEncoder
    }

    // MARK: - Public API

    /// Returns the best-available `UserSelfModel` for `userId`.
    ///
    /// - If the cache is warm, the cached snapshot is returned immediately
    ///   and a background refresh is kicked off.
    /// - If the cache is empty, the server is pulled synchronously.
    public func currentModel(userId: String) async throws -> UserSelfModel {
        if let cached = try await cache.load(userId: userId, schemaVersion: configuration.schemaVersion) {
            Task { _ = try? await self.pull(userId: userId) }
            return cached
        }
        return try await pull(userId: userId)
    }

    /// Forces a server pull and updates the cache. Dedupes concurrent callers.
    @discardableResult
    public func pull(userId: String) async throws -> UserSelfModel {
        if let existing = inFlight {
            return try await existing.value
        }
        let task = Task<UserSelfModel, Error> { [self] in
            try await self.performPull(userId: userId)
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    /// Pushes a single block update to the server. Applies LWW: the server
    /// rejects when the block version is stale, and we fall back to a pull.
    @discardableResult
    public func pushBlock(
        userId: String,
        blockName: String,
        blockPayload: [String: JSONValue]
    ) async throws -> UserSelfModel {
        let url = try makeURL(path: "/api/v1/users/\(userId)/self-model")
        let body: [String: Any] = [
            "block_name": blockName,
            "block_data": blockPayload.mapValues { $0.asAny() },
        ]
        let payload = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        let request = try await makeRequest(method: "PUT", url: url, body: payload)
        _ = try await executeWithRetry(request: request)

        // After any block push we pull the authoritative snapshot. This
        // guarantees block_versions + recomputed_at stay aligned across
        // clients and simplifies reasoning about LWW.
        return try await performPull(userId: userId)
    }

    /// Requests a full recomputation on the server, then pulls.
    public func requestRecompute(userId: String) async throws -> UserSelfModel {
        let url = try makeURL(path: "/api/v1/users/\(userId)/self-model/recompute")
        let request = try await makeRequest(method: "POST", url: url, body: nil)
        _ = try await executeWithRetry(request: request)
        return try await performPull(userId: userId)
    }

    // MARK: - Internals

    private func performPull(userId: String) async throws -> UserSelfModel {
        let url = try makeURL(path: "/api/v1/users/\(userId)/self-model")
        let request = try await makeRequest(method: "GET", url: url, body: nil)
        let data = try await executeWithRetry(request: request)

        let response: UserSelfModelWire
        do {
            response = try decoder.decode(UserSelfModelWire.self, from: data)
        } catch {
            throw USMSyncError.decodingFailed
        }

        let model = response.toUserSelfModel()
        let blockVersions = response.blockVersions ?? [:]

        _ = try await cache.save(
            userId: userId,
            model: model,
            blockVersions: blockVersions,
            recomputedAt: response.recomputedAt
        )
        return model
    }

    private func makeURL(path: String) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw USMSyncError.invalidURL
        }
        if path.hasPrefix("/") {
            components.path = components.path.trimmingTrailingSlash() + path
        } else {
            components.path = components.path.trimmingTrailingSlash() + "/" + path
        }
        guard let url = components.url else {
            throw USMSyncError.invalidURL
        }
        return url
    }

    private func makeRequest(
        method: String,
        url: URL,
        body: Data?
    ) async throws -> URLRequest {
        let token = try await tokenProvider.idToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
        }
        return request
    }

    /// Executes `request` with exponential backoff. Retries only on 5xx
    /// responses and transport errors. 4xx responses fail fast so auth
    /// failures don't burn attempts.
    private func executeWithRetry(request: URLRequest) async throws -> Data {
        var lastError: Error?
        for attempt in 0..<configuration.maxAttempts {
            do {
                let (data, response) = try await transport.send(request: request)
                switch response.statusCode {
                case 200..<300:
                    return data
                case 500..<600:
                    lastError = USMSyncError.http(statusCode: response.statusCode)
                default:
                    throw USMSyncError.http(statusCode: response.statusCode)
                }
            } catch let error as USMSyncError {
                if case .http(let statusCode) = error, !(500..<600).contains(statusCode) {
                    throw error
                }
                lastError = error
            } catch {
                lastError = USMSyncError.transport(message: error.localizedDescription)
            }

            if attempt < configuration.maxAttempts - 1 {
                let delay = backoffDelay(attempt: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? USMSyncError.retryExhausted
    }

    private func backoffDelay(attempt: Int) -> TimeInterval {
        let exp = min(pow(4.0, Double(attempt)) * configuration.baseDelay, configuration.maxDelay)
        let jitter = exp * configuration.jitterFactor * (Double.random(in: -1.0...1.0))
        return max(0.0, exp + jitter)
    }
}

// MARK: - Wire format

/// Mirror of `UserSelfModelResponse` from the FastAPI route. Decodes the
/// server payload and maps it onto the strongly-typed `UserSelfModel`.
struct UserSelfModelWire: Decodable {
    let userId: String
    let modelVersion: Int
    let createdAt: Date
    let updatedAt: Date
    let recomputedAt: Date
    let blockVersions: [String: Int]?
    let astroBlock: USMAstroBlock?
    let psychBlock: USMPsychBlock?
    let dynamicBlock: USMDynamicBlock?
    let visualBlock: USMVisualBlock?
    let predictBlock: USMPredictBlock?
    let neuroBlock: USMNeuroBlock?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case modelVersion = "model_version"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case recomputedAt = "recomputed_at"
        case blockVersions = "block_versions"
        case astroBlock = "astro_block"
        case psychBlock = "psych_block"
        case dynamicBlock = "dynamic_block"
        case visualBlock = "visual_block"
        case predictBlock = "predict_block"
        case neuroBlock = "neuro_block"
    }

    func toUserSelfModel() -> UserSelfModel {
        UserSelfModel(
            identity: UserSelfModel.Identity(
                userId: userId,
                modelVersion: modelVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                recomputedAt: recomputedAt
            ),
            astroBlock: astroBlock ?? USMAstroBlock.makeEmpty(),
            psychBlock: psychBlock ?? USMPsychBlock.makeEmpty(),
            dynamicBlock: dynamicBlock ?? USMDynamicBlock.makeEmpty(),
            visualBlock: visualBlock ?? USMVisualBlock.makeEmpty(),
            predictBlock: predictBlock ?? USMPredictBlock.makeEmpty(),
            neuroBlock: neuroBlock ?? USMNeuroBlock.makeEmpty()
        )
    }
}

// MARK: - Small utilities

private extension String {
    func trimmingTrailingSlash() -> String {
        var s = self
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
}

private extension JSONValue {
    /// Unwraps the Codable enum into a JSON-friendly `Any` for `JSONSerialization`.
    func asAny() -> Any {
        switch self {
        case .null: return NSNull()
        case .bool(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .string(let v): return v
        case .array(let v): return v.map { $0.asAny() }
        case .object(let v): return v.mapValues { $0.asAny() }
        }
    }
}

import Foundation
import FirebaseAuth
import FirebaseCore

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let retryPolicy: RetryPolicy

    let baseURL = AppConfig.apiBaseURL

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        retryPolicy: RetryPolicy = .default
    ) {
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
        self.retryPolicy = retryPolicy
    }

    enum APIError: LocalizedError {
        case invalidURL
        case networkError
        case decodingError
        case unauthorized
        case httpError(statusCode: Int)
        case firebaseNotConfigured
        case missingAuthToken
        case retryExhausted

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL."
            case .networkError:
                return "Network request failed."
            case .decodingError:
                return "Response decoding failed."
            case .unauthorized:
                return "Unauthorized request."
            case let .httpError(statusCode):
                return "HTTP error: \(statusCode)."
            case .firebaseNotConfigured:
                return "Firebase is not configured."
            case .missingAuthToken:
                return "Missing auth token."
            case .retryExhausted:
                return "Request failed after retries."
            }
        }
    }

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    struct RetryPolicy {
        let maxAttempts: Int
        let baseDelaySeconds: Double
        let retryableStatusCodes: Set<Int>

        static let `default` = RetryPolicy(
            maxAttempts: 3,
            baseDelaySeconds: 0.4,
            retryableStatusCodes: [408, 429, 500, 502, 503, 504]
        )
    }

    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        requiresAuth: Bool = true
    ) async throws -> T {
        try await request(endpoint: endpoint, method: method, body: Optional<String>.none, requiresAuth: requiresAuth)
    }

    func request<T: Decodable, Body: Encodable>(
        endpoint: String,
        method: HTTPMethod = .post,
        body: Body?,
        requiresAuth: Bool = true
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            request.setValue("Bearer \(try await authToken())", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await performRequestWithRetry(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }

    func requestVoid(
        endpoint: String,
        method: HTTPMethod = .post,
        requiresAuth: Bool = true
    ) async throws {
        try await requestVoid(endpoint: endpoint, method: method, body: Optional<String>.none, requiresAuth: requiresAuth)
    }

    func requestVoid<Body: Encodable>(
        endpoint: String,
        method: HTTPMethod = .post,
        body: Body?,
        requiresAuth: Bool = true
    ) async throws {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            request.setValue("Bearer \(try await authToken())", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (_, response) = try await performRequestWithRetry(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func authToken() async throws -> String {
        guard FirebaseApp.app() != nil else {
            throw APIError.firebaseNotConfigured
        }
        guard let user = Auth.auth().currentUser else {
            throw APIError.missingAuthToken
        }
        let tokenResult = try await user.getIDTokenResult()
        return tokenResult.token
    }

    private func performRequestWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var attempt = 0
        var lastError: Error?

        while attempt < retryPolicy.maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse,
                   retryPolicy.retryableStatusCodes.contains(http.statusCode),
                   attempt < retryPolicy.maxAttempts - 1 {
                    attempt += 1
                    try await backoffDelay(for: attempt)
                    continue
                }
                return (data, response)
            } catch {
                lastError = error
                if attempt >= retryPolicy.maxAttempts - 1 {
                    break
                }
                attempt += 1
                try await backoffDelay(for: attempt)
            }
        }

        if lastError != nil {
            throw APIError.networkError
        }
        throw APIError.retryExhausted
    }

    private func backoffDelay(for attempt: Int) async throws {
        let delay = retryPolicy.baseDelaySeconds * pow(2, Double(max(attempt - 1, 0)))
        try await Task.sleep(for: .seconds(delay))
    }
}

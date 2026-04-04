import Foundation
import FirebaseAuth
import FirebaseCore

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    let baseURL = AppConfig.apiBaseURL

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    enum APIError: LocalizedError {
        case invalidURL
        case networkError
        case decodingError
        case unauthorized
        case httpError(statusCode: Int)
        case firebaseNotConfigured
        case missingAuthToken

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

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError
        }

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
}

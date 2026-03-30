import Foundation

/// Placeholder API client for future backend integration.
final class APIClient {
    static let shared = APIClient()
    private init() {}

    let baseURL: URL = URL(string: "https://api.envi.app/v1") ?? URL(fileURLWithPath: "/")

    enum APIError: Error {
        case networkError
        case decodingError
        case unauthorized
        case notImplemented
    }

    /// Placeholder: Simulate a network call with mock data
    func mockRequest<T: Decodable>(endpoint: String, responseType: T.Type) async throws -> T {
        throw APIError.notImplemented
    }
}

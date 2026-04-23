import Foundation

enum USMRecomputeError: LocalizedError {
    case notAuthenticated
    case server(status: Int, message: String)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .server(let status, let message):
            return "Server error (\(status)): \(message)"
        case .transport(let error):
            return "Network error: \(error.localizedDescription)"
        case .decoding(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

/// Default URLSession-backed implementation of USMRecomputeClientProtocol.
final class USMRecomputeClient: USMRecomputeClientProtocol, Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let authTokenProvider: @Sendable () async -> String?

    /// Initialize with a base URL, session, and token provider.
    public init(
        baseURL: URL,
        session: URLSession = .shared,
        authTokenProvider: @escaping @Sendable () async -> String?
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    /// Recompute the USM for a user.
    /// POSTs to `/api/v1/users/{user_id}/self-model/recompute` with a 90-second timeout.
    public func recompute(
        userId: String,
        request: USMRecomputeRequest
    ) async throws -> USMRecomputeResponse {
        guard let token = await authTokenProvider() else {
            throw USMRecomputeError.notAuthenticated
        }

        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("self-model")
            .appendingPathComponent("recompute")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 90.0
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw USMRecomputeError.decoding(error)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw USMRecomputeError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw USMRecomputeError.transport(NSError(domain: "USMRecompute", code: -1))
        }

        // Check status code
        switch httpResponse.statusCode {
        case 200..<300:
            // Success
            break
        case 400..<500:
            let message = parseErrorMessage(from: data) ?? "Client error"
            throw USMRecomputeError.server(status: httpResponse.statusCode, message: message)
        case 500..<600:
            let message = parseErrorMessage(from: data) ?? "Server error"
            throw USMRecomputeError.server(status: httpResponse.statusCode, message: message)
        default:
            throw USMRecomputeError.server(status: httpResponse.statusCode, message: "Unknown error")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(USMRecomputeResponse.self, from: data)
        } catch {
            throw USMRecomputeError.decoding(error)
        }
    }

    // MARK: - Helpers

    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["detail"] as? String ?? json["message"] as? String else {
            return nil
        }
        return message
    }
}

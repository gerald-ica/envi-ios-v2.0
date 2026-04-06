import Foundation

// MARK: - Generic Repository Provider

/// A generic container that resolves the correct repository implementation
/// based on the current `AppEnvironment`.
///
/// Usage:
/// ```swift
/// enum FooRepositoryProvider {
///     static var shared = RepositoryProvider<FooRepository>(
///         dev: MockFooRepository(),
///         api: APIFooRepository()
///     )
/// }
/// ```
///
/// Access: `FooRepositoryProvider.shared.repository`
struct RepositoryProvider<T> {
    var repository: T

    init(dev: T, api: T) {
        switch AppEnvironment.current {
        case .dev:
            repository = dev
        case .staging, .prod:
            repository = api
        }
    }
}

// MARK: - Shared Empty Body

/// A reusable empty `Encodable` body for API calls that require a body parameter
/// but have no payload (e.g., POST with no request body).
struct EmptyBody: Encodable {}

// MARK: - Query Builder

/// Builds a URL query string from key-value pairs.
///
/// Usage: `buildQueryString(["sort": "name", "limit": "10"])` returns `"?sort=name&limit=10"`
func buildQueryString(_ params: [String: String]) -> String {
    guard !params.isEmpty else { return "" }
    var components = URLComponents()
    components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
    return components.string ?? ""
}

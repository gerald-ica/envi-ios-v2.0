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

// MARK: - Canonical Resolver Facade (Phase 19 — Plan 02)

/// Canonical entry point for the analytics family of repositories. Gives the
/// call site a single, flag-aware resolver per repo so VMs don't each have
/// to know about `FeatureFlags.connectorsInsightsLive` branching or remember
/// which provider enum owns a given resolver.
///
/// Usage:
/// ```swift
/// init(repository: AdvancedAnalyticsRepository? = nil) {
///     self.repository = repository ?? Repositories.advancedAnalytics
/// }
/// ```
///
/// Existing `SomeRepositoryProvider.resolve()` methods remain for backwards
/// compatibility — they're what this struct forwards to. Prefer the
/// facade for new code.
@MainActor
enum Repositories {
    static var analytics: AnalyticsRepository {
        AnalyticsRepositoryProvider.resolve()
    }

    static var advancedAnalytics: AdvancedAnalyticsRepository {
        AdvancedAnalyticsRepositoryProvider.resolve()
    }

    static var benchmark: BenchmarkRepository {
        BenchmarkRepositoryProvider.resolve()
    }
}

import Foundation

// MARK: - Protocol

/// Phase 3 repository contract for camera-roll-driven video templates.
/// Phase 4 swaps `MockVideoTemplateRepository` for a Lynx/server-backed impl
/// without touching the ranker, match engine, or view model.
protocol VideoTemplateRepository {
    func fetchCatalog() async throws -> [VideoTemplate]
    func fetchTrending() async throws -> [VideoTemplate]
    func fetchByCategory(_ category: VideoTemplateCategory) async throws -> [VideoTemplate]

    /// Phase 18-03: create a copy of an existing template as a new record.
    /// Mock path deep-copies the struct and assigns a fresh UUID; server
    /// path (when wired) POSTs to `templates/:id/duplicate` and returns
    /// the server-assigned clone. The template tab's context menu
    /// ("Find Similar Content") calls this.
    func duplicate(templateID: UUID) async throws -> VideoTemplate
}

// MARK: - Error

enum VideoTemplateRepositoryError: LocalizedError {
    case catalogUnavailable
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .catalogUnavailable:
            return "The template catalog is temporarily unavailable."
        case .invalidResponse:
            return "The template catalog response was invalid."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Mock

/// Mock repository backed by `VideoTemplate.mockLibrary`. Never hits the
/// network. Supports latency + error injection so Phase 5 UI can exercise
/// loading and failure states without a server.
final class MockVideoTemplateRepository: VideoTemplateRepository {
    /// Error injection modes for test/preview scaffolding.
    enum ThrowMode {
        case never
        case onCatalog(VideoTemplateRepositoryError)
        case onTrending(VideoTemplateRepositoryError)
        case onCategory(VideoTemplateRepositoryError)
        case onDuplicate(VideoTemplateRepositoryError)
        case always(VideoTemplateRepositoryError)
    }

    /// Simulated latency per call. Defaults to zero so unit tests stay fast.
    var latency: Duration
    var throwMode: ThrowMode
    private let library: [VideoTemplate]

    init(
        library: [VideoTemplate] = VideoTemplate.mockLibrary,
        latency: Duration = .zero,
        throwMode: ThrowMode = .never
    ) {
        self.library = library
        self.latency = latency
        self.throwMode = throwMode
    }

    func fetchCatalog() async throws -> [VideoTemplate] {
        try await simulateLatency()
        try throwIfNeeded(for: .catalog)
        return library
    }

    func fetchTrending() async throws -> [VideoTemplate] {
        try await simulateLatency()
        try throwIfNeeded(for: .trending)
        // "Trending" = top-half by popularity, descending. Deterministic for tests.
        return library
            .sorted { $0.popularity > $1.popularity }
            .prefix(max(1, library.count / 2))
            .map { $0 }
    }

    func fetchByCategory(_ category: VideoTemplateCategory) async throws -> [VideoTemplate] {
        try await simulateLatency()
        try throwIfNeeded(for: .category)
        return library.filter { $0.category == category }
    }

    func duplicate(templateID: UUID) async throws -> VideoTemplate {
        try await simulateLatency()
        try throwIfNeeded(for: .duplicate)

        // Prefer the source template if we have it; otherwise duplicate the
        // first library entry so the UI still gets a clone to display.
        let source = library.first(where: { $0.id == templateID })
            ?? library.first
            ?? VideoTemplate(name: "Untitled", category: .grwm, aspectRatio: .portrait9x16)

        return VideoTemplate(
            id: UUID(),
            remoteID: nil,
            name: "\(source.name) Copy",
            category: source.category,
            aspectRatio: source.aspectRatio,
            duration: source.duration,
            slots: source.slots,
            textOverlays: source.textOverlays,
            transitions: source.transitions,
            audioTrack: source.audioTrack,
            suggestedPlatforms: source.suggestedPlatforms,
            thumbnailURL: source.thumbnailURL,
            popularity: source.popularity
        )
    }

    // MARK: - Helpers

    private enum Endpoint { case catalog, trending, category, duplicate }

    private func simulateLatency() async throws {
        guard latency > .zero else { return }
        try await Task.sleep(for: latency)
    }

    private func throwIfNeeded(for endpoint: Endpoint) throws {
        switch throwMode {
        case .never:
            return
        case .always(let error):
            throw error
        case .onCatalog(let error) where endpoint == .catalog:
            throw error
        case .onTrending(let error) where endpoint == .trending:
            throw error
        case .onCategory(let error) where endpoint == .category:
            throw error
        case .onDuplicate(let error) where endpoint == .duplicate:
            throw error
        default:
            return
        }
    }
}

// MARK: - Provider

/// Phase 3 ships only the mock. Phase 4 adds an `APIVideoTemplateRepository`
/// and wires it into `RepositoryProvider` here.
enum VideoTemplateRepositoryProvider {
    static nonisolated(unsafe) var shared: VideoTemplateRepository = MockVideoTemplateRepository()
}

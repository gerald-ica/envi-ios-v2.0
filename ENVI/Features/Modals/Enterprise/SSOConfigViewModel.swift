import SwiftUI
import Combine

/// ViewModel for `SSOConfigView` (Phase 19 — Plan 01).
///
/// Replaces the prior "repo-in-view" anti-pattern where the view itself held
/// `private let repository = EnterpriseRepositoryProvider.shared.repository`.
/// The VM owns the SSO + SCIM state, the load flow, and the save flow; the
/// view just drives Bindings and renders.
@MainActor
final class SSOConfigViewModel: ObservableObject {

    // MARK: - Published State

    @Published var config: SSOConfig = .mock
    @Published var scimConfig: SCIMConfig = .mock
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private nonisolated(unsafe) let repository: EnterpriseRepository

    // MARK: - Init

    init(repository: EnterpriseRepository? = nil) {
        self.repository = repository ?? EnterpriseRepositoryProvider.shared.repository
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let sso = repository.fetchSSOConfig()
            async let scim = repository.fetchSCIMConfig()
            config = try await sso
            scimConfig = try await scim
        } catch {
            errorMessage = "Unable to load SSO configuration."
        }
        isLoading = false
    }

    // MARK: - Mutation

    /// Add / overwrite a SAML metadata entry.
    func addMetadata(key: String, value: String) {
        guard !key.isEmpty else { return }
        config.metadata[key] = value
    }

    // MARK: - Saving

    func save() async {
        isSaving = true
        errorMessage = nil
        do {
            config = try await repository.updateSSOConfig(config)
        } catch {
            errorMessage = "Unable to save SSO configuration."
        }
        isSaving = false
    }
}

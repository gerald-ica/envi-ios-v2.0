//
//  LinkedInAuthorPickerViewModel.swift
//  ENVI
//
//  Phase 11 — LinkedIn Connector (v1.1 Real Social Connectors).
//
//  ObservableObject backing `LinkedInAuthorPickerView`. Knows how to load
//  the member handle + the admin-organization list from `LinkedInConnector`
//  and exposes a typed `LinkedInAuthorOption` selection the host view
//  commits on confirm.
//
//  Scope gating
//  ------------
//  When the current LinkedIn connection lacks `w_organization_social` we
//  don't attempt the org fetch; instead we expose a `canPostAsOrganization`
//  flag that the view reads to show a locked "Unlock company pages" row.
//  Tapping that row calls `upgradeToOrganizationScopes()` which drops back
//  into `LinkedInConnector.connect(includeOrganizationScopes: true)`.
//
//  Selection semantics
//  -------------------
//  `authorOptions` is kept in display order — member row always first,
//  organizations sorted by `localizedName` (case-insensitive) beneath.
//  `selectedAuthor` starts on `.member` so a user tapping "Post" without
//  touching anything gets the most common flow.
//

import Foundation
import SwiftUI

// MARK: - Option Enum

/// What the user has selected in the picker. Matches the `authorType`
/// discriminator the dispatch Cloud Function expects on the wire.
enum LinkedInAuthorOption: Equatable, Hashable {

    /// Post as the signed-in LinkedIn member. `handle` is the cached
    /// `{firstName} {lastName}` string from `/v2/me`.
    case member(handle: String)

    /// Post as the referenced organization. Identity is carried by the
    /// full `LinkedInOrganization` record so the view can render logo +
    /// localized name without a second fetch.
    case organization(LinkedInOrganization)

    /// Stable identity for SwiftUI `ForEach(id:)` selection.
    var id: String {
        switch self {
        case .member(let handle): return "member:\(handle)"
        case .organization(let org): return "org:\(org.urn)"
        }
    }

    /// Primary row text.
    var displayName: String {
        switch self {
        case .member(let handle): return handle
        case .organization(let org): return org.localizedName
        }
    }

    /// Row subtitle copy — distinguishes personal vs company at a glance.
    var subtitle: String {
        switch self {
        case .member: return "Personal profile"
        case .organization: return "Company page"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class LinkedInAuthorPickerViewModel: ObservableObject {

    // MARK: - Published state

    /// Ordered list of rows shown in the picker (member first, orgs after).
    @Published private(set) var authorOptions: [LinkedInAuthorOption] = []

    /// Current radio selection. `nil` until `load()` succeeds — the confirm
    /// button is disabled while this is `nil` so users can't submit nothing.
    @Published var selectedAuthor: LinkedInAuthorOption?

    /// Controls the spinner on first load AND during the re-fetch that
    /// follows a successful `upgradeToOrganizationScopes()` call.
    @Published private(set) var isLoading: Bool = false

    /// Human-readable error string. The view surfaces this in a banner;
    /// dismiss behavior is up to the host.
    @Published var errorMessage: String?

    /// `true` when the current LinkedIn connection includes
    /// `w_organization_social`. Controls whether we show live org rows or
    /// the locked upgrade row.
    @Published private(set) var canPostAsOrganization: Bool = false

    // MARK: - Dependencies

    private nonisolated(unsafe) let connector: LinkedInConnector
    private let connectionProvider: @Sendable () async throws -> PlatformConnection

    /// - Parameters:
    ///   - connector: `LinkedInConnector` to fetch orgs / upgrade scopes.
    ///   - connectionProvider: closure that returns the current
    ///     `PlatformConnection` so we can inspect the granted scope set.
    ///     Injected so tests can stub without touching `SocialOAuthManager`.
    init(
        connector: LinkedInConnector = .shared,
        connectionProvider: @escaping @Sendable () async throws -> PlatformConnection = {
            try await SocialOAuthManager.shared.connectionStatus(platform: .linkedin)
        }
    ) {
        self.connector = connector
        self.connectionProvider = connectionProvider
    }

    // MARK: - Load

    /// Fetch the member handle from the cached `PlatformConnection` and —
    /// when scopes allow — the admin-organization list. Swallows the org
    /// fetch error into `errorMessage` but keeps the member option usable.
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 1. Resolve the member handle + scope set from the connection doc.
        let memberHandle: String
        let scopes: [String]
        do {
            let connection = try await connectionProvider()
            guard connection.isConnected else {
                errorMessage = LinkedInConnectorError.notConnected.localizedDescription
                authorOptions = []
                selectedAuthor = nil
                return
            }
            memberHandle = connection.handle ?? "LinkedIn Member"
            scopes = connection.scopes
        } catch {
            errorMessage = "Could not load LinkedIn connection: \(error.localizedDescription)"
            authorOptions = []
            selectedAuthor = nil
            return
        }

        let memberOption: LinkedInAuthorOption = .member(handle: memberHandle)
        canPostAsOrganization = scopes.contains("w_organization_social")

        // 2. Fetch admin orgs only when the scope is present. Avoids a
        //    403 round-trip for users who never upgraded.
        var orgOptions: [LinkedInAuthorOption] = []
        if canPostAsOrganization {
            do {
                let orgs = try await connector.fetchAdminOrganizations()
                orgOptions = orgs
                    .sorted { lhs, rhs in
                        lhs.localizedName.localizedCaseInsensitiveCompare(rhs.localizedName)
                            == .orderedAscending
                    }
                    .map(LinkedInAuthorOption.organization)
            } catch {
                // Non-fatal: member posting still works. Surface the error
                // so power users can retry via pull-to-refresh.
                errorMessage = "Could not load company pages: \(error.localizedDescription)"
            }
        }

        authorOptions = [memberOption] + orgOptions
        // Preserve the current selection when it's still valid; otherwise
        // drop back to the member row.
        if let current = selectedAuthor, authorOptions.contains(current) {
            // keep
        } else {
            selectedAuthor = memberOption
        }
    }

    // MARK: - Upgrade to org scopes

    /// Kick off a second OAuth round-trip that adds `r_organization_social`
    /// and `w_organization_social` to the granted scope set. On success we
    /// re-enter `load()` so the picker populates with the company-page
    /// rows without the caller having to dismiss + reopen.
    func upgradeToOrganizationScopes() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await connector.connect(includeOrganizationScopes: true)
            await load()
        } catch {
            errorMessage = "LinkedIn did not grant company-page access: \(error.localizedDescription)"
        }
    }
}

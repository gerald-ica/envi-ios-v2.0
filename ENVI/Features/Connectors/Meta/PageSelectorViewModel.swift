//
//  PageSelectorViewModel.swift
//  ENVI
//
//  Phase 10 — Meta Family Connector, Page selector view model.
//
//  Drives `PageSelectorView`. Loads the user's Facebook Pages via the
//  broker `GET /meta/pages` route, lets the user pick one, and finalizes
//  the Connect flow by posting `/oauth/facebook/select-page` with the
//  chosen Page id. The broker marks that Page as `selectedPageId` and
//  encrypts + stores each Page access token (separate from the user token)
//  in Firestore.
//

import Foundation
import Combine

/// Lightweight representation of a Facebook Page surfaced by
/// `GET /me/accounts`. Keeps identifiers + display fields only — the
/// broker retains the encrypted Page access token server-side.
struct MetaPageItem: Identifiable, Decodable, Hashable {
    let pageID: String
    let pageName: String
    let category: String?
    /// Admin tasks the user can perform on this Page. Used to filter out
    /// Pages where the user lacks `CREATE_CONTENT`.
    let tasks: [String]

    var id: String { pageID }

    /// Whether this Page grants the tasks needed to publish.
    var canPublish: Bool {
        tasks.contains("CREATE_CONTENT") || tasks.contains("MANAGE")
    }

    enum CodingKeys: String, CodingKey {
        case pageID = "page_id"
        case pageName = "page_name"
        case category
        case tasks
    }
}

/// Loading/error state machine for `PageSelectorView`. Kept as a nested
/// enum so SwiftUI can `switch` on it in the body.
enum PageSelectorState: Equatable {
    case loading
    case loaded(pages: [MetaPageItem])
    case empty
    case error(message: String)
}

/// ViewModel for the page selector modal.
@MainActor
final class PageSelectorViewModel: ObservableObject {

    // MARK: - Published State

    @Published var state: PageSelectorState = .loading
    @Published var selectedPageID: String?
    @Published var isContinuing = false
    @Published var continueError: String?

    // MARK: - Dependencies

    private let apiClient: APIClient

    // MARK: - Init

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Load

    /// Fetch the user's Pages via the broker. Idempotent; `PageSelectorView`
    /// calls this from `.task` and from the retry button.
    func loadPages() async {
        state = .loading
        continueError = nil

        do {
            let response: PageListResponse = try await apiClient.request(
                endpoint: "meta/pages",
                method: .get,
                requiresAuth: true
            )

            if response.pages.isEmpty {
                state = .empty
                return
            }

            state = .loaded(pages: response.pages)
            // Preselect the first publishable Page so the Continue button
            // isn't dead on first render.
            selectedPageID = response.pages.first(where: { $0.canPublish })?.pageID
                ?? response.pages.first?.pageID
        } catch {
            state = .error(message: "Couldn't load your Facebook Pages. Try again.")
        }
    }

    // MARK: - Continue

    /// Post the chosen Page to the broker. Completes the Connect flow.
    ///
    /// - Parameter onComplete: Invoked with `true` when selection succeeds
    ///   (caller typically dismisses the sheet), `false` on error.
    func continueWithSelection(onComplete: @escaping (Bool) -> Void) async {
        guard let pageID = selectedPageID else {
            continueError = "Pick a Page to continue."
            onComplete(false)
            return
        }

        isContinuing = true
        continueError = nil

        defer { isContinuing = false }

        let body = SelectPageRequest(pageID: pageID)

        do {
            try await apiClient.requestVoid(
                endpoint: "oauth/facebook/select-page",
                method: .post,
                body: body,
                requiresAuth: true
            )
            onComplete(true)
        } catch {
            continueError = "Couldn't save your Page selection. Try again."
            onComplete(false)
        }
    }
}

// MARK: - Wire Types

private struct PageListResponse: Decodable {
    let pages: [MetaPageItem]
}

private struct SelectPageRequest: Encodable {
    let pageID: String

    enum CodingKeys: String, CodingKey {
        case pageID = "page_id"
    }
}

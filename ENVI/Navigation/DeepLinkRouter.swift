import Foundation

/// Phase 15-03 — Parses inbound `enviapp://` URLs into `AppDestination`
/// values.
///
/// ## URL grammar supported
/// ```
/// enviapp://oauth-callback/{provider}        — NOT parsed here
///                                              (handled by Phase 6's
///                                              OAuthCallbackHandler)
/// enviapp://destination/{caseName}            — no-payload destinations
/// enviapp://destination/{caseName}?id={value} — cases with an id payload
/// ```
///
/// The OAuth callback path is deliberately skipped: `destination(from:)`
/// returns `nil` for `oauth-callback` URLs so the AppDelegate's existing
/// `application(_:open:)` path (which dispatches to
/// `OAuthCallbackHandler.handle`) keeps working unchanged.
///
/// Adding a new destination to the URL grammar is a one-line change in
/// `caseRegistry` — no switch sprawl.
enum DeepLinkRouter {

    /// Registry of destination-name → parser. Each parser receives the
    /// already-validated URL (scheme=enviapp, host=destination) and
    /// returns the `AppDestination` to present, or `nil` if the URL is
    /// missing required payload.
    ///
    /// Case names use the exact enum-case spelling so the URL round-trip
    /// matches developer intuition.
    private static let caseRegistry: [String: (URL) -> AppDestination?] = [
        // No-payload destinations
        "admin": { _ in .admin },
        "enterprise": { _ in .enterprise },
        "agency": { _ in .agency },
        "teams": { _ in .teams },
        "brandKit": { _ in .brandKit },
        "campaigns": { _ in .campaigns },
        "collaboration": { _ in .collaboration },
        "community": { _ in .community },
        "commerce": { _ in .commerce },
        "experiments": { _ in .experiments },
        "metadata": { _ in .metadata },
        // Sprint-03: hidden — routes to PlaceholderSheetView. Re-enable when Publishing tab is fully wired.
        // "publishing": { _ in .publishing },
        "contentCalendar": { _ in .contentCalendar },
        "repurposing": { _ in .repurposing },
        "search": { _ in .search },
        "ideation": { _ in .ideation },
        "aiVisualEditor": { _ in .aiVisualEditor },
        "captionGenerator": { _ in .captionGenerator },
        "hookLibrary": { _ in .hookLibrary },
        "scriptEditor": { _ in .scriptEditor },
        "styleTransfer": { _ in .styleTransfer },
        "imageGenerator": { _ in .imageGenerator },
        "notifications": { _ in .notifications },
        "security": { _ in .security },
        // Sprint-03: hidden profile-adjacent routes — no real UI wired yet.
        // "billing": { _ in .billing },
        // "education": { _ in .education },
        // "support": { _ in .support },
        // "subscription": { _ in .subscription },
        "chatHistory": { _ in .chatHistory },
        "contentLibrarySettings": { _ in .contentLibrarySettings },
        // Sprint-03: hidden library/tool routes — no real UI wired yet.
        // "exportSheet": { _ in .exportSheet },
        // "mediaPicker": { _ in .mediaPicker },
        // "phPicker": { _ in .phPicker },

        // Id-payload destinations
        // Sprint-03: campaignDetail hidden — no detail view wired yet.
        // "campaignDetail": { url in
        //     guard let id = queryValue(url: url, name: "id") else { return nil }
        //     return .campaignDetail(id: id)
        // },
        // Sprint-03: contentEditor hidden — EditorContainerView requires ContentPiece/ContentItem, not just an ID.
        // "contentEditor": { url in
        //     guard let id = queryValue(url: url, name: "id") else { return nil }
        //     return .contentEditor(contentID: id)
        // }
    ]

    // MARK: - Public API

    /// Parse a URL into an `AppDestination`. Returns `nil` when:
    ///   - scheme is not `enviapp`
    ///   - host is `oauth-callback` (leave to OAuthCallbackHandler)
    ///   - host is not `destination`
    ///   - the destination case name is unknown
    ///   - a payload-bearing case is missing required query items
    ///
    /// Fires a `deepLinkMalformed` telemetry event when a URL looks like
    /// an intended deep link (scheme + destination host) but can't be
    /// parsed, so we have observability on bad links in production.
    static func destination(from url: URL) -> AppDestination? {
        guard url.scheme?.lowercased() == "enviapp" else { return nil }

        // OAuth callback URLs belong to Phase 6's handler. Do not touch.
        if url.host?.lowercased() == "oauth-callback" { return nil }

        guard url.host?.lowercased() == "destination" else { return nil }

        let segments = url.pathComponents.filter { $0 != "/" }
        guard let caseName = segments.first else {
            TelemetryManager.shared.track(.deepLinkMalformed, parameters: [
                "reason": "missing_case_name"
            ])
            return nil
        }

        guard let parser = caseRegistry[caseName] else {
            TelemetryManager.shared.track(.deepLinkMalformed, parameters: [
                "reason": "unknown_case",
                "case_name": caseName
            ])
            return nil
        }

        guard let destination = parser(url) else {
            TelemetryManager.shared.track(.deepLinkMalformed, parameters: [
                "reason": "missing_payload",
                "case_name": caseName
            ])
            return nil
        }

        return destination
    }

    // MARK: - Helpers

    private static func queryValue(url: URL, name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}

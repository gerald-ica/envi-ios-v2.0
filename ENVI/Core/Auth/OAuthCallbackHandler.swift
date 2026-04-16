import Foundation

/// Phase 06-04 — OAuth callback URL parser for `enviapp://oauth-callback/*` URLs.
///
/// The app registers `enviapp` as a custom URL scheme; when a provider
/// redirects back, iOS hands us the callback URL which must be parsed for
/// `code` / `state` / `error` payloads and dispatched to the subscribing
/// OAuth flow via `NotificationCenter`.
enum OAuthCallbackHandler {

    /// Known OAuth providers surfaced in the callback path segment.
    enum Provider: String, CaseIterable {
        case tiktok, x, instagram, youtube, threads, linkedin, reddit
    }

    /// Outcome of handling an incoming URL.
    enum Outcome: Equatable {
        case handled
        case invalid
        case unrelated
    }

    /// Parsed representation of a valid callback URL.
    struct Parsed: Equatable {
        let provider: Provider
        let code: String?
        let state: String?
        let error: String?
        let rawURL: URL
    }

    static let notificationName = Notification.Name("com.envi.oauth.callback")

    /// Parse an incoming URL. Returns `nil` if the scheme/host/path don't
    /// match the `enviapp://oauth-callback/{provider}` shape.
    static func parse(_ url: URL) -> Parsed? {
        guard url.scheme?.lowercased() == "enviapp" else { return nil }
        guard url.host?.lowercased() == "oauth-callback" else { return nil }
        let segments = url.path.split(separator: "/").map(String.init)
        guard let slug = segments.first?.lowercased(),
              let provider = Provider(rawValue: slug) else { return nil }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let lookup: (String) -> String? = { name in items.first(where: { $0.name == name })?.value }

        return Parsed(
            provider: provider,
            code: lookup("code"),
            state: lookup("state"),
            error: lookup("error"),
            rawURL: url
        )
    }

    /// Handle an incoming URL — parse, post a notification on success, and
    /// report the outcome back to the caller (typically `application(_:open:)`).
    @discardableResult
    static func handle(
        _ url: URL,
        notificationCenter: NotificationCenter = .default
    ) -> Outcome {
        guard url.scheme?.lowercased() == "enviapp" else { return .unrelated }
        guard let parsed = parse(url) else { return .invalid }
        notificationCenter.post(
            name: notificationName,
            object: nil,
            userInfo: ["parsed": parsed]
        )
        return .handled
    }
}

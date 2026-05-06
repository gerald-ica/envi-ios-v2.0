import Foundation

/// Phase 06-04 — thin abstraction over whatever system-provided web auth
/// primitive we use to round-trip through a provider's authorization UI.
///
/// The concrete implementation in v1.1 is `ASWebAuthenticationSessionAdapter`.
/// Keeping this behind a protocol lets us:
///   - swap in a recording stub for UI tests / previews;
///   - inject an offline fake in unit tests;
///   - later migrate to Universal Links (v1.2) without touching callers.
///
/// Callers (e.g. the future OAuthBroker client) are expected to:
///   1. Ask the server for an `authorizationURL` (broker-side state + PKCE).
///   2. `try await start(authorizationURL:callbackScheme:)`.
///   3. Hand the returned URL to `OAuthCallbackHandler.parse(_:)`.
///
/// Main-actor isolation is intentional here: the system auth session presents
/// UIKit-owned UI and must be driven from the main actor.
@MainActor
protocol OAuthSession: AnyObject {
    /// Open the provider's authorization URL in a secure web context and
    /// suspend until the OS re-invokes us via `callbackScheme`.
    ///
    /// - Parameters:
    ///   - authorizationURL: The full provider URL (with state + PKCE).
    ///   - callbackScheme: The custom URL scheme registered in Info.plist
    ///     (`enviapp`). The scheme — NOT the full redirect URI — is what
    ///     `ASWebAuthenticationSession` matches on.
    /// - Returns: The callback URL the provider redirected back to.
    /// - Throws: `OAuthSessionError.userCancelled` if the user dismisses the
    ///   sheet, `OAuthSessionError.callbackURLInvalid` on malformed redirects,
    ///   `OAuthSessionError.sessionAlreadyActive` when called reentrantly.
    func start(authorizationURL: URL, callbackScheme: String) async throws -> URL

    /// Cancel any in-flight session. No-op if none is active.
    func cancel()
}

/// Error surface for OAuthSession implementations. Kept small — callers map
/// these onto `SocialOAuthManager.OAuthError` at the broker boundary.
enum OAuthSessionError: Error, Equatable, LocalizedError {
    case userCancelled
    case callbackURLInvalid(URL)
    case presentationAnchorUnavailable
    case sessionAlreadyActive

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "You cancelled the sign-in."
        case .callbackURLInvalid(let url):
            return "Received an invalid callback from the provider: \(url.absoluteString)"
        case .presentationAnchorUnavailable:
            return "Unable to present sign-in because no active window scene is available."
        case .sessionAlreadyActive:
            return "Another sign-in is already in progress."
        }
    }
}

// Note: the callback URL payload type is defined as `OAuthCallbackHandler.Parsed`
// — see `OAuthCallbackHandler.swift`. Callers receive a parsed payload via the
// `OAuthCallbackHandler.notificationName` Notification userInfo dictionary
// under the key "parsed".

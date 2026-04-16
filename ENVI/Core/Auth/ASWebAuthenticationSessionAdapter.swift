import Foundation
import AuthenticationServices
import UIKit

/// `OAuthSession` implementation backed by `ASWebAuthenticationSession`.
///
/// Design notes:
///   - `prefersEphemeralWebBrowserSession = false` — we WANT provider cookies
///     to persist between connects so reconnecting the same account is a
///     one-tap flow. This is a conscious trade-off: the user is already
///     signed in to e.g. TikTok in Safari, and we don't want to force a full
///     re-login every time.
///   - `@MainActor` because ASWebAuthenticationSession's init + start must run
///     on main, and the presentation anchor is a UIWindow.
///   - We keep a single in-flight session at a time; reentrant calls throw
///     `.sessionAlreadyActive` rather than stacking webviews.
@MainActor
final class ASWebAuthenticationSessionAdapter: NSObject, OAuthSession {
    private var activeSession: ASWebAuthenticationSession?
    private weak var presentationAnchor: ASPresentationAnchor?
    private let presentationAnchorProvider: @MainActor () -> ASPresentationAnchor?

    /// - Parameter presentationAnchorProvider: Injectable so tests can supply
    ///   a stub window and `SceneDelegate` can plug in its managed UIWindow.
    ///   Defaults to "first key window in the foreground-active scene".
    init(
        presentationAnchorProvider: @escaping @MainActor () -> ASPresentationAnchor? = {
            ASWebAuthenticationSessionAdapter.defaultPresentationAnchor()
        }
    ) {
        self.presentationAnchorProvider = presentationAnchorProvider
        super.init()
    }

    func start(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        guard activeSession == nil else {
            throw OAuthSessionError.sessionAlreadyActive
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                // Make sure we only resume the continuation once.
                Task { @MainActor [weak self] in
                    self?.activeSession = nil
                }

                if let error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        continuation.resume(throwing: OAuthSessionError.userCancelled)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(
                        throwing: OAuthSessionError.callbackURLInvalid(authorizationURL)
                    )
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            self.presentationAnchor = self.presentationAnchorProvider()
            self.activeSession = session

            if !session.start() {
                self.activeSession = nil
                continuation.resume(
                    throwing: OAuthSessionError.callbackURLInvalid(authorizationURL)
                )
            }
        }
    }

    func cancel() {
        activeSession?.cancel()
        activeSession = nil
    }

    // MARK: - Default presentation anchor

    private static func defaultPresentationAnchor() -> ASPresentationAnchor? {
        let scenes = UIApplication.shared.connectedScenes
        let activeWindowScene = scenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? scenes.compactMap({ $0 as? UIWindowScene }).first
        return activeWindowScene?.keyWindow
            ?? activeWindowScene?.windows.first
            ?? UIWindow()
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension ASWebAuthenticationSessionAdapter: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        // UIKit requires an anchor. If, for some edge case, we lost the
        // captured anchor, return a throwaway UIWindow — the session will
        // fail-close immediately.
        MainActor.assumeIsolated {
            presentationAnchor ?? UIWindow()
        }
    }
}

//
//  AuthManager+CurrentUser.swift
//  ENVI
//
//  Phase 14 — Plan 03. Thin bridge from `FirebaseAuth.User` to the
//  domain `User` model so feature view models (currently just
//  `ProfileViewModel`) can hydrate identity without each one having to
//  know about Firebase's types.
//
//  Deliberately scoped:
//  - Does NOT round-trip to Firestore. If we need richer profile data
//    (`dateOfBirth`, `location`, etc.) we'll fetch it separately via a
//    dedicated profile repo. This extension only maps what's present on
//    the Firebase Auth session (uid, displayName, email, photoURL).
//  - Returns `nil` when there is no signed-in user — callers are
//    responsible for rendering the empty / loading / error state.
//  - Does NOT mutate `AuthManager.shared`. Intentional — the singleton's
//    observable state is the `authState` enum; this is a pure accessor.
//

import Foundation
import FirebaseCore
import FirebaseAuth

extension AuthManager {

    /// Maps the current `FirebaseAuth.User` (if any) to the domain
    /// `User` model. Returns `nil` when no one is signed in or when
    /// Firebase hasn't been configured yet (which shouldn't happen at
    /// runtime but is guarded for test environments).
    ///
    /// The mapping is intentionally partial:
    /// - `displayName` is split on the first whitespace for
    ///   `firstName` / `lastName`. If it's empty, both fall back to
    ///   empty strings (ProfileView's text labels handle empty
    ///   gracefully).
    /// - `handle` defaults to `@` + the portion of `email` before the
    ///   `@`. If `email` is nil we use `@user`.
    /// - Stats (`publishedCount`, `draftsCount`, `templatesCount`) and
    ///   `connectedPlatforms` are zero / empty — these come from other
    ///   services; `ProfileViewModel.loadConnections()` populates the
    ///   platform list separately.
    func currentUser() -> User? {
        guard FirebaseApp.app() != nil else { return nil }
        guard let fbUser = Auth.auth().currentUser else { return nil }

        let displayName = fbUser.displayName ?? ""
        let parts = displayName
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .map { String($0) }
        let first = parts.first ?? ""
        let last = parts.count > 1 ? parts[1] : ""

        let email = fbUser.email ?? ""
        let handlePrefix: String = {
            if let at = email.firstIndex(of: "@") {
                return String(email[..<at])
            }
            return "user"
        }()

        return User(
            id: UUID(),
            firstName: first,
            lastName: last,
            email: email,
            dateOfBirth: nil,
            location: nil,
            birthplace: nil,
            avatarURL: fbUser.photoURL?.absoluteString,
            handle: "@" + handlePrefix,
            bio: nil,
            connectedPlatforms: [],
            publishedCount: 0,
            draftsCount: 0,
            templatesCount: 0
        )
    }
}

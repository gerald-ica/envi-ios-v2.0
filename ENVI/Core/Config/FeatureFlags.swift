//
//  FeatureFlags.swift
//  ENVI
//
//  Phase 4 — Template Tab v1 (Task 4).
//
//  Centralized feature flags. Reads from Firebase Remote Config when
//  available, falls back to code-defined defaults. Allows runtime A/B
//  tests and safe rollback of Phase 4's Lynx-backed template catalog
//  without an App Store resubmission.
//
//  Integration model
//  -----------------
//  - Defaults live in code (per-flag `#if DEBUG` / release split).
//  - If FirebaseRemoteConfig is linked into the app target,
//    `refreshFromRemoteConfig()` fetches + activates and overrides
//    code defaults for known keys.
//  - If FirebaseRemoteConfig is NOT linked (current Package.swift
//    state — see TODO below), the method is a no-op and code
//    defaults rule.
//
//  The singleton is @MainActor so SwiftUI @Observable observers can
//  bind directly without actor hops. Mutations happen only on the
//  main actor (Remote Config callback or unit-test overrides).
//

import Foundation

#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

/// Centralized feature flags for ENVI. See file header for the full
/// integration model.
@MainActor
@Observable
public final class FeatureFlags {

    /// Process-wide singleton. Direct access is fine from the main
    /// actor (views, view models, coordinators).
    public static let shared = FeatureFlags()

    // MARK: - Template Tab

    /// Source for the video template catalog.
    ///
    /// Accepted values:
    /// - `"lynx"` (default in release): `TemplateCatalogClient`
    ///   fetches the server manifest and downloads the Lynx render
    ///   bundle. Enables shipping new templates without an App
    ///   Store update.
    /// - `"mock"` (default in DEBUG): `MockVideoTemplateRepository`
    ///   for offline development and unit tests.
    ///
    /// Any other value triggers an assertion in debug builds and
    /// falls back to `"mock"` in release (fail-open for emergency
    /// rollback — see Phase 4 PLAN, Task 4).
    public var templateCatalogSource: String = {
        #if DEBUG
        return "mock"
        #else
        return "lynx"
        #endif
    }()

    // MARK: - Connectors (Phase 07)

    /// Controls the OAuth code path used by `SocialOAuthManager`.
    ///
    /// - `true`  (default in DEBUG): the mock code path runs — deterministic
    ///   latency + fake handles, no network. Preserves SwiftUI previews and
    ///   unit-test determinism without wiring a Functions emulator.
    /// - `false` (default in release): real round-trip via the Cloud
    ///   Functions OAuth broker (Phase 07) — `POST /oauth/:provider/start`,
    ///   `ASWebAuthenticationSession`, `GET /oauth/:provider/status`.
    ///
    /// Remote Config key: `"connectorsUseMockOAuth"`. Setting it at runtime
    /// lets us flip the mock path on in prod as an emergency brake if a
    /// broker deploy breaks (e.g. provider outage, secret rotation gap).
    public var connectorsUseMockOAuth: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    // MARK: - Init

    /// Private to enforce singleton use. Tests that need an isolated
    /// instance should mutate `shared` and restore state in
    /// `tearDown` — the class is intentionally final and non-Sendable
    /// so a full stub swap is unnecessary for current test needs.
    private init() {}

    // MARK: - Remote Config refresh

    /// Fetches the latest Remote Config values and activates them,
    /// then copies the known string/bool flags into this instance.
    ///
    /// If `FirebaseRemoteConfig` is not linked into the target this
    /// is a no-op — code defaults remain authoritative.
    ///
    /// Safe to call multiple times. Errors are swallowed (flags just
    /// keep their previous values); callers that need to know
    /// whether a refresh succeeded should observe the flag
    /// properties for change.
    public func refreshFromRemoteConfig() async {
        #if canImport(FirebaseRemoteConfig)
        let rc = RemoteConfig.remoteConfig()
        do {
            _ = try await rc.fetchAndActivate()
            applyRemoteConfigValues(from: rc)
        } catch {
            // Swallow — keep current (code or previously-activated) values.
        }
        #else
        // TODO(phase-4): When FirebaseRemoteConfig is added to
        // Package.swift, delete this branch. Until then, Remote
        // Config is a no-op and code defaults rule.
        return
        #endif
    }

    #if canImport(FirebaseRemoteConfig)
    private func applyRemoteConfigValues(from rc: RemoteConfig) {
        let catalogKey = "templateCatalogSource"
        let catalogValue = rc.configValue(forKey: catalogKey).stringValue
        if !catalogValue.isEmpty {
            self.templateCatalogSource = catalogValue
        }

        let mockOAuthKey = "connectorsUseMockOAuth"
        let mockOAuthValue = rc.configValue(forKey: mockOAuthKey)
        // Only override when Remote Config actually carries a value —
        // `.stringValue` on a missing key returns "" so we check the raw
        // data length as well.
        if mockOAuthValue.dataValue.count > 0 {
            self.connectorsUseMockOAuth = mockOAuthValue.boolValue
        }
    }
    #endif
}

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
    /// - `true`: the mock code path runs — deterministic latency + fake
    ///   handles, no network. Intended for SwiftUI previews and unit tests
    ///   only; tests/previews flip this on their own before exercising the
    ///   manager.
    /// - `false` (default, DEBUG + release): real round-trip via the Cloud
    ///   Functions OAuth broker (Phase 07) — `POST /oauth/:provider/start`,
    ///   `ASWebAuthenticationSession`, `GET /oauth/:provider/status`.
    ///
    /// Remote Config key: `"connectorsUseMockOAuth"`. Setting it at runtime
    /// lets us flip the mock path on in prod as an emergency brake if a
    /// broker deploy breaks (e.g. provider outage, secret rotation gap).
    ///
    /// Production-readiness note: onboarding now bootstraps an anonymous
    /// Firebase identity so broker calls have a valid UID even before the
    /// user has completed email/Apple/Google sign-in — so there is no
    /// reason to mock in DEBUG.
    public var connectorsUseMockOAuth: Bool = false

    // MARK: - TikTok Connector (Phase 08)

    /// Gates the real TikTok sandbox connector path.
    ///
    /// - `true` (staging/prod default): `SocialOAuthManager.connect(.tiktok)`
    ///   delegates to `TikTokConnector.shared.connect()` which drives the
    ///   broker round-trip against TikTok's sandbox.
    /// - `false` (DEBUG default): legacy behaviour — `SocialOAuthManager`
    ///   handles `.tiktok` the same way it handles every other provider.
    ///   Keeps unit tests deterministic and avoids invoking the new code
    ///   path from SwiftUI previews.
    ///
    /// Remote Config key: `"useTikTokConnector"`. Flipping at runtime lets
    /// us disable the real connector in prod without a resubmission if a
    /// broker deploy regresses. Works together with
    /// `connectorsUseMockOAuth`: BOTH flags' conditions must be satisfied
    /// (mock off, connector on) for the real path to run.
    public var useTikTokConnector: Bool = true

    // MARK: - X Connector (Phase 09)

    /// Gates the real X (Twitter) proxy routes (`/connectors/x/*`).
    ///
    /// - `true`  (default in release): publish / media / account calls hit
    ///   the Cloud Function which proxies to `api.x.com` v2 endpoints.
    /// - `false` (default in DEBUG): `XTwitterConnector` returns
    ///   deterministic mock payloads — no network, stable ids for
    ///   snapshot tests.
    ///
    /// Remote Config key: `"useXConnector"`. Flip to `false` in prod as an
    /// emergency brake if X has an outage or we hit a rate-limit wall
    /// that needs a broader fix.
    public var useXConnector: Bool = true

    // MARK: - Meta Family (Phase 10)

    /// Gates the Facebook Pages connector in the Connect UI.
    ///
    /// FB Pages publishing requires Meta App Review approval for
    /// `pages_manage_posts` + `pages_read_engagement` scopes. Until that is
    /// granted, `.facebook` must NOT appear as a user-connectable option.
    /// Instagram and Threads each have their own App Review lifecycles and
    /// are gated independently by their connector code paths.
    ///
    /// Default: `false`. Flip to `true` via Remote Config once App Review
    /// completes (key `"canConnectFacebook"`).
    public var canConnectFacebook: Bool = false

    // MARK: - Analytics Insights (Phase 13)

    /// Gates the Firestore-backed analytics / advanced / benchmark repositories.
    ///
    /// - `true` (default): `FirestoreBackedAnalyticsRepository`,
    ///            `FirestoreBackedAdvancedAnalyticsRepository`, and
    ///            `FirestoreBackedBenchmarkRepository` read from the per-user
    ///            `insights/{provider}/{yyyy-mm-dd}` docs written by the
    ///            nightly Cloud Function sync (see Phase 13-01). Users with
    ///            no connected accounts see `ConnectAccountEmptyStateView`.
    /// - `false`: legacy mock/API path — existing mock/API repositories keep
    ///            serving the same canned data they shipped in v1.0. Set via
    ///            Remote Config for rollback if the sync job regresses.
    ///
    /// Remote Config key: `"connectorsInsightsLive"`. Flipped to `true` by
    /// default in Phase 14-02 once `FirebaseFirestore` was linked (14-01) and
    /// the provider chain was pinned by XCTest. Rollback: set the Remote
    /// Config key to `false` and call `refreshFromRemoteConfig()`.
    public var connectorsInsightsLive: Bool = true

    // MARK: - Admin & Enterprise Tools (Phase 16-04)

    /// Gates the Admin + Enterprise entries in the Library tools menu
    /// (and any future Admin-only surface).
    ///
    /// - `true`: `LibraryToolsMenu` renders Admin (`SystemHealthView`)
    ///           and Enterprise (`ContractManagerView`) alongside the
    ///           creator-facing tools. Intended for internal dogfooding
    ///           and future role-gated enterprise tenants.
    /// - `false` (default): those rows are hidden entirely from the
    ///           menu — regular creators never see them.
    ///
    /// This is a hard-coded placeholder until the role system lands
    /// (role-based visibility tracked in the Phase-17 roadmap). Remote
    /// Config key: `"showAdminTools"`. Flipping true in Remote Config
    /// will expose the admin surfaces app-wide without a resubmission.
    public var showAdminTools: Bool = false

    // MARK: - USM (Sprint 1 + 2)

    /// Master kill-switch for the User Self-Model feature.
    /// - `true`: USM cache + sync + onboarding + recompute enabled.
    /// - `false` (default in release): USM pipeline inactive; legacy code paths only.
    /// Remote Config key: `"usmEnabled"`.
    public var usmEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Controls whether the USM 4-screen onboarding coordinator is used.
    /// Requires `usmEnabled == true`. When both flags are on, new users see the
    /// USM-specific flow (name, DOB+time, birth place, current location) instead
    /// of the legacy `OnboardingCoordinator`.
    /// Remote Config key: `"usmOnboardingEnabled"`.
    public var usmOnboardingEnabled: Bool = {
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

        let xConnectorKey = "useXConnector"
        let xConnectorValue = rc.configValue(forKey: xConnectorKey)
        if xConnectorValue.dataValue.count > 0 {
            self.useXConnector = xConnectorValue.boolValue
        }

        let tiktokConnectorKey = "useTikTokConnector"
        let tiktokConnectorValue = rc.configValue(forKey: tiktokConnectorKey)
        if tiktokConnectorValue.dataValue.count > 0 {
            self.useTikTokConnector = tiktokConnectorValue.boolValue
        }

        let insightsLiveKey = "connectorsInsightsLive"
        let insightsLiveValue = rc.configValue(forKey: insightsLiveKey)
        if insightsLiveValue.dataValue.count > 0 {
            self.connectorsInsightsLive = insightsLiveValue.boolValue
        }

        let usmEnabledKey = "usmEnabled"
        let usmEnabledValue = rc.configValue(forKey: usmEnabledKey)
        if usmEnabledValue.dataValue.count > 0 {
            self.usmEnabled = usmEnabledValue.boolValue
        }

        let usmOnboardingEnabledKey = "usmOnboardingEnabled"
        let usmOnboardingEnabledValue = rc.configValue(forKey: usmOnboardingEnabledKey)
        if usmOnboardingEnabledValue.dataValue.count > 0 {
            self.usmOnboardingEnabled = usmOnboardingEnabledValue.boolValue
        }
    }
    #endif
}

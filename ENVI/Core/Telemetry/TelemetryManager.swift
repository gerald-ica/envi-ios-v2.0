import Foundation
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

final class TelemetryManager {
    static let shared = TelemetryManager()

    private init() {}

    // MARK: - Event Catalog

    enum Event: String {
        // App Lifecycle
        case appLaunched = "app_launched"

        // Auth
        case authSignInStarted = "auth_sign_in_started"
        case authSignInSucceeded = "auth_sign_in_succeeded"
        case authSignInFailed = "auth_sign_in_failed"
        case authSignedOut = "auth_signed_out"

        // Content Lifecycle
        case contentImportStarted = "content_import_started"
        case contentImportCompleted = "content_import_completed"
        case contentImportFailed = "content_import_failed"
        case contentAssemblyStarted = "content_assembly_started"
        case contentAssemblyCompleted = "content_assembly_completed"
        case contentAssemblyFailed = "content_assembly_failed"
        case contentViewed = "content_viewed"
        case contentEdited = "content_edited"
        case contentDeleted = "content_deleted"

        // Publishing
        case publishStarted = "publish_started"
        case publishCompleted = "publish_completed"
        case publishFailed = "publish_failed"
        case publishScheduled = "publish_scheduled"
        case publishCancelled = "publish_cancelled"
        case platformConnected = "platform_connected"
        case platformDisconnected = "platform_disconnected"

        // OAuth Lifecycle — Phase 12
        // Fired by `SocialOAuthManager.connect/disconnect/refreshToken`.
        // Parameters are enforced no-PII: platform slug + sanitized error
        // code only. Never log handles, tokens, captions, media URIs.
        case oauthConnectSuccess  = "oauth_connect_success"
        case oauthConnectFailure  = "oauth_connect_failure"
        case oauthDisconnect      = "oauth_disconnect"
        case oauthRefreshSuccess  = "oauth_refresh_success"
        case oauthRefreshFailure  = "oauth_refresh_failure"

        // Publish Dispatcher — Phase 12
        // `publishDispatch` fires client-side when the job is accepted by
        // the dispatcher Callable. `publishProviderSuccess`/`Failure` fire
        // server-side from each platform worker (see
        // `functions/src/publish/workers/*`).
        case publishDispatch         = "publish_dispatch"
        case publishProviderSuccess  = "publish_provider_success"
        case publishProviderFailure  = "publish_provider_failure"

        // Library & Planning
        case libraryOpened = "library_opened"
        case librarySearched = "library_searched"
        case libraryFiltered = "library_filtered"
        case planItemCreated = "plan_item_created"
        case planItemUpdated = "plan_item_updated"
        case planItemDeleted = "plan_item_deleted"
        case planItemReordered = "plan_item_reordered"
        case templateApplied = "template_applied"
        case templateDuplicated = "template_duplicated"
        case templateDeleted = "template_deleted"

        // Analytics Dashboard
        case analyticsViewed = "analytics_viewed"
        case analyticsPlatformFiltered = "analytics_platform_filtered"
        case cohortViewed = "cohort_viewed"
        case attributionViewed = "attribution_viewed"

        // Editor
        case editorOpened = "editor_opened"
        case editorExportStarted = "editor_export_started"
        case editorExportCompleted = "editor_export_completed"
        case editorTrimApplied = "editor_trim_applied"

        // Subscription
        case paywallViewed = "paywall_viewed"
        case paywallDismissed = "paywall_dismissed"
        case subscriptionStarted = "subscription_started"
        case subscriptionRestored = "subscription_restored"

        // Navigation
        case tabSwitched = "tab_switched"
        case screenViewed = "screen_viewed"
        case oracleThreadStarted = "oracle_thread_started"
        case oracleMessageSent = "oracle_message_sent"

        // Media Scan (Phase 6, Task 3) — background classification pipeline.
        // No PII: only counts, durations, coarse state strings.
        case mediaScanStarted = "media_scan_started"
        case mediaScanCompleted = "media_scan_completed"
        case mediaScanThermalPause = "media_scan_thermal_pause"
        case mediaScanThermalResume = "media_scan_thermal_resume"
        case mediaScanFailedAssets = "media_scan_failed_assets"

        // Template Tab (Phase 6, Task 3) — user-facing template flow.
        case templateTabOpened = "template_tab_opened"
        case templateSelected = "template_selected"
        case templateSlotSwapped = "template_slot_swapped"
        case templateExported = "template_exported"

        // Embedding index lifecycle.
        case embeddingIndexRebuilt = "embedding_index_rebuilt"
    }

    // MARK: - Core Tracking

    func track(_ event: Event, parameters: [String: Any]? = nil) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(event.rawValue, parameters: parameters)
    }

    func record(error: Error, context: String) {
        guard FirebaseApp.app() != nil else { return }
        Crashlytics.crashlytics().setCustomValue(context, forKey: "context")
        Crashlytics.crashlytics().record(error: error)
    }

    // MARK: - Convenience Methods

    func trackScreen(_ screenName: String) {
        track(.screenViewed, parameters: ["screen_name": screenName])
    }

    func trackContent(_ event: Event, contentID: String, platform: String? = nil) {
        var params: [String: Any] = ["content_id": contentID]
        if let platform { params["platform"] = platform }
        track(event, parameters: params)
    }

    func trackPublish(_ event: Event, jobID: String, platforms: [String]) {
        track(event, parameters: [
            "job_id": jobID,
            "platforms": platforms.joined(separator: ",")
        ])
    }

    // MARK: - OAuth / Publish Telemetry (Phase 12)
    //
    // Strict no-PII policy: only platform slug, sanitized error code, job_id,
    // and attempt count are permitted. Do NOT add handles, tokens, captions,
    // media URIs, or raw provider error bodies.

    /// Fire an OAuth lifecycle event. `platform` is the lowercased
    /// `SocialPlatform.apiSlug`. `error` is a sanitized code
    /// (`rate_limited`, `auth_expired`, `unknown`, …) — never a raw provider
    /// body.
    func trackOAuth(_ event: Event, platform: String, error: String? = nil) {
        var params: [String: Any] = ["platform": platform]
        if let error { params["error"] = error }
        track(event, parameters: params)
    }

    /// Fire a per-provider publish event. `jobID` matches the Firestore doc
    /// under `publish_jobs/{jobID}`. `attempt` is 1-indexed and comes from
    /// the worker's stored attempt count (not Pub/Sub delivery count).
    func trackPublishProvider(
        _ event: Event,
        jobID: String,
        platform: String,
        attempt: Int,
        error: String? = nil
    ) {
        var params: [String: Any] = [
            "job_id": jobID,
            "platform": platform,
            "attempt": attempt
        ]
        if let error { params["error"] = error }
        track(event, parameters: params)
    }

    // MARK: - User Properties

    func setUserProperty(_ value: String?, forName name: String) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.setUserProperty(value, forName: name)
    }

    func setUserID(_ uid: String?) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.setUserID(uid)
    }

    // MARK: - Media Scan Telemetry (Phase 6, Task 3)
    //
    // Strict no-PII policy: never log PHAsset.localIdentifiers, filenames,
    // locations, or any per-asset content. Events capture only counts,
    // durations, template IDs (which are catalog-public), and coarse
    // state strings (e.g. thermal state enum names).

    func logMediaScanStarted(assetCount: Int, scanType: String) {
        track(.mediaScanStarted, parameters: [
            "asset_count": assetCount,
            "scan_type": scanType
        ])
    }

    func logMediaScanCompleted(assetCount: Int, duration: TimeInterval, scanType: String) {
        track(.mediaScanCompleted, parameters: [
            "asset_count": assetCount,
            "duration_ms": Int(duration * 1000),
            "scan_type": scanType
        ])
    }

    func logMediaScanThermalPause(state: String) {
        track(.mediaScanThermalPause, parameters: [
            "thermal_state": state
        ])
    }

    func logMediaScanThermalResume() {
        track(.mediaScanThermalResume, parameters: nil)
    }

    func logMediaScanFailedAssets(count: Int, reasonsSummary: String) {
        track(.mediaScanFailedAssets, parameters: [
            "failed_count": count,
            "reasons": reasonsSummary
        ])
    }

    // MARK: - Template Tab Telemetry

    func logTemplateTabOpened() {
        track(.templateTabOpened, parameters: nil)
    }

    func logTemplateSelected(templateID: String, fillRate: Double) {
        track(.templateSelected, parameters: [
            "template_id": templateID,
            "fill_rate": fillRate
        ])
    }

    func logTemplateSlotSwapped(templateID: String, slotID: String) {
        track(.templateSlotSwapped, parameters: [
            "template_id": templateID,
            "slot_id": slotID
        ])
    }

    func logTemplateExported(templateID: String, durationToExport: TimeInterval) {
        track(.templateExported, parameters: [
            "template_id": templateID,
            "export_duration_ms": Int(durationToExport * 1000)
        ])
    }

    // MARK: - Embedding Index

    func logEmbeddingIndexRebuilt(assetCount: Int, duration: TimeInterval) {
        track(.embeddingIndexRebuilt, parameters: [
            "asset_count": assetCount,
            "duration_ms": Int(duration * 1000)
        ])
    }
}

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

    // MARK: - User Properties

    func setUserProperty(_ value: String?, forName name: String) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.setUserProperty(value, forName: name)
    }

    func setUserID(_ uid: String?) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.setUserID(uid)
    }
}

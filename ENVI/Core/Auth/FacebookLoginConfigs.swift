import Foundation

/// Facebook Login for Business configuration IDs registered against the
/// ENVI Meta app (App ID `1422291482707790` — the production parent;
/// test child `1233228574968466` is no longer used by iOS).
///
/// These IDs come from the **Use cases** tab on the Meta App dashboard.
/// Each Login for Business "use case" gets its own config ID that binds a
/// fixed permission set + audience to a single identifier; web/JS SDK
/// callers pass `config_id=...` to `FB.login()` to drive the right
/// consent screen.
///
/// **iOS native SDK does NOT consume these IDs.** FBSDK 18.0.3's
/// `LoginConfiguration` has no `loginConfigID` parameter — the iOS SDK
/// uses Meta's *default* Login for Business config when
/// `LoginManager.logIn(permissions:from:)` runs. So these constants are
/// only referenced by:
///
/// 1. The **publishing connector flow** (`SocialOAuthManager`), which
///    drives `ASWebAuthenticationSession` directly to a manually-built
///    `m.facebook.com/v18.0/dialog/oauth?...&config_id=...` URL.
/// 2. Server-side broker exchanges that mirror the web flow.
///
/// If we ever need to differentiate sign-in vs posting on iOS we'd have
/// to build that web-based path; the SDK doesn't expose a hook.
enum FacebookLoginConfigs {

    /// User authentication / sign-in (parent-app config "Envi").
    /// Currently scoped to `email` + `instagram_basic` — `public_profile`
    /// requires Advanced Access on the parent app, which is gated on
    /// app review submission. Once Advanced Access is approved, edit
    /// the dashboard config to add `public_profile` and (optionally)
    /// drop the `instagram_basic` companion that was added to satisfy
    /// Meta's "email needs a partner scope" wizard rule.
    static let signIn = "1600816680981138"

    /// Page management (parent-app config "Instagram Onboarding").
    /// Scopes: `pages_show_list`, `pages_manage_posts`,
    /// `pages_read_engagement`, `instagram_basic`,
    /// `instagram_content_publish`. Used by `SocialOAuthManager` when
    /// the user taps "Connect Facebook Page" in the Profile/Connectors
    /// UI.
    static let pageManagement = "954328457361944"

    /// Instagram Creator Marketplace (parent-app config). Scopes:
    /// `instagram_basic`, `instagram_content_publish`,
    /// `pages_show_list`, `instagram_branded_content_brand`,
    /// `instagram_branded_content_creator`,
    /// `instagram_manage_insights`. Used for the branded-content
    /// onboarding flow.
    static let thirdConfig = "966476716301984"
}

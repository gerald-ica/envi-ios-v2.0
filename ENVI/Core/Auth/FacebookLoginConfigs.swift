import Foundation

/// Facebook Login for Business configuration IDs registered against the
/// ENVI Meta app (App ID `1233228574968466`).
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

    /// User authentication / sign-in. Asks for `email` + `public_profile`
    /// only. Used at the SignInView "Continue with Facebook" entry
    /// point — but right now the iOS SDK ignores this and uses the
    /// dashboard's default config instead. Kept here so a future web
    /// flow can target the right config explicitly.
    static let signIn = "1340471514631612"

    /// Page management — content publishing, post creation, page
    /// insights. This is what `SocialOAuthManager` will pass to the
    /// connector OAuth flow when a user taps "Connect Facebook Page" in
    /// the Profile/Connectors UI. Scope set on the dashboard side
    /// includes `pages_manage_posts`, `pages_read_engagement`,
    /// `pages_show_list`.
    static let pageManagement = "4386185514970426"

    /// Third Login for Business configuration. Likely tied to a separate
    /// connector (Instagram Graph, Threads, or ad-account access) — to be
    /// confirmed on the Meta dashboard when we wire the corresponding
    /// connector flow.
    static let thirdConfig = "2189661441829437"
}

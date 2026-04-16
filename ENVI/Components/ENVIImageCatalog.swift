import SwiftUI

/// Central catalog of all image assets from the ENVI iOS v2.0 Sketch files.
/// Structure: Symbols:Badges:Icons:Decor | Backgrounds | Sample Users Photos | Root
enum ENVIImageCatalog {

    // MARK: - Symbols, Badges, Icons & Decor

    static let enviLogo              = Image("Symbols:Badges:Icons:Decor/envi-logo")
    static let shape07               = Image("Symbols:Badges:Icons:Decor/shape-07")
    static let shape15               = Image("Symbols:Badges:Icons:Decor/shape-15")
    static let shape01               = Image("Symbols:Badges:Icons:Decor/shape-01")
    static let shape01Alt            = Image("Symbols:Badges:Icons:Decor/shape-01-alt")
    static let shape25               = Image("Symbols:Badges:Icons:Decor/shape-25")
    static let aiConfidence          = Image("Symbols:Badges:Icons:Decor/envi-ai-confidence")
    static let aiConfidenceAlt       = Image("Symbols:Badges:Icons:Decor/envi-ai-confidence-alt")
    static let headerAbstractShape   = Image("Symbols:Badges:Icons:Decor/header-abstract-shape")
    static let abstractShapeBehindLogo = Image("Symbols:Badges:Icons:Decor/abstract-shape-behind-logo")
    static let abstractDecoration1   = Image("Symbols:Badges:Icons:Decor/abstract-decoration-1")
    static let abstractDecoration2   = Image("Symbols:Badges:Icons:Decor/abstract-decoration-2")
    static let particleShape34b      = Image("Symbols:Badges:Icons:Decor/particle-shape-34b")
    static let decoShape10           = Image("Symbols:Badges:Icons:Decor/deco-shape-10")
    static let chatHomeIcon          = Image("Symbols:Badges:Icons:Decor/chat-home-icon")

    static let badgeAnalyticsPro     = Image("Symbols:Badges:Icons:Decor/badge-analytics-pro")
    static let badgeMultiPlat        = Image("Symbols:Badges:Icons:Decor/badge-multi-plat")
    static let badgeScheduler        = Image("Symbols:Badges:Icons:Decor/badge-scheduler")
    static let badgeStreak7          = Image("Symbols:Badges:Icons:Decor/badge-streak-7")
    static let badgeTopCreator       = Image("Symbols:Badges:Icons:Decor/badge-top-creator")

    static func decorativeShape(_ number: Int) -> Image {
        Image("Symbols:Badges:Icons:Decor/decorative-shape-\(number)")
    }

    static let decorativeAIVisualEditor    = Image("Symbols:Badges:Icons:Decor/decorative-ai-visual-editor")
    static let decorativeCaptionGenerator  = Image("Symbols:Badges:Icons:Decor/decorative-caption-generator")
    static let decorativeHookLibrary       = Image("Symbols:Badges:Icons:Decor/decorative-hook-library")
    static let decorativeIdeaBoard         = Image("Symbols:Badges:Icons:Decor/decorative-idea-board")
    static let decorativeIdeationDashboard = Image("Symbols:Badges:Icons:Decor/decorative-ideation-dashboard")
    static let decorativeImageGenerator    = Image("Symbols:Badges:Icons:Decor/decorative-image-generator")
    static let decorativeScriptEditor      = Image("Symbols:Badges:Icons:Decor/decorative-script-editor")
    static let decorativeStyleTransfer     = Image("Symbols:Badges:Icons:Decor/decorative-style-transfer")

    // MARK: - Backgrounds

    static let bg1                   = Image("Backgrounds/bg-1")
    static let bg2                   = Image("Backgrounds/bg-2")
    static let bg3                   = Image("Backgrounds/bg-3")
    static let avatarBg              = Image("Backgrounds/avatar-bg")
    static let worldExplorerBg       = Image("Backgrounds/world-explorer-bg")
    static let frontCard1            = Image("Backgrounds/front-card-1")
    static let frontCard2            = Image("Backgrounds/front-card-2")
    static let heroImage             = Image("Backgrounds/hero-image")
    static let analyticsBg           = Image("Backgrounds/analytics-bg")
    static let profileBg             = Image("Backgrounds/profile-bg")
    static let chatHomeBg            = Image("Backgrounds/chat-home-bg")
    static let decorativeGlass       = Image("Backgrounds/decorative-glass")
    static let fractalGlass          = Image("Backgrounds/fractal-glass-5")
    static let fractalGlassOverlay   = Image("Backgrounds/fractal-glass-overlay")
    static let fractalGlassImageGen  = Image("Backgrounds/fractal-glass-image-generator")
    static let fractalGlassStyleXfer = Image("Backgrounds/fractal-glass-style-transfer")
    static let abstract9             = Image("Backgrounds/abstract-9")

    static let glassCube             = Image("Backgrounds/3D-Assets-bg/glass-cube")
    static let glassWireframeSphere  = Image("Backgrounds/3D-Assets-bg/glass-wireframe-sphere")
    static let abstract7             = Image("Backgrounds/3D-Assets-bg/abstract-7")

    static func bgTexture(_ number: Int) -> Image {
        Image("Backgrounds/bg-texture-\(String(format: "%02d", number))")
    }

    // MARK: - Sample Users Photos

    static let contactAvatar         = Image("Sample Users Photos/contact-avatar")

    static func avatarAgency(_ number: Int) -> Image {
        Image("Sample Users Photos/avatar-agency-\(number)")
    }

    static func avatarAudit(_ number: Int) -> Image {
        Image("Sample Users Photos/avatar-audit-\(number)")
    }

    static func photo(_ number: Int) -> Image {
        Image("Sample Users Photos/photo-\(String(format: "%02d", number))")
    }

    static func contentPhoto(_ number: Int) -> Image {
        Image("Sample Users Photos/content-photo-\(String(format: "%02d", number))")
    }

    static func marketplacePhoto(_ number: Int) -> Image {
        Image("Sample Users Photos/marketplace-photo-\(number)")
    }

    static func templatePhoto(_ number: Int) -> Image {
        Image("Sample Users Photos/template-photo-\(number)")
    }

    static func previewPhoto(_ number: Int) -> Image {
        Image("Sample Users Photos/preview-photo-\(number)")
    }

    static let previewFill           = Image("Sample Users Photos/preview-fill")
    static let contentPreviewThumb   = Image("Sample Users Photos/content-preview-thumb")
    static let photoPreview1         = Image("Sample Users Photos/photo-preview-1")
    static let resultAThumb          = Image("Sample Users Photos/result-a-thumb")
    static let resultBThumb          = Image("Sample Users Photos/result-b-thumb")
    static let variantBThumb         = Image("Sample Users Photos/variant-b-thumb")
    static let postPreviewImage      = Image("Sample Users Photos/post-preview-image")
    static let thumbHolidayPromo     = Image("Sample Users Photos/thumb-holiday-promo")
    static let thumbProductLaunchQ3  = Image("Sample Users Photos/thumb-product-launch-q3")
    static let thumbBrandRefresh     = Image("Sample Users Photos/thumb-brand-refresh")
}

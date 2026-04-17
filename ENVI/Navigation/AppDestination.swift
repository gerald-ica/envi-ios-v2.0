import Foundation

/// Phase 15-01 — Central route registry for ENVI's SwiftUI surface.
///
/// Each case represents a reachable destination in the app. The enum is
/// pure data — it deliberately does NOT depend on SwiftUI so it can be
/// unit-tested without the UI framework. `AppRouter` (a separate file)
/// consumes these values to drive `.sheet(item:)` / `.fullScreenCover(item:)`
/// and cross-tab navigation.
///
/// Payloads are kept minimal — a String id rather than a whole model —
/// so two destinations with the same identity compare equal and
/// `sheet(item:)` can key off `id` safely.
///
/// Cases enumerated here come from the 2026-04-17 Frontend Audit:
///   - 14 orphan Modal groups under `ENVI/Features/Modals/*`
///   - 7 AIFeatures views under `ENVI/Features/ChatExplore/AIFeatures/*`
///   - 6 Profile sub-sections
///   - Existing live destinations that Plan 15-02 migrates
enum AppDestination: Identifiable, Hashable, Equatable {

    // MARK: - Presentation style

    /// How a destination prefers to be surfaced. `AppRouter` honors this
    /// unless the caller of `present(_:preferring:)` overrides.
    enum Presentation: Hashable {
        case sheet
        case fullScreenCover
        case push
        case tab(Int)
    }

    // MARK: - Modals / Admin & Enterprise

    case admin
    case enterprise

    // MARK: - Modals / Agency & Teams

    case agency
    case teams

    // MARK: - Modals / Brand & Campaigns

    case brandKit
    case campaigns
    case campaignDetail(id: String)

    // MARK: - Modals / Collaboration & Community

    case collaboration
    case community

    // MARK: - Modals / Commerce

    case commerce

    // MARK: - Modals / Experiments

    case experiments

    // MARK: - Modals / Metadata

    case metadata

    // MARK: - Modals / Publishing & Scheduling

    case publishing
    case contentCalendar
    case schedulePost
    case publishResults
    case linkedInAuthorPicker

    // MARK: - Modals / Repurposing

    case repurposing

    // MARK: - Modals / Search

    case search

    // MARK: - AIFeatures (7 views under ChatExplore/AIFeatures)

    case ideation
    case aiVisualEditor
    case captionGenerator
    case hookLibrary
    case scriptEditor
    case styleTransfer
    case imageGenerator

    // MARK: - Profile sub-sections (6)

    case notifications
    case security
    case billing
    case education
    case support
    case subscription

    // MARK: - Existing live destinations (migrated in Plan 15-02)

    case chatHistory
    case contentLibrarySettings
    case exportSheet
    case mediaPicker
    case phPicker

    // MARK: - Editor (full-screen)

    case contentEditor(contentID: String)

    // MARK: - Identifiable

    /// Stable, case-name + payload-scoped id so `.sheet(item:)` can key
    /// off it without collisions between destinations that share a payload
    /// shape.
    var id: String {
        switch self {
        // No-payload cases
        case .admin: return "admin"
        case .enterprise: return "enterprise"
        case .agency: return "agency"
        case .teams: return "teams"
        case .brandKit: return "brandKit"
        case .campaigns: return "campaigns"
        case .collaboration: return "collaboration"
        case .community: return "community"
        case .commerce: return "commerce"
        case .experiments: return "experiments"
        case .metadata: return "metadata"
        case .publishing: return "publishing"
        case .contentCalendar: return "contentCalendar"
        case .schedulePost: return "schedulePost"
        case .publishResults: return "publishResults"
        case .linkedInAuthorPicker: return "linkedInAuthorPicker"
        case .repurposing: return "repurposing"
        case .search: return "search"
        case .ideation: return "ideation"
        case .aiVisualEditor: return "aiVisualEditor"
        case .captionGenerator: return "captionGenerator"
        case .hookLibrary: return "hookLibrary"
        case .scriptEditor: return "scriptEditor"
        case .styleTransfer: return "styleTransfer"
        case .imageGenerator: return "imageGenerator"
        case .notifications: return "notifications"
        case .security: return "security"
        case .billing: return "billing"
        case .education: return "education"
        case .support: return "support"
        case .subscription: return "subscription"
        case .chatHistory: return "chatHistory"
        case .contentLibrarySettings: return "contentLibrarySettings"
        case .exportSheet: return "exportSheet"
        case .mediaPicker: return "mediaPicker"
        case .phPicker: return "phPicker"
        // Cases with payloads — include the payload so siblings with
        // different ids don't collide.
        case .campaignDetail(let id): return "campaignDetail:\(id)"
        case .contentEditor(let id): return "contentEditor:\(id)"
        }
    }

    // MARK: - Default presentation

    /// Preferred surfacing style. Caller may override via
    /// `AppRouter.present(_:preferring:)`.
    var defaultPresentation: Presentation {
        switch self {
        case .contentEditor:
            // Editor takes over — full-screen.
            return .fullScreenCover
        default:
            return .sheet
        }
    }
}

import Foundation

// MARK: - Waterfall Platform

/// Platforms available for waterfall (repurpose) suggestions.
/// A superset of content platforms including non-social destinations.
enum WaterfallPlatform: String, Codable, CaseIterable {
    case instagram  = "Instagram"
    case youtube    = "YouTube"
    case twitter    = "Twitter"
    case linkedin   = "LinkedIn"
    case pinterest  = "Pinterest"
    case website    = "Website"
    case metaAds    = "Meta Ads"
}

// MARK: - Waterfall Suggestion

/// AI-generated repurpose suggestion for a content piece.
/// Each suggestion recommends converting the piece into a different format
/// for a specific platform, with a brief description of the approach.
struct WaterfallSuggestion: Identifiable, Codable {
    let id: UUID
    let format: String
    let platform: WaterfallPlatform
    let description: String

    init(id: UUID = UUID(), format: String, platform: WaterfallPlatform, description: String) {
        self.id = id
        self.format = format
        self.platform = platform
        self.description = description
    }

    /// Returns waterfall (repurpose) suggestions tailored to the content piece type.
    /// Ported from WorldExplorer.tsx getWaterfallSuggestions().
    static func suggestions(for piece: ContentPiece) -> [WaterfallSuggestion] {
        switch piece.type {
        case .video, .reel:
            return [
                WaterfallSuggestion(
                    format: "Story Clips",
                    platform: .instagram,
                    description: "Split into 3–4 story segments with poll stickers"
                ),
                WaterfallSuggestion(
                    format: "YouTube Short",
                    platform: .youtube,
                    description: "Vertical 15s cut with hook-first edit"
                ),
                WaterfallSuggestion(
                    format: "GIF Set",
                    platform: .twitter,
                    description: "Extract 3 reaction-worthy moments as GIFs"
                ),
                WaterfallSuggestion(
                    format: "Carousel Stills",
                    platform: .instagram,
                    description: "Pull best frames into a swipeable breakdown"
                ),
            ]
        case .carousel:
            return [
                WaterfallSuggestion(
                    format: "Thread",
                    platform: .twitter,
                    description: "Convert each slide into a numbered tweet thread"
                ),
                WaterfallSuggestion(
                    format: "LinkedIn Post",
                    platform: .linkedin,
                    description: "Summarize key slides into a text post with takeaways"
                ),
                WaterfallSuggestion(
                    format: "Reel Slideshow",
                    platform: .instagram,
                    description: "Animate slides with transitions and trending audio"
                ),
                WaterfallSuggestion(
                    format: "Blog Draft",
                    platform: .website,
                    description: "Expand carousel points into a full article"
                ),
            ]
        case .photo, .story:
            return [
                WaterfallSuggestion(
                    format: "Story Post",
                    platform: .instagram,
                    description: "Add context text and a question sticker for engagement"
                ),
                WaterfallSuggestion(
                    format: "Pin",
                    platform: .pinterest,
                    description: "Reformat to 2:3 ratio with keyword-rich description"
                ),
                WaterfallSuggestion(
                    format: "Quote Card",
                    platform: .linkedin,
                    description: "Overlay a key insight as a typography-forward card"
                ),
                WaterfallSuggestion(
                    format: "Ad Creative",
                    platform: .metaAds,
                    description: "Crop and add CTA overlay for paid campaign testing"
                ),
            ]
        }
    }
}

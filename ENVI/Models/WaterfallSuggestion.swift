import Foundation

// MARK: - Waterfall Suggestion

/// AI-generated repurpose suggestion for a content piece.
/// Each suggestion recommends converting the piece into a different format
/// for a specific platform, with a brief description of the approach.
struct WaterfallSuggestion: Identifiable {
    let id = UUID()
    let format: String
    let platform: String
    let description: String

    /// Returns waterfall (repurpose) suggestions tailored to the content piece type.
    /// Ported from WorldExplorer.tsx getWaterfallSuggestions().
    static func suggestions(for piece: ContentPiece) -> [WaterfallSuggestion] {
        switch piece.type {
        case .video, .reel:
            return [
                WaterfallSuggestion(
                    format: "Story Clips",
                    platform: "Instagram",
                    description: "Split into 3–4 story segments with poll stickers"
                ),
                WaterfallSuggestion(
                    format: "YouTube Short",
                    platform: "YouTube",
                    description: "Vertical 15s cut with hook-first edit"
                ),
                WaterfallSuggestion(
                    format: "GIF Set",
                    platform: "Twitter",
                    description: "Extract 3 reaction-worthy moments as GIFs"
                ),
                WaterfallSuggestion(
                    format: "Carousel Stills",
                    platform: "Instagram",
                    description: "Pull best frames into a swipeable breakdown"
                ),
            ]
        case .carousel:
            return [
                WaterfallSuggestion(
                    format: "Thread",
                    platform: "Twitter",
                    description: "Convert each slide into a numbered tweet thread"
                ),
                WaterfallSuggestion(
                    format: "LinkedIn Post",
                    platform: "LinkedIn",
                    description: "Summarize key slides into a text post with takeaways"
                ),
                WaterfallSuggestion(
                    format: "Reel Slideshow",
                    platform: "Instagram",
                    description: "Animate slides with transitions and trending audio"
                ),
                WaterfallSuggestion(
                    format: "Blog Draft",
                    platform: "Website",
                    description: "Expand carousel points into a full article"
                ),
            ]
        case .photo, .story:
            return [
                WaterfallSuggestion(
                    format: "Story Post",
                    platform: "Instagram",
                    description: "Add context text and a question sticker for engagement"
                ),
                WaterfallSuggestion(
                    format: "Pin",
                    platform: "Pinterest",
                    description: "Reformat to 2:3 ratio with keyword-rich description"
                ),
                WaterfallSuggestion(
                    format: "Quote Card",
                    platform: "LinkedIn",
                    description: "Overlay a key insight as a typography-forward card"
                ),
                WaterfallSuggestion(
                    format: "Ad Creative",
                    platform: "Meta Ads",
                    description: "Crop and add CTA overlay for paid campaign testing"
                ),
            ]
        }
    }
}

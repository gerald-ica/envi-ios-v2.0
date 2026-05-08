import Foundation
import SwiftUI

// MARK: - Content Type

/// The format of a content piece (edited media from the user's camera roll).
enum ContentType: String, CaseIterable, Codable {
    case photo, video, carousel, story, reel

    var label: String {
        rawValue.uppercased()
    }
}

// MARK: - Content Platform

/// Social platforms a content piece can target.
/// Note: Separate from the account-level `SocialPlatform` in Platform.swift
/// because this set uses "twitter" while the other uses "x", and the two enums
/// serve different domains (content vs. account connections).
enum ContentPlatform: String, CaseIterable, Codable {
    case instagram, tiktok, youtube, twitter, linkedin

    var label: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok:    return "TikTok"
        case .youtube:   return "YouTube"
        case .twitter:   return "X / Twitter"
        case .linkedin:  return "LinkedIn"
        }
    }

    var color: Color {
        switch self {
        case .instagram: return Color(hex: "#E1306C")
        case .tiktok:    return Color(hex: "#00F2EA")
        case .youtube:   return Color(hex: "#FF0000")
        case .twitter:   return Color(hex: "#1DA1F2")
        case .linkedin:  return Color(hex: "#0A66C2")
        }
    }
}

// MARK: - Content Source

/// Where a content piece originates from.
enum ContentSource: String, CaseIterable {
    case photoLibrary
    case contentLibrary
    case predicted       // AI-generated future recommendation

    var label: String {
        switch self {
        case .photoLibrary:   return "Camera Roll"
        case .contentLibrary: return "Content Timeline"
        case .predicted:      return "AI Predicted"
        }
    }

    var displayLabel: String {
        switch self {
        case .photoLibrary:   return "From your Camera Roll"
        case .contentLibrary: return "From Content Timeline"
        case .predicted:      return "AI Recommended"
        }
    }
}

// MARK: - Content Metrics

/// Engagement metrics for a content piece.
struct ContentMetrics {
    var views: Int?
    var likes: Int?
    var shares: Int?
    var comments: Int?
}

// MARK: - Content Piece

/// An edited media asset from the user's camera roll, surfaced in the ENVI content library.
/// Content pieces represent photos, videos, carousels, reels, and stories that the user
/// has already created or edited, imported via full Photos app access during onboarding.
struct ContentPiece: Identifiable {
    let id: String
    let title: String
    let type: ContentType
    let platform: ContentPlatform
    let description: String
    let aiScore: Int           // 0–100
    let createdAt: String      // ISO date
    let tags: [String]
    let metrics: ContentMetrics?
    let aiSuggestion: String?
    let imageName: String
    let source: ContentSource

    // Future/predicted content fields
    let predictedEngagement: String?
    let confidenceScore: Int?          // 0–100, e.g. 87
    let aiExplanation: String?         // "Why this recommendation"

    var isFuture: Bool { source == .predicted }

    init(
        id: String, title: String, type: ContentType, platform: ContentPlatform,
        description: String, aiScore: Int, createdAt: String, tags: [String],
        metrics: ContentMetrics?, aiSuggestion: String?, imageName: String,
        source: ContentSource,
        predictedEngagement: String? = nil,
        confidenceScore: Int? = nil,
        aiExplanation: String? = nil
    ) {
        self.id = id; self.title = title; self.type = type; self.platform = platform
        self.description = description; self.aiScore = aiScore; self.createdAt = createdAt
        self.tags = tags; self.metrics = metrics; self.aiSuggestion = aiSuggestion
        self.imageName = imageName; self.source = source
        self.predictedEngagement = predictedEngagement
        self.confidenceScore = confidenceScore
        self.aiExplanation = aiExplanation
    }

    // MARK: - Sample Library
    // Placeholder content — in production, assembled from user's camera roll.
    // All 14 content pieces ported from WorldExplorer.tsx CONTENT_PIECES.

    static let sampleLibrary: [ContentPiece] = [
        ContentPiece(
            id: "content-1",
            title: "Brand Reveal — Close Up",
            type: .video,
            platform: .instagram,
            description: "Cinematic close-up product reveal with dramatic lighting. 15s vertical format optimized for Reels and Stories. Features slow-motion macro shots with ambient soundtrack.",
            aiScore: 94,
            createdAt: "2026-03-25",
            tags: ["branding", "product", "cinematic"],
            metrics: ContentMetrics(views: 12400, likes: 1830, shares: 245, comments: 89),
            aiSuggestion: "Add a text overlay at 0:03 with your tagline — posts with early text hooks see 23% more completions.",
            imageName: "Closer",
            source: .photoLibrary
        ),
        ContentPiece(
            id: "content-2",
            title: "Hero Campaign — Spring Drop",
            type: .photo,
            platform: .instagram,
            description: "High-impact hero shot for the Spring 2026 collection launch. Studio-lit with bold color grading and centered composition. Designed for grid and ad placements.",
            aiScore: 91,
            createdAt: "2026-03-23",
            tags: ["campaign", "hero", "spring"],
            metrics: ContentMetrics(views: 8700, likes: 2100, shares: 312, comments: nil),
            aiSuggestion: "Crop to 4:5 for feed — this 1:1 ratio loses 18% engagement on Instagram grid.",
            imageName: "card-graphic",
            source: .photoLibrary
        ),
        ContentPiece(
            id: "content-3",
            title: "Lifestyle — Morning Routine",
            type: .carousel,
            platform: .instagram,
            description: "5-slide carousel documenting a morning routine. Warm tones, natural light, lifestyle aesthetic. Each slide has a different wellness moment with minimal text overlay.",
            aiScore: 87,
            createdAt: "2026-03-21",
            tags: ["lifestyle", "wellness", "carousel"],
            metrics: ContentMetrics(views: 6200, likes: 980, shares: 156, comments: 67),
            aiSuggestion: "Slide 3 has low contrast text — increase font weight or add a subtle drop shadow for readability.",
            imageName: "runway",
            source: .photoLibrary
        ),
        ContentPiece(
            id: "content-4",
            title: "Behind the Scenes — Studio",
            type: .video,
            platform: .tiktok,
            description: "Raw behind-the-scenes footage from the photo studio. Quick cuts, trending audio, authentic energy. 30s format showing the creative process from setup to final shot.",
            aiScore: 82,
            createdAt: "2026-03-20",
            tags: ["bts", "studio", "authentic"],
            metrics: ContentMetrics(views: 34500, likes: 4200, shares: 890, comments: nil),
            aiSuggestion: "The first 2 seconds are static — start with the final shot as a hook, then rewind to the process.",
            imageName: "card-graphic",
            source: .photoLibrary
        ),
        ContentPiece(
            id: "content-5",
            title: "Product Flat Lay — Essentials",
            type: .photo,
            platform: .instagram,
            description: "Clean flat lay arrangement of core product lineup. Neutral background, consistent shadows, each item precisely spaced. Perfect for product catalog and shoppable posts.",
            aiScore: 79,
            createdAt: "2026-03-18",
            tags: ["product", "flatlay", "catalog"],
            metrics: ContentMetrics(views: 4100, likes: 620, shares: 88, comments: nil),
            aiSuggestion: "Add lifestyle context — flat lays with a hand or prop in frame get 31% more saves.",
            imageName: "jacket",
            source: .contentLibrary
        ),
        ContentPiece(
            id: "content-6",
            title: "Event Recap — Gallery Night",
            type: .reel,
            platform: .instagram,
            description: "Fast-paced event recap reel from the downtown gallery opening. Mix of candid moments, artwork close-ups, and crowd energy. Set to upbeat instrumental.",
            aiScore: 88,
            createdAt: "2026-03-15",
            tags: ["event", "gallery", "culture"],
            metrics: ContentMetrics(views: 15800, likes: 2400, shares: 567, comments: 134),
            aiSuggestion: "Strong piece. Consider a carousel companion post with hi-res stills from the same event for 2x content.",
            imageName: "fashion-group",
            source: .photoLibrary
        ),
        ContentPiece(
            id: "content-7",
            title: "Creative Process — Timelapse",
            type: .video,
            platform: .youtube,
            description: "60-second timelapse of a design project from blank canvas to finished piece. Overhead camera, natural desk setup. Great for showing creative credibility.",
            aiScore: 85,
            createdAt: "2026-03-12",
            tags: ["process", "timelapse", "design"],
            metrics: ContentMetrics(views: 9300, likes: 1100, shares: 234, comments: nil),
            aiSuggestion: "YouTube Shorts version could reach 5x the audience — cut to the best 15s with a before/after hook.",
            imageName: "cyclist",
            source: .photoLibrary
        ),
        ContentPiece(
            id: "content-8",
            title: "Quote Card — Weekly Wisdom",
            type: .photo,
            platform: .linkedin,
            description: "Minimalist typography quote card with brand colors. Custom lettering on a gradient background. Part of a weekly wisdom series for thought leadership.",
            aiScore: 72,
            createdAt: "2026-03-10",
            tags: ["quote", "typography", "leadership"],
            metrics: ContentMetrics(views: 3200, likes: 410, shares: 190, comments: nil),
            aiSuggestion: "Quote cards without a personal story get 40% less engagement — add a 2-line personal take in the caption.",
            imageName: "red-silhouette",
            source: .contentLibrary
        ),
        ContentPiece(
            id: "content-9",
            title: "Collab Announcement",
            type: .carousel,
            platform: .instagram,
            description: "Partnership announcement carousel with both brands featured. Slide 1: teaser, Slides 2-4: collab details, Slide 5: CTA. Dual brand identity maintained throughout.",
            aiScore: 90,
            createdAt: "2026-03-08",
            tags: ["collab", "partnership", "announcement"],
            metrics: ContentMetrics(views: 11200, likes: 1900, shares: 445, comments: 201),
            aiSuggestion: "Pin this to your grid — collab posts drive profile visits. Tag the partner account in every slide, not just the caption.",
            imageName: "culture-food",
            source: .photoLibrary
        ),
        ContentPiece(
            id: "content-10",
            title: "Tutorial — Edit Walkthrough",
            type: .video,
            platform: .youtube,
            description: "Step-by-step editing tutorial showing the full workflow from raw footage to polished export. Screen recording with voiceover and chapter markers.",
            aiScore: 86,
            createdAt: "2026-03-06",
            tags: ["tutorial", "editing", "education"],
            metrics: ContentMetrics(views: 22100, likes: 3400, shares: 678, comments: nil),
            aiSuggestion: "Add chapters and timestamps in description — tutorial videos with chapters get 28% more watch time.",
            imageName: "subway",
            source: .photoLibrary
        ),
        ContentPiece(
            id: "content-11",
            title: "AI Art Series — Dreamscape",
            type: .photo,
            platform: .twitter,
            description: "AI-generated dreamscape artwork, part of an ongoing series exploring surreal landscapes. Vivid colors, ethereal atmosphere. Pairs with a thread about AI creativity.",
            aiScore: 76,
            createdAt: "2026-03-04",
            tags: ["ai-art", "creative", "series"],
            metrics: ContentMetrics(views: 7600, likes: 890, shares: 234, comments: nil),
            aiSuggestion: "Thread format outperforms single tweets for art — add 3-4 process images showing how the prompt evolved.",
            imageName: "desert-car",
            source: .contentLibrary
        ),
        ContentPiece(
            id: "content-12",
            title: "Mood Board — Q2 Direction",
            type: .carousel,
            platform: .instagram,
            description: "Visual mood board carousel setting the creative direction for Q2. Color palettes, texture references, typography samples, and inspiration imagery across 8 slides.",
            aiScore: 81,
            createdAt: "2026-03-02",
            tags: ["moodboard", "direction", "creative"],
            metrics: ContentMetrics(views: 5400, likes: 780, shares: 145, comments: nil),
            aiSuggestion: "Save this as a Guide on Instagram — mood boards in Guides get ongoing discovery vs. feed posts.",
            imageName: "chopsticks",
            source: .photoLibrary
        ),
        ContentPiece(
            id: "content-13",
            title: "Testimonial — Client Story",
            type: .video,
            platform: .linkedin,
            description: "Client testimonial video with b-roll of the project outcome. Professional edit with lower thirds, brand transitions, and a clear call-to-action at the end.",
            aiScore: 83,
            createdAt: "2026-02-28",
            tags: ["testimonial", "social-proof", "client"],
            metrics: ContentMetrics(views: 4800, likes: 560, shares: 312, comments: 45),
            aiSuggestion: "Lead with the result, not the introduction — \"We grew 40%\" hooks better than \"Hi, I'm...\" openings.",
            imageName: "parking-garage",
            source: .contentLibrary
        ),
        ContentPiece(
            id: "content-14",
            title: "Trend Remix — Viral Sound",
            type: .reel,
            platform: .tiktok,
            description: "Brand remix of a trending TikTok audio. Original creative take on the format while staying true to brand voice. Quick transitions and bold text overlays.",
            aiScore: 92,
            createdAt: "2026-02-25",
            tags: ["trend", "remix", "viral"],
            metrics: ContentMetrics(views: 89200, likes: 12300, shares: 3400, comments: 567),
            aiSuggestion: "This has viral momentum — cross-post to Reels within 24hrs. Trending sounds have a 3-5 day peak window.",
            imageName: "industrial-girl",
            source: .photoLibrary
        ),

        // MARK: - Future / AI-Predicted Content Pieces

        ContentPiece(
            id: "future-1",
            title: "Recommended: Trend Video — Trending Audio Remix for TikTok",
            type: .reel,
            platform: .tiktok,
            description: "AI recommends creating a trend remix video using the currently viral audio. Your audience engagement peaks with short-form trend content on TikTok.",
            aiScore: 88,
            createdAt: "2026-03-28",
            tags: ["trend", "audio", "tiktok", "predicted"],
            metrics: nil,
            aiSuggestion: nil,
            imageName: "industrial-girl",
            source: .predicted,
            predictedEngagement: "~15K views",
            confidenceScore: 87,
            aiExplanation: "Your last 3 TikTok trend remixes averaged 34K views. Current audio is trending upward with 12M uses this week. Posting within the next 48hrs maximizes reach."
        ),
        ContentPiece(
            id: "future-2",
            title: "Optimal: Carousel — Week Recap for LinkedIn",
            type: .carousel,
            platform: .linkedin,
            description: "AI suggests a weekly recap carousel summarizing your top content moments. LinkedIn carousels from your account see 2.3x higher impressions than static posts.",
            aiScore: 79,
            createdAt: "2026-03-30",
            tags: ["recap", "linkedin", "carousel", "predicted"],
            metrics: nil,
            aiSuggestion: nil,
            imageName: "red-silhouette",
            source: .predicted,
            predictedEngagement: "~3K impressions",
            confidenceScore: 82,
            aiExplanation: "Your LinkedIn audience is most active on Sundays. Weekly recap carousels in your niche see 40% higher save rates than standalone posts."
        ),
        ContentPiece(
            id: "future-3",
            title: "National Coffee Day — Brand Moment Opportunity",
            type: .photo,
            platform: .instagram,
            description: "April 1 is National Coffee Day — a high-engagement brand moment. AI recommends a lifestyle photo tying your brand to the cultural moment.",
            aiScore: 91,
            createdAt: "2026-04-01",
            tags: ["coffee-day", "brand-moment", "instagram", "predicted"],
            metrics: nil,
            aiSuggestion: nil,
            imageName: "culture-food",
            source: .predicted,
            predictedEngagement: "High opportunity — trending hashtag",
            confidenceScore: 91,
            aiExplanation: "National Coffee Day generated 2.1M Instagram posts last year. Brands in your category saw 3x engagement spikes. Early posting (7-9am) captures peak interest."
        ),
        ContentPiece(
            id: "future-4",
            title: "Predicted Peak Window — Your Audience Is Most Active",
            type: .story,
            platform: .instagram,
            description: "AI detected your highest-engagement posting window. Schedule any content during this window for maximum reach.",
            aiScore: 85,
            createdAt: "2026-04-03",
            tags: ["peak-window", "scheduling", "predicted"],
            metrics: nil,
            aiSuggestion: nil,
            imageName: "Closer",
            source: .predicted,
            predictedEngagement: "Optimal posting window",
            confidenceScore: 93,
            aiExplanation: "Analysis of your last 90 days shows Thursday 2-4pm is your highest engagement window. Followers online: +47% vs. average."
        ),
        ContentPiece(
            id: "future-5",
            title: "Content Gap Alert — No Video Content in 14 Days",
            type: .video,
            platform: .tiktok,
            description: "AI detected a content gap: you haven't published video content in 14 days. Your video posts drive 60% of total engagement — this gap may impact growth.",
            aiScore: 77,
            createdAt: "2026-04-05",
            tags: ["content-gap", "video", "tiktok", "predicted"],
            metrics: nil,
            aiSuggestion: nil,
            imageName: "card-graphic",
            source: .predicted,
            predictedEngagement: "Gap risk — engagement may drop 20%",
            confidenceScore: 85,
            aiExplanation: "Your video content averages 4.2x more engagement than photo posts. Going 14+ days without video historically correlates with a 20% follower engagement drop."
        ),
        ContentPiece(
            id: "future-6",
            title: "Collaboration: Partner Content Cross-Post",
            type: .carousel,
            platform: .instagram,
            description: "AI identified a collaboration opportunity. Cross-posting with partners in your niche drives mutual audience growth and 2x engagement on carousel format.",
            aiScore: 84,
            createdAt: "2026-04-07",
            tags: ["collab", "cross-post", "multi-platform", "predicted"],
            metrics: nil,
            aiSuggestion: nil,
            imageName: "fashion-group",
            source: .predicted,
            predictedEngagement: "~8K combined impressions",
            confidenceScore: 78,
            aiExplanation: "Your last collab post (Mar 8) drove 11.2K views and 201 comments — your highest engagement that week. Partner accounts with 5K-50K followers see the best cross-pollination."
        ),
    ]

    /// All future/predicted content pieces
    static let futurePieces: [ContentPiece] = sampleLibrary.filter { $0.isFuture }

    /// All past (real) content pieces
    static let pastPieces: [ContentPiece] = sampleLibrary.filter { !$0.isFuture }
}

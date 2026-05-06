// ContentArchetype.swift
// ENVI v3.0 — Extended Content Taxonomy (474 Archetypes)
// Generated: 2026-05-05
// iOS 26+ | Swift 6 Strict | Sendable
//
// This file EXTENDS the existing VideoTemplateCategory (from VideoTemplateModels.swift)
// rather than replacing it. The 12 existing categories are mapped to subsets of the
// expanded 474 archetypes via the VideoTemplateCategory.ContentMapping extension.

import Foundation

// MARK: - Content Format Enum
@available(iOS 26, *)
enum ENVIContentFormat: String, Codable, Sendable, CaseIterable {
    case photo = "photo"
    case carousel = "carousel"
    case video = "video"
    case story = "story"
    case newFormat = "newFormat"

    var displayName: String {
        switch self {
        case .photo: return "Photo"
        case .carousel: return "Carousel"
        case .video: return "Video"
        case .story: return "Story"
        case .newFormat: return "New Format"
        }
    }
}

// MARK: - Content Archetype (Discriminated Union)
@available(iOS 26, *)
enum ContentArchetype: Codable, Sendable, Hashable {
    case photo(PhotoArchetype)
    case carousel(CarouselArchetype)
    case video(VideoArchetype)
    case story(StoryArchetype)
    case newFormat(NewFormatArchetype)

    var format: ENVIContentFormat {
        switch self {
        case .photo: return .photo
        case .carousel: return .carousel
        case .video: return .video
        case .story: return .story
        case .newFormat: return .newFormat
        }
    }

    var id: String {
        switch self {
        case .photo(let a): return a.rawValue
        case .carousel(let a): return a.rawValue
        case .video(let a): return a.rawValue
        case .story(let a): return a.rawValue
        case .newFormat(let a): return a.rawValue
        }
    }

    var displayName: String {
        switch self {
        case .photo(let a): return a.displayName
        case .carousel(let a): return a.displayName
        case .video(let a): return a.displayName
        case .story(let a): return a.displayName
        case .newFormat(let a): return a.displayName
        }
    }

    var description: String {
        switch self {
        case .photo(let a): return a.description
        case .carousel(let a): return a.description
        case .video(let a): return a.description
        case .story(let a): return a.description
        case .newFormat(let a): return a.description
        }
    }
}

// MARK: - Photo Archetypes (58)
@available(iOS 26, *)
enum PhotoArchetype: String, Codable, Sendable, CaseIterable {
    // Original 14
    case P1 = "P1"
    case P2 = "P2"
    case P3 = "P3"
    case P4 = "P4"
    case P5 = "P5"
    case P6 = "P6"
    case P7 = "P7"
    case P8 = "P8"
    case P9 = "P9"
    case P10 = "P10"
    case P11 = "P11"
    case P12 = "P12"
    case P13 = "P13"
    case P14 = "P14"
    // Expanded 44
    case P15 = "P15"
    case P16 = "P16"
    case P17 = "P17"
    case P18 = "P18"
    case P19 = "P19"
    case P20 = "P20"
    case P21 = "P21"
    case P22 = "P22"
    case P23 = "P23"
    case P24 = "P24"
    case P25 = "P25"
    case P26 = "P26"
    case P27 = "P27"
    case P28 = "P28"
    case P29 = "P29"
    case P30 = "P30"
    case P31 = "P31"
    case P32 = "P32"
    case P33 = "P33"
    case P34 = "P34"
    case P35 = "P35"
    case P36 = "P36"
    case P37 = "P37"
    case P38 = "P38"
    case P39 = "P39"
    case P40 = "P40"
    case P41 = "P41"
    case P42 = "P42"
    case P43 = "P43"
    case P44 = "P44"
    case P45 = "P45"
    case P46 = "P46"
    case P47 = "P47"
    case P48 = "P48"
    case P49 = "P49"
    case P50 = "P50"
    case P51 = "P51"
    case P52 = "P52"
    case P53 = "P53"
    case P54 = "P54"
    case P55 = "P55"
    case P56 = "P56"
    case P57 = "P57"
    case P58 = "P58"

    var displayName: String {
        switch self {
        case .P1: return "Centerpiece Portrait"
        case .P2: return "Rule of Thirds Editorial"
        case .P3: return "Flat Lay Overhead"
        case .P4: return "Color Block Background"
        case .P5: return "Text-Heavy Announcement"
        case .P6: return "Before/After Split"
        case .P7: return "Quote Card"
        case .P8: return "Product Showcase"
        case .P9: return "Collage Grid"
        case .P10: return "Meme Format"
        case .P11: return "Aesthetic Frame"
        case .P12: return "Minimalist Single Object"
        case .P13: return "Infographic Slice"
        case .P14: return "Cinematic Crop"
        case .P15: return "Social Proof Card"
        case .P16: return "Announcement Card"
        case .P17: return "Holiday Greeting"
        case .P18: return "Resume Snapshot"
        case .P19: return "Portfolio Piece"
        case .P20: return "Certificate Display"
        case .P21: return "Double Exposure"
        case .P22: return "Light Painting"
        case .P23: return "Forced Perspective"
        case .P24: return "Levitation Shot"
        case .P25: return "Gaming Screenshot Overlay"
        case .P26: return "Achievement Card"
        case .P27: return "Leaderboard Snapshot"
        case .P28: return "Food Macro"
        case .P29: return "Deconstructed Dish"
        case .P30: return "Ingredient Close-Up"
        case .P31: return "Fitness Progress Pic"
        case .P32: return "Form Check Frame"
        case .P33: return "Gym Check-In"
        case .P34: return "Equipment Hero"
        case .P35: return "Desk Setup Flat Lay"
        case .P36: return "Gear Grid"
        case .P37: return "Annotated Screenshot"
        case .P38: return "Reaction Image"
        case .P39: return "Exploitable Template"
        case .P40: return "Alignment Chart"
        case .P41: return "Word Art Poster"
        case .P42: return "Calligraphy Card"
        case .P43: return "Slogan Poster"
        case .P44: return "Polaroid Wall"
        case .P45: return "Film Strip Montage"
        case .P46: return "Scrapbook Page"
        case .P47: return "Mood Board"
        case .P48: return "Single Line Art"
        case .P49: return "Monochrome Study"
        case .P50: return "Negative Space Portrait"
        case .P51: return "Luxury Detail Shot"
        case .P52: return "Packaging Unboxing"
        case .P53: return "Tintype Effect"
        case .P54: return "Daguerreotype Style"
        case .P55: return "Instant Camera Frame"
        case .P56: return "Bokeh Portrait"
        case .P57: return "Silhouette Art"
        case .P58: return "Reflection Shot"
        }
    }

    var description: String {
        switch self {
        case .P1: return "Subject centered with symmetrical framing"
        case .P2: return "Subject at intersection points with negative space"
        case .P3: return "Top-down product/lifestyle arrangement"
        case .P4: return "Solid or gradient background with foreground subject"
        case .P5: return "Large typography as primary visual element"
        case .P6: return "Vertical or horizontal comparison frame"
        case .P7: return "Text-centric with decorative elements"
        case .P8: return "Single product with shadow/reflection"
        case .P9: return "Multiple images in geometric arrangement"
        case .P10: return "Image with overlaid text (top/bottom)"
        case .P11: return "Decorative border with central content"
        case .P12: return "Isolated object on plain background"
        case .P13: return "Single data visualization or chart"
        case .P14: return "Wide/ultra-wide subject with film grain"
        case .P15: return "Review/rating displayed with product image"
        case .P16: return "Launch/event/milestone announcement with bold typography"
        case .P17: return "Seasonal/cultural festival greeting card"
        case .P18: return "Professional credentials in clean layout"
        case .P19: return "Single work with title and description overlay"
        case .P20: return "Credential/award with seal and border"
        case .P21: return "Two overlaid images creating surreal composite"
        case .P22: return "Long-exposure light trails as art"
        case .P23: return "Optical illusion via angle and distance"
        case .P24: return "Subject appears to float mid-air"
        case .P25: return "Screenshot with HUD, stats, and rank overlay"
        case .P26: return "Unlock/badge/trophy showcase"
        case .P27: return "Rankings and scores displayed graphically"
        case .P28: return "Extreme close-up of food texture and detail"
        case .P29: return "Ingredients laid out separately around empty plate"
        case .P30: return "Single ingredient as hero subject"
        case .P31: return "Side-by-side or overlaid transformation"
        case .P32: return "Exercise pose with grid and angle markers"
        case .P33: return "Gym environment with location and stats"
        case .P34: return "Single piece of gym gear as subject"
        case .P35: return "Overhead view of workstation arrangement"
        case .P36: return "Multiple tech items in organized grid"
        case .P37: return "Screenshot with arrows, circles, text callouts"
        case .P38: return "Expressive face/moment for meme response"
        case .P39: return "Blank slate image with designated text areas"
        case .P40: return "3x3 grid categorizing items/people"
        case .P41: return "Typography as sole visual element forming image"
        case .P42: return "Hand-lettered script as decorative piece"
        case .P43: return "Bold statement text with minimal graphic"
        case .P44: return "Multiple photos in Polaroid frame arrangement"
        case .P45: return "Sequential frames in film strip border"
        case .P46: return "Mixed media with paper texture and stickers"
        case .P47: return "Collection of images, colors, textures in collage"
        case .P48: return "Minimalist composition using single continuous line"
        case .P49: return "Black and white with tonal range emphasis"
        case .P50: return "Subject defined by surrounding emptiness"
        case .P51: return "Premium product texture and material close-up"
        case .P52: return "Product packaging as staged still life"
        case .P53: return "Antique photographic plate aesthetic"
        case .P54: return "Mirror-like silver plate antique photo"
        case .P55: return "Polaroid/Instax border with handwritten caption"
        case .P56: return "Subject sharp against creamy blurred lights"
        case .P57: return "Subject as dark shape against bright background"
        case .P58: return "Subject mirrored in water/glass/surface"
        }
    }

    var defaultAspectRatio: String { "4:5" }
    var defaultResolution: String { "1080x1350" }
    var requiredMediaCount: Int { 1 }
    var maxMediaCount: Int { 1 }
    var styleHints: [String] { ["Clean", "Minimal", "Editorial", "Modern"] }
    var nicheHints: [String] { ["Fashion", "Beauty", "Lifestyle", "Food"] }
    var requiredOperations: [String] { ["smartCrop", "colorGrade", "filter"] }
}

// MARK: - Carousel Archetypes (58)
@available(iOS 26, *)
enum CarouselArchetype: String, Codable, Sendable, CaseIterable {
    // Original 14
    case C1 = "C1"; case C2 = "C2"; case C3 = "C3"; case C4 = "C4"
    case C5 = "C5"; case C6 = "C6"; case C7 = "C7"; case C8 = "C8"
    case C9 = "C9"; case C10 = "C10"; case C11 = "C11"; case C12 = "C12"
    case C13 = "C13"; case C14 = "C14"
    // Expanded 44
    case C15 = "C15"; case C16 = "C16"; case C17 = "C17"; case C18 = "C18"
    case C19 = "C19"; case C20 = "C20"; case C21 = "C21"; case C22 = "C22"
    case C23 = "C23"; case C24 = "C24"; case C25 = "C25"; case C26 = "C26"
    case C27 = "C27"; case C28 = "C28"; case C29 = "C29"; case C30 = "C30"
    case C31 = "C31"; case C32 = "C32"; case C33 = "C33"; case C34 = "C34"
    case C35 = "C35"; case C36 = "C36"; case C37 = "C37"; case C38 = "C38"
    case C39 = "C39"; case C40 = "C40"; case C41 = "C41"; case C42 = "C42"
    case C43 = "C43"; case C44 = "C44"; case C45 = "C45"; case C46 = "C46"
    case C47 = "C47"; case C48 = "C48"; case C49 = "C49"; case C50 = "C50"
    case C51 = "C51"; case C52 = "C52"; case C53 = "C53"; case C54 = "C54"
    case C55 = "C55"; case C56 = "C56"; case C57 = "C57"; case C58 = "C58"

    var displayName: String {
        switch self {
        case .C1: return "Tutorial Steps"
        case .C2: return "Product Feature Tour"
        case .C3: return "Listicle Countdown"
        case .C4: return "Before/During/After"
        case .C5: return "Swipeable Gallery"
        case .C6: return "Story Narrative"
        case .C7: return "Comparison Matrix"
        case .C8: return "Tips & Hacks"
        case .C9: return "Myth vs Fact"
        case .C10: return "Recipe Cards"
        case .C11: return "Outfit Breakdown"
        case .C12: return "Educational Explainer"
        case .C13: return "Testimonial Carousel"
        case .C14: return "Process Documentation"
        case .C15: return "Deep Tutorial"
        case .C16: return "Multi-Product Comparison"
        case .C17: return "Portfolio Deep Dive"
        case .C18: return "Travel Itinerary"
        case .C19: return "Seasonal Lookbook"
        case .C20: return "Capsule Wardrobe"
        case .C21: return "Math Problem Walkthrough"
        case .C22: return "Science Concept Series"
        case .C23: return "History Timeline"
        case .C24: return "Data Story"
        case .C25: return "Craft Process"
        case .C26: return "Art Making Of"
        case .C27: return "Manufacturing Process"
        case .C28: return "Color Palette Mood Board"
        case .C29: return "Advice Thread"
        case .C30: return "Story Episodes"
        case .C31: return "Q&A Compilation"
        case .C32: return "Transformation Series"
        case .C33: return "Ingredient Spotlight"
        case .C34: return "Fitness Challenge Tracker"
        case .C35: return "Book Chapter Summary"
        case .C36: return "Course Module Preview"
        case .C37: return "Salary Negotiation Script"
        case .C38: return "Interview Prep Cards"
        case .C39: return "Event Recap"
        case .C40: return "Weekly Roundup"
        case .C41: return "Brand Values Series"
        case .C42: return "Customer Journey Map"
        case .C43: return "Startup Pitch Deck"
        case .C44: return "Career Path Guide"
        case .C45: return "Language Learning Cards"
        case .C46: return "Home Renovation Progress"
        case .C47: return "Garden Seasonal Guide"
        case .C48: return "Pet Training Steps"
        case .C49: return "Music Theory Lesson"
        case .C50: return "Film Study Breakdown"
        case .C51: return "Budget Breakdown"
        case .C52: return "Travel Packing List"
        case .C53: return "Emergency Preparedness"
        case .C54: return "Medical Symptom Checker"
        case .C55: return "Legal Rights Explainer"
        case .C56: return "Eco-Friendly Swaps"
        case .C57: return "DIY Repair Guide"
        case .C58: return "Mental Health Toolkit"
        }
    }

    var description: String {
        switch self {
        case .C1: return "Step-by-step instructional sequence"
        case .C2: return "Multi-angle product exploration"
        case .C3: return "Numbered list with visual progression"
        case .C4: return "Transformation timeline"
        case .C5: return "Portfolio or collection showcase"
        case .C6: return "Sequential storytelling with plot"
        case .C7: return "Side-by-side or alternating comparison"
        case .C8: return "Quick actionable advice collection"
        case .C9: return "Debunking format with reveal structure"
        case .C10: return "Ingredient -> Process -> Result sequence"
        case .C11: return "Fashion look decomposition"
        case .C12: return "Concept breakdown with diagrams"
        case .C13: return "Social proof with multiple voices"
        case .C14: return "Behind-the-scenes workflow reveal"
        case .C15: return "10+ step comprehensive guide"
        case .C16: return "3+ products compared feature-by-feature"
        case .C17: return "10+ piece showcase with details"
        case .C18: return "Day-by-day trip breakdown"
        case .C19: return "Fashion for a specific season/occasion"
        case .C20: return "Minimal essential pieces guide"
        case .C21: return "Step-by-step equation solving"
        case .C22: return "Breaking down complex phenomena"
        case .C23: return "Chronological event sequence"
        case .C24: return "Narrative-driven infographic sequence"
        case .C25: return "Handmade item from raw to finished"
        case .C26: return "Behind-the-scenes creative process"
        case .C27: return "How a product is made"
        case .C28: return "Curated colors, textures, images for design"
        case .C29: return "10 tips, 20 lessons, or 30 mistakes"
        case .C30: return "Serialized content with cliffhangers"
        case .C31: return "Top questions answered in sequence"
        case .C32: return "Day 1 to Day 365 progression"
        case .C33: return "Deep dive on single food ingredient"
        case .C34: return "30-day/60-day challenge progress"
        case .C35: return "Key takeaways from each chapter"
        case .C36: return "What each lesson covers"
        case .C37: return "Word-for-word conversation guide"
        case .C38: return "Common questions and model answers"
        case .C39: return "Wedding, party, or trip highlight reel"
        case .C40: return "Best of the week compilation"
        case .C41: return "What the company stands for"
        case .C42: return "Experience from discovery to loyalty"
        case .C43: return "Investor presentation in carousel form"
        case .C44: return "How to advance in a profession"
        case .C45: return "Vocabulary/grammar in visual chunks"
        case .C46: return "Before/during/after room by room"
        case .C47: return "What to plant/harvest each month"
        case .C48: return "Command training progression"
        case .C49: return "Scales, chords, progressions visualized"
        case .C50: return "Scene analysis shot by shot"
        case .C51: return "Where money goes each month"
        case .C52: return "Categorized items for specific trip"
        case .C53: return "What to do in crisis situations"
        case .C54: return "Visual guide to common symptoms"
        case .C55: return "Simplified law for everyday people"
        case .C56: return "Sustainable alternatives guide"
        case .C57: return "Fix common household items"
        case .C58: return "Coping strategies visual guide"
        }
    }

    var defaultAspectRatio: String { "1:1" }
    var defaultResolution: String { "1080x1080" }
    var requiredMediaCount: Int { 2 }
    var maxMediaCount: Int { 10 }
    var styleHints: [String] { ["Clean", "Instructional", "Modern"] }
    var nicheHints: [String] { ["Education", "DIY", "Product", "Travel"] }
    var requiredOperations: [String] { ["layoutGeneration", "textOverlay"] }
}

// MARK: - Video Archetypes (198)
@available(iOS 26, *)
enum VideoArchetype: String, Codable, Sendable, CaseIterable {
    case V1 = "V1"
    case V2 = "V2"
    case V3 = "V3"
    case V4 = "V4"
    case V5 = "V5"
    case V6 = "V6"
    case V7 = "V7"
    case V8 = "V8"
    case V9 = "V9"
    case V10 = "V10"
    case V11 = "V11"
    case V12 = "V12"
    case V13 = "V13"
    case V14 = "V14"
    case V15 = "V15"
    case V16 = "V16"
    case V17 = "V17"
    case V18 = "V18"
    case V19 = "V19"
    case V20 = "V20"
    case V21 = "V21"
    case V22 = "V22"
    case V23 = "V23"
    case V24 = "V24"
    case V25 = "V25"
    case V26 = "V26"
    case V27 = "V27"
    case V28 = "V28"
    case V29 = "V29"
    case V30 = "V30"
    case V31 = "V31"
    case V32 = "V32"
    case V33 = "V33"
    case V34 = "V34"
    case V35 = "V35"
    case V36 = "V36"
    case V37 = "V37"
    case V38 = "V38"
    case V39 = "V39"
    case V40 = "V40"
    case V41 = "V41"
    case V42 = "V42"
    case V43 = "V43"
    case V44 = "V44"
    case V45 = "V45"
    case V46 = "V46"
    case V47 = "V47"
    case V48 = "V48"
    case V49 = "V49"
    case V50 = "V50"
    case V51 = "V51"
    case V52 = "V52"
    case V53 = "V53"
    case V54 = "V54"
    case V55 = "V55"
    case V56 = "V56"
    case V57 = "V57"
    case V58 = "V58"
    case V59 = "V59"
    case V60 = "V60"
    case V61 = "V61"
    case V62 = "V62"
    case V63 = "V63"
    case V64 = "V64"
    case V65 = "V65"
    case V66 = "V66"
    case V67 = "V67"
    case V68 = "V68"
    case V69 = "V69"
    case V70 = "V70"
    case V71 = "V71"
    case V72 = "V72"
    case V73 = "V73"
    case V74 = "V74"
    case V75 = "V75"
    case V76 = "V76"
    case V77 = "V77"
    case V78 = "V78"
    case V79 = "V79"
    case V80 = "V80"
    case V81 = "V81"
    case V82 = "V82"
    case V83 = "V83"
    case V84 = "V84"
    case V85 = "V85"
    case V86 = "V86"
    case V87 = "V87"
    case V88 = "V88"
    case V89 = "V89"
    case V90 = "V90"
    case V91 = "V91"
    case V92 = "V92"
    case V93 = "V93"
    case V94 = "V94"
    case V95 = "V95"
    case V96 = "V96"
    case V97 = "V97"
    case V98 = "V98"
    case V99 = "V99"
    case V100 = "V100"
    case V101 = "V101"
    case V102 = "V102"
    case V103 = "V103"
    case V104 = "V104"
    case V105 = "V105"
    case V106 = "V106"
    case V107 = "V107"
    case V108 = "V108"
    case V109 = "V109"
    case V110 = "V110"
    case V111 = "V111"
    case V112 = "V112"
    case V113 = "V113"
    case V114 = "V114"
    case V115 = "V115"
    case V116 = "V116"
    case V117 = "V117"
    case V118 = "V118"
    case V119 = "V119"
    case V120 = "V120"
    case V121 = "V121"
    case V122 = "V122"
    case V123 = "V123"
    case V124 = "V124"
    case V125 = "V125"
    case V126 = "V126"
    case V127 = "V127"
    case V128 = "V128"
    case V129 = "V129"
    case V130 = "V130"
    case V131 = "V131"
    case V132 = "V132"
    case V133 = "V133"
    case V134 = "V134"
    case V135 = "V135"
    case V136 = "V136"
    case V137 = "V137"
    case V138 = "V138"
    case V139 = "V139"
    case V140 = "V140"
    case V141 = "V141"
    case V142 = "V142"
    case V143 = "V143"
    case V144 = "V144"
    case V145 = "V145"
    case V146 = "V146"
    case V147 = "V147"
    case V148 = "V148"
    case V149 = "V149"
    case V150 = "V150"
    case V151 = "V151"
    case V152 = "V152"
    case V153 = "V153"
    case V154 = "V154"
    case V155 = "V155"
    case V156 = "V156"
    case V157 = "V157"
    case V158 = "V158"
    case V159 = "V159"
    case V160 = "V160"
    case V161 = "V161"
    case V162 = "V162"
    case V163 = "V163"
    case V164 = "V164"
    case V165 = "V165"
    case V166 = "V166"
    case V167 = "V167"
    case V168 = "V168"
    case V169 = "V169"
    case V170 = "V170"
    case V171 = "V171"
    case V172 = "V172"
    case V173 = "V173"
    case V174 = "V174"
    case V175 = "V175"
    case V176 = "V176"
    case V177 = "V177"
    case V178 = "V178"
    case V179 = "V179"
    case V180 = "V180"
    case V181 = "V181"
    case V182 = "V182"
    case V183 = "V183"
    case V184 = "V184"
    case V185 = "V185"
    case V186 = "V186"
    case V187 = "V187"
    case V188 = "V188"
    case V189 = "V189"
    case V190 = "V190"
    case V191 = "V191"
    case V192 = "V192"
    case V193 = "V193"
    case V194 = "V194"
    case V195 = "V195"
    case V196 = "V196"
    case V197 = "V197"
    case V198 = "V198"

    var displayName: String {
        let names: [String: String] = [
            "V1": "Hook Punch Tutorial", "V2": "Day in the Life", "V3": "Transformation Reveal",
            "V4": "Trending Audio Lip Sync", "V5": "POV Experience", "V6": "Quick Recipe",
            "V7": "Fitness Routine", "V8": "Unboxing/Review", "V9": "Comedy Skit",
            "V10": "Travel Montage", "V11": "Get Ready With Me", "V12": "Storytime Narration",
            "V13": "Product Demo", "V14": "ASMR/Satisfying", "V15": "Dance/Choreography",
            "V16": "News/Reaction", "V17": "Minimalist Aesthetic", "V18": "Behind the Scenes",
            "V19": "POV Swap", "V20": "What's In My Bag", "V21": "Room Tour",
            "V22": "Speed Clean", "V23": "Organization", "V24": "Routine Video",
            "V25": "Habit Tracking", "V26": "Journaling", "V27": "Plan With Me",
            "V28": "Study With Me", "V29": "Co-Work Session", "V30": "Live Stream Clip",
            "V31": "Reels Remix", "V32": "Reels Transition", "V33": "Reels Text Animation",
            "V34": "Shorts Remix", "V35": "Shorts Quick Facts", "V36": "Shorts Tutorial",
            "V37": "Elevator Pitch", "V38": "Product Demo Business", "V39": "Explainer Video",
            "V40": "Case Study", "V41": "Testimonial Video", "V42": "Behind the Brand",
            "V43": "Office Tour", "V44": "Team Introduction", "V45": "Hiring Post",
            "V46": "Product Launch", "V47": "Feature Drop", "V48": "Update Vlog",
            "V49": "AMA Session", "V50": "Fireside Chat",
            "V51": "Quick Lesson", "V52": "Fact Drop", "V53": "Myth Bust",
            "V54": "History Bite", "V55": "Science Demo", "V56": "Language Tip",
            "V57": "Book Summary", "V58": "Course Preview", "V59": "Study Hack",
            "V60": "Exam Prep",
            "V61": "Morning Routine", "V62": "Night Routine", "V63": "Weekend Vlog",
            "V64": "Hair Routine", "V65": "Makeup Routine", "V66": "Outfit of the Day",
            "V67": "What I Eat", "V68": "Grocery Haul", "V69": "Meal Prep",
            "V70": "Recipe Video", "V71": "Home Tour", "V72": "Decor Update",
            "V73": "Clean With Me", "V74": "Organize With Me", "V75": "Declutter",
            "V76": "Thrift Flip", "V77": "DIY Project", "V78": "Craft Tutorial",
            "V79": "Garden Update", "V80": "Plant Care",
            "V81": "City Guide", "V82": "Hotel Review", "V83": "Food Tour",
            "V84": "Travel Hack", "V85": "Packing Guide", "V86": "Budget Breakdown",
            "V87": "Adventure Clip", "V88": "Nature Moment", "V89": "Wildlife Encounter",
            "V90": "Drone Footage", "V91": "Travel Diary",
            "V92": "Outfit Transition", "V93": "Style Hack", "V94": "Thrift Haul",
            "V95": "Try-On", "V96": "Lookbook", "V97": "Seasonal Guide",
            "V98": "Trend Report", "V99": "Designer Review", "V100": "Street Style",
            "V101": "Sustainable Fashion", "V102": "Capsule Wardrobe",
            "V103": "Product Review", "V104": "Swatch Test", "V105": "Application Tutorial",
            "V106": "Tool Demo", "V107": "Ingredient Breakdown", "V108": "Hair Transformation",
            "V109": "Nail Art", "V110": "Makeup Challenge", "V111": "Dupes",
            "V112": "Empties", "V113": "Favorites",
            "V114": "Workout Demo", "V115": "Exercise Form", "V116": "Gym Routine",
            "V117": "Home Workout", "V118": "Stretch Routine", "V119": "Yoga Flow",
            "V120": "Run Update", "V121": "Progress Check", "V122": "Meal Prep Fitness",
            "V123": "Supplement Review", "V124": "Recovery Routine", "V125": "Challenge Entry",
            "V126": "Money Tip", "V127": "Investment Explainer", "V128": "Side Hustle",
            "V129": "Budget Breakdown", "V130": "Savings Challenge", "V131": "Debt Payoff",
            "V132": "Credit Tips", "V133": "Tax Hack", "V134": "Passive Income",
            "V135": "Crypto Update", "V136": "Stock Analysis",
            "V137": "Gadget Review", "V138": "App Demo", "V139": "Setup Tour",
            "V140": "Coding Tip", "V141": "AI Tool Demo", "V142": "Productivity Hack",
            "V143": "Software Tutorial", "V144": "Hardware Unbox", "V145": "Comparison Review",
            "V146": "Speed Test",
            "V147": "Recipe Video", "V148": "Cooking Hack", "V149": "Kitchen Tour",
            "V150": "Restaurant Review", "V151": "Food Challenge", "V152": "Taste Test",
            "V153": "Ingredient Spotlight", "V154": "Technique Demo", "V155": "Plating Guide",
            "V156": "Food Science",
            "V157": "Gameplay Clip", "V158": "Game Review", "V159": "Speedrun",
            "V160": "Walkthrough", "V161": "Tips & Tricks", "V162": "Esports Highlight",
            "V163": "Tournament Clip", "V164": "Cosplay", "V165": "Fan Art Process",
            "V166": "Lore Explainer", "V167": "Character Guide", "V168": "Weapon/Build Showcase",
            "V169": "Cover Snippet", "V170": "Original Song", "V171": "Instrument Demo",
            "V172": "Production Breakdown", "V173": "Lyrics Analysis", "V174": "Playlist Share",
            "V175": "Concert Moment", "V176": "Jam Session", "V177": "Music Tutorial",
            "V178": "Gear Review",
            "V179": "Process Video", "V180": "Sketch to Final", "V181": "Speed Paint",
            "V182": "Material Review", "V183": "Studio Tour", "V184": "Gallery Visit",
            "V185": "Commission Process", "V186": "Style Study", "V187": "Challenge Entry",
            "V188": "Collab Piece",
            "V189": "Cute Moment", "V190": "Training Tip", "V191": "Breed Info",
            "V192": "Product Review Pet", "V193": "Pet Routine", "V194": "Meet My Pet",
            "V195": "Pet Hack", "V196": "Rescue Story", "V197": "Funny Compilation",
            "V198": "Talent Show"
        ]
        return names[self.rawValue] ?? "Video Archetype \(self.rawValue)"
    }

    var description: String { return "Short-form video content: \(displayName)" }
    var defaultAspectRatio: String { "9:16" }
    var defaultResolution: String { "1080x1920" }
    var requiredMediaCount: Int { 1 }
    var maxMediaCount: Int { 5 }
    var styleHints: [String] { ["Modern", "Trending", "Clean"] }
    var nicheHints: [String] { ["Lifestyle", "Entertainment", "Education"] }
    var requiredOperations: [String] { ["speedRamp", "textOverlay", "musicOverlay"] }
}

// MARK: - Story Archetypes (100)
@available(iOS 26, *)
enum StoryArchetype: String, Codable, Sendable, CaseIterable {
    case S1 = "S1"
    case S2 = "S2"
    case S3 = "S3"
    case S4 = "S4"
    case S5 = "S5"
    case S6 = "S6"
    case S7 = "S7"
    case S8 = "S8"
    case S9 = "S9"
    case S10 = "S10"
    case S11 = "S11"
    case S12 = "S12"
    case S13 = "S13"
    case S14 = "S14"
    case S15 = "S15"
    case S16 = "S16"
    case S17 = "S17"
    case S18 = "S18"
    case S19 = "S19"
    case S20 = "S20"
    case S21 = "S21"
    case S22 = "S22"
    case S23 = "S23"
    case S24 = "S24"
    case S25 = "S25"
    case S26 = "S26"
    case S27 = "S27"
    case S28 = "S28"
    case S29 = "S29"
    case S30 = "S30"
    case S31 = "S31"
    case S32 = "S32"
    case S33 = "S33"
    case S34 = "S34"
    case S35 = "S35"
    case S36 = "S36"
    case S37 = "S37"
    case S38 = "S38"
    case S39 = "S39"
    case S40 = "S40"
    case S41 = "S41"
    case S42 = "S42"
    case S43 = "S43"
    case S44 = "S44"
    case S45 = "S45"
    case S46 = "S46"
    case S47 = "S47"
    case S48 = "S48"
    case S49 = "S49"
    case S50 = "S50"
    case S51 = "S51"
    case S52 = "S52"
    case S53 = "S53"
    case S54 = "S54"
    case S55 = "S55"
    case S56 = "S56"
    case S57 = "S57"
    case S58 = "S58"
    case S59 = "S59"
    case S60 = "S60"
    case S61 = "S61"
    case S62 = "S62"
    case S63 = "S63"
    case S64 = "S64"
    case S65 = "S65"
    case S66 = "S66"
    case S67 = "S67"
    case S68 = "S68"
    case S69 = "S69"
    case S70 = "S70"
    case S71 = "S71"
    case S72 = "S72"
    case S73 = "S73"
    case S74 = "S74"
    case S75 = "S75"
    case S76 = "S76"
    case S77 = "S77"
    case S78 = "S78"
    case S79 = "S79"
    case S80 = "S80"
    case S81 = "S81"
    case S82 = "S82"
    case S83 = "S83"
    case S84 = "S84"
    case S85 = "S85"
    case S86 = "S86"
    case S87 = "S87"
    case S88 = "S88"
    case S89 = "S89"
    case S90 = "S90"
    case S91 = "S91"
    case S92 = "S92"
    case S93 = "S93"
    case S94 = "S94"
    case S95 = "S95"
    case S96 = "S96"
    case S97 = "S97"
    case S98 = "S98"
    case S99 = "S99"
    case S100 = "S100"

    var displayName: String {
        let names: [String: String] = [
            "S1": "Poll Question", "S2": "Quiz Challenge", "S3": "This or That",
            "S4": "Countdown Teaser", "S5": "Q&A Session", "S6": "Swipe-Up Link",
            "S7": "DM Me Prompt", "S8": "Emoji Slider", "S9": "Add Yours Chain",
            "S10": "Story Takeover",
            "S11": "Scale Poll", "S12": "Preference Poll", "S13": "Would You Rather",
            "S14": "Never Have I Ever", "S15": "Trivia Quiz", "S16": "Personality Quiz",
            "S17": "Knowledge Check", "S18": "Guess the Answer", "S19": "Rate This",
            "S20": "Rank These",
            "S21": "Link Drop", "S22": "Product Link", "S23": "Article Share",
            "S24": "Video Link", "S25": "Playlist Link", "S26": "Countdown Launch",
            "S27": "Countdown Event", "S28": "Reminder Set", "S29": "Calendar Event",
            "S30": "Save the Date",
            "S31": "Collab Invite", "S32": "Tag Challenge", "S33": "Shoutout",
            "S34": "Repost Request", "S35": "DM Prompt Open", "S36": "Question Box",
            "S37": "Sneak Peek", "S38": "Spoiler Alert", "S39": "Clip Preview",
            "S40": "Behind Scenes Story", "S41": "Making Of", "S42": "Draft Reveal",
            "S43": "Bloopers", "S44": "Deleted Scenes",
            "S45": "Riddle Challenge", "S46": "Puzzle Game", "S47": "Word Scramble",
            "S48": "True or False", "S49": "Fill in Blank",
            "S50": "Mood Board", "S51": "Vibe Check", "S52": "Current Song",
            "S53": "Currently Reading", "S54": "Currently Watching", "S55": "Daily Gratitude",
            "S56": "Affirmation", "S57": "Manifestation", "S58": "Quote Share",
            "S59": "Status Update", "S60": "Progress Report", "S61": "Streak Post",
            "S62": "Win Celebration", "S63": "Milestone", "S64": "Achievement Unlock",
            "S65": "Flash Sale", "S66": "Limited Drop", "S67": "Exclusive Access",
            "S68": "Early Bird", "S69": "Waitlist", "S70": "Pre-Order",
            "S71": "Back in Stock",
            "S72": "React To This", "S73": "Same Energy", "S74": "Mood",
            "S75": "Relatable", "S76": "It Me", "S77": "Big Mood",
            "S78": "Check-In", "S79": "Travel Update", "S80": "Location Tag",
            "S81": "Where I'm At", "S82": "Destination Rec",
            "S83": "Day in Stories", "S84": "Week Recap", "S85": "Month Highlight",
            "S86": "Year Review", "S87": "Seasonal Moment", "S88": "Holiday Greeting",
            "S89": "Awareness Post", "S90": "Donation Drive", "S91": "Petition Share",
            "S92": "Volunteer Call", "S93": "Resource Share",
            "S94": "Throwback", "S95": "Prediction", "S96": "Unpopular Opinion",
            "S97": "Hot Take", "S98": "Confession", "S99": "Caption This",
            "S100": "Caption Contest"
        ]
        return names[self.rawValue] ?? "Story Archetype \(self.rawValue)"
    }

    var description: String { return "Ephemeral story content: \(displayName)" }
    var defaultAspectRatio: String { "9:16" }
    var defaultResolution: String { "1080x1920" }
    var requiredMediaCount: Int { 1 }
    var maxMediaCount: Int { 1 }
    var styleHints: [String] { ["Interactive", "Social", "Casual"] }
    var nicheHints: [String] { ["Lifestyle", "Social", "Engagement"] }
    var requiredOperations: [String] { ["textOverlay", "animation"] }
}

// MARK: - New Format Archetypes (60)
@available(iOS 26, *)
enum NewFormatArchetype: String, Codable, Sendable, CaseIterable {
    case N1 = "N1"
    case N2 = "N2"
    case N3 = "N3"
    case N4 = "N4"
    case N5 = "N5"
    case N6 = "N6"
    case N7 = "N7"
    case N8 = "N8"
    case N9 = "N9"
    case N10 = "N10"
    case N11 = "N11"
    case N12 = "N12"
    case N13 = "N13"
    case N14 = "N14"
    case N15 = "N15"
    case N16 = "N16"
    case N17 = "N17"
    case N18 = "N18"
    case N19 = "N19"
    case N20 = "N20"
    case N21 = "N21"
    case N22 = "N22"
    case N23 = "N23"
    case N24 = "N24"
    case N25 = "N25"
    case N26 = "N26"
    case N27 = "N27"
    case N28 = "N28"
    case N29 = "N29"
    case N30 = "N30"
    case N31 = "N31"
    case N32 = "N32"
    case N33 = "N33"
    case N34 = "N34"
    case N35 = "N35"
    case N36 = "N36"
    case N37 = "N37"
    case N38 = "N38"
    case N39 = "N39"
    case N40 = "N40"
    case N41 = "N41"
    case N42 = "N42"
    case N43 = "N43"
    case N44 = "N44"
    case N45 = "N45"
    case N46 = "N46"
    case N47 = "N47"
    case N48 = "N48"
    case N49 = "N49"
    case N50 = "N50"
    case N51 = "N51"
    case N52 = "N52"
    case N53 = "N53"
    case N54 = "N54"
    case N55 = "N55"
    case N56 = "N56"
    case N57 = "N57"
    case N58 = "N58"
    case N59 = "N59"
    case N60 = "N60"

    var displayName: String {
        let names: [String: String] = [
            "N1": "Live Photo Loop", "N2": "Live Photo Long Exposure", "N3": "Reels Remix Reaction",
            "N4": "Reels Remix Duet", "N5": "Reels Remix Response", "N6": "Threads Visual Post",
            "N7": "Threads Carousel", "N8": "Threads Poll", "N9": "Broadcast Announcement",
            "N10": "Broadcast Update", "N11": "Broadcast Exclusive", "N12": "Collab Post Dual",
            "N13": "Collab Post Multi", "N14": "Guide Step-by-Step", "N15": "Guide Recommendations",
            "N16": "Collection Wishlist", "N17": "Collection Saved Posts", "N18": "Collection Recommendations",
            "N19": "Notes Text-First", "N20": "Notes Memo", "N21": "Voice Memo Visual",
            "N22": "Voice Memo Transcribed", "N23": "AI Image Prompt", "N24": "AI Image Result",
            "N25": "AI Video Result", "N26": "AR Face Filter", "N27": "AR World Effect",
            "N28": "AR Portal Effect", "N29": "3D Spatial Photo", "N30": "3D Immersive Video",
            "N31": "NFT Showcase", "N32": "NFT Collection Drop", "N33": "Wedding Recap",
            "N34": "Birthday Celebration", "N35": "Graduation Commemoration", "N36": "Trip Recap",
            "N37": "Concert Recap", "N38": "Festival Recap", "N39": "Achievement Badge",
            "N40": "Achievement Milestone", "N41": "Achievement Unlock", "N42": "Sticker Reaction Pack",
            "N43": "Giphy Reaction", "N44": "Emoji Story", "N45": "Text Story",
            "N46": "Link Preview Card", "N47": "Music Share Card", "N48": "Podcast Clip",
            "N49": "Newsletter Preview", "N50": "Event Invitation", "N51": "Recipe Card",
            "N52": "Resume Card", "N53": "Menu Card", "N54": "Ticket Stub",
            "N55": "Receipt Review", "N56": "Map Route", "N57": "Weather Report",
            "N58": "Horoscope", "N59": "Birth Chart", "N60": "Dream Journal"
        ]
        return names[self.rawValue] ?? "New Format \(self.rawValue)"
    }

    var description: String { return "Emerging format: \(displayName)" }
    var defaultAspectRatio: String { "9:16" }
    var defaultResolution: String { "1080x1920" }
    var requiredMediaCount: Int { 1 }
    var maxMediaCount: Int { 1 }
    var styleHints: [String] { ["Futuristic", "Tech", "Innovative"] }
    var nicheHints: [String] { ["Tech", "Lifestyle", "Social"] }
    var requiredOperations: [String] { ["animation", "arOverlay"] }
}

// MARK: - VideoTemplateCategory Extension: Backward-Compatible Mapping
//
// This extension maps each of the 12 existing VideoTemplateCategory cases to a
// curated subset of the 474 expanded archetypes. Each category maps to relevant
// archetypes across Photo, Carousel, Video, Story, and NewFormat dimensions.

@available(iOS 26, *)
extension VideoTemplateCategory {

    /// The set of ContentArchetypes that belong to this category.
    var contentArchetypes: [ContentArchetype] {
        _archetypeSets[self] ?? []
    }

    /// A convenience property returning just the VideoArchetypes relevant to this category.
    var videoArchetypes: [VideoArchetype] {
        contentArchetypes.compactMap {
            if case .video(let va) = $0 { return va }
            return nil
        }
    }

    /// A convenience property returning just the PhotoArchetypes relevant to this category.
    var photoArchetypes: [PhotoArchetype] {
        contentArchetypes.compactMap {
            if case .photo(let pa) = $0 { return pa }
            return nil
        }
    }

    /// A convenience property returning just the CarouselArchetypes relevant to this category.
    var carouselArchetypes: [CarouselArchetype] {
        contentArchetypes.compactMap {
            if case .carousel(let ca) = $0 { return ca }
            return nil
        }
    }

    /// A convenience property returning just the StoryArchetypes relevant to this category.
    var storyArchetypes: [StoryArchetype] {
        contentArchetypes.compactMap {
            if case .story(let sa) = $0 { return sa }
            return nil
        }
    }

    /// A convenience property returning just the NewFormatArchetypes relevant to this category.
    var newFormatArchetypes: [NewFormatArchetype] {
        contentArchetypes.compactMap {
            if case .newFormat(let na) = $0 { return na }
            return nil
        }
    }
}

// MARK: - Archetype sets per category (cached lookup)

@available(iOS 26, *)
private let _archetypeSets: [VideoTemplateCategory: [ContentArchetype]] = {
    var result: [VideoTemplateCategory: [ContentArchetype]] = [:]

    // GRWM — personal routine, outfit, beauty prep
    result[.grwm] = [
        .video(.V11), .video(.V61), .video(.V62), .video(.V64), .video(.V65),
        .video(.V66), .video(.V67),
        .photo(.P1), .photo(.P11), .photo(.P35),
        .carousel(.C11), .carousel(.C19), .carousel(.C20),
        .story(.S55), .story(.S59), .story(.S60), .story(.S78),
        .newFormat(.N19), .newFormat(.N20)
    ]

    // Cooking — recipes, food prep, kitchen content
    result[.cooking] = [
        .video(.V6), .video(.V70), .video(.V147), .video(.V148), .video(.V149),
        .video(.V150), .video(.V151), .video(.V152), .video(.V153), .video(.V154),
        .video(.V155), .video(.V156),
        .photo(.P28), .photo(.P29), .photo(.P30),
        .carousel(.C10), .carousel(.C33), .carousel(.C47),
        .story(.S51), .story(.S54),
        .newFormat(.N51), .newFormat(.N53)
    ]

    // OOTD — outfit showcase, fashion, style
    result[.ootd] = [
        .video(.V66), .video(.V92), .video(.V93), .video(.V94), .video(.V95),
        .video(.V96), .video(.V97), .video(.V98), .video(.V99), .video(.V100),
        .video(.V101), .video(.V102),
        .photo(.P1), .photo(.P2), .photo(.P4), .photo(.P14),
        .carousel(.C11), .carousel(.C19), .carousel(.C20),
        .story(.S50), .story(.S59),
        .newFormat(.N29), .newFormat(.N46)
    ]

    // Travel — destinations, itineraries, adventures
    result[.travel] = [
        .video(.V10), .video(.V81), .video(.V82), .video(.V83), .video(.V84),
        .video(.V85), .video(.V86), .video(.V87), .video(.V88), .video(.V89),
        .video(.V90), .video(.V91),
        .photo(.P2), .photo(.P14), .photo(.P23),
        .carousel(.C18), .carousel(.C52),
        .story(.S79), .story(.S80), .story(.S81), .story(.S82), .story(.S87),
        .newFormat(.N36), .newFormat(.N56)
    ]

    // Fitness — workouts, form, progress, gym
    result[.fitness] = [
        .video(.V7), .video(.V114), .video(.V115), .video(.V116), .video(.V117),
        .video(.V118), .video(.V119), .video(.V120), .video(.V121), .video(.V122),
        .video(.V123), .video(.V124), .video(.V125),
        .photo(.P31), .photo(.P32), .photo(.P33), .photo(.P34),
        .carousel(.C34), .carousel(.C58),
        .story(.S61), .story(.S63), .story(.S64),
        .newFormat(.N57)
    ]

    // Product — reviews, demos, unboxings, comparisons
    result[.product] = [
        .video(.V8), .video(.V13), .video(.V37), .video(.V38), .video(.V46),
        .video(.V47), .video(.V103), .video(.V104), .video(.V105), .video(.V106),
        .video(.V107),
        .photo(.P8), .photo(.P51), .photo(.P52),
        .carousel(.C2), .carousel(.C16), .carousel(.C41), .carousel(.C42),
        .story(.S22), .story(.S65), .story(.S66), .story(.S67), .story(.S68),
        .story(.S69), .story(.S70), .story(.S71),
        .newFormat(.N24), .newFormat(.N25)
    ]

    // Beauty — makeup, hair, nails, skincare
    result[.beauty] = [
        .video(.V64), .video(.V65), .video(.V103), .video(.V104), .video(.V105),
        .video(.V107), .video(.V108), .video(.V109), .video(.V110), .video(.V111),
        .video(.V112), .video(.V113),
        .photo(.P1), .photo(.P8), .photo(.P56),
        .carousel(.C15), .carousel(.C33),
        .story(.S50), .story(.S55), .story(.S56), .story(.S57),
        .newFormat(.N26), .newFormat(.N47)
    ]

    // Lifestyle — daily routines, home, wellness, general life content
    result[.lifestyle] = [
        .video(.V2), .video(.V17), .video(.V18), .video(.V20), .video(.V21),
        .video(.V22), .video(.V23), .video(.V24), .video(.V25), .video(.V26),
        .video(.V27), .video(.V28), .video(.V29), .video(.V30),
        .video(.V61), .video(.V62), .video(.V63), .video(.V67), .video(.V68),
        .video(.V69), .video(.V71), .video(.V72), .video(.V73), .video(.V74),
        .video(.V75), .video(.V76), .video(.V77), .video(.V78), .video(.V79),
        .video(.V80),
        .photo(.P3), .photo(.P9), .photo(.P11), .photo(.P35), .photo(.P44),
        .photo(.P46), .photo(.P47),
        .carousel(.C5), .carousel(.C6), .carousel(.C28), .carousel(.C29),
        .carousel(.C40), .carousel(.C46), .carousel(.C47),
        .story(.S50), .story(.S51), .story(.S52), .story(.S53), .story(.S54),
        .story(.S55), .story(.S56), .story(.S57), .story(.S58), .story(.S59),
        .story(.S60), .story(.S61), .story(.S62), .story(.S63), .story(.S83),
        .story(.S84), .story(.S85), .story(.S86),
        .newFormat(.N19), .newFormat(.N20), .newFormat(.N21), .newFormat(.N22),
        .newFormat(.N44), .newFormat(.N45), .newFormat(.N60)
    ]

    // Fashion — style guides, trends, hauls, sustainable fashion
    result[.fashion] = [
        .video(.V66), .video(.V92), .video(.V93), .video(.V94), .video(.V95),
        .video(.V96), .video(.V97), .video(.V98), .video(.V99), .video(.V100),
        .video(.V101), .video(.V102),
        .photo(.P1), .photo(.P2), .photo(.P4), .photo(.P14), .photo(.P41),
        .carousel(.C11), .carousel(.C19), .carousel(.C20), .carousel(.C44),
        .story(.S50), .story(.S65), .story(.S66),
        .newFormat(.N29), .newFormat(.N46)
    ]

    // Food — culinary content, restaurant reviews, food culture
    result[.food] = [
        .video(.V6), .video(.V67), .video(.V68), .video(.V69), .video(.V70),
        .video(.V147), .video(.V148), .video(.V149), .video(.V150), .video(.V151),
        .video(.V152), .video(.V153), .video(.V154), .video(.V155), .video(.V156),
        .photo(.P28), .photo(.P29), .photo(.P30),
        .carousel(.C10), .carousel(.C33), .carousel(.C47),
        .story(.S51), .story(.S54),
        .newFormat(.N51), .newFormat(.N53)
    ]

    // Educational — lessons, explainers, study content, tutorials
    result[.educational] = [
        .video(.V36), .video(.V39), .video(.V40), .video(.V51), .video(.V52),
        .video(.V53), .video(.V54), .video(.V55), .video(.V56), .video(.V57),
        .video(.V58), .video(.V59), .video(.V60),
        .photo(.P5), .photo(.P7), .photo(.P13), .photo(.P37),
        .carousel(.C1), .carousel(.C8), .carousel(.C9), .carousel(.C12),
        .carousel(.C15), .carousel(.C21), .carousel(.C22), .carousel(.C23),
        .carousel(.C24), .carousel(.C35), .carousel(.C36), .carousel(.C37),
        .carousel(.C38), .carousel(.C44), .carousel(.C45), .carousel(.C49),
        .carousel(.C50), .carousel(.C54), .carousel(.C55), .carousel(.C57),
        .carousel(.C58),
        .story(.S1), .story(.S2), .story(.S5), .story(.S15), .story(.S16),
        .story(.S17), .story(.S18), .story(.S36), .story(.S45), .story(.S46),
        .story(.S47), .story(.S48), .story(.S49),
        .newFormat(.N14), .newFormat(.N15), .newFormat(.N52)
    ]

    // Entertainment — comedy, music, gaming, art, pets, creative content
    result[.entertainment] = [
        .video(.V4), .video(.V5), .video(.V9), .video(.V12), .video(.V14),
        .video(.V15), .video(.V16), .video(.V31), .video(.V32), .video(.V33),
        .video(.V34), .video(.V35),
        .video(.V157), .video(.V158), .video(.V159), .video(.V160), .video(.V161),
        .video(.V162), .video(.V163), .video(.V164), .video(.V165), .video(.V166),
        .video(.V167), .video(.V168),
        .video(.V169), .video(.V170), .video(.V171), .video(.V172), .video(.V173),
        .video(.V174), .video(.V175), .video(.V176), .video(.V177), .video(.V178),
        .video(.V179), .video(.V180), .video(.V181), .video(.V182), .video(.V183),
        .video(.V184), .video(.V185), .video(.V186), .video(.V187), .video(.V188),
        .video(.V189), .video(.V190), .video(.V191), .video(.V192), .video(.V193),
        .video(.V194), .video(.V195), .video(.V196), .video(.V197), .video(.V198),
        .photo(.P10), .photo(.P25), .photo(.P38), .photo(.P39), .photo(.P40),
        .photo(.P48), .photo(.P49), .photo(.P50),
        .carousel(.C25), .carousel(.C26), .carousel(.C27), .carousel(.C30),
        .carousel(.C39), .carousel(.C48), .carousel(.C50), .carousel(.C53),
        .story(.S3), .story(.S7), .story(.S8), .story(.S9), .story(.S10),
        .story(.S13), .story(.S14), .story(.S19), .story(.S20), .story(.S31),
        .story(.S32), .story(.S33), .story(.S34), .story(.S35), .story(.S72),
        .story(.S73), .story(.S74), .story(.S75), .story(.S76), .story(.S77),
        .story(.S94), .story(.S95), .story(.S96), .story(.S97), .story(.S98),
        .story(.S99), .story(.S100),
        .newFormat(.N1), .newFormat(.N2), .newFormat(.N3), .newFormat(.N4),
        .newFormat(.N5), .newFormat(.N6), .newFormat(.N7), .newFormat(.N8),
        .newFormat(.N42), .newFormat(.N43)
    ]

    return result
}()

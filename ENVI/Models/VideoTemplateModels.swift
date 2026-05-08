//
//  VideoTemplateModels.swift
//  ENVI
//
//  Phase 3 — Template Tab v1 (Task 1).
//
//  Data model for camera-roll-driven video templates. These describe
//  templates in terms of media *requirements* (slot shapes) that the
//  TemplateMatchEngine (Task 2) fills with the user's best-matching
//  ClassifiedAssets from Phase 1.
//
//  Coexists with `ContentTemplate` (caption/metadata templates) in
//  BrandKitModels.swift — different type, different purpose.
//
//  Naming: `AspectRatio` and `TextOverlay` already exist in
//  EditorModels.swift with slightly different shapes. To avoid
//  source-level collisions we nest the template-specific versions
//  inside `VideoTemplate` (reference as `VideoTemplate.AspectRatio`,
//  `VideoTemplate.TextOverlay`). Enums with associated values (e.g.
//  `FaceCountFilter.exactly(Int)`) hand-roll Codable using a
//  `type` + `value` discriminator since synthesized Codable does not
//  work cleanly for mixed-arity payloads.
//

import Foundation

// MARK: - VideoTemplate

/// A camera-roll-driven template: a collection of slots, each with
/// declarative media requirements. The match engine fills each slot
/// with the user's best-matching ClassifiedAsset.
struct VideoTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    let remoteID: String?
    let name: String
    let category: VideoTemplateCategory
    let aspectRatio: AspectRatio
    let duration: TimeInterval?
    let slots: [TemplateSlot]
    let textOverlays: [TextOverlay]
    let transitions: [TransitionType]
    let audioTrack: AudioTrackRef?
    let suggestedPlatforms: [SocialPlatform]
    let thumbnailURL: URL?
    let popularity: Int

    init(
        id: UUID = UUID(),
        remoteID: String? = nil,
        name: String,
        category: VideoTemplateCategory,
        aspectRatio: AspectRatio,
        duration: TimeInterval? = nil,
        slots: [TemplateSlot] = [],
        textOverlays: [TextOverlay] = [],
        transitions: [TransitionType] = [],
        audioTrack: AudioTrackRef? = nil,
        suggestedPlatforms: [SocialPlatform] = [],
        thumbnailURL: URL? = nil,
        popularity: Int = 0
    ) {
        self.id = id
        self.remoteID = remoteID
        self.name = name
        self.category = category
        self.aspectRatio = aspectRatio
        self.duration = duration
        self.slots = slots
        self.textOverlays = textOverlays
        self.transitions = transitions
        self.audioTrack = audioTrack
        self.suggestedPlatforms = suggestedPlatforms
        self.thumbnailURL = thumbnailURL
        self.popularity = popularity
    }

    // MARK: Nested types (scoped to avoid global-namespace collisions)

    /// Canonical canvas aspect ratios for template rendering.
    /// Nested under VideoTemplate to avoid conflicting with
    /// EditorModels.AspectRatio (which has different cases).
    enum AspectRatio: String, Codable, CaseIterable {
        case portrait9x16
        case square
        case landscape16x9
        case portrait4x5
    }

    /// Static text element anchored to a slot or the whole template.
    /// Nested to avoid conflicting with EditorModels.TextOverlay.
    struct TextOverlay: Codable, Equatable, Identifiable {
        let id: UUID
        let placement: Placement
        let text: String
        let style: Style

        enum Placement: String, Codable, CaseIterable {
            case topLeft, topCenter, topRight
            case middleLeft, middleCenter, middleRight
            case bottomLeft, bottomCenter, bottomRight
        }

        struct Style: Codable, Equatable {
            let fontName: String
            let fontSize: Double
            let colorHex: String
            let backgroundHex: String?
            let bold: Bool

            init(
                fontName: String = "SpaceMono-Bold",
                fontSize: Double = 28,
                colorHex: String = "#FFFFFF",
                backgroundHex: String? = nil,
                bold: Bool = true
            ) {
                self.fontName = fontName
                self.fontSize = fontSize
                self.colorHex = colorHex
                self.backgroundHex = backgroundHex
                self.bold = bold
            }
        }

        init(
            id: UUID = UUID(),
            placement: Placement,
            text: String,
            style: Style = Style()
        ) {
            self.id = id
            self.placement = placement
            self.text = text
            self.style = style
        }
    }
}

// MARK: - VideoTemplateCategory

enum VideoTemplateCategory: String, Codable, CaseIterable, Identifiable {
    case grwm
    case cooking
    case ootd
    case travel
    case fitness
    case product
    case beauty
    case lifestyle
    case fashion
    case food
    case educational
    case entertainment

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grwm:          return "GRWM"
        case .cooking:       return "Cooking"
        case .ootd:          return "OOTD"
        case .travel:        return "Travel"
        case .fitness:       return "Fitness"
        case .product:       return "Product"
        case .beauty:        return "Beauty"
        case .lifestyle:     return "Lifestyle"
        case .fashion:       return "Fashion"
        case .food:          return "Food"
        case .educational:   return "Educational"
        case .entertainment: return "Entertainment"
        }
    }
}

// MARK: - TemplateSlot

/// A single slot in a template. Has an order, duration, requirements
/// for what media can fill it, and an optional overlay caption.
struct TemplateSlot: Identifiable, Codable, Equatable {
    let id: UUID
    let order: Int
    let duration: TimeInterval
    let requirements: MediaRequirements
    let textOverlay: String?

    init(
        id: UUID = UUID(),
        order: Int,
        duration: TimeInterval,
        requirements: MediaRequirements,
        textOverlay: String? = nil
    ) {
        self.id = id
        self.order = order
        self.duration = duration
        self.requirements = requirements
        self.textOverlay = textOverlay
    }
}

// MARK: - MediaRequirements

/// Declarative filter spec for candidate ClassifiedAssets.
/// Consumed by the TemplateMatchEngine (Task 2).
struct MediaRequirements: Codable, Equatable {
    let acceptedMediaTypes: [MediaTypeFilter]
    let preferredLabels: [String]
    let excludedLabels: [String]
    let preferredOrientation: Orientation?
    let minimumAestheticsScore: Double
    let requireNonUtility: Bool
    let preferredFaceCount: FaceCountFilter?
    let preferredPersonCount: PersonCountFilter?
    let durationRange: DurationRange?
    let requireSubtypes: [PHAssetMediaSubtypeFilter]
    let excludeSubtypes: [PHAssetMediaSubtypeFilter]
    let recencyPreference: RecencyPreference

    init(
        acceptedMediaTypes: [MediaTypeFilter] = [.photo, .video],
        preferredLabels: [String] = [],
        excludedLabels: [String] = [],
        preferredOrientation: Orientation? = nil,
        minimumAestheticsScore: Double = -0.3,
        requireNonUtility: Bool = true,
        preferredFaceCount: FaceCountFilter? = nil,
        preferredPersonCount: PersonCountFilter? = nil,
        durationRange: DurationRange? = nil,
        requireSubtypes: [PHAssetMediaSubtypeFilter] = [],
        excludeSubtypes: [PHAssetMediaSubtypeFilter] = [],
        recencyPreference: RecencyPreference = .any
    ) {
        self.acceptedMediaTypes = acceptedMediaTypes
        self.preferredLabels = preferredLabels
        self.excludedLabels = excludedLabels
        self.preferredOrientation = preferredOrientation
        self.minimumAestheticsScore = minimumAestheticsScore
        self.requireNonUtility = requireNonUtility
        self.preferredFaceCount = preferredFaceCount
        self.preferredPersonCount = preferredPersonCount
        self.durationRange = durationRange
        self.requireSubtypes = requireSubtypes
        self.excludeSubtypes = excludeSubtypes
        self.recencyPreference = recencyPreference
    }

    /// Codable-friendly wrapper around a half-open Range<TimeInterval>.
    /// `Range` is not itself Codable, so we store endpoints.
    struct DurationRange: Codable, Equatable {
        let lowerBound: TimeInterval
        let upperBound: TimeInterval

        init(lowerBound: TimeInterval, upperBound: TimeInterval) {
            self.lowerBound = lowerBound
            self.upperBound = upperBound
        }

        init(_ range: Range<TimeInterval>) {
            self.lowerBound = range.lowerBound
            self.upperBound = range.upperBound
        }

        var range: Range<TimeInterval> { lowerBound..<upperBound }

        func contains(_ value: TimeInterval) -> Bool {
            value >= lowerBound && value < upperBound
        }
    }
}

// MARK: - Supporting enums (simple string-raw)

enum MediaTypeFilter: String, Codable, CaseIterable {
    case photo
    case video
    case livePhoto
}

enum Orientation: String, Codable, CaseIterable {
    case portrait
    case landscape
    case square
}

enum RecencyPreference: String, Codable, CaseIterable {
    case any
    case recent30Days
    case recent7Days
}

/// PHAssetMediaSubtype cases that are meaningful for template matching.
/// Mapped from `PHAssetMediaSubtype` raw flag values at query time.
enum PHAssetMediaSubtypeFilter: String, Codable, CaseIterable {
    case screenshot
    case panorama
    case hdr
    case live
    case depthEffect
    case slomo          // highFrameRate / video high frame rate
    case timelapse
    case cinematic
    case spatial
}

// MARK: - FaceCountFilter / PersonCountFilter (associated values)
//
// These enums carry an associated `Int` for `.exactly(n)`. Synthesized
// Codable cannot handle mixed-arity enum cases cleanly, so we hand-roll
// using a `type` + optional `value` discriminator pattern.

enum FaceCountFilter: Codable, Equatable {
    case none
    case exactly(Int)
    case group
    case any

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum Kind: String, Codable {
        case none, exactly, group, any
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(Kind.none, forKey: .type)
        case .exactly(let n):
            try container.encode(Kind.exactly, forKey: .type)
            try container.encode(n, forKey: .value)
        case .group:
            try container.encode(Kind.group, forKey: .type)
        case .any:
            try container.encode(Kind.any, forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .type)
        switch kind {
        case .none:    self = .none
        case .group:   self = .group
        case .any:     self = .any
        case .exactly:
            let n = try c.decode(Int.self, forKey: .value)
            self = .exactly(n)
        }
    }
}

enum PersonCountFilter: Codable, Equatable {
    case none
    case exactly(Int)
    case group
    case any

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum Kind: String, Codable {
        case none, exactly, group, any
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(Kind.none, forKey: .type)
        case .exactly(let n):
            try container.encode(Kind.exactly, forKey: .type)
            try container.encode(n, forKey: .value)
        case .group:
            try container.encode(Kind.group, forKey: .type)
        case .any:
            try container.encode(Kind.any, forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .type)
        switch kind {
        case .none:    self = .none
        case .group:   self = .group
        case .any:     self = .any
        case .exactly:
            let n = try c.decode(Int.self, forKey: .value)
            self = .exactly(n)
        }
    }
}

// MARK: - Transitions + Audio

enum TransitionType: String, Codable, CaseIterable {
    case cut
    case crossfade
    case slideLeft
    case slideRight
    case fadeToBlack
    case zoomIn
}

struct AudioTrackRef: Codable, Equatable {
    let trackID: String
    let title: String
    let artist: String
    let url: URL?

    init(trackID: String, title: String, artist: String, url: URL? = nil) {
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.url = url
    }
}

// MARK: - FilledSlot / PopulatedTemplate (non-Codable — reference ClassifiedAsset)
//
// ClassifiedAsset is a SwiftData @Model (not Codable), so these
// runtime-only types intentionally omit Codable conformance. They are
// produced by the TemplateMatchEngine and consumed by the UI layer.

struct FilledSlot: Identifiable, @unchecked Sendable {
    var id: UUID { slot.id }
    let slot: TemplateSlot
    let matchedAsset: ClassifiedAsset?
    let matchScore: Double
    let alternates: [ClassifiedAsset]

    init(
        slot: TemplateSlot,
        matchedAsset: ClassifiedAsset? = nil,
        matchScore: Double = 0.0,
        alternates: [ClassifiedAsset] = []
    ) {
        self.slot = slot
        self.matchedAsset = matchedAsset
        self.matchScore = matchScore
        self.alternates = alternates
    }
}

struct PopulatedTemplate: Identifiable, Hashable, Sendable {
    static func == (lhs: PopulatedTemplate, rhs: PopulatedTemplate) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    var id: UUID { template.id }
    let template: VideoTemplate
    let filledSlots: [FilledSlot]
    let fillRate: Double
    let overallScore: Double
    /// Composited preview thumbnail. Kept as Data (PNG/JPEG) rather
    /// than UIImage so this type stays platform-agnostic and doesn't
    /// drag UIKit into pure-model test targets. UI layer wraps in
    /// UIImage(data:) when rendering.
    let previewThumbnail: Data?

    init(
        template: VideoTemplate,
        filledSlots: [FilledSlot],
        fillRate: Double,
        overallScore: Double,
        previewThumbnail: Data? = nil
    ) {
        self.template = template
        self.filledSlots = filledSlots
        self.fillRate = fillRate
        self.overallScore = overallScore
        self.previewThumbnail = previewThumbnail
    }
}

// MARK: - Mock library (for Task 2+ tests and Phase 5 UI wiring)

extension VideoTemplate {

    /// 5 diverse mock templates covering the major categories.
    /// Used by MockVideoTemplateRepository (Task 3) until Phase 4
    /// wires up the Lynx/server-sourced catalog.
    static let mockLibrary: [VideoTemplate] = [
        grwmMock,
        cookingMock,
        ootdMock,
        travelMock,
        fitnessMock
    ]

    // MARK: GRWM

    private static let grwmMock = VideoTemplate(
        name: "Morning GRWM",
        category: .grwm,
        aspectRatio: .portrait9x16,
        duration: 15.0,
        slots: [
            TemplateSlot(
                order: 0,
                duration: 3.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo, .video],
                    preferredLabels: ["face", "person", "portrait"],
                    excludedLabels: ["screenshot", "document"],
                    preferredOrientation: .portrait,
                    minimumAestheticsScore: -0.1,
                    preferredFaceCount: .exactly(1),
                    preferredPersonCount: .exactly(1),
                    excludeSubtypes: [.screenshot, .panorama],
                    recencyPreference: .recent30Days
                ),
                textOverlay: "Get Ready With Me"
            ),
            TemplateSlot(
                order: 1,
                duration: 4.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.video],
                    preferredLabels: ["beauty", "cosmetics", "makeup"],
                    excludedLabels: ["screenshot"],
                    preferredOrientation: .portrait,
                    durationRange: MediaRequirements.DurationRange(lowerBound: 2.0, upperBound: 15.0),
                    excludeSubtypes: [.screenshot],
                    recencyPreference: .recent30Days
                )
            ),
            TemplateSlot(
                order: 2,
                duration: 4.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo, .video],
                    preferredLabels: ["face", "selfie", "mirror"],
                    preferredOrientation: .portrait,
                    minimumAestheticsScore: 0.0,
                    preferredFaceCount: .exactly(1),
                    recencyPreference: .recent30Days
                )
            ),
            TemplateSlot(
                order: 3,
                duration: 4.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo],
                    preferredLabels: ["outfit", "fashion", "clothing"],
                    preferredOrientation: .portrait,
                    minimumAestheticsScore: 0.1,
                    recencyPreference: .recent7Days
                ),
                textOverlay: "Ready!"
            )
        ],
        textOverlays: [
            VideoTemplate.TextOverlay(
                placement: .topCenter,
                text: "Morning Routine"
            )
        ],
        transitions: [.cut, .crossfade, .zoomIn, .cut],
        audioTrack: AudioTrackRef(
            trackID: "audio.grwm.upbeat01",
            title: "Sunrise Pop",
            artist: "ENVI Library"
        ),
        suggestedPlatforms: [.tiktok, .instagram, .youtube],
        popularity: 92
    )

    // MARK: Cooking

    private static let cookingMock = VideoTemplate(
        name: "Recipe Reel",
        category: .cooking,
        aspectRatio: .portrait9x16,
        duration: 20.0,
        slots: [
            TemplateSlot(
                order: 0,
                duration: 3.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo],
                    preferredLabels: ["food", "ingredients", "kitchen"],
                    excludedLabels: ["text", "menu", "document"],
                    preferredOrientation: .portrait,
                    minimumAestheticsScore: 0.0,
                    excludeSubtypes: [.screenshot, .panorama],
                    recencyPreference: .any
                ),
                textOverlay: "Ingredients"
            ),
            TemplateSlot(
                order: 1,
                duration: 6.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.video],
                    preferredLabels: ["cooking", "food preparation", "kitchen"],
                    preferredOrientation: .portrait,
                    durationRange: MediaRequirements.DurationRange(lowerBound: 3.0, upperBound: 20.0),
                    excludeSubtypes: [.screenshot]
                )
            ),
            TemplateSlot(
                order: 2,
                duration: 5.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.video],
                    preferredLabels: ["stove", "pan", "cooking"],
                    preferredOrientation: .portrait,
                    durationRange: MediaRequirements.DurationRange(lowerBound: 2.0, upperBound: 20.0)
                )
            ),
            TemplateSlot(
                order: 3,
                duration: 6.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo, .video],
                    preferredLabels: ["plate", "dish", "food", "meal"],
                    preferredOrientation: .portrait,
                    minimumAestheticsScore: 0.2,
                    recencyPreference: .recent30Days
                ),
                textOverlay: "Plated!"
            )
        ],
        textOverlays: [
            VideoTemplate.TextOverlay(placement: .topCenter, text: "Recipe of the Day")
        ],
        transitions: [.cut, .slideLeft, .slideLeft, .crossfade],
        audioTrack: AudioTrackRef(
            trackID: "audio.cooking.lofi01",
            title: "Kitchen Lofi",
            artist: "ENVI Library"
        ),
        suggestedPlatforms: [.tiktok, .instagram, .youtube],
        popularity: 78
    )

    // MARK: OOTD

    private static let ootdMock = VideoTemplate(
        name: "Outfit of the Day",
        category: .ootd,
        aspectRatio: .portrait9x16,
        duration: 10.0,
        slots: [
            TemplateSlot(
                order: 0,
                duration: 2.5,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo],
                    preferredLabels: ["outfit", "fashion", "mirror selfie"],
                    excludedLabels: ["screenshot", "document"],
                    preferredOrientation: .portrait,
                    minimumAestheticsScore: 0.0,
                    preferredPersonCount: .exactly(1),
                    excludeSubtypes: [.screenshot, .panorama],
                    recencyPreference: .recent7Days
                ),
                textOverlay: "OOTD"
            ),
            TemplateSlot(
                order: 1,
                duration: 2.5,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo],
                    preferredLabels: ["shoes", "accessory", "bag"],
                    preferredOrientation: .portrait,
                    recencyPreference: .recent7Days
                ),
                textOverlay: "Details"
            ),
            TemplateSlot(
                order: 2,
                duration: 2.5,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo, .livePhoto],
                    preferredLabels: ["outfit", "fashion", "pose"],
                    preferredOrientation: .portrait,
                    minimumAestheticsScore: 0.1,
                    preferredPersonCount: .exactly(1),
                    recencyPreference: .recent7Days
                )
            ),
            TemplateSlot(
                order: 3,
                duration: 2.5,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo],
                    preferredLabels: ["outfit", "fashion", "full body"],
                    preferredOrientation: .portrait,
                    minimumAestheticsScore: 0.2,
                    recencyPreference: .recent7Days
                ),
                textOverlay: "Tag: @"
            )
        ],
        textOverlays: [
            VideoTemplate.TextOverlay(placement: .bottomCenter, text: "Link in bio")
        ],
        transitions: [.slideLeft, .slideLeft, .zoomIn, .cut],
        audioTrack: AudioTrackRef(
            trackID: "audio.ootd.trending01",
            title: "Runway Pulse",
            artist: "ENVI Library"
        ),
        suggestedPlatforms: [.tiktok, .instagram],
        popularity: 85
    )

    // MARK: Travel

    private static let travelMock = VideoTemplate(
        name: "Travel Diary",
        category: .travel,
        aspectRatio: .portrait9x16,
        duration: 25.0,
        slots: [
            TemplateSlot(
                order: 0,
                duration: 5.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo, .video],
                    preferredLabels: ["landscape", "scenery", "outdoor", "nature"],
                    excludedLabels: ["screenshot", "receipt"],
                    preferredOrientation: .landscape,
                    minimumAestheticsScore: 0.2,
                    excludeSubtypes: [.screenshot],
                    recencyPreference: .any
                ),
                textOverlay: "Arrived"
            ),
            TemplateSlot(
                order: 1,
                duration: 5.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo],
                    preferredLabels: ["architecture", "city", "street"],
                    minimumAestheticsScore: 0.1,
                    recencyPreference: .any
                )
            ),
            TemplateSlot(
                order: 2,
                duration: 5.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo],
                    preferredLabels: ["food", "restaurant", "cafe"],
                    minimumAestheticsScore: 0.1,
                    recencyPreference: .any
                ),
                textOverlay: "Eats"
            ),
            TemplateSlot(
                order: 3,
                duration: 5.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo, .video],
                    preferredLabels: ["sunset", "sky", "view"],
                    preferredOrientation: .landscape,
                    minimumAestheticsScore: 0.3,
                    requireSubtypes: [],
                    recencyPreference: .any
                )
            ),
            TemplateSlot(
                order: 4,
                duration: 5.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo],
                    preferredLabels: ["selfie", "portrait", "travel"],
                    preferredFaceCount: .exactly(1),
                    recencyPreference: .any
                ),
                textOverlay: "Memories"
            )
        ],
        textOverlays: [
            VideoTemplate.TextOverlay(placement: .topCenter, text: "Wanderlust")
        ],
        transitions: [.crossfade, .crossfade, .slideRight, .fadeToBlack, .cut],
        audioTrack: AudioTrackRef(
            trackID: "audio.travel.cinematic01",
            title: "Horizon",
            artist: "ENVI Library"
        ),
        suggestedPlatforms: [.instagram, .youtube, .tiktok],
        popularity: 88
    )

    // MARK: Fitness

    private static let fitnessMock = VideoTemplate(
        name: "Workout of the Week",
        category: .fitness,
        aspectRatio: .portrait9x16,
        duration: 18.0,
        slots: [
            TemplateSlot(
                order: 0,
                duration: 3.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo, .video],
                    preferredLabels: ["gym", "fitness", "workout"],
                    excludedLabels: ["screenshot", "document"],
                    preferredOrientation: .portrait,
                    minimumAestheticsScore: -0.1,
                    excludeSubtypes: [.screenshot],
                    recencyPreference: .recent30Days
                ),
                textOverlay: "Warm up"
            ),
            TemplateSlot(
                order: 1,
                duration: 5.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.video],
                    preferredLabels: ["exercise", "weights", "fitness"],
                    preferredOrientation: .portrait,
                    durationRange: MediaRequirements.DurationRange(lowerBound: 3.0, upperBound: 15.0),
                    recencyPreference: .recent30Days
                ),
                textOverlay: "Set 1"
            ),
            TemplateSlot(
                order: 2,
                duration: 5.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.video],
                    preferredLabels: ["exercise", "cardio", "gym"],
                    preferredOrientation: .portrait,
                    durationRange: MediaRequirements.DurationRange(lowerBound: 3.0, upperBound: 15.0),
                    recencyPreference: .recent30Days
                ),
                textOverlay: "Set 2"
            ),
            TemplateSlot(
                order: 3,
                duration: 5.0,
                requirements: MediaRequirements(
                    acceptedMediaTypes: [.photo, .video],
                    preferredLabels: ["selfie", "gym", "progress"],
                    preferredOrientation: .portrait,
                    minimumAestheticsScore: 0.0,
                    preferredFaceCount: .exactly(1),
                    recencyPreference: .recent7Days
                ),
                textOverlay: "Done!"
            )
        ],
        textOverlays: [
            VideoTemplate.TextOverlay(placement: .topCenter, text: "Weekly Workout")
        ],
        transitions: [.cut, .zoomIn, .zoomIn, .crossfade],
        audioTrack: AudioTrackRef(
            trackID: "audio.fitness.trap01",
            title: "Push Through",
            artist: "ENVI Library"
        ),
        suggestedPlatforms: [.tiktok, .instagram, .youtube],
        popularity: 71
    )
}

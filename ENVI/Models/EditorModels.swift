import Foundation
import SwiftUI

// MARK: - Editor Project

/// A multi-track editor project containing video, audio, text, and effects.
struct EditorProject: Identifiable, Codable {
    let id: UUID
    var name: String
    var tracks: [EditorTrack]
    var duration: TimeInterval
    var aspectRatio: AspectRatio
    let createdAt: Date
    var lastEditedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Untitled",
        tracks: [EditorTrack] = EditorTrack.defaultTracks,
        duration: TimeInterval = 30,
        aspectRatio: AspectRatio = .portrait9x16,
        createdAt: Date = Date(),
        lastEditedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.duration = duration
        self.aspectRatio = aspectRatio
        self.createdAt = createdAt
        self.lastEditedAt = lastEditedAt
    }
}

// MARK: - Editor Track

/// A single lane in the multi-track timeline (video, audio, text, or effects).
struct EditorTrack: Identifiable, Codable {
    let id: UUID
    var type: TrackType
    var clips: [EditorClip]

    enum TrackType: String, Codable {
        case video, audio, text, effect
    }

    init(id: UUID = UUID(), type: TrackType, clips: [EditorClip] = []) {
        self.id = id
        self.type = type
        self.clips = clips
    }

    static let defaultTracks: [EditorTrack] = [
        EditorTrack(type: .video),
        EditorTrack(type: .audio),
        EditorTrack(type: .text),
        EditorTrack(type: .effect),
    ]
}

// MARK: - Editor Clip

/// A segment within a track, referencing a time range and optional source asset.
struct EditorClip: Identifiable, Codable {
    let id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var sourceAssetID: String?
    var effects: [ClipEffect]

    init(
        id: UUID = UUID(),
        startTime: TimeInterval = 0,
        endTime: TimeInterval = 10,
        sourceAssetID: String? = nil,
        effects: [ClipEffect] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.sourceAssetID = sourceAssetID
        self.effects = effects
    }
}

// MARK: - Clip Effect

/// A visual effect applied to a clip with tunable parameters.
struct ClipEffect: Codable, Identifiable {
    var id: String { type.rawValue }
    let type: EffectType
    var parameters: [String: Double]

    enum EffectType: String, Codable, CaseIterable {
        case colorGrade
        case blur
        case vignette
        case grain
        case lut
        case greenScreen
        case pip
    }

    init(type: EffectType, parameters: [String: Double] = [:]) {
        self.type = type
        self.parameters = parameters
    }
}

// MARK: - Aspect Ratio

/// Supported canvas aspect ratios for the editor.
enum AspectRatio: String, Codable, CaseIterable {
    case portrait9x16 = "9:16"
    case square1x1 = "1:1"
    case landscape16x9 = "16:9"
    case portrait4x5 = "4:5"
    case story = "Story"

    var displayName: String {
        switch self {
        case .portrait9x16:  return "9:16"
        case .square1x1:     return "1:1"
        case .landscape16x9: return "16:9"
        case .portrait4x5:   return "4:5"
        case .story:         return "Story"
        }
    }

    var platformHint: String {
        switch self {
        case .portrait9x16:  return "TikTok, Reels"
        case .square1x1:     return "Feed Post"
        case .landscape16x9: return "YouTube"
        case .portrait4x5:   return "Instagram Feed"
        case .story:         return "Stories"
        }
    }

    /// The width/height ratio value.
    var ratio: CGFloat {
        switch self {
        case .portrait9x16:  return 9.0 / 16.0
        case .square1x1:     return 1.0
        case .landscape16x9: return 16.0 / 9.0
        case .portrait4x5:   return 4.0 / 5.0
        case .story:         return 9.0 / 16.0
        }
    }
}

// MARK: - Text Overlay

/// A styled text element placed on the video preview at a specific time range.
struct TextOverlay: Identifiable, Codable {
    let id: UUID
    var text: String
    var fontName: String
    var fontSize: CGFloat
    var color: String           // hex color string
    var position: CGPoint
    var startTime: TimeInterval
    var endTime: TimeInterval
    var animation: TextAnimation

    init(
        id: UUID = UUID(),
        text: String = "Text",
        fontName: String = "SpaceMono-Bold",
        fontSize: CGFloat = 28,
        color: String = "#FFFFFF",
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        startTime: TimeInterval = 0,
        endTime: TimeInterval = 5,
        animation: TextAnimation = .none
    ) {
        self.id = id
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.color = color
        self.position = position
        self.startTime = startTime
        self.endTime = endTime
        self.animation = animation
    }
}

// MARK: - Text Animation

/// Animation presets for text overlays.
enum TextAnimation: String, Codable, CaseIterable {
    case none
    case fadeIn
    case typewriter
    case slideUp
    case bounce
    case glitch

    var displayName: String {
        switch self {
        case .none:       return "None"
        case .fadeIn:     return "Fade In"
        case .typewriter: return "Typewriter"
        case .slideUp:    return "Slide Up"
        case .bounce:     return "Bounce"
        case .glitch:     return "Glitch"
        }
    }

    var iconName: String {
        switch self {
        case .none:       return "textformat"
        case .fadeIn:     return "circle.dotted"
        case .typewriter: return "keyboard"
        case .slideUp:    return "arrow.up"
        case .bounce:     return "arrow.up.arrow.down"
        case .glitch:     return "waveform.path.ecg"
        }
    }
}

// MARK: - Audio Track Item

/// A music or audio element placed on the audio timeline.
struct AudioTrackItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: String
    var startTime: TimeInterval
    var volume: Float
    var fadeInDuration: TimeInterval
    var fadeOutDuration: TimeInterval
    var isMuted: Bool
    var isSoloed: Bool

    init(
        id: UUID = UUID(),
        name: String = "Audio",
        url: String = "",
        startTime: TimeInterval = 0,
        volume: Float = 1.0,
        fadeInDuration: TimeInterval = 0,
        fadeOutDuration: TimeInterval = 0,
        isMuted: Bool = false,
        isSoloed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.startTime = startTime
        self.volume = volume
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
        self.isMuted = isMuted
        self.isSoloed = isSoloed
    }

    /// Built-in placeholder tracks for the music library.
    static let builtInTracks: [AudioTrackItem] = [
        AudioTrackItem(name: "Lo-Fi Chill", url: "lofi-chill"),
        AudioTrackItem(name: "Cinematic Rise", url: "cinematic-rise"),
        AudioTrackItem(name: "Upbeat Pop", url: "upbeat-pop"),
        AudioTrackItem(name: "Ambient Texture", url: "ambient-texture"),
        AudioTrackItem(name: "Trap Beat", url: "trap-beat"),
        AudioTrackItem(name: "Acoustic Warm", url: "acoustic-warm"),
    ]
}

// MARK: - Color Grade Preset

/// A named color grading preset with shadow/midtone/highlight adjustments.
struct ColorGradePreset: Identifiable {
    let id: String
    let name: String
    let brightness: Float
    let contrast: Float
    let saturation: Float
    let temperature: Float      // -1.0 (cool) to 1.0 (warm)
    let tint: Float             // -1.0 (green) to 1.0 (magenta)
    let iconColor: Color

    static let presets: [ColorGradePreset] = [
        ColorGradePreset(id: "original", name: "Original", brightness: 0, contrast: 1.0, saturation: 1.0, temperature: 0, tint: 0, iconColor: .white),
        ColorGradePreset(id: "cinema", name: "Cinema", brightness: -0.02, contrast: 1.3, saturation: 0.85, temperature: -0.1, tint: 0.05, iconColor: Color(hex: "#4A90D9")),
        ColorGradePreset(id: "warm-glow", name: "Warm Glow", brightness: 0.05, contrast: 1.1, saturation: 1.2, temperature: 0.3, tint: 0.05, iconColor: Color(hex: "#F5A623")),
        ColorGradePreset(id: "cool-tone", name: "Cool Tone", brightness: 0, contrast: 1.15, saturation: 0.9, temperature: -0.25, tint: -0.05, iconColor: Color(hex: "#7EC8E3")),
        ColorGradePreset(id: "vintage", name: "Vintage", brightness: 0.03, contrast: 0.9, saturation: 0.7, temperature: 0.15, tint: 0.1, iconColor: Color(hex: "#D4A574")),
        ColorGradePreset(id: "high-contrast", name: "High Contrast", brightness: 0.02, contrast: 1.5, saturation: 1.1, temperature: 0, tint: 0, iconColor: .white),
        ColorGradePreset(id: "desaturated", name: "Desaturated", brightness: 0, contrast: 1.1, saturation: 0.3, temperature: 0, tint: 0, iconColor: Color(hex: "#999999")),
        ColorGradePreset(id: "neon", name: "Neon", brightness: 0.05, contrast: 1.4, saturation: 1.6, temperature: -0.1, tint: 0.15, iconColor: Color(hex: "#FF00FF")),
    ]
}

// MARK: - Drawing Tool

/// Tools for the photo editor drawing/annotation layer.
enum DrawingTool: String, CaseIterable {
    case pen
    case highlighter
    case eraser
    case arrow
    case rectangle
    case circle

    var displayName: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .pen:         return "pencil.tip"
        case .highlighter: return "highlighter"
        case .eraser:      return "eraser"
        case .arrow:       return "arrow.up.right"
        case .rectangle:   return "rectangle"
        case .circle:      return "circle"
        }
    }
}

// MARK: - Photo Export Format

/// Export formats supported by the photo editor.
enum PhotoExportFormat: String, CaseIterable {
    case png
    case jpeg
    case heic

    var displayName: String {
        rawValue.uppercased()
    }

    var fileExtension: String {
        rawValue
    }
}

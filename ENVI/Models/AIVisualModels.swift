import Foundation

// MARK: - AI Edit Type

enum AIEditType: String, Codable, CaseIterable, Identifiable {
    case backgroundRemoval
    case objectRemoval
    case styleTransfer
    case upscale
    case colorCorrection
    case faceEnhance
    case textToImage
    case imageExpand

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backgroundRemoval: return "Remove Background"
        case .objectRemoval:     return "Remove Object"
        case .styleTransfer:     return "Style Transfer"
        case .upscale:           return "Upscale"
        case .colorCorrection:   return "Color Correction"
        case .faceEnhance:       return "Face Enhance"
        case .textToImage:       return "Text to Image"
        case .imageExpand:       return "Expand Image"
        }
    }

    var iconName: String {
        switch self {
        case .backgroundRemoval: return "person.crop.rectangle"
        case .objectRemoval:     return "eraser"
        case .styleTransfer:     return "paintpalette"
        case .upscale:           return "arrow.up.left.and.arrow.down.right"
        case .colorCorrection:   return "slider.horizontal.3"
        case .faceEnhance:       return "face.smiling"
        case .textToImage:       return "text.below.photo"
        case .imageExpand:       return "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        }
    }

    var subtitle: String {
        switch self {
        case .backgroundRemoval: return "Isolate subjects cleanly"
        case .objectRemoval:     return "Erase unwanted elements"
        case .styleTransfer:     return "Apply artistic styles"
        case .upscale:           return "Enhance resolution"
        case .colorCorrection:   return "Fix lighting and colors"
        case .faceEnhance:       return "Sharpen facial details"
        case .textToImage:       return "Generate from text"
        case .imageExpand:       return "Extend image boundaries"
        }
    }
}

// MARK: - AI Edit Request

struct AIEditRequest: Encodable {
    let sourceAssetID: String
    let editType: String
    let parameters: [String: String]

    init(sourceAssetID: String, editType: AIEditType, parameters: [String: String] = [:]) {
        self.sourceAssetID = sourceAssetID
        self.editType = editType.rawValue
        self.parameters = parameters
    }
}

// MARK: - AI Edit Result

struct AIEditResult: Identifiable, Codable {
    let id: UUID
    let originalURL: URL
    let editedURL: URL
    let editType: AIEditType
    let confidence: Double
    let createdAt: Date

    init(
        id: UUID = UUID(),
        originalURL: URL,
        editedURL: URL,
        editType: AIEditType,
        confidence: Double = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.originalURL = originalURL
        self.editedURL = editedURL
        self.editType = editType
        self.confidence = confidence
        self.createdAt = createdAt
    }

    /// Formatted confidence as percentage string.
    var formattedConfidence: String {
        "\(Int(confidence * 100))%"
    }

    static let mock = AIEditResult(
        originalURL: URL(string: "https://example.com/original.jpg")!,
        editedURL: URL(string: "https://example.com/edited.jpg")!,
        editType: .backgroundRemoval,
        confidence: 0.95
    )

    static let mockList: [AIEditResult] = [
        .mock,
        AIEditResult(
            originalURL: URL(string: "https://example.com/photo2.jpg")!,
            editedURL: URL(string: "https://example.com/photo2_upscaled.jpg")!,
            editType: .upscale,
            confidence: 0.88
        ),
        AIEditResult(
            originalURL: URL(string: "https://example.com/photo3.jpg")!,
            editedURL: URL(string: "https://example.com/photo3_styled.jpg")!,
            editType: .styleTransfer,
            confidence: 0.92
        ),
    ]
}

// MARK: - Style Preset

struct StylePreset: Identifiable, Codable {
    let id: UUID
    let name: String
    let previewURL: URL
    let category: StyleCategory

    init(
        id: UUID = UUID(),
        name: String,
        previewURL: URL,
        category: StyleCategory = .artistic
    ) {
        self.id = id
        self.name = name
        self.previewURL = previewURL
        self.category = category
    }

    enum StyleCategory: String, Codable, CaseIterable, Identifiable {
        case artistic
        case photographic
        case cinematic
        case vintage
        case modern
        case abstract

        var id: String { rawValue }
        var displayName: String { rawValue.capitalized }
    }

    static let mockList: [StylePreset] = [
        StylePreset(name: "Oil Painting", previewURL: URL(string: "https://example.com/styles/oil.jpg")!, category: .artistic),
        StylePreset(name: "Watercolor", previewURL: URL(string: "https://example.com/styles/watercolor.jpg")!, category: .artistic),
        StylePreset(name: "Film Noir", previewURL: URL(string: "https://example.com/styles/noir.jpg")!, category: .cinematic),
        StylePreset(name: "Golden Hour", previewURL: URL(string: "https://example.com/styles/golden.jpg")!, category: .photographic),
        StylePreset(name: "Retro 80s", previewURL: URL(string: "https://example.com/styles/retro.jpg")!, category: .vintage),
        StylePreset(name: "Minimalist", previewURL: URL(string: "https://example.com/styles/minimal.jpg")!, category: .modern),
        StylePreset(name: "Glitch Art", previewURL: URL(string: "https://example.com/styles/glitch.jpg")!, category: .abstract),
        StylePreset(name: "Pop Art", previewURL: URL(string: "https://example.com/styles/pop.jpg")!, category: .artistic),
    ]
}

// MARK: - Generated Image

struct GeneratedImage: Identifiable, Codable {
    let id: UUID
    let prompt: String
    let imageURL: URL
    let dimensions: ImageDimensions
    let seed: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        prompt: String,
        imageURL: URL,
        dimensions: ImageDimensions = .square,
        seed: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.prompt = prompt
        self.imageURL = imageURL
        self.dimensions = dimensions
        self.seed = seed
        self.createdAt = createdAt
    }

    static let mock = GeneratedImage(
        prompt: "A serene mountain lake at sunset with vibrant reflections",
        imageURL: URL(string: "https://example.com/generated/mountain.jpg")!,
        dimensions: .square,
        seed: 42
    )

    static let mockList: [GeneratedImage] = [
        .mock,
        GeneratedImage(
            prompt: "Futuristic cityscape with neon lights and flying vehicles",
            imageURL: URL(string: "https://example.com/generated/city.jpg")!,
            dimensions: .landscape,
            seed: 1337
        ),
        GeneratedImage(
            prompt: "Abstract fluid art in deep blue and gold tones",
            imageURL: URL(string: "https://example.com/generated/abstract.jpg")!,
            dimensions: .portrait,
            seed: 256
        ),
    ]
}

// MARK: - Image Dimensions

enum ImageDimensions: String, Codable, CaseIterable, Identifiable {
    case square     = "1024x1024"
    case portrait   = "768x1024"
    case landscape  = "1024x768"
    case story      = "576x1024"
    case wide       = "1024x576"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .square:    return "Square"
        case .portrait:  return "Portrait"
        case .landscape: return "Landscape"
        case .story:     return "Story"
        case .wide:      return "Wide"
        }
    }

    var iconName: String {
        switch self {
        case .square:    return "square"
        case .portrait:  return "rectangle.portrait"
        case .landscape: return "rectangle"
        case .story:     return "rectangle.portrait"
        case .wide:      return "rectangle"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .square:    return 1.0
        case .portrait:  return 768.0 / 1024.0
        case .landscape: return 1024.0 / 768.0
        case .story:     return 576.0 / 1024.0
        case .wide:      return 1024.0 / 576.0
        }
    }
}

// MARK: - AI Visual Request Bodies

struct GenerateImageRequest: Encodable {
    let prompt: String
    let dimensions: String
}

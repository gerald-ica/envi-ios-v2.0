import Foundation

enum ExportContentKind {
    case photo
    case video
    case carousel
    case textPost

    init(contentItemType: ContentItem.ContentType) {
        switch contentItemType {
        case .photo:
            self = .photo
        case .video:
            self = .video
        case .carousel:
            self = .carousel
        case .textPost:
            self = .textPost
        }
    }

    init(contentType: ContentType) {
        switch contentType {
        case .photo, .story:
            self = .photo
        case .video, .reel:
            self = .video
        case .carousel:
            self = .carousel
        }
    }
}

struct ExportContext {
    let title: String
    let baseCaption: String
    let preferredPlatforms: [SocialPlatform]
    let kind: ExportContentKind
}

protocol ExportContextAdapter {
    var exportContext: ExportContext { get }
}

struct ContentItemExportAdapter: ExportContextAdapter {
    let item: ContentItem

    var exportContext: ExportContext {
        ExportContext(
            title: item.caption,
            baseCaption: item.bodyText ?? item.caption,
            preferredPlatforms: [item.platform],
            kind: ExportContentKind(contentItemType: item.type)
        )
    }
}

struct TemplateExportAdapter: ExportContextAdapter {
    let template: TemplateItem

    var exportContext: ExportContext {
        ExportContext(
            title: template.title,
            baseCaption: template.captionTemplate,
            preferredPlatforms: template.suggestedPlatforms,
            kind: template.contentKind
        )
    }
}

struct ContentPieceExportAdapter: ExportContextAdapter {
    let piece: ContentPiece

    var exportContext: ExportContext {
        let compactTags = piece.tags
            .prefix(2)
            .map { "#\($0.replacingOccurrences(of: " ", with: ""))" }
            .joined(separator: " ")
        let caption = compactTags.isEmpty ? piece.title : "\(piece.title) \(compactTags)"

        return ExportContext(
            title: piece.title,
            baseCaption: caption,
            preferredPlatforms: [PlatformAdapter.socialPlatform(for: piece.platform)],
            kind: ExportContentKind(contentType: piece.type)
        )
    }
}

enum PlatformAdapter {
    static func socialPlatform(for contentPlatform: ContentPlatform) -> SocialPlatform {
        switch contentPlatform {
        case .instagram:
            return .instagram
        case .tiktok:
            return .tiktok
        case .youtube:
            return .youtube
        case .twitter:
            return .x
        case .linkedin:
            return .linkedin
        }
    }
}

protocol ExportStrategy {
    var availablePlatforms: [SocialPlatform] { get }
    func initialRatio(for context: ExportContext) -> String
    func initialQuality(for context: ExportContext) -> Double
    func exportButtonTitle(for context: ExportContext) -> String
    func captionOptions(
        for context: ExportContext,
        selectedPlatforms: [SocialPlatform],
        ratio: String,
        quality: Double
    ) -> [String]
}

struct MediaExportStrategy: ExportStrategy {
    let availablePlatforms: [SocialPlatform] = [.instagram, .tiktok, .youtube, .x, .threads, .linkedin]

    func initialRatio(for context: ExportContext) -> String {
        switch context.kind {
        case .photo:
            return "4:5"
        case .video:
            return "9:16"
        case .carousel:
            return "4:5"
        case .textPost:
            return "1:1"
        }
    }

    func initialQuality(for context: ExportContext) -> Double {
        switch context.kind {
        case .video:
            return 0.9
        default:
            return 0.82
        }
    }

    func exportButtonTitle(for context: ExportContext) -> String {
        switch context.kind {
        case .video:
            return "Export Video"
        case .carousel:
            return "Export Carousel"
        case .photo:
            return "Export Post"
        case .textPost:
            return "Export Draft"
        }
    }

    func captionOptions(
        for context: ExportContext,
        selectedPlatforms: [SocialPlatform],
        ratio: String,
        quality: Double
    ) -> [String] {
        let base = context.baseCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBase = base.isEmpty ? "Fresh export from ENVI." : base
        let platformLine = selectedPlatforms.isEmpty
            ? "Built for your next post."
            : "Planned for \(selectedPlatforms.map(\.rawValue).sorted().joined(separator: ", "))."

        return [
            safeBase,
            "\(safeBase)\n\n\(platformLine)",
            "\(safeBase)\n\nLead with the strongest visual in the first beat to lift completion and saves.",
            "\(safeBase)\n\nExported in \(ratio) at \(Int(quality * 100))% quality."
        ]
    }
}

struct TextExportStrategy: ExportStrategy {
    let availablePlatforms: [SocialPlatform] = [.x, .threads, .linkedin, .instagram]

    func initialRatio(for context: ExportContext) -> String { "1:1" }
    func initialQuality(for context: ExportContext) -> Double { 0.72 }

    func exportButtonTitle(for context: ExportContext) -> String {
        switch context.preferredPlatforms.first {
        case .x:
            return "Export Tweet"
        case .threads:
            return "Export Thread"
        case .linkedin:
            return "Export Post"
        default:
            return "Export Draft"
        }
    }

    func captionOptions(
        for context: ExportContext,
        selectedPlatforms: [SocialPlatform],
        ratio: String,
        quality: Double
    ) -> [String] {
        let base = context.baseCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBase = base.isEmpty ? context.title : base
        let platformLine = selectedPlatforms.isEmpty
            ? "Drafted for your written post flow."
            : "Drafted for \(selectedPlatforms.map(\.rawValue).sorted().joined(separator: ", "))."

        return [
            safeBase,
            "\(safeBase)\n\n\(platformLine)",
            "Hook: \(context.title)\n\n\(safeBase)",
            "\(safeBase)\n\nTighten the first sentence so the opening line carries the whole post."
        ]
    }
}

struct ExportComposer {
    let context: ExportContext
    let strategy: any ExportStrategy

    var initialCaption: String {
        context.baseCaption
    }

    var preferredPlatforms: [SocialPlatform] {
        context.preferredPlatforms
    }

    var availablePlatforms: [SocialPlatform] {
        strategy.availablePlatforms
    }

    var initialRatio: String {
        strategy.initialRatio(for: context)
    }

    var initialQuality: Double {
        strategy.initialQuality(for: context)
    }

    var exportButtonTitle: String {
        strategy.exportButtonTitle(for: context)
    }

    func captionOptions(
        selectedPlatforms: [SocialPlatform],
        ratio: String,
        quality: Double
    ) -> [String] {
        strategy.captionOptions(
            for: context,
            selectedPlatforms: selectedPlatforms,
            ratio: ratio,
            quality: quality
        )
    }

    static let preview = ExportComposer(
        context: ExportContext(
            title: "Golden hour hits different in the desert",
            baseCaption: "Golden hour hits different in the desert #envi #creator",
            preferredPlatforms: [.instagram],
            kind: .photo
        ),
        strategy: MediaExportStrategy()
    )
}

enum ExportComposerFactory {
    static func make(
        contentItem: ContentItem? = nil,
        contentPiece: ContentPiece? = nil,
        template: TemplateItem? = nil
    ) -> ExportComposer {
        let context: ExportContext
        if let template {
            context = TemplateExportAdapter(template: template).exportContext
        } else if let contentItem {
            context = ContentItemExportAdapter(item: contentItem).exportContext
        } else if let contentPiece {
            context = ContentPieceExportAdapter(piece: contentPiece).exportContext
        } else {
            context = ExportContext(
                title: "ENVI Export",
                baseCaption: "Built in ENVI. Ready for your next post.",
                preferredPlatforms: [.instagram],
                kind: .photo
            )
        }

        let strategy: any ExportStrategy
        switch context.kind {
        case .textPost:
            strategy = TextExportStrategy()
        case .photo, .video, .carousel:
            strategy = MediaExportStrategy()
        }

        return ExportComposer(context: context, strategy: strategy)
    }
}

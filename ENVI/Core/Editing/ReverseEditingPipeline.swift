import SwiftUI
import Combine

// MARK: - ReverseEditingPipeline
/// Orchestrates the reverse editing flow: media analysis → template matching → rendering → approval.
///
/// Stub implementation — concrete logic lives in `MediaAnalysisEngine`,
/// `TemplateMatchingEngine`, and `ContentPieceAssembler`.
@MainActor
final class ReverseEditingPipeline: ObservableObject {

    // MARK: - Published State

    @Published var state: PipelineState = .idle
    @Published var progress: Double?
    @Published var renderedOutput: RenderedFileInfo?
    @Published var currentMatch: TemplateMatchResult?
    @Published var error: PipelineError?

    // MARK: - Actions

    func reset() {
        state = .idle
        progress = nil
        renderedOutput = nil
        currentMatch = nil
        error = nil
    }

    func cancel() {
        state = .cancelled
    }

    func start(with sources: [MediaAnalysisEngine.SourceMedia]) {
        state = .analyzing
    }
}

// MARK: - RenderProgressView
/// Simple progress view for the rendering pipeline.
struct RenderProgressView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress) {
                Text("Processing...")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: 300)
        }
        .padding()
    }
}

// MARK: - PipelineState

extension ReverseEditingPipeline {
    enum PipelineState: Equatable {
        case idle
        case analyzing
        case matching
        case rendering
        case preview
        case approved
        case rejected
        case cancelled
        case error
    }
}

// MARK: - TemplateMatchResult

extension ReverseEditingPipeline {
    struct TemplateMatchResult {
        let id: UUID
        let category: VideoTemplateCategory?
        let niche: String?
        let style: String?
        let score: Double
    }
}

// MARK: - RenderedFileInfo

extension ReverseEditingPipeline {
    struct RenderedFileInfo {
        let thumbnailURL: URL?
        let outputURL: URL?
        let fileName: String?
    }
}

// MARK: - PipelineError

extension ReverseEditingPipeline {
    enum PipelineError: LocalizedError {
        case analysisFailed(String)
        case matchingFailed(String)
        case renderFailed(String)
        case noTemplatesAvailable
        case userCancelled
        case engineNotReady

        var errorDescription: String? {
            switch self {
            case .analysisFailed(let msg): return "Analysis failed: \(msg)"
            case .matchingFailed(let msg): return "Template matching failed: \(msg)"
            case .renderFailed(let msg): return "Rendering failed: \(msg)"
            case .noTemplatesAvailable: return "No templates match your content."
            case .userCancelled: return "You cancelled the edit."
            case .engineNotReady: return "ENVI is still initializing."
            }
        }
    }
}

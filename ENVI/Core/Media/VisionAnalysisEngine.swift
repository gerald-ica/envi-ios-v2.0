import Foundation
import Vision
import CoreGraphics
import ImageIO
import AVFoundation
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

// MARK: - VisionAnalysis Result Model

/// Aggregated result of running the 9-request Vision batch on a single image
/// (or aggregated across keyframes for video). All fields are Codable so the
/// analysis can be persisted into the SwiftData `ClassificationCache` as a Data blob.
///
/// This is the pure data surface consumed by Phase 2's template-matching layer —
/// downstream code should never reach back into `Vision` types. If you need a
/// new field, add it here (Codable only) rather than leaking a `VN*` observation.
struct VisionAnalysis: Codable, Equatable {

    // MARK: Classification

    struct ClassificationLabel: Codable, Equatable {
        let identifier: String
        let confidence: Float
    }

    /// Top classification labels, confidence > 0.3, capped at 10.
    var classifications: [ClassificationLabel] = []

    // MARK: Aesthetics (iOS 18+)

    /// Overall aesthetics score in [-1, 1]. `nil` on iOS 26 when unavailable, or when request fails.
    var aestheticsScore: Float?

    /// True when Vision thinks this is "utility" content (screenshot, receipt, document).
    /// `nil` on iOS 26 when unavailable, or when request fails.
    var isUtility: Bool?

    // MARK: Faces

    struct FaceObservation: Codable, Equatable {
        /// Bounding box in Vision's normalized coordinates (origin bottom-left).
        let boundingBox: CodableRect
        /// Face capture quality in [0, 1]; `nil` if quality request yielded no result.
        var captureQuality: Float?
    }

    var faces: [FaceObservation] = []
    var faceCount: Int { faces.count }

    // MARK: Humans

    var humanBoundingBoxes: [CodableRect] = []
    var personCount: Int { humanBoundingBoxes.count }

    // MARK: Saliency

    /// Salient region's bounding box (attention-based), if detected.
    var salientRegion: CodableRect?

    // MARK: Feature Print

    /// Raw VNFeaturePrintObservation data for similarity comparisons in Phase 2.
    /// Stored in the parent SwiftData model as a separate column as well.
    var featurePrintData: Data?

    // MARK: Animals

    var animalLabels: [ClassificationLabel] = []

    // MARK: Horizon

    /// Horizon angle in radians. `nil` when the image has no detectable horizon.
    var horizonAngle: Float?

    // MARK: Meta

    /// How many frames were analyzed (1 for photos, up to 3 for video keyframes).
    var framesAnalyzed: Int = 1

    // MARK: iOS 26 additions
    //
    // Both fields are optional so existing on-disk `ClassificationCache` JSON blobs
    // (encoded without these keys) decode cleanly. Populated only when analysis runs
    // on iOS 26+; on older OSes they stay `nil` and the caller treats them as unknown.

    /// `true` when `RecognizeDocumentsRequest` returns at least one document observation.
    /// A stronger signal than `isUtility` for filtering receipts, screenshots, and
    /// scanned pages out of template suggestions. `nil` when unavailable.
    var documentDetected: Bool?

    /// `true` when `DetectCameraLensSmudgeRequest` finds a smudge with confidence > 0.5.
    /// Used to filter blurry lens-smudge photos from the template matcher. `nil` when
    /// unavailable.
    var cameraLensSmudged: Bool?
}

/// `CGRect` is not `Codable`. Use this small shim to keep `VisionAnalysis` pure-Codable.
struct CodableRect: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        self.x = Double(rect.origin.x)
        self.y = Double(rect.origin.y)
        self.width = Double(rect.size.width)
        self.height = Double(rect.size.height)
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - VisionAnalysisEngine

/// Actor that orchestrates the 9 Vision framework requests for a single image or
/// video, batched in a `TaskGroup` for maximum on-device parallelism.
///
/// Actor isolation keeps Vision's CPU/ANE workloads off the main actor. This engine
/// is stateless apart from a shared `VNSequenceRequestHandler` (not retained across
/// calls — we intentionally discard `CIImage`s and handlers once requests complete,
/// per Apple's guidance).
///
/// The engine complements `ContentAnalyzer` (see `ENVI/Core/AI/ContentAnalyzer.swift`),
/// which reads *posted* content metrics. `VisionAnalysisEngine` reads *candidate*
/// photos/videos from the camera roll and emits the metadata that downstream
/// template-matching uses to pick which asset to surface in which template slot.
///
/// API choice: we use the legacy `VN*Request` + `VNImageRequestHandler` path because
/// the deployment target is iOS 26 and the new `async` Vision request API
/// (e.g. `ClassifyImageRequest`) is iOS 18+ only. Requests are wrapped in
/// `withCheckedContinuation` and dispatched concurrently via `TaskGroup`, which
/// matches Apple's recommended batching shape. On iOS 18+ devices we additionally
/// run `VNCalculateImageAestheticsScoresRequest` for the aesthetics + isUtility
/// signals; when unavailable those fields return `nil` and the caller treats them as
/// "unknown" (fallback pipeline in Task 5 handles this).
actor VisionAnalysisEngine {

    // MARK: - Public API

    enum EngineError: Error {
        case invalidImageSource
        case videoHasNoFrames
    }

    static let shared = VisionAnalysisEngine()

    init() {}

    // MARK: Image

    /// Analyze a single image file at `url` (any format `ImageIO` understands).
    func analyzeImage(at url: URL, orientation: CGImagePropertyOrientation = .up) async throws -> VisionAnalysis {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw EngineError.invalidImageSource
        }
        return try await analyze(cgImage: cgImage, orientation: orientation)
    }

    /// Analyze raw image bytes.
    func analyzeImage(data: Data, orientation: CGImagePropertyOrientation = .up) async throws -> VisionAnalysis {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw EngineError.invalidImageSource
        }
        return try await analyze(cgImage: cgImage, orientation: orientation)
    }

    /// Analyze an already-decoded `CGImage`. Caller is responsible for lifetime —
    /// the engine will not retain this image past the function's scope.
    func analyze(cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> VisionAnalysis {
        try await runBatch(on: cgImage, orientation: orientation)
    }

    // MARK: Video

    /// Analyze a video by sampling 3 keyframes (start / middle / end) and aggregating:
    /// - classifications: union (unique identifier, max confidence per identifier)
    /// - aestheticsScore: max
    /// - isUtility: any frame utility -> true
    /// - faces / humans: max count across frames + bounding boxes from the frame with most
    /// - featurePrint: first non-nil (middle-frame preferred)
    /// - salientRegion: from middle frame
    /// - animalLabels: union
    /// - horizonAngle: first non-nil
    func analyzeVideo(at url: URL) async throws -> VisionAnalysis {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        guard totalSeconds.isFinite, totalSeconds > 0 else {
            throw EngineError.videoHasNoFrames
        }

        let samplePoints: [CMTime] = [
            .zero,
            CMTime(seconds: totalSeconds / 2.0, preferredTimescale: 600),
            CMTime(seconds: max(0, totalSeconds - 0.1), preferredTimescale: 600)
        ]

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.25, preferredTimescale: 600)

        var frameAnalyses: [VisionAnalysis] = []
        for time in samplePoints {
            do {
                let (cgImage, _) = try await generator.image(at: time)
                let analysis = try await runBatch(on: cgImage, orientation: .up)
                frameAnalyses.append(analysis)
            } catch {
                // Skip bad frames; keep going.
                continue
            }
        }

        guard !frameAnalyses.isEmpty else {
            throw EngineError.videoHasNoFrames
        }

        return aggregate(frameAnalyses)
    }

    // MARK: - Batch Runner

    /// Runs all Vision requests against `cgImage` via `BatchedVisionRequests`, which
    /// coalesces them into a single `VNImageRequestHandler.perform(_:)` call for a
    /// 1.5x+ speedup over the previous 9-handler-per-image implementation.
    ///
    /// The `CGImage` is not retained past this call — `BatchedVisionRequests.analyze`
    /// completes its handler synchronously before returning.
    private func runBatch(on cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> VisionAnalysis {
        try await BatchedVisionRequests.analyze(image: cgImage, orientation: orientation)
    }

    // MARK: - Aggregation

    private func aggregate(_ frames: [VisionAnalysis]) -> VisionAnalysis {
        var merged = VisionAnalysis()
        merged.framesAnalyzed = frames.count

        // Classifications: dedupe by identifier, keep max confidence.
        var labelMap: [String: Float] = [:]
        for frame in frames {
            for label in frame.classifications {
                labelMap[label.identifier] = max(labelMap[label.identifier] ?? 0, label.confidence)
            }
        }
        merged.classifications = labelMap
            .map { VisionAnalysis.ClassificationLabel(identifier: $0.key, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }
            .prefix(10)
            .map { $0 }

        // Aesthetics: max score; isUtility: any-true.
        merged.aestheticsScore = frames.compactMap { $0.aestheticsScore }.max()
        merged.isUtility = frames.compactMap { $0.isUtility }.contains(true)
            ? true
            : (frames.contains(where: { $0.isUtility == false }) ? false : nil)

        // Faces: pick frame with the most face observations.
        if let bestFrame = frames.max(by: { $0.faces.count < $1.faces.count }) {
            merged.faces = bestFrame.faces
        }

        // Humans: pick frame with most humans.
        if let bestFrame = frames.max(by: { $0.humanBoundingBoxes.count < $1.humanBoundingBoxes.count }) {
            merged.humanBoundingBoxes = bestFrame.humanBoundingBoxes
        }

        // Saliency: prefer middle frame (index 1) if present.
        merged.salientRegion = frames.indices.contains(1)
            ? (frames[1].salientRegion ?? frames.first?.salientRegion)
            : frames.first?.salientRegion

        // Feature print: prefer middle frame, fall back to first non-nil.
        let featurePrintCandidates: [Data?] = [
            frames.indices.contains(1) ? frames[1].featurePrintData : nil,
            frames.first?.featurePrintData,
            frames.last?.featurePrintData
        ]
        merged.featurePrintData = featurePrintCandidates.compactMap { $0 }.first

        // Animals: union with max-confidence dedupe.
        var animalMap: [String: Float] = [:]
        for frame in frames {
            for label in frame.animalLabels {
                animalMap[label.identifier] = max(animalMap[label.identifier] ?? 0, label.confidence)
            }
        }
        merged.animalLabels = animalMap
            .map { VisionAnalysis.ClassificationLabel(identifier: $0.key, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }

        // Horizon: first non-nil.
        merged.horizonAngle = frames.compactMap { $0.horizonAngle }.first

        // iOS 26 fields: any-true for document / smudge detection across keyframes.
        let docSignals = frames.compactMap { $0.documentDetected }
        merged.documentDetected = docSignals.isEmpty ? nil : docSignals.contains(true)

        let smudgeSignals = frames.compactMap { $0.cameraLensSmudged }
        merged.cameraLensSmudged = smudgeSignals.isEmpty ? nil : smudgeSignals.contains(true)

        return merged
    }
}

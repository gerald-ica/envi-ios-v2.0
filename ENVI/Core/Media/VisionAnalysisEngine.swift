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

    /// Overall aesthetics score in [-1, 1]. `nil` on iOS 17 or when request fails.
    var aestheticsScore: Float?

    /// True when Vision thinks this is "utility" content (screenshot, receipt, document).
    /// `nil` on iOS 17 or when request fails.
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
/// the deployment target is iOS 17 and the new `async` Vision request API
/// (e.g. `ClassifyImageRequest`) is iOS 18+ only. Requests are wrapped in
/// `withCheckedContinuation` and dispatched concurrently via `TaskGroup`, which
/// matches Apple's recommended batching shape. On iOS 18+ devices we additionally
/// run `VNCalculateImageAestheticsScoresRequest` for the aesthetics + isUtility
/// signals; on iOS 17 those fields return `nil` and the caller treats them as
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
                let cgImage: CGImage
                if #available(iOS 16, *) {
                    let (image, _) = try await generator.image(at: time)
                    cgImage = image
                } else {
                    cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                }
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

    /// Run all 9 Vision requests on one image, in parallel, via `TaskGroup`.
    ///
    /// Each sub-task creates its own `VNImageRequestHandler` — per Apple, handlers
    /// are cheap and are safe to use from a single queue but NOT safe to share
    /// across concurrent requests. Spawning one per task is the recommended shape.
    private func runBatch(on cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> VisionAnalysis {
        // Capture image dimensions for anything we need; don't retain the image past this function.
        let image = cgImage

        return await withTaskGroup(of: PartialResult.self) { group in

            group.addTask { await Self.runClassification(on: image, orientation: orientation) }
            group.addTask { await Self.runFaceRectangles(on: image, orientation: orientation) }
            group.addTask { await Self.runHumanRectangles(on: image, orientation: orientation) }
            group.addTask { await Self.runSaliency(on: image, orientation: orientation) }
            group.addTask { await Self.runFeaturePrint(on: image, orientation: orientation) }
            group.addTask { await Self.runAnimals(on: image, orientation: orientation) }
            group.addTask { await Self.runHorizon(on: image, orientation: orientation) }

            if #available(iOS 18.0, *) {
                group.addTask { await Self.runAesthetics(on: image, orientation: orientation) }
            }

            var analysis = VisionAnalysis()
            // Face quality runs as a follow-up: we need the face observations first.
            var pendingFaceRects: [VNFaceObservation] = []

            for await partial in group {
                switch partial {
                case .classification(let labels):
                    analysis.classifications = labels
                case .faces(let observations):
                    pendingFaceRects = observations
                    analysis.faces = observations.map {
                        VisionAnalysis.FaceObservation(boundingBox: CodableRect($0.boundingBox), captureQuality: nil)
                    }
                case .humans(let rects):
                    analysis.humanBoundingBoxes = rects.map { CodableRect($0) }
                case .saliency(let rect):
                    analysis.salientRegion = rect.map { CodableRect($0) }
                case .featurePrint(let data):
                    analysis.featurePrintData = data
                case .animals(let labels):
                    analysis.animalLabels = labels
                case .horizon(let angle):
                    analysis.horizonAngle = angle
                case .aesthetics(let score, let isUtility):
                    analysis.aestheticsScore = score
                    analysis.isUtility = isUtility
                }
            }

            // Follow-up: run DetectFaceCaptureQuality now that we have face rectangles.
            if !pendingFaceRects.isEmpty {
                let qualities = await Self.runFaceCaptureQuality(on: image, orientation: orientation, faces: pendingFaceRects)
                for (idx, quality) in qualities.enumerated() where idx < analysis.faces.count {
                    analysis.faces[idx].captureQuality = quality
                }
            }

            return analysis
        }
    }

    // MARK: - Per-request helpers

    private enum PartialResult {
        case classification([VisionAnalysis.ClassificationLabel])
        case faces([VNFaceObservation])
        case humans([CGRect])
        case saliency(CGRect?)
        case featurePrint(Data?)
        case animals([VisionAnalysis.ClassificationLabel])
        case horizon(Float?)
        case aesthetics(Float?, Bool?)
    }

    private static func makeHandler(_ image: CGImage, _ orientation: CGImagePropertyOrientation) -> VNImageRequestHandler {
        VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
    }

    private static func perform<T: VNRequest>(_ request: T, on image: CGImage, orientation: CGImagePropertyOrientation) async -> T? {
        await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            let handler = makeHandler(image, orientation)
            do {
                try handler.perform([request])
                continuation.resume(returning: request)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // 1. Classify image — top 10 labels w/ confidence > 0.3
    private static func runClassification(on image: CGImage, orientation: CGImagePropertyOrientation) async -> PartialResult {
        let request = VNClassifyImageRequest()
        guard let completed = await perform(request, on: image, orientation: orientation),
              let observations = completed.results
        else { return .classification([]) }
        let filtered = observations
            .filter { $0.confidence > 0.3 }
            .prefix(10)
            .map { VisionAnalysis.ClassificationLabel(identifier: $0.identifier, confidence: $0.confidence) }
        return .classification(Array(filtered))
    }

    // 2. Aesthetics + isUtility (iOS 18+)
    @available(iOS 18.0, *)
    private static func runAesthetics(on image: CGImage, orientation: CGImagePropertyOrientation) async -> PartialResult {
        let request = VNCalculateImageAestheticsScoresRequest()
        guard let completed = await perform(request, on: image, orientation: orientation),
              let observation = completed.results?.first as? VNImageAestheticsScoresObservation
        else { return .aesthetics(nil, nil) }
        return .aesthetics(observation.overallScore, observation.isUtility)
    }

    // 3. Face rectangles
    private static func runFaceRectangles(on image: CGImage, orientation: CGImagePropertyOrientation) async -> PartialResult {
        let request = VNDetectFaceRectanglesRequest()
        guard let completed = await perform(request, on: image, orientation: orientation),
              let observations = completed.results
        else { return .faces([]) }
        return .faces(observations)
    }

    // 4. Face capture quality (given prior face rectangles)
    private static func runFaceCaptureQuality(on image: CGImage, orientation: CGImagePropertyOrientation, faces: [VNFaceObservation]) async -> [Float?] {
        let request = VNDetectFaceCaptureQualityRequest()
        request.inputFaceObservations = faces
        guard let completed = await perform(request, on: image, orientation: orientation),
              let observations = completed.results
        else { return Array(repeating: nil, count: faces.count) }
        return observations.map { $0.faceCaptureQuality }
    }

    // 5. Human rectangles
    private static func runHumanRectangles(on image: CGImage, orientation: CGImagePropertyOrientation) async -> PartialResult {
        let request = VNDetectHumanRectanglesRequest()
        guard let completed = await perform(request, on: image, orientation: orientation),
              let observations = completed.results
        else { return .humans([]) }
        return .humans(observations.map { $0.boundingBox })
    }

    // 6. Attention-based saliency
    private static func runSaliency(on image: CGImage, orientation: CGImagePropertyOrientation) async -> PartialResult {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        guard let completed = await perform(request, on: image, orientation: orientation),
              let observation = completed.results?.first as? VNSaliencyImageObservation,
              let salientObjects = observation.salientObjects,
              let first = salientObjects.first
        else { return .saliency(nil) }
        return .saliency(first.boundingBox)
    }

    // 7. Feature print (stored as Data for similarity queries in Phase 2)
    private static func runFeaturePrint(on image: CGImage, orientation: CGImagePropertyOrientation) async -> PartialResult {
        let request = VNGenerateImageFeaturePrintRequest()
        guard let completed = await perform(request, on: image, orientation: orientation),
              let observation = completed.results?.first as? VNFeaturePrintObservation
        else { return .featurePrint(nil) }
        // VNFeaturePrintObservation.data is the raw feature vector bytes.
        return .featurePrint(observation.data)
    }

    // 8. Animal recognition
    private static func runAnimals(on image: CGImage, orientation: CGImagePropertyOrientation) async -> PartialResult {
        let request = VNRecognizeAnimalsRequest()
        guard let completed = await perform(request, on: image, orientation: orientation),
              let observations = completed.results
        else { return .animals([]) }
        let labels: [VisionAnalysis.ClassificationLabel] = observations.flatMap { obs -> [VisionAnalysis.ClassificationLabel] in
            obs.labels
                .filter { $0.confidence > 0.3 }
                .map { VisionAnalysis.ClassificationLabel(identifier: $0.identifier, confidence: $0.confidence) }
        }
        return .animals(labels)
    }

    // 9. Horizon detection
    private static func runHorizon(on image: CGImage, orientation: CGImagePropertyOrientation) async -> PartialResult {
        let request = VNDetectHorizonRequest()
        guard let completed = await perform(request, on: image, orientation: orientation),
              let observation = completed.results?.first as? VNHorizonObservation
        else { return .horizon(nil) }
        return .horizon(Float(observation.angle))
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

        return merged
    }
}

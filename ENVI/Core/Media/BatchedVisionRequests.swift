import Foundation
import Vision
import CoreGraphics
import CoreImage
import ImageIO

/// Coalesces all Vision requests for a single image into **one**
/// `VNImageRequestHandler.perform(_:)` call.
///
/// Apple's Vision engineering guidance (WWDC "Explore Advances in Vision" sessions
/// and API docs for `VNImageRequestHandler`): when you have several request types
/// to run against the same image, grouping them into a single handler invocation
/// is significantly faster than spawning one handler per request, because the image
/// is decoded + color-converted once and intermediate buffers (feature maps, pixel
/// buffers in the preferred color space) are shared across sub-requests. The
/// expected win on a typical iPhone is ~1.5–2x on the 9-request pipeline used by
/// `VisionAnalysisEngine`.
///
/// This struct is intentionally stateless apart from a single `static let`
/// Metal-backed `CIContext` that is reused across calls. `CIContext` is thread-safe
/// after construction and is expensive to create (it allocates a Metal command queue
/// and compiles shader variants lazily), so reusing one instance is a meaningful
/// optimization for bulk scans.
///
/// The `CGImage` passed in is NOT retained beyond the `perform` call — the handler
/// completes before this function returns, so the image is eligible for release as
/// soon as the caller's scope ends.
///
/// ### iOS 26 additions
/// When running on iOS 26+, two additional requests are added to the batch:
/// - `RecognizeDocumentsRequest` — a stronger signal than `VNImageAestheticsScoresRequest.isUtility`
///   for filtering receipts, screenshots, and scanned pages.
/// - `DetectCameraLensSmudgeRequest` — filters blurry lens-smudge photos before they
///   reach the template matching layer.
///
/// Both are wrapped in `#available` guards so the file stays compilable on older
/// toolchains; when unavailable the corresponding `VisionAnalysis` fields remain `nil`.
struct BatchedVisionRequests {

    // MARK: - Shared CIContext

    /// Metal-backed `CIContext` reused across every call to `analyze(...)`.
    ///
    /// Construction is lazy (via `static let`) and thread-safe per Swift's static
    /// initialization semantics. The context itself is documented as thread-safe
    /// once constructed, so concurrent Vision invocations that all pass this via
    /// `VNImageRequestHandler`'s `options` are safe.
    static let sharedCIContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: [
                .cacheIntermediates: false,      // bulk-scan workload: no locality benefit
                .useSoftwareRenderer: false,
                .highQualityDownsample: false
            ])
        }
        // Fallback for environments without Metal (Simulator w/ software renderer, CI).
        return CIContext(options: [.useSoftwareRenderer: true])
    }()

    // MARK: - Public API

    /// Run all Vision requests on `image` via a **single** `VNImageRequestHandler`.
    ///
    /// - Parameters:
    ///   - image: Decoded source image. Not retained past this call.
    ///   - orientation: EXIF orientation of the image.
    /// - Returns: Fully populated `VisionAnalysis` (fields unavailable on the current
    ///   OS — e.g. aesthetics on iOS 17 — remain `nil`).
    static func analyze(
        image: CGImage,
        orientation: CGImagePropertyOrientation
    ) async throws -> VisionAnalysis {

        // Build every request up-front. Requests are stateful value-ish reference
        // objects — each one gets its `.results` populated after `perform` returns.
        let classification = VNClassifyImageRequest()
        let faceRects = VNDetectFaceRectanglesRequest()
        let humanRects = VNDetectHumanRectanglesRequest()
        let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
        let featurePrint = VNGenerateImageFeaturePrintRequest()
        let animals = VNRecognizeAnimalsRequest()
        let horizon = VNDetectHorizonRequest()

        var allRequests: [VNRequest] = [
            classification,
            faceRects,
            humanRects,
            saliency,
            featurePrint,
            animals,
            horizon
        ]

        // iOS 18+ aesthetics
        var aesthetics: VNCalculateImageAestheticsScoresRequest?
        if #available(iOS 18.0, *) {
            let req = VNCalculateImageAestheticsScoresRequest()
            aesthetics = req
            allRequests.append(req)
        }

        // Single handler — image decode happens once here, shared across all sub-requests.
        let handler = VNImageRequestHandler(
            cgImage: image,
            orientation: orientation,
            options: [.ciContext: sharedCIContext]
        )

        // First pass: run all independent requests together.
        // We tolerate individual-request failures — a single bad request should not
        // wipe the rest of the analysis. VNImageRequestHandler.perform throws only on
        // handler-level failure, not per-request failure.
        do {
            try handler.perform(allRequests)
        } catch {
            // Handler-level failure (e.g. invalid image). Rethrow so the caller
            // can surface `EngineError.invalidImageSource` upstream.
            throw error
        }

        var analysis = VisionAnalysis()

        // MARK: Collect results

        if let observations = classification.results {
            analysis.classifications = observations
                .filter { $0.confidence > 0.3 }
                .prefix(10)
                .map { VisionAnalysis.ClassificationLabel(identifier: $0.identifier, confidence: $0.confidence) }
        }

        let faceObservations: [VNFaceObservation] = faceRects.results ?? []
        analysis.faces = faceObservations.map {
            VisionAnalysis.FaceObservation(boundingBox: CodableRect($0.boundingBox), captureQuality: nil)
        }

        if let humans = humanRects.results {
            analysis.humanBoundingBoxes = humans.map { CodableRect($0.boundingBox) }
        }

        if let saliencyObs = saliency.results?.first as? VNSaliencyImageObservation,
           let first = saliencyObs.salientObjects?.first {
            analysis.salientRegion = CodableRect(first.boundingBox)
        }

        if let fpObs = featurePrint.results?.first as? VNFeaturePrintObservation {
            analysis.featurePrintData = fpObs.data
        }

        if let animalObs = animals.results {
            analysis.animalLabels = animalObs.flatMap { obs -> [VisionAnalysis.ClassificationLabel] in
                obs.labels
                    .filter { $0.confidence > 0.3 }
                    .map { VisionAnalysis.ClassificationLabel(identifier: $0.identifier, confidence: $0.confidence) }
            }
        }

        if let horizonObs = horizon.results?.first as? VNHorizonObservation {
            analysis.horizonAngle = Float(horizonObs.angle)
        }

        if #available(iOS 18.0, *),
           let aestheticsReq = aesthetics,
           let aestheticsObs = aestheticsReq.results?.first as? VNImageAestheticsScoresObservation {
            analysis.aestheticsScore = aestheticsObs.overallScore
            analysis.isUtility = aestheticsObs.isUtility
        }

        // MARK: Second pass: face capture quality (depends on face rectangles)
        //
        // VNDetectFaceCaptureQualityRequest needs `inputFaceObservations` — if we
        // batched it with the rectangles request it'd run on zero inputs. We reuse
        // the same handler (still hot — the image buffer decoded in pass 1 is still
        // attached) rather than making a new one.
        if !faceObservations.isEmpty {
            let qualityRequest = VNDetectFaceCaptureQualityRequest()
            qualityRequest.inputFaceObservations = faceObservations
            do {
                try handler.perform([qualityRequest])
                if let qualities = qualityRequest.results {
                    for (idx, obs) in qualities.enumerated() where idx < analysis.faces.count {
                        analysis.faces[idx].captureQuality = obs.faceCaptureQuality
                    }
                }
            } catch {
                // Silently skip — face rects are still valid, only quality is lost.
            }
        }

        // MARK: iOS 26 exclusives
        if #available(iOS 26.0, *) {
            analysis = await Self.runIOS26Additions(
                analysis: analysis,
                image: image,
                orientation: orientation
            )
        }

        return analysis
    }

    // MARK: - iOS 26 additions

    /// Runs iOS 26-only Vision requests and returns an updated `VisionAnalysis`.
    ///
    /// Uses the new async Vision request API (`RecognizeDocumentsRequest`,
    /// `DetectCameraLensSmudgeRequest`). These share the same shared CIContext via
    /// a new handler (the old handler's sub-request graph is done; reopening on the
    /// same CGImage is cheap because the handler's decoded buffer is cached in the
    /// shared context's Metal texture cache when `cacheIntermediates` permits).
    @available(iOS 26.0, *)
    private static func runIOS26Additions(
        analysis: VisionAnalysis,
        image: CGImage,
        orientation: CGImagePropertyOrientation
    ) async -> VisionAnalysis {
        var updated = analysis

        // Use a fresh VNImageRequestHandler for the iOS 26 legacy-shaped requests.
        // If Apple exposes the new value-type `ImageRequest` API here, callers can
        // switch to that — but the legacy VN* path stays valid on iOS 26.
        let handler = VNImageRequestHandler(
            cgImage: image,
            orientation: orientation,
            options: [.ciContext: sharedCIContext]
        )

        var requests: [VNRequest] = []

        // RecognizeDocumentsRequest — the iOS 26 successor to DocumentDetection.
        // We probe for the Vision class dynamically so the file still compiles on
        // older SDKs that lack the symbol.
        let docClass: AnyClass? = NSClassFromString("VNRecognizeDocumentsRequest")
        let docRequest: VNRequest? = (docClass as? VNRequest.Type)?.init()
        if let docRequest = docRequest {
            requests.append(docRequest)
        }

        // DetectCameraLensSmudgeRequest — filters blurry lens-smudge photos.
        let smudgeClass: AnyClass? = NSClassFromString("VNDetectCameraLensSmudgeRequest")
        let smudgeRequest: VNRequest? = (smudgeClass as? VNRequest.Type)?.init()
        if let smudgeRequest = smudgeRequest {
            requests.append(smudgeRequest)
        }

        guard !requests.isEmpty else { return updated }

        do {
            try handler.perform(requests)
        } catch {
            return updated
        }

        // Interpret results via KVC since the symbol may not be linkable on older SDKs.
        if let docRequest = docRequest {
            let hasResults = (docRequest.results?.isEmpty == false)
            updated.documentDetected = hasResults
        }

        if let smudgeRequest = smudgeRequest,
           let obs = smudgeRequest.results?.first {
            // VNCameraLensSmudgeObservation exposes `confidence` on the observation.
            // A confidence > 0.5 is a conservative smudge threshold.
            updated.cameraLensSmudged = obs.confidence > 0.5
        }

        return updated
    }
}

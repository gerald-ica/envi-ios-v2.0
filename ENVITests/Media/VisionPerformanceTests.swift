import XCTest
import Vision
import CoreGraphics
import CoreImage
@testable import ENVI

/// Performance benchmark for Phase 6 Task 2: BatchedVisionRequests.
///
/// Compares the new single-handler path (`BatchedVisionRequests.analyze`) against
/// a cloned copy of the legacy 9-handlers-per-image serial path. The "serial"
/// baseline here runs each request in its own `VNImageRequestHandler` — the exact
/// shape of the pre-refactor `VisionAnalysisEngine` implementation — so the
/// delta in wall time is a faithful measurement of the coalescing win.
///
/// The benchmark uses 100 solid-color CGImages generated in memory (no disk IO,
/// no image decode variance) so the measurement isolates Vision's internal work
/// from file-system jitter. Solid-color images exercise the full Vision pipeline
/// (classify runs, aesthetics runs, feature print runs, saliency runs) even
/// though no faces/animals/horizons are present — the cost being measured is
/// the per-request handler overhead, which dominates the 1.5x+ win.
///
/// `XCTest.measure { }` blocks are used with the default `XCTClockMetric` so
/// Xcode records a wall-time baseline automatically. The correctness assertion
/// (`batched < 60% of serial`) runs outside the `measure` block using `Date()`
/// deltas so a single benchmark iteration decides pass/fail rather than an
/// unbounded number of `measure` iterations.
final class VisionPerformanceTests: XCTestCase {

    // MARK: - Sample dataset

    /// Produces `count` solid-color 128x128 CGImages in memory. We vary the color
    /// per image to keep Vision from hitting any obvious result-level cache.
    private func makeSampleImages(count: Int, dimension: Int = 128) -> [CGImage] {
        var images: [CGImage] = []
        images.reserveCapacity(count)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        for i in 0..<count {
            // Cycle through HSB hues to vary pixel data.
            let hue = CGFloat(i % 360) / 360.0
            let (r, g, b) = hsbToRGB(h: hue, s: 0.6, b: 0.8)

            guard let context = CGContext(
                data: nil,
                width: dimension,
                height: dimension,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                continue
            }

            context.setFillColor(red: r, green: g, blue: b, alpha: 1.0)
            context.fill(CGRect(x: 0, y: 0, width: dimension, height: dimension))

            // Add a diagonal stripe so feature-print has some variance to chew on.
            context.setFillColor(red: 1 - r, green: 1 - g, blue: 1 - b, alpha: 1.0)
            context.fill(CGRect(x: 0, y: dimension / 2, width: dimension, height: 2))

            if let cgImage = context.makeImage() {
                images.append(cgImage)
            }
        }
        return images
    }

    private func hsbToRGB(h: CGFloat, s: CGFloat, b: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let c = b * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = b - c
        let (r1, g1, b1): (CGFloat, CGFloat, CGFloat)
        switch h * 6 {
        case 0..<1: (r1, g1, b1) = (c, x, 0)
        case 1..<2: (r1, g1, b1) = (x, c, 0)
        case 2..<3: (r1, g1, b1) = (0, c, x)
        case 3..<4: (r1, g1, b1) = (0, x, c)
        case 4..<5: (r1, g1, b1) = (x, 0, c)
        default:    (r1, g1, b1) = (c, 0, x)
        }
        return (r1 + m, g1 + m, b1 + m)
    }

    // MARK: - Legacy serial path (cloned from pre-refactor VisionAnalysisEngine)
    //
    // Each request gets its own fresh VNImageRequestHandler — this is the exact
    // shape we're moving away from. Keep in sync with what `BatchedVisionRequests`
    // runs so the comparison is apples-to-apples.
    private func runSerialLegacyPath(on image: CGImage) {
        let orientation: CGImagePropertyOrientation = .up
        let requests: [VNRequest] = [
            VNClassifyImageRequest(),
            VNDetectFaceRectanglesRequest(),
            VNDetectHumanRectanglesRequest(),
            VNGenerateAttentionBasedSaliencyImageRequest(),
            VNGenerateImageFeaturePrintRequest(),
            VNRecognizeAnimalsRequest(),
            VNDetectHorizonRequest()
        ]
        for request in requests {
            let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
            _ = try? handler.perform([request])
        }
        if #available(iOS 18.0, *) {
            let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
            _ = try? handler.perform([VNCalculateImageAestheticsScoresRequest()])
        }
    }

    // MARK: - Tests

    /// Records a wall-time baseline for the batched path. Xcode's perf-baseline
    /// infra will flag regressions automatically once a baseline is set.
    func testBatchedPerformance() async throws {
        let images = makeSampleImages(count: 25)  // smaller count for measure loop
        try XCTSkipIf(images.isEmpty, "Could not generate sample images")

        measure {
            let sem = DispatchSemaphore(value: 0)
            Task {
                for image in images {
                    _ = try? await BatchedVisionRequests.analyze(image: image, orientation: .up)
                }
                sem.signal()
            }
            sem.wait()
        }
    }

    /// Compare new batched path vs. the legacy serial path over 100 images.
    /// Pass criterion: batched < 60% of serial (spec: 1.5x+ speedup, 60% budget
    /// leaves headroom for CI noise).
    func testBatchedClassifyVsSerial() async throws {
        let images = makeSampleImages(count: 100)
        try XCTSkipIf(images.count < 100, "Could not generate 100 sample images")

        // Warm up both paths — first Vision call on a process pays one-time model
        // compilation and Metal shader cost. Excluding warm-up keeps the ratio honest.
        _ = try await BatchedVisionRequests.analyze(image: images[0], orientation: .up)
        runSerialLegacyPath(on: images[0])

        // Serial baseline
        let serialStart = Date()
        for image in images {
            runSerialLegacyPath(on: image)
        }
        let serialElapsed = Date().timeIntervalSince(serialStart)

        // Batched path
        let batchedStart = Date()
        for image in images {
            _ = try? await BatchedVisionRequests.analyze(image: image, orientation: .up)
        }
        let batchedElapsed = Date().timeIntervalSince(batchedStart)

        print("[VisionPerformanceTests] serial=\(serialElapsed)s batched=\(batchedElapsed)s ratio=\(batchedElapsed / serialElapsed)")

        // The claim: batched is < 60% of serial (i.e. >= 1.67x speedup).
        // On Simulator / CI this ratio can be noisier than on-device; if we hit
        // environments where the win doesn't materialize we surface it via XCTFail
        // rather than silently pass.
        XCTAssertLessThan(
            batchedElapsed,
            serialElapsed * 0.60,
            "Expected batched path to be < 60% of serial path; got ratio \(batchedElapsed / serialElapsed)"
        )
    }
}

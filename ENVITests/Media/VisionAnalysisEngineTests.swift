import XCTest
import Vision
import CoreGraphics
import ImageIO
#if canImport(UIKit)
import UIKit
#endif
@testable import ENVI

final class VisionAnalysisEngineTests: XCTestCase {

    // MARK: - Helpers

    /// Load a bundled sample image. Walks the ENVI resource bundle as well as
    /// the plain target bundle since SwiftPM and xcodebuild produce slightly
    /// different bundle layouts for `.process(...)` resources.
    private func loadSampleCGImage(named name: String, ext: String = "jpg") throws -> CGImage {
        let candidateBundles: [Bundle] = [
            // SwiftPM generated resource bundle for the ENVI target
            Bundle(for: DummyBundleAnchor.self)
                .url(forResource: "ENVI_ENVI", withExtension: "bundle")
                .flatMap(Bundle.init(url:)) ?? Bundle(for: DummyBundleAnchor.self),
            Bundle.main,
            Bundle(for: DummyBundleAnchor.self)
        ]

        for bundle in candidateBundles {
            // Try directly, then inside Images/ subdirectory.
            if let url = bundle.url(forResource: name, withExtension: ext)
                ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "Images") {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    continue
                }
                return cgImage
            }
        }
        throw XCTSkip("Sample image \(name).\(ext) not found in any accessible bundle.")
    }

    private final class DummyBundleAnchor {}

    // MARK: - Tests

    func testAnalyzeFoodImage_detectsFoodLabelAndRuns() async throws {
        let cgImage = try loadSampleCGImage(named: "culture-food")

        let engine = VisionAnalysisEngine()
        let analysis = try await engine.analyze(cgImage: cgImage, orientation: .up)

        // The classifier should return at least one confident label.
        XCTAssertFalse(analysis.classifications.isEmpty, "Expected at least one classification label for the food image.")

        // Expect a food-related label to surface with confidence > 0.3. We accept any of the
        // synonyms Vision's taxonomy tends to use for prepared-food photos.
        let foodSynonyms: Set<String> = [
            "food", "meal", "dish", "cuisine", "snack", "breakfast", "lunch", "dinner",
            "dessert", "fruit", "vegetable", "drink", "beverage"
        ]
        let hasFoodLabel = analysis.classifications.contains { label in
            foodSynonyms.contains { label.identifier.lowercased().contains($0) }
        }
        XCTAssertTrue(
            hasFoodLabel,
            "Expected a food-related label in classifications; got: \(analysis.classifications.map { $0.identifier })"
        )

        // All surviving classifications must be > 0.3 confidence (the engine filters these).
        for label in analysis.classifications {
            XCTAssertGreaterThan(label.confidence, 0.3, "Classification \(label.identifier) below threshold")
        }
        XCTAssertLessThanOrEqual(analysis.classifications.count, 10, "Classifications capped at 10")

        // Feature print should populate.
        XCTAssertNotNil(analysis.featurePrintData, "Expected a VNFeaturePrintObservation data blob")
        XCTAssertGreaterThan(analysis.featurePrintData?.count ?? 0, 0)

        // On iOS 18+ we should also get an aesthetics score != nil. On iOS 17 it's nil by design.
        if #available(iOS 18.0, *) {
            XCTAssertNotNil(analysis.aestheticsScore, "iOS 18+ should return an aesthetics score")
            if let score = analysis.aestheticsScore {
                XCTAssertTrue((-1.0...1.0).contains(score), "Aesthetics score out of bounds: \(score)")
            }
        }

        XCTAssertEqual(analysis.framesAnalyzed, 1)
    }

    func testVisionAnalysisIsCodable() throws {
        var analysis = VisionAnalysis()
        analysis.classifications = [
            .init(identifier: "food", confidence: 0.91),
            .init(identifier: "meal", confidence: 0.55)
        ]
        analysis.aestheticsScore = 0.42
        analysis.isUtility = false
        analysis.faces = [
            .init(boundingBox: CodableRect(CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)), captureQuality: 0.77)
        ]
        analysis.humanBoundingBoxes = [CodableRect(CGRect(x: 0, y: 0, width: 1, height: 1))]
        analysis.salientRegion = CodableRect(CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
        analysis.featurePrintData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        analysis.animalLabels = [.init(identifier: "dog", confidence: 0.88)]
        analysis.horizonAngle = 0.02
        analysis.framesAnalyzed = 3

        let encoded = try JSONEncoder().encode(analysis)
        let decoded = try JSONDecoder().decode(VisionAnalysis.self, from: encoded)

        XCTAssertEqual(analysis, decoded)
    }

    func testAnalyzeHandlesSyntheticImageWithoutCrashing() async throws {
        // Solid color image — Vision requests should complete without throwing,
        // even if most observations are empty.
        let size = CGSize(width: 256, height: 256)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create bitmap context")
            return
        }
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        context.fill(CGRect(origin: .zero, size: size))
        guard let cgImage = context.makeImage() else {
            XCTFail("Could not create CGImage")
            return
        }

        let engine = VisionAnalysisEngine()
        let analysis = try await engine.analyze(cgImage: cgImage, orientation: .up)
        XCTAssertEqual(analysis.framesAnalyzed, 1)
        // Classifications list is allowed to be empty on a flat gray image.
        XCTAssertNotNil(analysis)
    }
}

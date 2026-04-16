//
//  VideoTemplateModelsTests.swift
//  ENVITests
//
//  Phase 3, Task 1 of Template Tab v1 — smoke tests for the data model.
//
//  Covers:
//    - `testMockLibraryHas5Templates`: sanity-check the seeded catalog.
//    - `testVideoTemplateCodableRoundTrip`: encode mockLibrary[0] → JSON →
//      decode → assert round-trip equality via Equatable conformance.
//    - `testMediaRequirementsFilters`: instantiate a MediaRequirements
//      with every filter set (including associated-value enums) and
//      verify full JSON round-trip.
//

import XCTest
@testable import ENVI

final class VideoTemplateModelsTests: XCTestCase {

    // MARK: - Library sanity

    func testMockLibraryHas5Templates() {
        let library = VideoTemplate.mockLibrary
        XCTAssertEqual(library.count, 5, "mockLibrary should seed 5 templates")

        // All 5 categories should be distinct and cover the core mix.
        let categories = Set(library.map(\.category))
        XCTAssertEqual(categories.count, 5, "Mock library should use 5 distinct categories")
        XCTAssertTrue(categories.contains(.grwm))
        XCTAssertTrue(categories.contains(.cooking))
        XCTAssertTrue(categories.contains(.ootd))
        XCTAssertTrue(categories.contains(.travel))
        XCTAssertTrue(categories.contains(.fitness))

        // Every template has at least one slot, a non-empty name, and a
        // portrait aspect (all mocks are vertical reel-shaped).
        for template in library {
            XCTAssertFalse(template.name.isEmpty)
            XCTAssertFalse(template.slots.isEmpty)
            XCTAssertEqual(template.aspectRatio, .portrait9x16)
            XCTAssertGreaterThan(template.popularity, 0)
        }
    }

    // MARK: - Codable

    func testVideoTemplateCodableRoundTrip() throws {
        let original = VideoTemplate.mockLibrary[0]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VideoTemplate.self, from: data)

        XCTAssertEqual(original, decoded,
                       "VideoTemplate should survive JSON round-trip losslessly")

        // Second-pass re-encode should produce byte-identical output
        // (deterministic encoding with sortedKeys).
        let reEncoded = try encoder.encode(decoded)
        XCTAssertEqual(data, reEncoded,
                       "Re-encoding a decoded template should be byte-identical")
    }

    func testAllMockTemplatesCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for template in VideoTemplate.mockLibrary {
            let data = try encoder.encode(template)
            let decoded = try decoder.decode(VideoTemplate.self, from: data)
            XCTAssertEqual(template, decoded, "\(template.name) round-trip failed")
        }
    }

    // MARK: - MediaRequirements (every filter set)

    func testMediaRequirementsFilters() throws {
        let requirements = MediaRequirements(
            acceptedMediaTypes: [.photo, .video, .livePhoto],
            preferredLabels: ["food", "indoor", "plated"],
            excludedLabels: ["screenshot", "document"],
            preferredOrientation: .portrait,
            minimumAestheticsScore: 0.15,
            requireNonUtility: true,
            preferredFaceCount: .exactly(2),
            preferredPersonCount: .group,
            durationRange: MediaRequirements.DurationRange(lowerBound: 2.5, upperBound: 12.0),
            requireSubtypes: [.cinematic, .depthEffect],
            excludeSubtypes: [.screenshot, .panorama, .slomo],
            recencyPreference: .recent7Days
        )

        let data = try JSONEncoder().encode(requirements)
        let decoded = try JSONDecoder().decode(MediaRequirements.self, from: data)

        XCTAssertEqual(requirements, decoded,
                       "MediaRequirements with every filter set should round-trip")

        // Spot-check associated-value enum decoding specifically, since
        // these are the custom-Codable paths.
        XCTAssertEqual(decoded.preferredFaceCount, .exactly(2))
        XCTAssertEqual(decoded.preferredPersonCount, .group)
        XCTAssertEqual(decoded.durationRange?.lowerBound, 2.5)
        XCTAssertEqual(decoded.durationRange?.upperBound, 12.0)
    }

    func testFaceCountFilterAllCasesRoundTrip() throws {
        let cases: [FaceCountFilter] = [.none, .exactly(0), .exactly(3), .group, .any]
        for value in cases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(FaceCountFilter.self, from: data)
            XCTAssertEqual(value, decoded, "FaceCountFilter \(value) failed round-trip")
        }
    }

    func testPersonCountFilterAllCasesRoundTrip() throws {
        let cases: [PersonCountFilter] = [.none, .exactly(1), .exactly(5), .group, .any]
        for value in cases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(PersonCountFilter.self, from: data)
            XCTAssertEqual(value, decoded, "PersonCountFilter \(value) failed round-trip")
        }
    }
}

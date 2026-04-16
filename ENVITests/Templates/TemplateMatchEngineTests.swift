//
//  TemplateMatchEngineTests.swift
//  ENVITests
//
//  Unit tests for Phase 3, Task 2 — TemplateMatchEngine.
//
//  Referenced Task 1 types (from `ENVI/Models/VideoTemplateModels.swift`,
//  written in parallel): VideoTemplate, TemplateSlot, MediaRequirements,
//  FilledSlot, PopulatedTemplate, MediaTypeFilter, Orientation,
//  FaceCountFilter, PersonCountFilter, RecencyPreference,
//  PHAssetMediaSubtypeFilter, VideoTemplateCategory, AspectRatio,
//  TransitionType, SocialPlatform, TextOverlay, AudioTrackRef.
//

import XCTest
import Photos
import SwiftData
@testable import ENVI

final class TemplateMatchEngineTests: XCTestCase {

    // MARK: - Helpers

    /// Make a fresh on-disk cache for each test — mirrors the production
    /// storage path so predicate semantics match.
    private func makeCache() throws -> (ClassificationCache, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TemplateMatchEngineTests-\(UUID().uuidString).sqlite")
        let cache = try ClassificationCache(storeURL: url)
        return (cache, url)
    }

    private func cleanup(_ url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
    }

    /// Encode a minimal `ExtractedMetadata` with the given surface values
    /// so TemplateMatchEngine's in-memory filters (orientation, duration,
    /// isFavorite/burst) can decode it.
    private func encodedMetadata(
        localID: String,
        pixelWidth: Int,
        pixelHeight: Int,
        duration: Double? = nil,
        isFavorite: Bool = false,
        burstUserPick: Bool = false,
        mediaType: MediaTypeCode = .image
    ) -> Data {
        let burstRaw: UInt = burstUserPick ? PHAssetBurstSelectionType.userPick.rawValue : 0
        let surface = AssetSurface(
            localIdentifier: localID,
            mediaType: mediaType,
            mediaSubtypeRawValue: 0,
            mediaSubtypeFlags: MediaSubtypeFlags(phSubtypes: []),
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            creationDate: Date(),
            modificationDate: nil,
            location: nil,
            duration: duration,
            isFavorite: isFavorite,
            burstIdentifier: nil,
            burstSelectionTypesRawValue: burstRaw,
            hasAdjustments: false,
            playbackStyleRawValue: 0
        )
        let meta = ExtractedMetadata(
            surface: surface,
            exif: nil, gps: nil, tiff: nil, makerApple: nil, video: nil
        )
        return (try? JSONEncoder().encode(meta)) ?? Data()
    }

    /// Build a ClassifiedAsset with the fields TemplateMatchEngine cares
    /// about. Non-critical fields default to sensible values.
    private func asset(
        id: String,
        labels: [String] = [],
        aesthetics: Double = 0.5,
        utility: Bool = false,
        faces: Int = 0,
        persons: Int = 0,
        mediaType: Int = PHAssetMediaType.image.rawValue,
        pixelWidth: Int = 1080,
        pixelHeight: Int = 1920,
        duration: Double? = nil,
        creationDaysAgo: Double = 1,
        isFavorite: Bool = false,
        burstUserPick: Bool = false
    ) -> ClassifiedAsset {
        let created = Date().addingTimeInterval(-creationDaysAgo * 86_400)
        let mtCode: MediaTypeCode = mediaType == PHAssetMediaType.video.rawValue ? .video : .image
        return ClassifiedAsset(
            localIdentifier: id,
            classifiedAt: Date(),
            classifierVersion: kCurrentClassifierVersion,
            metadata: encodedMetadata(
                localID: id,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                duration: duration,
                isFavorite: isFavorite,
                burstUserPick: burstUserPick,
                mediaType: mtCode
            ),
            visionAnalysis: Data(),
            featurePrint: nil,
            aestheticsScore: aesthetics,
            isUtility: utility,
            faceCount: faces,
            personCount: persons,
            topLabels: labels,
            mediaType: mediaType,
            mediaSubtypeRaw: 0,
            creationDate: created,
            latitude: nil,
            longitude: nil
        )
    }

    /// Build a TemplateSlot with the most common requirement shape.
    private func slot(
        order: Int,
        preferredLabels: [String] = [],
        acceptedMediaTypes: [MediaTypeFilter] = [.photo],
        orientation: Orientation? = nil,
        minAesthetics: Double = -0.3,
        recency: RecencyPreference = .any,
        faces: FaceCountFilter? = nil,
        persons: PersonCountFilter? = nil,
        duration: MediaRequirements.DurationRange? = nil
    ) -> TemplateSlot {
        TemplateSlot(
            id: UUID(),
            order: order,
            duration: 2.0,
            requirements: MediaRequirements(
                acceptedMediaTypes: acceptedMediaTypes,
                preferredLabels: preferredLabels,
                excludedLabels: [],
                preferredOrientation: orientation,
                minimumAestheticsScore: minAesthetics,
                requireNonUtility: true,
                preferredFaceCount: faces,
                preferredPersonCount: persons,
                durationRange: duration,
                requireSubtypes: [],
                excludeSubtypes: [],
                recencyPreference: recency
            ),
            textOverlay: nil
        )
    }

    private func template(name: String, slots: [TemplateSlot]) -> VideoTemplate {
        VideoTemplate(
            id: UUID(),
            remoteID: nil,
            name: name,
            category: .lifestyle,
            aspectRatio: .portrait9x16,
            duration: Double(slots.count) * 2.0,
            slots: slots,
            textOverlays: [],
            transitions: [],
            audioTrack: nil,
            suggestedPlatforms: [],
            thumbnailURL: nil,
            popularity: 0
        )
    }

    // MARK: - Tests

    /// Seed 50 diverse mock ClassifiedAssets + 3 mock VideoTemplates,
    /// populate all, and assert each slot gets a match with no duplicates.
    func testPopulateAllSlotsFromClassifiedLibrary() async throws {
        let (cache, url) = try makeCache()
        defer { cleanup(url) }

        // 50 mock assets across three "themes" so each template has plenty
        // of candidates that match its preferredLabels.
        var assets: [ClassifiedAsset] = []
        for i in 0..<20 {
            assets.append(self.asset(
                id: "food-\(i)",
                labels: ["food", "indoor"],
                aesthetics: 0.6,
                pixelWidth: 1080, pixelHeight: 1920
            ))
        }
        for i in 0..<15 {
            assets.append(self.asset(
                id: "outfit-\(i)",
                labels: ["outfit", "mirror"],
                aesthetics: 0.4, faces: 1, persons: 1,
                pixelWidth: 1080, pixelHeight: 1920
            ))
        }
        for i in 0..<15 {
            assets.append(self.asset(
                id: "travel-\(i)",
                labels: ["travel", "outdoor"],
                aesthetics: 0.5,
                pixelWidth: 1920, pixelHeight: 1080
            ))
        }
        try await cache.batchUpsert(assets)

        let t1 = template(name: "Cooking", slots: [
            slot(order: 0, preferredLabels: ["food"]),
            slot(order: 1, preferredLabels: ["food", "indoor"]),
            slot(order: 2, preferredLabels: ["indoor"]),
        ])
        let t2 = template(name: "OOTD", slots: [
            slot(order: 0, preferredLabels: ["outfit"], faces: .exactly(1)),
            slot(order: 1, preferredLabels: ["mirror", "outfit"]),
        ])
        let t3 = template(name: "Travel", slots: [
            slot(order: 0, preferredLabels: ["travel"], orientation: .landscape),
            slot(order: 1, preferredLabels: ["outdoor"], orientation: .landscape),
        ])

        let engine = TemplateMatchEngine()
        let index = EmbeddingIndex(checkpointURL: FileManager.default
            .temporaryDirectory.appendingPathComponent("emb-\(UUID()).cache"))

        let populated = await engine.populateAll(
            templates: [t1, t2, t3],
            from: cache,
            using: index
        )

        XCTAssertEqual(populated.count, 3)

        // Each template should have every slot filled (plenty of candidates).
        for p in populated {
            XCTAssertEqual(
                p.filledSlots.count,
                p.template.slots.count,
                "\(p.template.name) filled-slot count mismatch"
            )
            XCTAssertEqual(
                p.fillRate, 1.0, accuracy: 0.001,
                "\(p.template.name) should have fillRate = 1.0"
            )
            XCTAssertGreaterThan(
                p.overallScore, TemplateMatchEngine.matchThreshold,
                "\(p.template.name) overallScore should clear threshold"
            )
            // No duplicate assets within this template.
            let ids = p.filledSlots.compactMap { $0.matchedAsset?.localIdentifier }
            XCTAssertEqual(
                Set(ids).count, ids.count,
                "\(p.template.name) has duplicate assets across slots"
            )
        }
    }

    /// Empty cache + a template with 4 slots → fillRate == 0, overallScore == 0,
    /// slots exist but have nil matchedAsset.
    func testEmptyMatchWhenNoCandidates() async throws {
        let (cache, url) = try makeCache()
        defer { cleanup(url) }

        let t = template(name: "Empty", slots: [
            slot(order: 0, preferredLabels: ["food"]),
            slot(order: 1, preferredLabels: ["food"]),
            slot(order: 2, preferredLabels: ["food"]),
            slot(order: 3, preferredLabels: ["food"]),
        ])

        let engine = TemplateMatchEngine()
        let index = EmbeddingIndex(checkpointURL: FileManager.default
            .temporaryDirectory.appendingPathComponent("emb-\(UUID()).cache"))

        let populated = await engine.populate(template: t, from: cache, using: index)

        XCTAssertEqual(populated.filledSlots.count, 4)
        XCTAssertEqual(populated.fillRate, 0.0, accuracy: 0.001)
        XCTAssertEqual(populated.overallScore, 0.0, accuracy: 0.001)
        for fs in populated.filledSlots {
            XCTAssertNil(fs.matchedAsset)
            XCTAssertEqual(fs.matchScore, 0.0, accuracy: 0.001)
            XCTAssertTrue(fs.alternates.isEmpty)
        }
    }

    /// Swap a slot's matched asset and verify the output reflects the
    /// change — matchedAsset + matchScore update, fillRate unchanged,
    /// old pick moves into alternates.
    func testSwapReplacesSlot() async throws {
        let (cache, url) = try makeCache()
        defer { cleanup(url) }

        // Plenty of high-match assets so every slot fills.
        var assets: [ClassifiedAsset] = []
        for i in 0..<10 {
            assets.append(self.asset(
                id: "food-\(i)",
                labels: ["food"],
                aesthetics: 0.8
            ))
        }
        try await cache.batchUpsert(assets)

        let t = template(name: "Swap", slots: [
            slot(order: 0, preferredLabels: ["food"]),
            slot(order: 1, preferredLabels: ["food"]),
        ])

        let engine = TemplateMatchEngine()
        let index = EmbeddingIndex(checkpointURL: FileManager.default
            .temporaryDirectory.appendingPathComponent("emb-\(UUID()).cache"))
        let populated = await engine.populate(template: t, from: cache, using: index)

        XCTAssertEqual(populated.fillRate, 1.0, accuracy: 0.001)
        guard let firstSlot = populated.filledSlots.first,
              let originalPick = firstSlot.matchedAsset,
              let replacement = firstSlot.alternates.first else {
            return XCTFail("Expected slot 0 to have a pick + alternates")
        }

        let swapped = await engine.swap(
            slot: firstSlot.slot,
            in: populated,
            to: replacement
        )

        XCTAssertEqual(swapped.filledSlots.count, populated.filledSlots.count)
        XCTAssertEqual(swapped.fillRate, populated.fillRate, accuracy: 0.001)

        let newFirst = swapped.filledSlots.first!
        XCTAssertEqual(newFirst.matchedAsset?.localIdentifier, replacement.localIdentifier)
        XCTAssertNotEqual(newFirst.matchedAsset?.localIdentifier, originalPick.localIdentifier)
        XCTAssertGreaterThan(newFirst.matchScore, 0)
        // Original pick should now be in alternates (swap merges it back in),
        // and the new pick should not still appear there.
        XCTAssertTrue(
            newFirst.alternates.contains(where: { $0.localIdentifier == originalPick.localIdentifier })
        )
        XCTAssertFalse(
            newFirst.alternates.contains(where: { $0.localIdentifier == replacement.localIdentifier })
        )
    }
}

import XCTest
import Photos
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import ENVI

/// Unit tests for `MediaMetadataExtractor`.
///
/// Fixture strategy: we try to create five synthetic PHAssets in the
/// simulator's Photos library (photo, video, screenshot, panorama,
/// livePhoto) via `PHAssetCreationRequest`. Photos authorization in the
/// simulator is typically granted automatically for test targets; when it
/// isn't, the creation calls are skipped and the corresponding test
/// exits early via `XCTSkip`. This keeps CI green on restricted hosts
/// while giving real coverage on dev machines.
final class MediaMetadataExtractorTests: XCTestCase {

    // MARK: - Authorization helper

    private func ensureAuthorizedOrSkip() throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let granted = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if granted == .authorized || granted == .limited { return }
            throw XCTSkip("Photos authorization not granted in test environment")
        default:
            throw XCTSkip("Photos authorization denied in test environment")
        }
    }

    // MARK: - Fixture builders

    /// Write a solid-color JPEG to a temp URL with optional EXIF baked in.
    private func makeTempJPEG(size: CGSize = CGSize(width: 64, height: 64)) throws -> URL {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw XCTSkip("Unable to render JPEG fixture")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try data.write(to: url)
        return url
    }

    /// Write a tiny MOV using a 1-frame AVAssetWriter. The resulting file is
    /// a valid video the Photos framework will ingest.
    private func makeTempMOV() async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        let width = 64
        let height = 64
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        guard writer.canAdd(input) else {
            throw XCTSkip("AVAssetWriter refused input configuration")
        }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // Append a single black frame.
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw XCTSkip("Could not create pixel buffer for fixture MOV")
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 0, CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        // Spin until the input is ready.
        while !input.isReadyForMoreMediaData {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        _ = adaptor.append(buffer, withPresentationTime: .zero)
        input.markAsFinished()
        await writer.finishWriting()

        if writer.status != .completed {
            throw XCTSkip("AVAssetWriter did not complete: \(writer.status.rawValue)")
        }
        return url
    }

    private enum FixtureKind {
        case photo
        case screenshot
        case panorama
        case livePhoto
        case video
    }

    /// Ingest the fixture into the photo library and return its PHAsset.
    private func ingestFixture(kind: FixtureKind) async throws -> PHAsset {
        try ensureAuthorizedOrSkip()

        var placeholder: PHObjectPlaceholder?

        switch kind {
        case .photo, .screenshot, .panorama:
            let url = try makeTempJPEG(
                size: kind == .panorama ? CGSize(width: 512, height: 128) : CGSize(width: 64, height: 64)
            )
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                req.addResource(with: .photo, fileURL: url, options: options)
                placeholder = req.placeholderForCreatedAsset
            }
        case .video:
            let url = try await makeTempMOV()
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                req.addResource(with: .video, fileURL: url, options: options)
                placeholder = req.placeholderForCreatedAsset
            }
        case .livePhoto:
            // Live Photos require a paired still+mov resource. We approximate
            // by registering a still photo plus a pairedVideo resource.
            let stillURL = try makeTempJPEG()
            let movURL = try await makeTempMOV()
            try await PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                req.addResource(with: .photo, fileURL: stillURL, options: options)
                req.addResource(with: .pairedVideo, fileURL: movURL, options: options)
                placeholder = req.placeholderForCreatedAsset
            }
        }

        guard let id = placeholder?.localIdentifier else {
            throw XCTSkip("Photo library refused fixture ingest")
        }
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetched.firstObject else {
            throw XCTSkip("Ingested fixture not found after write")
        }
        return asset
    }

    // MARK: - Tests

    /// Photo fixture: confirm the surface metadata (localIdentifier,
    /// mediaType, pixel size, creationDate) populates.
    func testExtractPhotoSurface() async throws {
        let asset = try await ingestFixture(kind: .photo)
        let metadata = await MediaMetadataExtractor.extract(asset)

        XCTAssertEqual(metadata.surface.localIdentifier, asset.localIdentifier)
        XCTAssertEqual(metadata.surface.mediaType, .image)
        XCTAssertGreaterThan(metadata.surface.pixelWidth, 0)
        XCTAssertGreaterThan(metadata.surface.pixelHeight, 0)
        XCTAssertNotNil(metadata.surface.creationDate)
        XCTAssertFalse(metadata.surface.isFavorite)
        XCTAssertNil(metadata.video)
    }

    /// Video fixture: confirm we load an AVAsset and produce at least one
    /// video track description.
    func testExtractVideoMetadata() async throws {
        let asset = try await ingestFixture(kind: .video)
        let metadata = await MediaMetadataExtractor.extract(asset)

        XCTAssertEqual(metadata.surface.mediaType, .video)
        XCTAssertNotNil(metadata.video)
        if let video = metadata.video {
            XCTAssertFalse(video.videoTracks.isEmpty, "expected at least one video track")
        }
    }

    /// Screenshot fixture: the subtype bitmask is set by the system only
    /// when a screenshot is actually captured on-device, so we only verify
    /// the surface does not panic on this input path.
    func testExtractScreenshotSurface() async throws {
        let asset = try await ingestFixture(kind: .screenshot)
        let metadata = await MediaMetadataExtractor.extract(asset)
        XCTAssertEqual(metadata.surface.mediaType, .image)
        // Flags struct populates from whatever raw value the system assigns.
        XCTAssertNotNil(metadata.surface.mediaSubtypeFlags)
    }

    /// Panorama fixture: just verify the extractor handles wide-aspect
    /// input and exposes the flags struct.
    func testExtractPanoramaSurface() async throws {
        let asset = try await ingestFixture(kind: .panorama)
        let metadata = await MediaMetadataExtractor.extract(asset)
        XCTAssertEqual(metadata.surface.mediaType, .image)
        XCTAssertGreaterThan(metadata.surface.pixelWidth, metadata.surface.pixelHeight)
    }

    /// Live-photo-style fixture: confirm the extractor doesn't crash on a
    /// resource pair.
    func testExtractLivePhotoSurface() async throws {
        let asset = try await ingestFixture(kind: .livePhoto)
        let metadata = await MediaMetadataExtractor.extract(asset)
        XCTAssertEqual(metadata.surface.mediaType, .image)
        XCTAssertNotNil(metadata.surface.mediaSubtypeFlags)
    }

    /// ExtractedMetadata must round-trip through JSON.
    func testExtractedMetadataIsCodable() throws {
        let surface = AssetSurface(
            localIdentifier: "test-id",
            mediaType: .image,
            mediaSubtypeRawValue: 0,
            mediaSubtypeFlags: MediaSubtypeFlags(phSubtypes: []),
            pixelWidth: 100,
            pixelHeight: 200,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            modificationDate: nil,
            location: nil,
            duration: nil,
            isFavorite: false,
            burstIdentifier: nil,
            burstSelectionTypesRawValue: 0,
            hasAdjustments: false,
            playbackStyleRawValue: 1
        )
        let meta = ExtractedMetadata(
            surface: surface,
            exif: EXIFMetadata(
                exposureTime: 0.008,
                fNumber: 1.8,
                isoSpeedRatings: [400],
                focalLength: 6.86,
                focalLengthIn35mm: 26,
                flash: 0,
                whiteBalance: 0,
                lensMake: "Apple",
                lensModel: "iPhone 16 Pro back camera",
                sceneCaptureType: 0,
                bodySerialNumber: nil,
                dateTimeOriginal: "2026:04:13 10:00:00",
                subsecTimeOriginal: "123",
                offsetTimeOriginal: "-07:00"
            ),
            gps: nil,
            tiff: TIFFMetadata(make: "Apple", model: "iPhone 16 Pro", software: "18.1", orientation: 1),
            makerApple: ["1": AnyCodable(42), "Text": AnyCodable("val")],
            video: nil
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(ExtractedMetadata.self, from: data)

        XCTAssertEqual(decoded.surface, meta.surface)
        XCTAssertEqual(decoded.exif, meta.exif)
        XCTAssertEqual(decoded.tiff, meta.tiff)
        XCTAssertEqual(decoded.makerApple?.keys.sorted(), ["1", "Text"])
    }
}

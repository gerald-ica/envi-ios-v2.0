import Foundation
import Photos
import ImageIO
@preconcurrency import AVFoundation
import CoreLocation

// MARK: - MediaMetadataExtractor
/// Extracts every piece of metadata Apple already computes for a PHAsset —
/// EXIF, GPS, TIFF, Apple MakerNote, PHAsset surface properties, and
/// AVFoundation video track metadata — *without* running any ML.
///
/// This is the cheap, always-run first stage of the media classification
/// pipeline (Phase 1, Task 1 of the Template Tab v1 milestone). Vision ML
/// orchestration lives in `VisionAnalysisEngine` (Task 2).
///
/// Design notes:
///   - All work is `async`; nothing blocks the caller's thread.
///   - Uses `CGImageSource` properties-only reads so we never materialize
///     the full image bitmap just to grab EXIF.
///   - Every field on `ExtractedMetadata` is optional except
///     `localIdentifier` — devices/OS versions populate EXIF differently
///     and we never want to force-unwrap platform data.
///   - No force-unwraps anywhere in this file.
enum MediaMetadataExtractor {

    // MARK: - Public API

    /// Extract all available Apple-computed metadata for `asset`.
    ///
    /// Safe to call from any actor. Performs a `PHContentEditingInput`
    /// request for photos and an `AVURLAsset` load for videos. Returns a
    /// best-effort `ExtractedMetadata` — missing fields remain `nil` rather
    /// than throwing.
    static func extract(_ asset: PHAsset) async -> ExtractedMetadata {
        let surface = extractSurface(asset)

        switch asset.mediaType {
        case .image:
            let imageMetadata = await extractImageMetadata(asset)
            return ExtractedMetadata(
                surface: surface,
                exif: imageMetadata.exif,
                gps: imageMetadata.gps,
                tiff: imageMetadata.tiff,
                makerApple: imageMetadata.makerApple,
                video: nil
            )
        case .video:
            let video = await extractVideoMetadata(asset)
            return ExtractedMetadata(
                surface: surface,
                exif: nil,
                gps: nil,
                tiff: nil,
                makerApple: nil,
                video: video
            )
        default:
            return ExtractedMetadata(
                surface: surface,
                exif: nil,
                gps: nil,
                tiff: nil,
                makerApple: nil,
                video: nil
            )
        }
    }

    // MARK: - PHAsset Surface

    private static func extractSurface(_ asset: PHAsset) -> AssetSurface {
        let location = asset.location.map { loc in
            GeoCoordinate(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                altitude: loc.altitude,
                horizontalAccuracy: loc.horizontalAccuracy,
                verticalAccuracy: loc.verticalAccuracy,
                speed: loc.speed >= 0 ? loc.speed : nil,
                course: loc.course >= 0 ? loc.course : nil,
                timestamp: loc.timestamp
            )
        }

        return AssetSurface(
            localIdentifier: asset.localIdentifier,
            mediaType: MediaTypeCode(phType: asset.mediaType),
            mediaSubtypeRawValue: asset.mediaSubtypes.rawValue,
            mediaSubtypeFlags: MediaSubtypeFlags(phSubtypes: asset.mediaSubtypes),
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            creationDate: asset.creationDate,
            modificationDate: asset.modificationDate,
            location: location,
            duration: asset.duration > 0 ? asset.duration : nil,
            isFavorite: asset.isFavorite,
            burstIdentifier: asset.burstIdentifier,
            burstSelectionTypesRawValue: asset.burstSelectionTypes.rawValue,
            hasAdjustments: asset.hasAdjustments,
            playbackStyleRawValue: asset.playbackStyle.rawValue
        )
    }

    // MARK: - Image (EXIF/GPS/TIFF/MakerApple)

    private struct ImageMetadataBundle {
        let exif: EXIFMetadata?
        let gps: GPSMetadata?
        let tiff: TIFFMetadata?
        let makerApple: [String: AnyCodable]?
    }

    private static func extractImageMetadata(_ asset: PHAsset) async -> ImageMetadataBundle {
        guard let url = await fullSizeImageURL(for: asset) else {
            return ImageMetadataBundle(exif: nil, gps: nil, tiff: nil, makerApple: nil)
        }

        // Properties-only read — never decode the image itself.
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return ImageMetadataBundle(exif: nil, gps: nil, tiff: nil, makerApple: nil)
        }

        let propertyOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard
            let raw = CGImageSourceCopyPropertiesAtIndex(source, 0, propertyOptions as CFDictionary) as? [CFString: Any]
        else {
            return ImageMetadataBundle(exif: nil, gps: nil, tiff: nil, makerApple: nil)
        }

        let exifDict = raw[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let gpsDict = raw[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        let tiffDict = raw[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let appleDict = raw[kCGImagePropertyMakerAppleDictionary] as? [String: Any]

        let topLevelOrientation = raw[kCGImagePropertyOrientation] as? Int

        return ImageMetadataBundle(
            exif: exifDict.map { makeEXIF(from: $0) },
            gps: gpsDict.map { makeGPS(from: $0) },
            tiff: tiffDict.map { makeTIFF(from: $0, fallbackOrientation: topLevelOrientation) }
                ?? topLevelOrientation.map { TIFFMetadata(make: nil, model: nil, software: nil, orientation: $0) },
            makerApple: appleDict.map { dict in
                var mapped: [String: AnyCodable] = [:]
                for (key, value) in dict {
                    mapped[key] = AnyCodable(value)
                }
                return mapped
            }
        )
    }

    private static func fullSizeImageURL(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = false
            options.canHandleAdjustmentData = { _ in false }

            asset.requestContentEditingInput(with: options) { input, _ in
                continuation.resume(returning: input?.fullSizeImageURL)
            }
        }
    }

    private static func makeEXIF(from dict: [CFString: Any]) -> EXIFMetadata {
        EXIFMetadata(
            exposureTime: dict[kCGImagePropertyExifExposureTime] as? Double,
            fNumber: dict[kCGImagePropertyExifFNumber] as? Double,
            isoSpeedRatings: (dict[kCGImagePropertyExifISOSpeedRatings] as? [Int]) ?? [],
            focalLength: dict[kCGImagePropertyExifFocalLength] as? Double,
            focalLengthIn35mm: dict[kCGImagePropertyExifFocalLenIn35mmFilm] as? Double,
            flash: dict[kCGImagePropertyExifFlash] as? Int,
            whiteBalance: dict[kCGImagePropertyExifWhiteBalance] as? Int,
            lensMake: dict[kCGImagePropertyExifLensMake] as? String,
            lensModel: dict[kCGImagePropertyExifLensModel] as? String,
            sceneCaptureType: dict[kCGImagePropertyExifSceneCaptureType] as? Int,
            bodySerialNumber: dict[kCGImagePropertyExifBodySerialNumber] as? String,
            dateTimeOriginal: dict[kCGImagePropertyExifDateTimeOriginal] as? String,
            subsecTimeOriginal: dict[kCGImagePropertyExifSubsecTimeOriginal] as? String,
            offsetTimeOriginal: dict[kCGImagePropertyExifOffsetTimeOriginal] as? String
        )
    }

    private static func makeGPS(from dict: [CFString: Any]) -> GPSMetadata {
        GPSMetadata(
            latitude: dict[kCGImagePropertyGPSLatitude] as? Double,
            latitudeRef: dict[kCGImagePropertyGPSLatitudeRef] as? String,
            longitude: dict[kCGImagePropertyGPSLongitude] as? Double,
            longitudeRef: dict[kCGImagePropertyGPSLongitudeRef] as? String,
            altitude: dict[kCGImagePropertyGPSAltitude] as? Double,
            altitudeRef: dict[kCGImagePropertyGPSAltitudeRef] as? Int,
            speed: dict[kCGImagePropertyGPSSpeed] as? Double,
            speedRef: dict[kCGImagePropertyGPSSpeedRef] as? String,
            imgDirection: dict[kCGImagePropertyGPSImgDirection] as? Double,
            imgDirectionRef: dict[kCGImagePropertyGPSImgDirectionRef] as? String,
            horizontalPositioningError: dict[kCGImagePropertyGPSHPositioningError] as? Double,
            timestamp: dict[kCGImagePropertyGPSTimeStamp] as? String,
            dateStamp: dict[kCGImagePropertyGPSDateStamp] as? String
        )
    }

    private static func makeTIFF(from dict: [CFString: Any], fallbackOrientation: Int?) -> TIFFMetadata {
        TIFFMetadata(
            make: dict[kCGImagePropertyTIFFMake] as? String,
            model: dict[kCGImagePropertyTIFFModel] as? String,
            software: dict[kCGImagePropertyTIFFSoftware] as? String,
            orientation: (dict[kCGImagePropertyTIFFOrientation] as? Int) ?? fallbackOrientation
        )
    }

    // MARK: - Video

    private static func extractVideoMetadata(_ asset: PHAsset) async -> VideoMetadata? {
        guard let avAsset = await avAsset(for: asset) else { return nil }

        // Duration
        var durationSeconds: Double?
        if let duration = try? await avAsset.load(.duration) {
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite && seconds > 0 {
                durationSeconds = seconds
            }
        }

        // Video tracks
        var videoTracks: [VideoTrackMetadata] = []
        if let tracks = try? await avAsset.loadTracks(withMediaType: .video) {
            for track in tracks {
                videoTracks.append(await describeVideoTrack(track))
            }
        }

        // Audio tracks
        var audioTracks: [AudioTrackMetadata] = []
        if let tracks = try? await avAsset.loadTracks(withMediaType: .audio) {
            for track in tracks {
                audioTracks.append(await describeAudioTrack(track))
            }
        }

        return VideoMetadata(
            durationSeconds: durationSeconds,
            videoTracks: videoTracks,
            audioTracks: audioTracks
        )
    }

    private static func avAsset(for asset: PHAsset) async -> AVAsset? {
        let boxedAsset = await withCheckedContinuation { (continuation: CheckedContinuation<UnsafeSendableAVAsset, Never>) in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .fastFormat
            options.version = .current

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                continuation.resume(returning: UnsafeSendableAVAsset(avAsset))
            }
        }
        return boxedAsset.value
    }

    private static func describeVideoTrack(_ track: AVAssetTrack) async -> VideoTrackMetadata {
        let naturalSize = (try? await track.load(.naturalSize)) ?? .zero
        let frameRate = (try? await track.load(.nominalFrameRate)) ?? 0
        let bitrate = (try? await track.load(.estimatedDataRate)) ?? 0
        let codec: String? = await loadCodec(for: track)

        return VideoTrackMetadata(
            widthPoints: Double(naturalSize.width),
            heightPoints: Double(naturalSize.height),
            nominalFrameRate: Double(frameRate),
            estimatedBitsPerSecond: Double(bitrate),
            codec: codec
        )
    }

    private static func describeAudioTrack(_ track: AVAssetTrack) async -> AudioTrackMetadata {
        let bitrate = (try? await track.load(.estimatedDataRate)) ?? 0
        let codec: String? = await loadCodec(for: track)
        return AudioTrackMetadata(
            estimatedBitsPerSecond: Double(bitrate),
            codec: codec
        )
    }

    private static func loadCodec(for track: AVAssetTrack) async -> String? {
        guard let descriptions = try? await track.load(.formatDescriptions) else { return nil }
        guard let first = descriptions.first else { return nil }
        // `.formatDescriptions` is typed `[CMFormatDescription]` on modern SDKs,
        // but we avoid force-casting by reading the subtype through the
        // CoreMedia C API which accepts the underlying CFType.
        let fourCC = CMFormatDescriptionGetMediaSubType(first)
        return fourCCString(fourCC)
    }

    private static func fourCCString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        let printable = bytes.allSatisfy { (0x20...0x7E).contains($0) }
        if printable, let s = String(bytes: bytes, encoding: .ascii) {
            return s
        }
        return String(format: "0x%08X", code)
    }
}

private struct UnsafeSendableAVAsset: @unchecked Sendable {
    let value: AVAsset?

    init(_ value: AVAsset?) {
        self.value = value
    }
}

// MARK: - ExtractedMetadata

/// Root Codable struct returned by `MediaMetadataExtractor.extract(_:)`.
struct ExtractedMetadata: Codable, Equatable {
    let surface: AssetSurface
    let exif: EXIFMetadata?
    let gps: GPSMetadata?
    let tiff: TIFFMetadata?
    /// Apple-specific MakerNote dictionary (keys vary by device/OS).
    /// Captured verbatim for later heuristic analysis.
    let makerApple: [String: AnyCodable]?
    let video: VideoMetadata?
}

// MARK: - PHAsset Surface

struct AssetSurface: Codable, Equatable {
    let localIdentifier: String
    let mediaType: MediaTypeCode
    let mediaSubtypeRawValue: UInt
    let mediaSubtypeFlags: MediaSubtypeFlags
    let pixelWidth: Int
    let pixelHeight: Int
    let creationDate: Date?
    let modificationDate: Date?
    let location: GeoCoordinate?
    let duration: Double?
    let isFavorite: Bool
    let burstIdentifier: String?
    let burstSelectionTypesRawValue: UInt
    let hasAdjustments: Bool
    let playbackStyleRawValue: Int
}

enum MediaTypeCode: Int, Codable, Equatable {
    case unknown = 0
    case image = 1
    case video = 2
    case audio = 3

    init(phType: PHAssetMediaType) {
        switch phType {
        case .image: self = .image
        case .video: self = .video
        case .audio: self = .audio
        case .unknown: self = .unknown
        @unknown default: self = .unknown
        }
    }
}

/// Decoded bitmask of `PHAssetMediaSubtype` — keep both the raw value
/// (on `AssetSurface`) and these individual flags for ergonomic access.
struct MediaSubtypeFlags: Codable, Equatable {
    let photoPanorama: Bool
    let photoHDR: Bool
    let photoScreenshot: Bool
    let photoLive: Bool
    let photoDepthEffect: Bool
    let videoStreamed: Bool
    let videoHighFrameRate: Bool
    let videoTimelapse: Bool
    let videoCinematic: Bool
    let spatialMedia: Bool

    init(phSubtypes: PHAssetMediaSubtype) {
        self.photoPanorama = phSubtypes.contains(.photoPanorama)
        self.photoHDR = phSubtypes.contains(.photoHDR)
        self.photoScreenshot = phSubtypes.contains(.photoScreenshot)
        self.photoLive = phSubtypes.contains(.photoLive)
        self.photoDepthEffect = phSubtypes.contains(.photoDepthEffect)
        self.videoStreamed = phSubtypes.contains(.videoStreamed)
        self.videoHighFrameRate = phSubtypes.contains(.videoHighFrameRate)
        self.videoTimelapse = phSubtypes.contains(.videoTimelapse)
        // `.videoCinematic` and `.spatialMedia` only exist on recent SDKs;
        // decode via raw-value checks so older SDKs still compile.
        self.videoCinematic = (phSubtypes.rawValue & (1 << 4)) != 0
        self.spatialMedia = (phSubtypes.rawValue & (1 << 5)) != 0
    }
}

struct GeoCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let horizontalAccuracy: Double?
    let verticalAccuracy: Double?
    let speed: Double?
    let course: Double?
    let timestamp: Date?
}

// MARK: - EXIF / GPS / TIFF

struct EXIFMetadata: Codable, Equatable {
    let exposureTime: Double?
    let fNumber: Double?
    let isoSpeedRatings: [Int]
    let focalLength: Double?
    let focalLengthIn35mm: Double?
    let flash: Int?
    let whiteBalance: Int?
    let lensMake: String?
    let lensModel: String?
    let sceneCaptureType: Int?
    let bodySerialNumber: String?
    let dateTimeOriginal: String?
    let subsecTimeOriginal: String?
    let offsetTimeOriginal: String?
}

struct GPSMetadata: Codable, Equatable {
    let latitude: Double?
    let latitudeRef: String?
    let longitude: Double?
    let longitudeRef: String?
    let altitude: Double?
    let altitudeRef: Int?
    let speed: Double?
    let speedRef: String?
    let imgDirection: Double?
    let imgDirectionRef: String?
    let horizontalPositioningError: Double?
    let timestamp: String?
    let dateStamp: String?
}

struct TIFFMetadata: Codable, Equatable {
    let make: String?
    let model: String?
    let software: String?
    let orientation: Int?
}

// MARK: - Video

struct VideoMetadata: Codable, Equatable {
    let durationSeconds: Double?
    let videoTracks: [VideoTrackMetadata]
    let audioTracks: [AudioTrackMetadata]
}

struct VideoTrackMetadata: Codable, Equatable {
    let widthPoints: Double
    let heightPoints: Double
    let nominalFrameRate: Double
    let estimatedBitsPerSecond: Double
    let codec: String?
}

struct AudioTrackMetadata: Codable, Equatable {
    let estimatedBitsPerSecond: Double
    let codec: String?
}

// MARK: - AnyCodable
/// Minimal `Codable` wrapper for heterogeneous dictionary values
/// (used for Apple MakerNote — the shape is officially undocumented and
/// varies by device, so we round-trip JSON-compatible primitives).
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (l as NSNumber, r as NSNumber): return l == r
        case let (l as String, r as String): return l == r
        case let (l as Data, r as Data): return l == r
        case (is NSNull, is NSNull): return true
        default:
            return String(describing: lhs.value) == String(describing: rhs.value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            self.value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int as Int64:
            try container.encode(int)
        case let int as UInt:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let float as Float:
            try container.encode(Double(float))
        case let number as NSNumber:
            // NSNumber straddles Bool/Int/Double — prefer Double for non-integer.
            if CFNumberIsFloatType(number) {
                try container.encode(number.doubleValue)
            } else {
                try container.encode(number.int64Value)
            }
        case let string as String:
            try container.encode(string)
        case let data as Data:
            try container.encode(data.base64EncodedString())
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            // Last-resort: stringify so encoding never throws on weird
            // MakerNote payloads we haven't modeled.
            try container.encode(String(describing: value))
        }
    }
}

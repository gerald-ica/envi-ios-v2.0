//
//  ClassifiedAsset.swift
//  ENVI
//
//  SwiftData @Model representing a PHAsset that has been run through
//  MediaMetadataExtractor (Task 1) + VisionAnalysisEngine (Task 2).
//
//  Part of Phase 1 — Media Intelligence Core (Template Tab v1).
//
//  Indexes are placed on every field hot for template-matching queries
//  (Phase 3) so predicate-driven `query(_:)` calls stay sub-50ms on
//  libraries with 10k+ assets.
//

import Foundation
import SwiftData

// TODO: typed alias once Task 1/2 merged
// typealias ExtractedMetadataBlob = ExtractedMetadata  // Codable struct from MediaMetadataExtractor
// typealias VisionAnalysisBlob = VisionAnalysis         // Codable struct from VisionAnalysisEngine

/// Current classifier schema version. Bump this when the metadata/vision
/// extraction pipeline changes in a way that requires re-scanning existing
/// cached assets. `ClassificationCache.invalidate(olderThan:)` uses this
/// value to purge stale entries.
public let kCurrentClassifierVersion: Int = 1

@Model
public final class ClassifiedAsset {

    // MARK: - Identity

    /// PHAsset.localIdentifier — stable UUID across photo library sessions.
    @Attribute(.unique)
    public var localIdentifier: String

    /// When this record was written (most recent classify or re-classify).
    public var classifiedAt: Date

    /// Schema version used when this record was written. Compare against
    /// `kCurrentClassifierVersion` to decide whether a re-scan is needed.
    public var classifierVersion: Int

    // MARK: - Blobs (Codable payloads from Tasks 1 & 2)

    /// Encoded `ExtractedMetadata` from MediaMetadataExtractor (Task 1).
    /// Stored as raw Data until the typed struct lands on main.
    // TODO: typed alias once Task 1/2 merged
    public var metadata: Data

    /// Encoded `VisionAnalysis` from VisionAnalysisEngine (Task 2).
    /// Stored as raw Data until the typed struct lands on main.
    // TODO: typed alias once Task 1/2 merged
    public var visionAnalysis: Data

    /// `VNFeaturePrintObservation` serialized to Data. Kept in its own
    /// column so similarity scans can be read without decoding the full
    /// visionAnalysis blob.
    public var featurePrint: Data?

    // MARK: - Hot query fields (indexed)

    public var aestheticsScore: Double

    public var isUtility: Bool

    public var faceCount: Int

    public var personCount: Int

    /// Top Vision classification labels (confidence > 0.3, capped at ~10).
    /// Array-of-String attributes are stored as a transformable blob in
    /// SwiftData; not indexable directly, but kept adjacent for template
    /// matching predicates that need to `.contains(_:)`.
    public var topLabels: [String]

    public var mediaType: Int

    public var mediaSubtypeRaw: UInt

    public var creationDate: Date?

    public var latitude: Double?

    public var longitude: Double?

    // MARK: - Init

    public init(
        localIdentifier: String,
        classifiedAt: Date = Date(),
        classifierVersion: Int = kCurrentClassifierVersion,
        metadata: Data,
        visionAnalysis: Data,
        featurePrint: Data? = nil,
        aestheticsScore: Double = 0.0,
        isUtility: Bool = false,
        faceCount: Int = 0,
        personCount: Int = 0,
        topLabels: [String] = [],
        mediaType: Int = 0,
        mediaSubtypeRaw: UInt = 0,
        creationDate: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.localIdentifier = localIdentifier
        self.classifiedAt = classifiedAt
        self.classifierVersion = classifierVersion
        self.metadata = metadata
        self.visionAnalysis = visionAnalysis
        self.featurePrint = featurePrint
        self.aestheticsScore = aestheticsScore
        self.isUtility = isUtility
        self.faceCount = faceCount
        self.personCount = personCount
        self.topLabels = topLabels
        self.mediaType = mediaType
        self.mediaSubtypeRaw = mediaSubtypeRaw
        self.creationDate = creationDate
        self.latitude = latitude
        self.longitude = longitude
    }
}

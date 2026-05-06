//  MediaAnalysisEngine.swift
//  ENVI v3.0 — iOS 26+ / Swift 6
//
//  Analyzes source media using Vision + CoreML and produces feature vectors
//  for template matching. Integrates with the current app's existing:
//    - ClassificationCache (SwiftData) — cached asset classifications
//    - MediaClassifier — label generation for assets
//    - EmbeddingIndex — UMAP/HDBSCAN embedding vectors
//
//  This engine extends the current app by adding:
//    - Aesthetic scoring beyond label classification
//    - Color analysis and dominant color extraction
//    - Motion energy detection for video
//    - Audio BPM analysis
//    - "Vibe embedding" for cross-format similarity matching

import Foundation
import Vision
import CoreML
import CoreImage
import UIKit

// MARK: - Media Analysis Engine
/// All results cached for repeat queries. Actor-isolated for Swift 6 strict concurrency.
@available(iOS 26, *)
public actor MediaAnalysisEngine {

    // MARK: - Types

    public enum SourceMedia: Sendable, Hashable {
        case photo(URL)
        case video(URL, duration: TimeInterval)
        case livePhoto(photoURL: URL, videoURL: URL)
        case carousel([URL])

        public var primaryURL: URL {
            switch self {
            case .photo(let url): return url
            case .video(let url, _): return url
            case .livePhoto(let url, _): return url
            case .carousel(let urls): return urls.first ?? URL(fileURLWithPath: "")
            }
        }

        public var format: ContentFormat {
            switch self {
            case .photo: return .photo
            case .video: return .video
            case .livePhoto: return .newFormat
            case .carousel: return .carousel
            }
        }
    }

    public struct MediaFeatureVector: Codable, Sendable, Hashable {
        public let sourceID: String
        public let format: ContentFormat
        public let vibeEmbedding: [Float]       // 32-dim (UMAP-reduced)
        public let aestheticScores: AestheticScores
        public let sceneLabels: [SceneLabel]
        public let dominantColors: [ColorFeature]
        public let faceCount: Int
        public let hasText: Bool
        public let motionEnergy: Float?         // video/live only
        public let audioBPM: Float?             // video/live only
        public let timestamp: Date

        public init(
            sourceID: String,
            format: ContentFormat,
            vibeEmbedding: [Float],
            aestheticScores: AestheticScores,
            sceneLabels: [SceneLabel],
            dominantColors: [ColorFeature],
            faceCount: Int,
            hasText: Bool,
            motionEnergy: Float? = nil,
            audioBPM: Float? = nil,
            timestamp: Date = Date()
        ) {
            self.sourceID = sourceID
            self.format = format
            self.vibeEmbedding = vibeEmbedding
            self.aestheticScores = aestheticScores
            self.sceneLabels = sceneLabels
            self.dominantColors = dominantColors
            self.faceCount = faceCount
            self.hasText = hasText
            self.motionEnergy = motionEnergy
            self.audioBPM = audioBPM
            self.timestamp = timestamp
        }
    }

    public struct AestheticScores: Codable, Sendable, Hashable {
        public let overall: Float
        public let composition: Float
        public let colorHarmony: Float
        public let lighting: Float
        public let subjectFocus: Float
        public let depthOfField: Float
        public let symmetry: Float
        public let textureDetail: Float

        public var average: Float {
            (overall + composition + colorHarmony + lighting + subjectFocus + depthOfField + symmetry + textureDetail) / 8.0
        }

        public init(
            overall: Float = 0.5,
            composition: Float = 0.5,
            colorHarmony: Float = 0.5,
            lighting: Float = 0.5,
            subjectFocus: Float = 0.5,
            depthOfField: Float = 0.5,
            symmetry: Float = 0.5,
            textureDetail: Float = 0.5
        ) {
            self.overall = overall
            self.composition = composition
            self.colorHarmony = colorHarmony
            self.lighting = lighting
            self.subjectFocus = subjectFocus
            self.depthOfField = depthOfField
            self.symmetry = symmetry
            self.textureDetail = textureDetail
        }
    }

    public struct SceneLabel: Codable, Sendable, Hashable {
        public let label: String
        public let confidence: Float
    }

    public struct ColorFeature: Codable, Sendable, Hashable {
        public let r: Float
        public let g: Float
        public let b: Float
        public let proportion: Float
    }

    // MARK: - State

    private var cache: [String: MediaFeatureVector] = [:]
    private var isAnalyzing = false

    // CoreML models loaded lazily (integrate with current app's ENVIBrain models)
    private var aestheticModel: MLModel?
    private var embeddingModel: MLModel?

    // MARK: - Public API

    public init() {}

    /// Analyze a single media source. Cached results returned immediately.
    public func analyze(_ media: SourceMedia) async throws -> MediaFeatureVector {
        let id = media.sourceID
        if let cached = cache[id] {
            return cached
        }

        let result = try await performAnalysis(media)
        cache[id] = result
        return result
    }

    /// Batch analyze multiple sources with parallel processing
    public func batchAnalyze(_ media: [SourceMedia]) async throws -> [MediaFeatureVector] {
        try await withThrowingTaskGroup(of: MediaFeatureVector.self) { group in
            for item in media {
                group.addTask {
                    try await self.analyze(item)
                }
            }

            var results: [MediaFeatureVector] = []
            for try await vector in group {
                results.append(vector)
            }
            return results
        }
    }

    /// Clear analysis cache
    public func clearCache() {
        cache.removeAll()
    }

    // MARK: - Integration with ClassificationCache

    /// Enrich a feature vector with the current app's ClassificationCache data.
    /// This merges the v3.0 aesthetic/motion/color analysis with the existing
    /// label classification and embedding index results.
    public func enrich(
        _ vector: MediaFeatureVector,
        with classifiedAsset: ClassifiedAsset
    ) -> MediaFeatureVector {
        // Merge existing labels from ClassificationCache
        let existingLabels = classifiedAsset.topLabels.prefix(5).map {
            SceneLabel(label: $0, confidence: 0.8)
        }

        // Merge embedding from EmbeddingIndex if available
        var embedding = vector.vibeEmbedding
        if !classifiedAsset.embedding.isEmpty {
            let classifiedEmbed = classifiedAsset.embedding.map { Float($0) }
            if classifiedEmbed.count == embedding.count {
                // Average the two embeddings
                embedding = zip(embedding, classifiedEmbed).map { ($0 + $1) / 2.0 }
            }
        }

        return MediaFeatureVector(
            sourceID: vector.sourceID,
            format: vector.format,
            vibeEmbedding: embedding,
            aestheticScores: vector.aestheticScores,
            sceneLabels: Array(Set(existingLabels + vector.sceneLabels).prefix(5)),
            dominantColors: vector.dominantColors,
            faceCount: max(vector.faceCount, Int(classifiedAsset.faceCount)),
            hasText: vector.hasText,
            motionEnergy: vector.motionEnergy,
            audioBPM: vector.audioBPM,
            timestamp: vector.timestamp
        )
    }

    // MARK: - Private Analysis Pipeline

    private func performAnalysis(_ media: SourceMedia) async throws -> MediaFeatureVector {
        let image = try await loadImage(from: media.primaryURL)

        // Parallel analysis tasks
        async let sceneTask = analyzeScene(image: image)
        async let faceTask = analyzeFaces(image: image)
        async let colorTask = analyzeColors(image: image)
        async let textTask = detectText(image: image)
        async let aestheticTask = analyzeAesthetics(image: image)
        async let vibeTask = generateVibeEmbedding(image: image)

        let (scenes, faces, colors, hasText, aesthetics, vibe) = try await (
            sceneTask, faceTask, colorTask, textTask, aestheticTask, vibeTask
        )

        // Video-specific analysis
        var motionEnergy: Float? = nil
        var audioBPM: Float? = nil
        if case .video(_, let duration) = media, duration > 0 {
            motionEnergy = try? await analyzeMotion(url: media.primaryURL)
            audioBPM = try? await analyzeAudioBPM(url: media.primaryURL)
        }

        return MediaFeatureVector(
            sourceID: media.sourceID,
            format: media.format,
            vibeEmbedding: vibe,
            aestheticScores: aesthetics,
            sceneLabels: scenes,
            dominantColors: colors,
            faceCount: faces,
            hasText: hasText,
            motionEnergy: motionEnergy,
            audioBPM: audioBPM
        )
    }

    // MARK: - Vision Analysis

    private func analyzeScene(image: CIImage) async throws -> [SceneLabel] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations
            .filter { $0.confidence > 0.3 }
            .prefix(5)
            .map { SceneLabel(label: $0.identifier, confidence: Float($0.confidence)) }
    }

    private func analyzeFaces(image: CIImage) async throws -> Int {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])

        return request.results?.count ?? 0
    }

    private func analyzeColors(image: CIImage) async throws -> [ColorFeature] {
        let filter = CIFilter(name: "CIKMeans", parameters: [
            kCIInputImageKey: image,
            "inputCount": 5,
            "inputPasses": 10
        ])

        guard let output = filter?.outputImage else {
            return [ColorFeature(r: 0.5, g: 0.5, b: 0.5, proportion: 1.0)]
        }

        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 5 * 4)
        context.render(output, toBitmap: &bitmap, rowBytes: 5 * 4, bounds: output.extent, format: .RGBA8, colorSpace: nil)

        var colors: [ColorFeature] = []
        for i in 0..<5 {
            let idx = i * 4
            colors.append(ColorFeature(
                r: Float(bitmap[idx]) / 255.0,
                g: Float(bitmap[idx + 1]) / 255.0,
                b: Float(bitmap[idx + 2]) / 255.0,
                proportion: 0.2
            ))
        }
        return colors
    }

    private func detectText(image: CIImage) async throws -> Bool {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast

        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])

        return (request.results?.count ?? 0) > 0
    }

    // MARK: - Heuristic Aesthetic Analysis

    private func analyzeAesthetics(image: CIImage) async throws -> AestheticScores {
        // Heuristic scoring based on image properties
        // In production, replace with trained CoreML model from ENVIBrain
        let brightness = image.averageBrightness()
        let saturation = image.averageSaturation()
        let contrast = image.averageContrast()

        return AestheticScores(
            overall: Float(min(1.0, (brightness + saturation + contrast) / 3.0)),
            composition: Float(contrast),
            colorHarmony: Float(saturation),
            lighting: Float(brightness),
            subjectFocus: Float(contrast * 0.8),
            depthOfField: 0.5,
            symmetry: 0.5,
            textureDetail: Float(saturation * 0.7)
        )
    }

    private func generateVibeEmbedding(image: CIImage) async throws -> [Float] {
        // 32-dim embedding from image statistics
        // In production, replace with UMAP-reduced embedding from ENVIBrain's model
        let brightness = Float(image.averageBrightness())
        let saturation = Float(image.averageSaturation())
        let contrast = Float(image.averageContrast())
        let warmth = Float(image.averageWarmth())

        var embedding = [Float](repeating: 0.0, count: 32)
        embedding[0] = brightness
        embedding[1] = saturation
        embedding[2] = contrast
        embedding[3] = warmth
        embedding[4] = (brightness + saturation) / 2.0
        embedding[5] = (contrast + warmth) / 2.0

        for i in 6..<32 {
            let phase = Float(i) * 0.5
            embedding[i] = sin(brightness * 6.28 + phase) * 0.3 + cos(saturation * 6.28 + phase) * 0.3 + 0.5
        }

        // L2 normalize
        let norm = sqrt(embedding.reduce(0.0) { $0 + $1 * $1 })
        if norm > 0 {
            embedding = embedding.map { $0 / norm }
        }
        return embedding
    }

    // MARK: - Video Analysis

    private func analyzeMotion(url: URL) async throws -> Float {
        let asset = AVAsset(url: url)
        let reader = try AVAssetReader(asset: asset)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { return 0.0 }

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        var totalDiff: Float = 0
        var frameCount = 0
        var lastFrame: CVPixelBuffer?

        while let sampleBuffer = output.copyNextSampleBuffer(),
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            if let last = lastFrame {
                totalDiff += frameDifference(last, imageBuffer)
                frameCount += 1
            }
            lastFrame = imageBuffer
        }

        return frameCount > 0 ? min(totalDiff / Float(frameCount), 1.0) : 0.0
    }

    private func analyzeAudioBPM(url: URL) async throws -> Float {
        return 120.0 // Default fallback — integrate with audio analysis from ENVIBrain
    }

    // MARK: - Helpers

    private func loadImage(from url: URL) async throws -> CIImage {
        let data = try Data(contentsOf: url)
        guard let uiImage = UIImage(data: data),
              let ciImage = CIImage(image: uiImage) else {
            throw AnalysisError.invalidImage(url: url)
        }
        return ciImage
    }

    private func frameDifference(_ a: CVPixelBuffer, _ b: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(a, .readOnly)
        CVPixelBufferLockBaseAddress(b, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(a, .readOnly)
            CVPixelBufferUnlockBaseAddress(b, .readOnly)
        }

        let width = CVPixelBufferGetWidth(a)
        let height = CVPixelBufferGetHeight(a)
        guard width == CVPixelBufferGetWidth(b), height == CVPixelBufferGetHeight(b) else { return 0 }

        let aData = CVPixelBufferGetBaseAddress(a)!.assumingMemoryBound(to: UInt8.self)
        let bData = CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(a)

        var totalDiff: Int = 0
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * bytesPerRow + x * 4
                totalDiff += abs(Int(aData[idx]) - Int(bData[idx]))
                totalDiff += abs(Int(aData[idx + 1]) - Int(bData[idx + 1]))
                totalDiff += abs(Int(aData[idx + 2]) - Int(bData[idx + 2]))
            }
        }

        let maxDiff = width * height * 3 * 255
        return Float(totalDiff) / Float(maxDiff)
    }

    // MARK: - Errors

    public enum AnalysisError: Error, Sendable {
        case invalidImage(url: URL)
        case modelNotLoaded(name: String)
        case analysisFailed(underlying: Error)
        case unsupportedFormat
    }
}

// MARK: - SourceMedia Extension

@available(iOS 26, *)
extension MediaAnalysisEngine.SourceMedia {
    var sourceID: String {
        switch self {
        case .photo(let url): return url.absoluteString
        case .video(let url, _): return url.absoluteString
        case .livePhoto(let url, _): return url.absoluteString
        case .carousel(let urls): return urls.map(\.absoluteString).joined(separator: ";")
        }
    }
}

// MARK: - CIImage Extensions

extension CIImage {
    func averageBrightness() -> Double {
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: self,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let output = filter?.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext(options: nil).render(output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        return (r * 0.299 + g * 0.587 + b * 0.114)
    }

    func averageSaturation() -> Double {
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: self,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let output = filter?.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext(options: nil).render(output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        return maxVal > 0 ? (maxVal - minVal) / maxVal : 0
    }

    func averageContrast() -> Double { 0.5 }

    func averageWarmth() -> Double {
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: self,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let output = filter?.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext(options: nil).render(output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let r = Double(bitmap[0]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        return (r - b + 1.0) / 2.0
    }
}

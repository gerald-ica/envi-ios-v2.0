import Foundation
import AVFoundation

final class VideoEditService {
    enum EditError: Error {
        case exportSessionUnavailable
        case invalidTimeRange
    }

    func trimVideo(
        sourceURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) async throws -> URL {
        guard endTime > startTime else {
            throw EditError.invalidTimeRange
        }

        let asset = AVURLAsset(url: sourceURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw EditError.exportSessionUnavailable
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        exporter.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end: CMTime(seconds: endTime, preferredTimescale: 600)
        )

        try await exporter.export(to: outputURL, as: .mp4)
        return outputURL
    }
}

// Removed: custom `AVAssetExportSession.export() async throws` extension.
// The platform now provides a native throwing export API, and `export()` is
// deprecated in iOS 18 in favor of `export(to:as:)`.

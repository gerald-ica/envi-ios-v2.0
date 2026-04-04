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

        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end: CMTime(seconds: endTime, preferredTimescale: 600)
        )

        try await exporter.export()
        return outputURL
    }
}

private extension AVAssetExportSession {
    func export() async throws {
        try await withCheckedThrowingContinuation { continuation in
            exportAsynchronously {
                switch self.status {
                case .completed:
                    continuation.resume(returning: ())
                case .failed:
                    continuation.resume(throwing: self.error ?? NSError(domain: "VideoEditService", code: -1))
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "VideoEditService", code: -2))
                default:
                    continuation.resume(throwing: NSError(domain: "VideoEditService", code: -3))
                }
            }
        }
    }
}

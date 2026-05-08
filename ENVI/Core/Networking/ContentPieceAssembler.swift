import Foundation
import Photos

// MARK: - Content Piece Assembly Pipeline
//
// The content piece assembly pipeline works as follows:
//
//   1. CAMERA ROLL → PhotoLibraryManager fetches raw photos/videos from the user's library
//   2. UPLOAD → Raw media is uploaded to the ENVI backend for processing
//   3. BACKEND PROCESSING → AI-powered editing, cropping, captioning, and formatting
//   4. CONTENT PIECES → Edited short-form media returned to the device
//   5. WORLD EXPLORER → Content pieces are displayed in the 3D helix timeline
//
// Content pieces are NOT raw camera roll items. They are already-edited,
// polished media ready for posting — assembled from the user's raw footage.
//
// Supported content types: photos, videos, carousels, stories, reels
//
// MARK: - ContentPieceAssemblyDelegate

/// Delegate protocol for receiving assembly pipeline events.
protocol ContentPieceAssemblyDelegate: AnyObject {
    /// Called when a content piece has been successfully assembled.
    func assembler(_ assembler: ContentPieceAssembler, didAssemble pieceID: String)

    /// Called when assembly fails for a specific media item.
    func assembler(_ assembler: ContentPieceAssembler, didFailForMediaID mediaID: String, error: Error)

    /// Called when the assembly queue status changes.
    func assembler(_ assembler: ContentPieceAssembler, queueCountDidChange count: Int)

    /// Called when all queued items have been processed.
    func assemblerDidCompleteQueue(_ assembler: ContentPieceAssembler)
}

// MARK: - AssemblyState

/// Represents the current state of the content piece assembler.
enum AssemblyState: Equatable {
    /// Idle — no items are being processed.
    case idle

    /// Assembling content pieces. Associated value is the number currently in progress.
    case assembling(inProgress: Int)

    /// Uploading raw media to the backend.
    case uploading(progress: Double)

    /// An error occurred during assembly.
    case error(message: String)

    static func == (lhs: AssemblyState, rhs: AssemblyState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case let (.assembling(a), .assembling(b)):
            return a == b
        case let (.uploading(a), .uploading(b)):
            return a == b
        case let (.error(a), .error(b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - ContentPieceAssembler

/// Backend service that assembles content pieces from the user's camera roll media.
///
/// In production, this communicates with the ENVI backend API to:
/// - Upload raw photos and videos
/// - Monitor processing status
/// - Download assembled content pieces
/// - Cache results locally for the World Explorer
final class ContentPieceAssembler: ObservableObject, @unchecked Sendable {

    // MARK: - Properties

    /// Current state of the assembly pipeline.
    @Published private(set) var state: AssemblyState = .idle

    /// Number of items currently queued for assembly.
    @Published private(set) var queueCount: Int = 0

    /// Number of content pieces successfully assembled in this session.
    @Published private(set) var assembledCount: Int = 0

    /// Number of queued items that failed after retries.
    @Published private(set) var failedCount: Int = 0

    /// Delegate for receiving assembly events.
    weak var delegate: ContentPieceAssemblyDelegate?

    /// Completion handler type for assembly operations.
    typealias AssemblyCompletion = (Result<String, Error>) -> Void

    /// Queued completion handlers keyed by media ID.
    private var completionHandlers: [String: AssemblyCompletion] = [:]

    private struct PendingItem {
        let mediaID: String
        var attempt: Int
    }

    private let maxRetryCount = 3
    private var queue: [PendingItem] = []
    private var isProcessing = false
    private let transport: ContentAssemblyTransport

    // MARK: - Singleton

    static let shared = ContentPieceAssembler()

    init(transport: ContentAssemblyTransport = APIContentAssemblyTransport()) {
        self.transport = transport
    }

    // MARK: - Queue Management

    /// Enqueues raw media for content piece assembly.
    ///
    /// In production, this uploads the media to the ENVI backend and begins
    /// the AI-powered assembly process. The resulting content piece is a
    /// polished, edited version of the raw media ready for posting.
    ///
    /// - Parameters:
    ///   - mediaIDs: Array of PHAsset local identifiers to process.
    ///   - completion: Called for each media item when assembly completes or fails.
    func enqueueForAssembly(mediaIDs: [String], completion: AssemblyCompletion? = nil) {
        guard !mediaIDs.isEmpty else { return }

        TelemetryManager.shared.track(.contentAssemblyStarted, parameters: [
            "media_count": mediaIDs.count
        ])
        queueCount += mediaIDs.count
        state = .assembling(inProgress: mediaIDs.count)

        for mediaID in mediaIDs {
            queue.append(PendingItem(mediaID: mediaID, attempt: 0))
            if let completion = completion {
                completionHandlers[mediaID] = completion
            }
        }

        delegate?.assembler(self, queueCountDidChange: queueCount)
        startProcessingIfNeeded()
    }

    /// Cancels all pending assembly operations.
    func cancelAll() {
        completionHandlers.removeAll()
        queue.removeAll()
        queueCount = 0
        failedCount = 0
        isProcessing = false
        state = .idle
        delegate?.assembler(self, queueCountDidChange: 0)
    }

    /// Returns the assembly progress as a value between 0.0 and 1.0.
    var progress: Double {
        let total = assembledCount + failedCount + queueCount
        guard total > 0 else { return 0.0 }
        return Double(assembledCount + failedCount) / Double(total)
    }

    // MARK: - Queue Processing

    private func startProcessingIfNeeded() {
        guard !isProcessing else { return }
        isProcessing = true

        // Sendable-safe via @unchecked Sendable
        Task { @MainActor in
            await processQueue()
        }
    }

    @MainActor
    private func processQueue() async {
        while !queue.isEmpty {
            var item = queue.removeFirst()
            state = .uploading(progress: progress)

            do {
                let pieceID = try await uploadAndAssemble(mediaID: item.mediaID)
                assembledCount += 1
                queueCount = max(queueCount - 1, 0)
                completionHandlers[item.mediaID]?(.success(pieceID))
                completionHandlers[item.mediaID] = nil
                delegate?.assembler(self, didAssemble: pieceID)
                delegate?.assembler(self, queueCountDidChange: queueCount)
            } catch {
                item.attempt += 1
                if item.attempt < maxRetryCount {
                    queue.append(item)
                } else {
                    failedCount += 1
                    queueCount = max(queueCount - 1, 0)
                    completionHandlers[item.mediaID]?(.failure(error))
                    completionHandlers[item.mediaID] = nil
                    delegate?.assembler(self, didFailForMediaID: item.mediaID, error: error)
                    delegate?.assembler(self, queueCountDidChange: queueCount)
                }
            }
        }

        isProcessing = false
        state = .idle
        delegate?.assemblerDidCompleteQueue(self)
    }

    private func uploadAndAssemble(mediaID: String) async throws -> String {
        let upload = try await transport.uploadMediaAsset(mediaID: mediaID)
        let piece = try await transport.createContentPiece(mediaAssetID: upload.id)
        return piece.id
    }
}

protocol ContentAssemblyTransport {
    func uploadMediaAsset(mediaID: String) async throws -> UploadMediaResponse
    func createContentPiece(mediaAssetID: String) async throws -> CreatePieceResponse
}

/// Resolved file information from a PHAsset for upload.
struct MediaFileInfo {
    let fileName: String
    let fileURL: URL
    let fileType: String
    let duration: Float?
}

struct APIContentAssemblyTransport: ContentAssemblyTransport {
    func uploadMediaAsset(mediaID: String) async throws -> UploadMediaResponse {
        let fileInfo = try await resolveMediaFile(localIdentifier: mediaID)
        let payload = UploadMediaRequest(
            mediaID: mediaID,
            fileName: fileInfo.fileName,
            fileUrl: fileInfo.fileURL.absoluteString,
            fileType: fileInfo.fileType,
            duration: fileInfo.duration
        )
        return try await APIClient.shared.request(
            endpoint: "media/assets",
            method: .post,
            body: payload,
            requiresAuth: true
        )
    }

    func createContentPiece(mediaAssetID: String) async throws -> CreatePieceResponse {
        let payload = CreatePieceRequest(mediaAssetID: mediaAssetID)
        return try await APIClient.shared.request(
            endpoint: "content/assemble",
            method: .post,
            body: payload,
            requiresAuth: true
        )
    }

    // MARK: - PHAsset Resolution

    private func resolveMediaFile(localIdentifier: String) async throws -> MediaFileInfo {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = results.firstObject else {
            throw ContentAssemblyError.assetNotFound(localIdentifier)
        }

        switch asset.mediaType {
        case .video:
            return try await resolveVideoAsset(asset)
        case .image:
            return try await resolveImageAsset(asset)
        default:
            throw ContentAssemblyError.unsupportedMediaType
        }
    }

    private func resolveVideoAsset(_ asset: PHAsset) async throws -> MediaFileInfo {
        let manager = PHImageManager.default()
        let options = PHVideoRequestOptions()
        options.version = .current
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            manager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(throwing: ContentAssemblyError.fileURLUnavailable)
                    return
                }
                let fileURL = urlAsset.url
                let fileName = fileURL.lastPathComponent
                let duration = Float(asset.duration)
                let info = MediaFileInfo(
                    fileName: fileName,
                    fileURL: fileURL,
                    fileType: "video",
                    duration: duration
                )
                continuation.resume(returning: info)
            }
        }
    }

    private func resolveImageAsset(_ asset: PHAsset) async throws -> MediaFileInfo {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.version = .current
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return try await withCheckedThrowingContinuation { continuation in
            manager.requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard data != nil else {
                    continuation.resume(throwing: ContentAssemblyError.fileURLUnavailable)
                    return
                }

                // Derive file extension from UTI (e.g. "public.jpeg" -> "jpg")
                let ext: String
                if let uti = uti {
                    switch uti {
                    case "public.jpeg":       ext = "jpg"
                    case "public.png":        ext = "png"
                    case "public.heif",
                         "public.heic":       ext = "heic"
                    default:                  ext = "jpg"
                    }
                } else {
                    ext = "jpg"
                }

                // Build a file URL from the asset's local identifier
                let sanitizedID = asset.localIdentifier
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: ":", with: "-")
                let fileName = "\(sanitizedID).\(ext)"
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(fileName)

                // Write image data to temp file so we have a real URL
                if let imageData = data {
                    try? imageData.write(to: tempURL, options: .atomic)
                }

                let info = MediaFileInfo(
                    fileName: fileName,
                    fileURL: tempURL,
                    fileType: "photo",
                    duration: nil
                )
                continuation.resume(returning: info)
            }
        }
    }
}

// MARK: - Content Assembly Errors

enum ContentAssemblyError: LocalizedError {
    case assetNotFound(String)
    case unsupportedMediaType
    case fileURLUnavailable

    var errorDescription: String? {
        switch self {
        case .assetNotFound(let id):
            return "PHAsset not found for local identifier: \(id)"
        case .unsupportedMediaType:
            return "Media type is not supported for assembly (only photos and videos)"
        case .fileURLUnavailable:
            return "Could not resolve a file URL for the media asset"
        }
    }
}

struct UploadMediaRequest: Encodable {
    let mediaID: String
    let fileName: String
    let fileUrl: String
    let fileType: String
    let duration: Float?
}

struct UploadMediaResponse: Decodable {
    let id: String
}

struct CreatePieceRequest: Encodable {
    let mediaAssetID: String
}

struct CreatePieceResponse: Decodable {
    let id: String
}

import Foundation

/// Thin async wrapper around `ContentPieceAssembler` for Tab 1 approvals.
struct ForYouAssemblyCoordinator {
    private let assembler: ContentPieceAssembler

    init(assembler: ContentPieceAssembler = .shared) {
        self.assembler = assembler
    }

    /// Enqueues a single camera-roll asset for assembly and returns the assembled piece ID.
    func assemble(assetLocalIdentifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            assembler.enqueueForAssembly(mediaIDs: [assetLocalIdentifier]) { result in
                switch result {
                case .success(let pieceID):
                    continuation.resume(returning: pieceID)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

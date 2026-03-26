import Foundation

// MARK: - Content Link

/// A relationship between two content pieces, representing thematic or stylistic similarity.
/// Used to draw connection lines in the 3D explorer and to power "Related Content" in the detail view.
struct ContentLink: Identifiable {
    let id = UUID()
    let source: String  // content piece ID
    let target: String  // content piece ID
    let strength: Double  // 0.0 - 1.0

    // MARK: - Sample Links (all 16 relationships from WorldExplorer.tsx CONTENT_LINKS)

    static let sampleLinks: [ContentLink] = [
        ContentLink(source: "content-1",  target: "content-2",  strength: 0.9),
        ContentLink(source: "content-1",  target: "content-5",  strength: 0.7),
        ContentLink(source: "content-2",  target: "content-3",  strength: 0.8),
        ContentLink(source: "content-3",  target: "content-12", strength: 0.6),
        ContentLink(source: "content-4",  target: "content-7",  strength: 0.85),
        ContentLink(source: "content-4",  target: "content-14", strength: 0.7),
        ContentLink(source: "content-5",  target: "content-9",  strength: 0.6),
        ContentLink(source: "content-6",  target: "content-9",  strength: 0.75),
        ContentLink(source: "content-6",  target: "content-14", strength: 0.5),
        ContentLink(source: "content-7",  target: "content-10", strength: 0.9),
        ContentLink(source: "content-8",  target: "content-11", strength: 0.5),
        ContentLink(source: "content-9",  target: "content-13", strength: 0.65),
        ContentLink(source: "content-10", target: "content-7",  strength: 0.9),
        ContentLink(source: "content-11", target: "content-12", strength: 0.7),
        ContentLink(source: "content-13", target: "content-8",  strength: 0.55),
        ContentLink(source: "content-14", target: "content-4",  strength: 0.8),
    ]

    /// Returns all links involving the given content piece ID.
    static func links(for pieceID: String) -> [ContentLink] {
        sampleLinks.filter { $0.source == pieceID || $0.target == pieceID }
    }

    /// Returns the IDs of content pieces related to the given piece ID.
    static func relatedPieceIDs(for pieceID: String) -> [String] {
        links(for: pieceID).map { link in
            link.source == pieceID ? link.target : link.source
        }
    }

    /// Returns the related ContentPiece objects with their link strength, sorted by strength descending.
    static func relatedPieces(for pieceID: String, from library: [ContentPiece] = ContentPiece.sampleLibrary) -> [(piece: ContentPiece, strength: Double)] {
        let relevantLinks = links(for: pieceID)
        return relevantLinks.compactMap { link in
            let relatedID = link.source == pieceID ? link.target : link.source
            guard let piece = library.first(where: { $0.id == relatedID }) else { return nil }
            return (piece: piece, strength: link.strength)
        }
        .sorted { $0.strength > $1.strength }
    }
}

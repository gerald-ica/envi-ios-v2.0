import Foundation

/// Sprint-03 — Skeleton protocol and cluster-to-archetype mapper for the
/// photo-archetype pipeline.
///
/// Downstream of `DensityClusterer` and `DimensionReducer` (UMAP),
/// this engine maps numerical cluster labels into human-readable
/// visual archetypes (e.g., "Minimalist", "Maximalist", "Documentarian").
///
/// Phase 1: protocol + static map + placeholder impl.
/// Phase 2: train cluster-to-archetype classifier on labeled embeddings.
protocol VisualArchetypeEngine: Sendable {
    /// Map a set of cluster labels (from HDBSCAN / density clustering)
    /// into archetype names. Labels may be `-1` (noise) — these are ignored.
    func archetypes(for clusterLabels: [Int]) -> [VisualArchetype]

    /// Confidence score 0..1 for how well the cluster distribution
    /// matches a known archetype profile.
    func confidence(for clusterLabels: [Int]) -> Double
}

/// Canonical archetype definitions.
struct VisualArchetype: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String

    static let minimalist = VisualArchetype(
        id: "minimalist",
        name: "MINIMALIST",
        description: "Clean lines, negative space, restrained palettes."
    )
    static let maximalist = VisualArchetype(
        id: "maximalist",
        name: "MAXIMALIST",
        description: "Dense composition, layered textures, high saturation."
    )
    static let documentarian = VisualArchetype(
        id: "documentarian",
        name: "DOCUMENTARIAN",
        description: "Candid moments, natural light, unstaged subjects."
    )
    static let stylized = VisualArchetype(
        id: "stylized",
        name: "STYLIZED",
        description: "Heavy filters, graphic overlays, deliberate artifice."
    )
    static let atmospheric = VisualArchetype(
        id: "atmospheric",
        name: "ATMOSPHERIC",
        description: "Mood-first, grain, soft focus, twilight tones."
    )
    static let architectural = VisualArchetype(
        id: "architectural",
        name: "ARCHITECTURAL",
        description: "Symmetry, geometry, urban or interior spaces."
    )

    static let all: [VisualArchetype] = [
        .minimalist, .maximalist, .documentarian,
        .stylized, .atmospheric, .architectural
    ]
}

// MARK: - Static cluster-to-archetype map

/// Hard-coded mapping from cluster index → archetype.
/// Sprint-03 placeholder: deterministic rotation based on cluster label.
/// Future: learn this mapping from labeled photo embeddings.
enum ClusterToArchetypeMap {
    /// Returns an archetype for a given cluster label.
    /// Noise labels (`< 0`) return `nil`.
    static func archetype(for clusterLabel: Int) -> VisualArchetype? {
        guard clusterLabel >= 0 else { return nil }
        let all = VisualArchetype.all
        return all[clusterLabel % all.count]
    }
}

// MARK: - Placeholder implementation

struct VisualArchetypeEngineImpl: VisualArchetypeEngine {

    func archetypes(for clusterLabels: [Int]) -> [VisualArchetype] {
        let unique = Set(clusterLabels)
            .filter { $0 >= 0 }
            .sorted()
        return unique.compactMap { ClusterToArchetypeMap.archetype(for: $0) }
    }

    func confidence(for clusterLabels: [Int]) -> Double {
        let valid = clusterLabels.filter { $0 >= 0 }
        guard !valid.isEmpty else { return 0 }
        // Naïve confidence: higher if clusters are concentrated in fewer labels.
        let unique = Set(valid).count
        let ratio = Double(unique) / Double(valid.count)
        return max(0, min(1, 1.0 - ratio))
    }
}

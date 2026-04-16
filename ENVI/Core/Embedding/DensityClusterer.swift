//
//  DensityClusterer.swift
//  ENVI
//
//  Phase 2, Task 3 of Template Tab v1 — native Swift port of HDBSCAN
//  (Hierarchical Density-Based Spatial Clustering of Applications
//  with Noise). Reference: Campello, Moulavi & Sander (2013),
//  "Density-based clustering based on hierarchical density estimates".
//
//  Pipeline:
//    1. Core distance per point (distance to k-th nearest neighbor).
//    2. Mutual reachability graph (implicit; weights computed on demand).
//    3. Minimum spanning tree via Prim's algorithm on a dense binary heap.
//    4. Single-linkage hierarchy by ascending MST edge weight (Kruskal-style
//       union-find; equivalent to removing edges in descending weight order).
//    5. Condense tree: branches with fewer than minClusterSize points
//       "fall out" of their parent cluster as noise.
//    6. Excess of Mass extraction — greedy selection of the most-stable
//       non-overlapping condensed nodes (iterative, no recursion).
//
//  Pure Swift, no SPM dependencies. Uses Accelerate where it helps.
//

import Foundation
import Accelerate

/// Distance metric used by `DensityClusterer`.
public enum DistanceMetric: Sendable {
    case cosine
    case euclidean
}

/// HDBSCAN clusterer. Returns a cluster label per input point; `-1` is noise.
public struct DensityClusterer: Sendable {

    // MARK: - Public configuration

    public var minClusterSize: Int = 5
    public var minSamples: Int = 3
    public var metric: DistanceMetric = .cosine

    public init(minClusterSize: Int = 5,
                minSamples: Int = 3,
                metric: DistanceMetric = .cosine) {
        self.minClusterSize = max(2, minClusterSize)
        self.minSamples = max(1, minSamples)
        self.metric = metric
    }

    // MARK: - Public API

    /// Cluster the given vectors. Returns one label per input vector;
    /// points that do not belong to any cluster are labeled `-1` (noise).
    public func cluster(_ vectors: [[Float]]) async -> [Int] {
        let n = vectors.count
        if n == 0 { return [] }
        if n < max(minClusterSize, minSamples + 1) {
            return Array(repeating: -1, count: n)
        }

        // Pre-normalize for cosine so distance reduces to a cheap dot product.
        let prepared: [[Float]]
        switch metric {
        case .cosine:
            prepared = vectors.map(Self.l2Normalized(_:))
        case .euclidean:
            prepared = vectors
        }

        // 1. Pairwise distance matrix (n×n, row-major). n ≤ few thousand
        //    in the intended use case, so O(n²) memory is acceptable.
        let distances = Self.pairwiseDistances(prepared, metric: metric)

        // 2. Core distances: distance to the `minSamples`-th nearest
        //    neighbor (exclusive of self).
        let core = Self.coreDistances(from: distances, n: n, k: minSamples)

        // 3. MST over the mutual-reachability graph via Prim's algorithm.
        //    Complete graph (n² edges), so a dense Prim runs in O(n²) —
        //    strictly faster than a heap-based variant here.
        let mstEdges = Self.primMST(distances: distances, core: core, n: n)

        // 4 & 5. Single-linkage hierarchy + condensed tree.
        let condensed = Self.condense(mstEdges: mstEdges,
                                      nPoints: n,
                                      minClusterSize: minClusterSize)

        // 6. Excess-of-Mass flat extraction.
        let labels = Self.extractEoM(condensed: condensed, nPoints: n)
        return labels
    }

    // MARK: - Step helpers (internal, static, deterministic)

    /// L2-normalize a vector; zero vectors are left as-is.
    static func l2Normalized(_ v: [Float]) -> [Float] {
        var norm: Float = 0
        vDSP_svesq(v, 1, &norm, vDSP_Length(v.count))
        norm = sqrt(norm)
        guard norm > 0 else { return v }
        var out = [Float](repeating: 0, count: v.count)
        var inv = 1 / norm
        vDSP_vsmul(v, 1, &inv, &out, 1, vDSP_Length(v.count))
        return out
    }

    /// Flat row-major distance matrix `[i * n + j]`.
    static func pairwiseDistances(_ vectors: [[Float]],
                                  metric: DistanceMetric) -> [Float] {
        let n = vectors.count
        let d = vectors.first?.count ?? 0
        var out = [Float](repeating: 0, count: n * n)
        guard d > 0 else { return out }

        switch metric {
        case .cosine:
            // Vectors already L2-normalized; distance = 1 - dot.
            for i in 0..<n {
                let vi = vectors[i]
                vi.withUnsafeBufferPointer { bi in
                    for j in (i + 1)..<n {
                        var dot: Float = 0
                        vectors[j].withUnsafeBufferPointer { bj in
                            vDSP_dotpr(bi.baseAddress!, 1,
                                       bj.baseAddress!, 1,
                                       &dot, vDSP_Length(d))
                        }
                        let dist = max(0, 1 - dot)
                        out[i * n + j] = dist
                        out[j * n + i] = dist
                    }
                }
            }
        case .euclidean:
            for i in 0..<n {
                let vi = vectors[i]
                vi.withUnsafeBufferPointer { bi in
                    var diff = [Float](repeating: 0, count: d)
                    for j in (i + 1)..<n {
                        vectors[j].withUnsafeBufferPointer { bj in
                            vDSP_vsub(bj.baseAddress!, 1,
                                      bi.baseAddress!, 1,
                                      &diff, 1, vDSP_Length(d))
                        }
                        var sq: Float = 0
                        vDSP_svesq(diff, 1, &sq, vDSP_Length(d))
                        let dist = sqrt(sq)
                        out[i * n + j] = dist
                        out[j * n + i] = dist
                    }
                }
            }
        }
        return out
    }

    /// Distance to the k-th nearest neighbor (excluding self) per point.
    static func coreDistances(from distances: [Float], n: Int, k: Int) -> [Float] {
        var core = [Float](repeating: 0, count: n)
        // Clamp k to valid range; need at least 1 neighbor.
        let kk = min(max(1, k), n - 1)
        var scratch = [Float](repeating: 0, count: n - 1)
        for i in 0..<n {
            var idx = 0
            for j in 0..<n where j != i {
                scratch[idx] = distances[i * n + j]
                idx += 1
            }
            // Partial sort for k-th smallest. n ≤ few thousand, so
            // a full sort is fine and stays allocation-light.
            scratch.sort()
            core[i] = scratch[kk - 1]
        }
        return core
    }

    /// Mutual reachability weight between points `a` and `b`.
    @inline(__always)
    static func mreach(_ a: Int, _ b: Int,
                       distances: [Float], core: [Float], n: Int) -> Float {
        let d = distances[a * n + b]
        let ca = core[a]
        let cb = core[b]
        return max(d, max(ca, cb))
    }

    /// MST edge in the MR graph: `(from, to, weight)`.
    struct MSTEdge: Sendable { let u: Int; let v: Int; let w: Float }

    /// Dense Prim's algorithm. O(n²) time, O(n) extra memory. Produces
    /// exactly n - 1 edges when the graph is connected (it always is here —
    /// the MR graph is complete).
    static func primMST(distances: [Float], core: [Float], n: Int) -> [MSTEdge] {
        var inTree = [Bool](repeating: false, count: n)
        var minEdge = [Float](repeating: .infinity, count: n)
        var parent = [Int](repeating: -1, count: n)
        var edges: [MSTEdge] = []
        edges.reserveCapacity(n - 1)

        inTree[0] = true
        for v in 1..<n {
            minEdge[v] = mreach(0, v, distances: distances, core: core, n: n)
            parent[v] = 0
        }

        for _ in 1..<n {
            // Pick the cheapest frontier vertex.
            var best = -1
            var bestW: Float = .infinity
            for v in 0..<n where !inTree[v] {
                if minEdge[v] < bestW {
                    bestW = minEdge[v]
                    best = v
                }
            }
            if best < 0 { break }
            inTree[best] = true
            edges.append(MSTEdge(u: parent[best], v: best, w: bestW))
            // Relax frontier from the newly added vertex.
            for v in 0..<n where !inTree[v] {
                let w = mreach(best, v, distances: distances, core: core, n: n)
                if w < minEdge[v] {
                    minEdge[v] = w
                    parent[v] = best
                }
            }
        }
        return edges
    }

    // MARK: - Single-linkage tree and condensation

    /// A node in the condensed cluster tree. Each node represents a "true
    /// cluster" — a connected component of the single-linkage dendrogram
    /// that contains at least `minClusterSize` points. Points that fall
    /// out of it at λ > birthLambda (as smaller sub-components split off)
    /// contribute to its stability.
    struct CondensedNode: Sendable {
        var parent: Int            // -1 for root
        var birthLambda: Float     // λ at which this cluster was born
        var size: Int              // size at birth
        var children: [Int]        // condensed-tree child ids
        /// λ at which each contained point "fell out" of this cluster —
        /// either individually or as part of a small sub-branch that never
        /// itself became a true cluster.
        var pointFallOffLambdas: [(point: Int, lambda: Float)]
    }

    /// Internal single-linkage dendrogram node. Leaves (id < n) are points.
    /// Internal nodes have two children and a merge λ = 1 / edge_weight.
    struct SLNode: Sendable {
        var left: Int   // child id (point or internal node)
        var right: Int
        var lambda: Float
        var size: Int
    }

    /// Build the single-linkage binary dendrogram from MST edges. Returns
    /// the array of internal nodes (size n - 1) and the id of the root.
    /// Internal nodes are indexed starting at `n`.
    static func buildSingleLinkageTree(mstEdges: [MSTEdge], n: Int)
        -> (nodes: [SLNode], root: Int)
    {
        let sorted = mstEdges.sorted { $0.w < $1.w }
        var uf = UnionFind(n: n)
        // Map from union-find root to current "tree id" (point id or
        // internal node id) representing that component.
        var compNode = Array(0..<n)
        var compSize = [Int](repeating: 1, count: n)
        var internalNodes: [SLNode] = []
        internalNodes.reserveCapacity(max(0, n - 1))

        for e in sorted {
            let ra = uf.find(e.u)
            let rb = uf.find(e.v)
            if ra == rb { continue }
            let leftNode = compNode[ra]
            let rightNode = compNode[rb]
            let newSize = compSize[ra] + compSize[rb]
            let lambda = e.w > 0 ? 1 / e.w : Float.greatestFiniteMagnitude
            let newID = n + internalNodes.count
            internalNodes.append(SLNode(left: leftNode,
                                        right: rightNode,
                                        lambda: lambda,
                                        size: newSize))
            let newRoot = uf.union(ra, rb)
            compNode[newRoot] = newID
            compSize[newRoot] = newSize
        }
        let rootID = n + internalNodes.count - 1
        return (internalNodes, rootID)
    }

    /// Condense the dendrogram top-down. At each internal split, if a side
    /// has fewer than `mcs` leaf descendants, all its leaves are recorded
    /// as falling out of the current condensed cluster at the split's λ.
    /// Otherwise that side becomes a new condensed child.
    static func condense(mstEdges: [MSTEdge],
                         nPoints n: Int,
                         minClusterSize mcs: Int) -> [CondensedNode] {
        let (sl, rootSL) = buildSingleLinkageTree(mstEdges: mstEdges, n: n)

        // Helper: size of subtree at dendrogram id x (point or internal).
        func slSize(_ x: Int) -> Int {
            if x < n { return 1 }
            return sl[x - n].size
        }

        // Iterative leaf collection for a given dendrogram subtree.
        func leaves(of root: Int) -> [Int] {
            var out: [Int] = []
            var stack: [Int] = [root]
            while let top = stack.popLast() {
                if top < n {
                    out.append(top)
                } else {
                    let node = sl[top - n]
                    stack.append(node.left)
                    stack.append(node.right)
                }
            }
            return out
        }

        var nodes: [CondensedNode] = []
        nodes.reserveCapacity(max(1, n / max(2, mcs)))

        // Root condensed cluster: whole dataset, born at λ = 0.
        nodes.append(CondensedNode(parent: -1,
                                   birthLambda: 0,
                                   size: n,
                                   children: [],
                                   pointFallOffLambdas: []))

        // Work queue: (slNodeID, condensedClusterID, birthLambdaOfThatCluster).
        // birthLambda is redundant with nodes[id].birthLambda but cached for speed.
        var work: [(Int, Int, Float)] = [(rootSL, 0, 0)]

        while let (slID, condID, _) = work.popLast() {
            // Leaf point: falls off at ∞ (lives to the very end).
            if slID < n {
                nodes[condID].pointFallOffLambdas.append((slID, .greatestFiniteMagnitude))
                continue
            }
            let node = sl[slID - n]
            let lambda = node.lambda
            let lSize = slSize(node.left)
            let rSize = slSize(node.right)
            let lBig = lSize >= mcs
            let rBig = rSize >= mcs

            switch (lBig, rBig) {
            case (false, false):
                // Both sides too small — entire subtree falls out of condID at λ.
                for p in leaves(of: node.left) {
                    nodes[condID].pointFallOffLambdas.append((p, lambda))
                }
                for p in leaves(of: node.right) {
                    nodes[condID].pointFallOffLambdas.append((p, lambda))
                }
            case (true, false):
                // Right falls out; left continues as same cluster.
                for p in leaves(of: node.right) {
                    nodes[condID].pointFallOffLambdas.append((p, lambda))
                }
                work.append((node.left, condID, nodes[condID].birthLambda))
            case (false, true):
                for p in leaves(of: node.left) {
                    nodes[condID].pointFallOffLambdas.append((p, lambda))
                }
                work.append((node.right, condID, nodes[condID].birthLambda))
            case (true, true):
                // True split — birth two new condensed children at λ.
                let leftID = nodes.count
                nodes.append(CondensedNode(parent: condID,
                                           birthLambda: lambda,
                                           size: lSize,
                                           children: [],
                                           pointFallOffLambdas: []))
                let rightID = nodes.count
                nodes.append(CondensedNode(parent: condID,
                                           birthLambda: lambda,
                                           size: rSize,
                                           children: [],
                                           pointFallOffLambdas: []))
                nodes[condID].children.append(leftID)
                nodes[condID].children.append(rightID)
                work.append((node.left, leftID, lambda))
                work.append((node.right, rightID, lambda))
            }
        }

        return nodes
    }

    // MARK: - Excess of Mass extraction

    /// Greedy EoM: for every condensed cluster, compute stability
    /// S(C) = Σ (λ_fall − λ_birth) over all points that fell out of C.
    /// Then walk the tree bottom-up: select C if S(C) ≥ Σ selected
    /// descendants' stability; otherwise propagate the descendants' sum
    /// upward. Selected clusters are non-overlapping by construction.
    /// All points outside the selected clusters become noise (-1).
    static func extractEoM(condensed nodes: [CondensedNode],
                           nPoints n: Int) -> [Int] {
        guard !nodes.isEmpty else { return Array(repeating: -1, count: n) }

        // Stability per node (root is never selectable).
        var stability = [Float](repeating: 0, count: nodes.count)
        for i in 0..<nodes.count {
            let birth = nodes[i].birthLambda
            var s: Float = 0
            for fo in nodes[i].pointFallOffLambdas {
                // Clamp the infinity-lambda leaves: their contribution is
                // effectively (maxFiniteLambda - birth). Using .greatestFiniteMagnitude
                // for surviving leaves would dominate and wreck EoM. Instead
                // treat them as "never fell out" → contribute 0 for the
                // individual leaf case, but their presence is what makes
                // a cluster persist. The canonical HDBSCAN paper uses
                // λ_max of the cluster for survivors; we substitute the
                // max finite λ seen among this node's fallOffs, or the
                // node's birthLambda if none.
                var lam = fo.lambda
                if lam == .greatestFiniteMagnitude {
                    // Compute a sane per-node λ_max on demand (cheap: few survivors).
                    var maxFinite = birth
                    for g in nodes[i].pointFallOffLambdas
                        where g.lambda != .greatestFiniteMagnitude && g.lambda > maxFinite {
                        maxFinite = g.lambda
                    }
                    lam = maxFinite
                }
                s += max(0, lam - birth)
            }
            stability[i] = s
        }

        // Topological order: root last. Because children ids are always
        // allocated after their parents in our construction, a reverse
        // iteration over node ids is a valid bottom-up order.
        var selected = [Bool](repeating: false, count: nodes.count)
        var subtreeStability = stability // mutable copy

        // Root is id 0 — exclude it from selection.
        for id in stride(from: nodes.count - 1, through: 1, by: -1) {
            let childSum = nodes[id].children.reduce(Float(0)) { $0 + subtreeStability[$1] }
            if stability[id] >= childSum && stability[id] > 0 {
                selected[id] = true
                // Deselect any descendants that were previously selected.
                var stack = nodes[id].children
                while let c = stack.popLast() {
                    if selected[c] { selected[c] = false }
                    stack.append(contentsOf: nodes[c].children)
                }
                subtreeStability[id] = stability[id]
            } else {
                subtreeStability[id] = childSum
            }
        }

        // Assign labels. Every point whose fall-off is recorded in a
        // selected cluster's subtree becomes a member of that cluster…
        // BUT we apply a GLOSH-style outlier filter: a point p with
        // fall-off λ_p in a selected leaf cluster C is an outlier
        // (label -1) if (1 - λ_p / λ_max(C)) exceeds `outlierThreshold`.
        //
        // λ_max(C) is the deepest λ any point reaches in C's subtree.
        // This prunes noise points that briefly joined C's single-linkage
        // neighborhood before being dropped as a tiny sub-branch.
        let outlierThreshold: Float = 0.9

        // Precompute λ_max per selected cluster (max over its subtree).
        var lambdaMax = [Float](repeating: 0, count: nodes.count)
        for id in stride(from: nodes.count - 1, through: 0, by: -1) {
            var lm: Float = nodes[id].birthLambda
            for fo in nodes[id].pointFallOffLambdas where fo.lambda > lm {
                lm = fo.lambda
            }
            for c in nodes[id].children where lambdaMax[c] > lm {
                lm = lambdaMax[c]
            }
            lambdaMax[id] = lm
        }

        var labels = [Int](repeating: -1, count: n)
        var nextLabel = 0
        for id in 0..<nodes.count where selected[id] {
            let lmax = lambdaMax[id]
            var stack = [id]
            while let cur = stack.popLast() {
                for fo in nodes[cur].pointFallOffLambdas {
                    let score = lmax > 0 ? (1 - fo.lambda / lmax) : 1
                    if score <= outlierThreshold {
                        labels[fo.point] = nextLabel
                    }
                }
                stack.append(contentsOf: nodes[cur].children)
            }
            nextLabel += 1
        }
        return labels
    }
}

// MARK: - Union-Find with member enumeration

/// A small union-find specialized to keep a linked list of members per
/// root so we can enumerate them cheaply when a small component falls
/// off into a larger cluster as noise.
struct UnionFind {
    private var parent: [Int]
    private var rank: [Int]
    /// Singly linked list: next[i] = next member after i in its component,
    /// or -1 at end. head[root] = first member.
    private var next: [Int]
    private var tail: [Int]

    init(n: Int) {
        parent = Array(0..<n)
        rank = Array(repeating: 0, count: n)
        next = Array(repeating: -1, count: n)
        tail = Array(0..<n) // each singleton's tail is itself
    }

    mutating func find(_ x: Int) -> Int {
        var r = x
        while parent[r] != r { r = parent[r] }
        // Path compression.
        var y = x
        while parent[y] != r {
            let p = parent[y]
            parent[y] = r
            y = p
        }
        return r
    }

    /// Union by rank. Returns the new root.
    @discardableResult
    mutating func union(_ a: Int, _ b: Int) -> Int {
        let ra = find(a)
        let rb = find(b)
        if ra == rb { return ra }
        let newRoot: Int
        let absorbed: Int
        if rank[ra] < rank[rb] {
            parent[ra] = rb
            newRoot = rb; absorbed = ra
        } else if rank[ra] > rank[rb] {
            parent[rb] = ra
            newRoot = ra; absorbed = rb
        } else {
            parent[rb] = ra
            rank[ra] += 1
            newRoot = ra; absorbed = rb
        }
        // Splice member list of `absorbed` onto `newRoot`.
        let tailOfNew = tail[newRoot]
        next[tailOfNew] = absorbed
        tail[newRoot] = tail[absorbed]
        return newRoot
    }

    /// Return all member indices of the component containing `x`.
    func members(of x: Int) -> [Int] {
        // Walk starting from root.
        var r = x
        while parent[r] != r { r = parent[r] }
        var out: [Int] = [r]
        var cur = next[r]
        while cur != -1 {
            out.append(cur)
            cur = next[cur]
        }
        return out
    }
}

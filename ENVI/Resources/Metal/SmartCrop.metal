// ============================================================================
// SmartCrop.metal — Saliency-Guided Smart Crop Kernel Spec
// ============================================================================
// Target: A17 Pro / M4 (Metal 3); graceful degradation on A16–A15
// Input:  RGBA8Unorm texture + R16Float saliency heatmap + face rect buffer
// Output: Float4 best crop rect (x, y, w, h) in device buffer
// Approach: Two-stage compute — (A) blend saliency + faces into importance map,
//           (B) score candidate crop windows across aspect ratios.
// ============================================================================

#include <metal_stdlib>
using namespace metal;

// ============================================================================
// Stage A: saliencyBlend
// ============================================================================

/// Blends CoreML saliency heatmap with face detection rectangles into a
/// unified per-pixel importance map.
///
/// @param srcTexture       Input RGBA8Unorm texture (full resolution)
/// @param saliencyTexture  CoreML saliency heatmap, R16Float (downscaled or same-res)
/// @param faceRects        Buffer of float4 face rectangles [x, y, w, h] in pixel coords
/// @param faceCount        Number of valid face rectangles
/// @param importanceMap    Output importance map, R16Float (same resolution as src)
/// @param gid              2D thread position in grid (pixel coordinate)
kernel void saliencyBlend(
    texture2d<float, access::read>  srcTexture      [[texture(0)]],
    texture2d<float, access::read>  saliencyTexture [[texture(1)]],
    constant float4*                faceRects       [[buffer(0)]],
    constant uint&                  faceCount       [[buffer(1)]],
    texture2d<float, access::write> importanceMap   [[texture(2)]],
    uint2                           gid             [[thread_position_in_grid]]
)
{
    // Implementation note:
    // 1. Read saliency value at gid from saliencyTexture
    //    - If saliencyTexture is downscaled (e.g. 1/4), bilinear sample at
    //      float2(gid) / float2(srcTexture.get_width(), srcTexture.get_height())
    // 2. Initialize importance = saliency * 0.6f (heatmaps are normalized 0–1)
    // 3. For each face rect i in [0, faceCount):
    //    - Compute normalized distance from gid to rect center:
    //      dx = abs(gid.x - (rect.x + rect.z*0.5)) / (rect.z * 0.5)
    //      dy = abs(gid.y - (rect.y + rect.w*0.5)) / (rect.w * 0.5)
    //    - If dx < 1.0 && dy < 1.0: inside face rect → importance += 0.4f
    //    - Else: falloff = exp(-(dx*dx + dy*dy) * 2.0f); importance += 0.4f * falloff
    // 4. Clamp importance to [0.0, 1.0]
    // 5. Write importance to importanceMap at gid
    //
    // Face rect count is typically 0–8. Unroll loop for count <= 4,
    // dynamic loop for 5–8 (rare). Branch divergence minimal because
    // faceCount is uniform across threadgroup.
}

// ============================================================================
// Stage B: smartCropScore
// ============================================================================

/// Scores predefined candidate crop windows and selects the best rect.
///
/// @param importanceMap    Input importance map, R16Float (full resolution)
/// @param faceRects        Buffer of float4 face rectangles [x, y, w, h]
/// @param faceCount        Number of valid face rectangles
/// @param imageSize        Float2 (width, height) of input image
/// @param candidateRatios  Buffer of float2 aspect ratios [w/h, ...] (e.g. 9/16, 1/1, 4/5, 16/9)
/// @param candidateCount   Number of candidate aspect ratios (typically 4–8)
/// @param bestCropRect     Output float4 best crop [x, y, w, h] in pixel coords
/// @param gid              1D thread index = candidate aspect ratio index
kernel void smartCropScore(
    texture2d<float, access::read>  importanceMap   [[texture(0)]],
    constant float4*                faceRects       [[buffer(0)]],
    constant uint&                  faceCount       [[buffer(1)]],
    constant float2&                imageSize       [[buffer(2)]],
    constant float2*                candidateRatios [[buffer(3)]],
    constant uint&                  candidateCount  [[buffer(4)]],
    device   float4*                bestCropRect    [[buffer(5)]],
    uint                            gid             [[thread_position_in_grid]]
)
{
    // Implementation note:
    // 1. Each thread handles ONE candidate aspect ratio at index gid.
    //    If gid >= candidateCount, return immediately.
    // 2. Compute candidate crop dimensions from imageSize and ratio:
    //    ratio = candidateRatios[gid].x / candidateRatios[gid].y
    //    If imageSize.x / imageSize.y > ratio: crop height = imageSize.y,
    //                                           crop width  = imageSize.y * ratio
    //    Else: crop width = imageSize.x, crop height = imageSize.x / ratio
    // 3. Slide crop window across image in N steps (e.g. 8×8 grid of positions).
    //    For each position (cx, cy):
    //    a. Integrated importance: sum importanceMap pixels inside window
    //       → use threadgroup shared memory reduction or atomic_add to shared accumulator
    //    b. Face center proximity: for each face, compute distance from face center
    //       to window center. Penalty = sum(dist^2) / (faceCount + 1)
    //    c. Rule-of-thirds alignment: compute thirds lines at window.cx ± w/6,
    //       window.cy ± h/6. Score = -sum(|faceCenter - thirdsLine|)
    //    d. Edge penalty: if any face rect extends outside window, apply heavy
    //       penalty (1.0 per pixel outside).
    //    e. Composite score = importance * 0.4 + proximity * 0.3 + thirds * 0.2 + edge * 0.1
    // 4. Thread with best score writes best rect to bestCropRect[0].
    //    Use atomic_max on a shared score variable, or reduction in shared mem.
    // 5. After all positions evaluated, one thread (thread 0) writes the winning
    //    float4(x, y, width, height) to bestCropRect buffer.
}

// MARK: - Threadgroup Configuration (A17 Pro Tuned)

/*
--- Stage A: saliencyBlend ---
Grid size (1080p):
    width  = (1920 + 15) / 16 = 120 threadgroups
    height = (1080 + 15) / 16 =  68 threadgroups
    total  = 120 × 68 = 8,160 threadgroups

Threads per threadgroup:
    threadsPerThreadgroup = uint3(16, 16, 1)  // 256 threads

Threadgroups per grid:
    threadgroupsPerGrid   = uint3(120, 68, 1)

Shared memory (Stage A):
    No shared memory required — each thread reads independently.
    Optional: 16×16 tile cache of saliencyTexture if downscaled,
    to reduce texture cache pressure. ~512 B.

Rationale:
    256 threads / 32 SIMD = 8 warps per threadgroup.
    8,160 threadgroups × 8 warps = 65,280 warps → fills A17 Pro GPU.
    Memory-bound kernel; high threadgroup count maximizes latency hiding.

--- Stage B: smartCropScore ---
Grid size:
    One dimension only: threadgroupsPerGrid = uint3(1, 1, 1)
    (All candidate scoring happens within a single threadgroup)

Threads per threadgroup:
    threadsPerThreadgroup = uint3(8, 1, 1)  // 8 threads = 8 candidate ratios max

Shared memory (Stage B):
    importanceAccumulator:  float  (1 × 4 B)     = 4 B
    bestScoreAccumulator:   float  (1 × 4 B)     = 4 B
    bestRectAccumulator:    float4 (1 × 16 B)     = 16 B
    faceCenters (computed): float2 × 8 faces      = 64 B
    windowScores scratch:   float  × 8 candidates = 32 B
    subtotal: ~120 B

    Plus importance map tile (if caching a 32×32 region for fast sum):
    32 × 32 × 2 B (half) = 2,048 B

    Total shared: ~2.2 KB (well under 64 KB)

Rationale:
    Stage B has very few threads (1 per candidate ratio). This is
    intentional — the work per thread is large (scoring many positions),
    and shared memory is used for cross-thread reduction.
    If candidateCount < 8, pad with identity threads that return early.
    A17 Pro supports up to 1,024 threads/threadgroup, so 8 is trivial.
*/

// MARK: - Memory Bandwidth Estimate

/*
For 1080p @ full resolution processing:

--- Stage A ---
Read:
    Input texture (RGBA8Unorm):     1920 × 1080 × 4  =  8.29 MB
    Saliency heatmap (R16Float):    1920 × 1080 × 2  =  4.15 MB
    Face rects buffer:              8 × 16 B         = 128 B (negligible)
    Face count:                     4 B

Write:
    Importance map (R16Float):      1920 × 1080 × 2  =  4.15 MB

Stage A total: 12.44 MB read + 4.15 MB write = 16.59 MB

--- Stage B ---
Read:
    Importance map (R16Float):      1920 × 1080 × 2  =  4.15 MB
    Face rects buffer:              8 × 16 B         = 128 B
    Candidate ratios buffer:        8 × 8 B          = 64 B

Write:
    Best crop rect (float4):        16 B

Stage B total: ~4.15 MB read + 16 B write = ~4.15 MB

Combined per frame:
    ~16.6 MB read + 4.2 MB write = ~20.8 MB/frame
    @ 30 fps → ~624 MB/s

Peak device bandwidth (A17 Pro): ~51 GB/s → ~1.2% utilization
(Heavily compute-bound in Stage B due to scoring iterations.)
*/

// MARK: - Compute Estimate (FLOPs)

/*
--- Stage A: saliencyBlend ---
Per pixel operations:
    Read saliency + bilinear sample:      ~4 FLOPs
    Face rect loop (avg 2 faces):
        - Center computation:             ~6 FLOPs per face
        - Distance + falloff (exp approx):~12 FLOPs per face
        - Importance accumulation:        ~4 FLOPs per face
    Average face ops:                     ~44 FLOPs
    Clamp + write:                        ~2 FLOPs
    Total per pixel: ~50 FLOPs

Per 1080p frame:
    1920 × 1080 × 50 ≈ 103.7 MFLOPs

--- Stage B: smartCropScore ---
Per candidate ratio (avg 4 candidates):
    Window positions evaluated: 8 × 8 = 64 positions per candidate
    Per position:
        - Importance integration (sampling importanceMap):  ~200 FLOPs (64×64 area, bilinear)
        - Face proximity (avg 2 faces):                   ~24 FLOPs
        - Rule-of-thirds alignment:                       ~18 FLOPs
        - Edge penalty check:                             ~16 FLOPs
        - Score composite:                                ~8 FLOPs
    Per position: ~266 FLOPs
    Per candidate: 64 × 266 = 17,024 FLOPs
    All candidates: 4 × 17,024 = 68,096 FLOPs

    Plus shared memory reduction + atomic compare:          ~200 FLOPs
    Total Stage B: ~68.3 KFLOPs (negligible vs Stage A)

Combined per 1080p frame:
    ~103.7 MFLOPs (Stage A) + 0.07 MFLOPs (Stage B) ≈ 103.8 MFLOPs
    @ 30 fps → 3.1 GFLOPS

A17 Pro GPU FP16: ~2+ TFLOPS → utilization ~0.15%
(Stage A is ALU-light; Stage B is control-flow heavy with loop divergence.)
*/

// MARK: - Texture Format

/*
Input:
    srcTexture:       MTLPixelFormatRGBA8Unorm
                      MTLTextureUsageShaderRead
                      Storage: MTLStorageModePrivate

Saliency heatmap:
    saliencyTexture:  MTLPixelFormatR16Float
                      MTLTextureUsageShaderRead
                      Storage: MTLStorageModePrivate
                      (Created from CoreML output CVPixelBuffer via
                       CVMetalTextureCache)

Importance map (intermediate):
    importanceMap:    MTLPixelFormatR16Float
                      MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite
                      Storage: MTLStorageModePrivate

Output:
    bestCropRect:     MTLBuffer, 16 B (float4)
                      Storage: MTLStorageModeShared (CPU needs result)

Face data:
    faceRects:        MTLBuffer, 8 × 16 B = 128 B max
                      Storage: MTLStorageModeShared (updated per frame by Vision)

Candidate ratios:
    candidateRatios:  MTLBuffer, 8 × 8 B = 64 B
                      Storage: MTLStorageModeShared (static)
*/

// MARK: - Fallback Path

/*
Priority 1 (Custom compute kernel — this file):
    Always works on Metal 3 devices. Primary path.

Priority 2 (CoreImage CIFilter + CIFaceFeature):
    CIAspectRatioCrop for each candidate ratio, then score using:
    - CIDetector with CIDetectorTypeFace for face rects
    - CISaliencyMapFilter (iOS 13+) for saliency approximation
    - CICrop + CIContext to test crop windows
    Latency: ~45ms (1080p) — much slower than Metal compute.

Priority 3 (Vision + CoreGraphics):
    VNGenerateAttentionBasedSaliencyImageRequest for saliency.
    VNDetectFaceRectanglesRequest for faces.
    Compute crop rect in Swift using same scoring formula.
    Latency: ~80ms (1080p) on CPU.

Priority 4 (Identity / Center Crop):
    If all above fail, return center-weighted crop at first candidate ratio.
    Never blocks the UI.
*/

// MARK: - Error Handling Strategy

/*
Pipeline error (MTLCommandBufferErrorEncoderInternal):
    1. Log GPU fault, capture frame if Metal Diagnostics enabled.
    2. Recycle MTLDevice via TransformEngine.deviceRecovery().
    3. Retry with CoreImage fallback (Priority 2) for this frame.
    4. If CoreImage also fails, use Vision + CoreGraphics (Priority 3).

OOM (texture allocation failure):
    1. Importance map is only 4.15 MB — unlikely to fail alone.
    2. If pool exhausted: TransformEngine evicts LRU textures.
    3. Retry allocation.
    4. If still failing: skip smart crop, return center crop at 1:1.

Thermal throttling:
    .reduced  → no change (kernel is low power: ~200mW).
    .minimal → skip Stage A if ANE saliency already computed;
                use cached importance map from prior frame.
    .none    → return center crop (no compute).

Saliency / Face detection failure:
    If CoreML saliency request fails (ANE error, model missing):
    - saliencyBlend falls back to uniform 0.5 importance.
    - Face rects from Vision framework still applied if available.
    - If no faces detected, use center-weighted scoring.
    - Never returns nil; always produces a valid crop rect.

Zero faces, zero saliency:
    Default to center crop at the most common ratio (1:1 or 4:5).
    Score = 0.5 for all positions; first valid position wins.
*/

// MARK: - Performance Estimate (A17 Pro)

/*
| Mode                        | Latency | Throughput | Power   | Notes                    |
|-----------------------------|---------|------------|---------|--------------------------|
| Metal 3 (both stages)       | 8.0 ms  | 125 fps    | ~220 mW | Full custom compute      |
| Metal 3 (ANE saliency cached)| 4.5 ms  | 222 fps    | ~150 mW | Skip Stage A; Stage B only|
| CoreImage CIFilter          | 45 ms   | 22 fps     | ~600 mW | Quality matches          |
| Vision + CoreGraphics       | 80 ms   | 12 fps     | ~400 mW | Slower, same quality     |
| Center crop (identity)      | 0.1 ms  | 10k fps    | ~5 mW   | Emergency fallback       |

Target: <8ms @ 1080p for full pipeline (saliency + scoring).
        <5ms if ANE saliency heatmap precomputed (common in ENVI pipeline).

A16 degradation: ~10% slower (SIMD width 32→32, but fewer GPU cores).
A15 degradation: ~25% slower (less L2 cache, older TBDR architecture).
*/

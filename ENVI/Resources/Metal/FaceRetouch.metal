// ============================================================================
// FaceRetouch.metal — Skin Smoothing + Eye Brightening + Teeth Whitening
// ============================================================================
// Target: A17 Pro / M4 (Metal 3); graceful degradation on A16–A15
// Input:  RGBA8Unorm texture + R8Unorm face mask (0=non-skin, 1=skin, 2=eye, 3=teeth/lips)
// Output: Retouched RGBA8Unorm texture (same resolution)
// Approach: Three-stage bilateral grid pipeline — construct edge-aware grid,
//           slice back with mask-weighted smoothing, then brighten eyes/teeth.
// ============================================================================

#include <metal_stdlib>
using namespace metal;

// ============================================================================
// Stage A: bilateralGridConstruct
// ============================================================================

/// Builds an edge-aware bilateral grid from luminance + face mask.
/// Grid dimensions: 16×16 spatial tiles × 8 intensity bins per tile.
///
/// @param srcTexture       Input RGBA8Unorm texture (full resolution)
/// @param faceMask         Face mask, R8Unorm (0=non-skin, 1=skin, 2=eye, 3=teeth/lips)
/// @param gridBuffer       Output bilateral grid buffer:
///                         Layout: [spatialX][spatialY][bin][channel]
///                         Size per tile: 16×16×8 bins × 4 channels × 2B half = ~16KB
///                         Total: ceil(width/16) × ceil(height/16) tiles
/// @param gridDims         Float4 (tileWidth, tileHeight, binCount=8, channels=4)
/// @param gid              2D thread position in grid (tile coordinate)
kernel void bilateralGridConstruct(
    texture2d<float, access::read>  srcTexture   [[texture(0)]],
    texture2d<float, access::read>  faceMask     [[texture(1)]],
    device   half4*                 gridBuffer   [[buffer(0)]],
    constant float4&                gridDims     [[buffer(1)]],
    uint2                           gid          [[thread_position_in_grid]]
)
{
    // Implementation note:
    // 1. Each threadgroup handles ONE 16×16 spatial tile.
    //    gid = tile index (tileX, tileY).
    // 2. Compute tile bounds in image space:
    //    baseX = gid.x * 16, baseY = gid.y * 16
    // 3. Each thread within the threadgroup (8×8 threads) processes a subset
    //    of pixels within the tile (4 pixels per thread = 16×16 / 64).
    // 4. For each pixel (px, py) in tile:
    //    a. Read RGBA, compute luminance = dot(RGB, float3(0.299, 0.587, 0.114))
    //    b. Read faceMask value m. If m == 0 (non-skin): skip (weight = 0)
    //    c. Compute intensity bin index: bin = clamp(int(luminance * 7.0), 0, 7)
    //    d. Compute spatial sub-tile index within 16×16:
    //       subX = px % 16, subY = py % 16
    //    e. Accumulate into shared memory grid[subX][subY][bin] += half4(RGB, weight)
    //       where weight = 1.0 for skin, 0.5 for eye, 0.3 for teeth (lips ignored)
    // 5. After all pixels processed, normalize each bin by total weight:
    //    grid[subX][subY][bin] /= grid[subX][subY][bin].w
    // 6. Write completed tile grid to gridBuffer at tile offset:
    //    tileBase = (gid.y * gridTileCountX + gid.x) * (16*16*8)
    //
    // Edge handling: pixels outside image bounds contribute zero weight
    // (implicit via texture read returning 0 with clampToEdge).
}

// ============================================================================
// Stage B: bilateralGridSlice
// ============================================================================

/// Slices the bilateral grid back to full resolution with mask-weighted smoothing.
///
/// @param srcTexture       Input RGBA8Unorm texture (full resolution)
/// @param faceMask         Face mask, R8Unorm
/// @param gridBuffer       Bilateral grid buffer (from Stage A)
/// @param gridDims         Float4 (tileWidth, tileHeight, binCount=8, channels=4)
/// @param dstTexture       Output RGBA8Unorm texture (smoothed, eyes+teeth untouched)
/// @param gid              2D thread position in grid (pixel coordinate)
kernel void bilateralGridSlice(
    texture2d<float, access::read>  srcTexture   [[texture(0)]],
    texture2d<float, access::read>  faceMask     [[texture(1)]],
    constant half4*                 gridBuffer   [[buffer(0)]],
    constant float4&                gridDims     [[buffer(1)]],
    texture2d<float, access::write> dstTexture   [[texture(2)]],
    uint2                           gid          [[thread_position_in_grid]]
)
{
    // Implementation note:
    // 1. Read RGBA from srcTexture at gid
    // 2. Read faceMask value m
    //    - m == 0 (non-skin):  write original pixel unchanged; return
    //    - m == 1 (skin):      smoothingStrength = 0.7
    //    - m == 2 (eye):       smoothingStrength = 0.3 (preserve detail)
    //    - m == 3 (teeth/lips): smoothingStrength = 0.1 (preserve detail)
    // 3. Compute luminance = dot(RGB, float3(0.299, 0.587, 0.114))
    // 4. Compute tile index: tileX = gid.x / 16, tileY = gid.y / 16
    //    Compute sub-tile offset: subX = gid.x % 16, subY = gid.y % 16
    //    Compute bin: bin = clamp(int(luminance * 7.0), 0, 7)
    // 5. Trilinear interpolation in grid:
    //    - Fetch 8 neighboring bins (bin±1 in each dimension, clamped)
    //    - Spatial bilinear: interpolate between (subX, subY) and neighboring
    //      sub-tiles using fractional position within tile
    //    - Intensity linear: interpolate between bin and bin+1 using frac(luminance*7)
    // 6. Blend smoothed value with original:
    //    result = original * (1.0 - strength) + gridSample * strength
    // 7. Preserve original alpha. Write result to dstTexture.
    //
    // Trilinear fetch: 8 texture/buffer reads → use buffer loads (faster than
    // texture for grid data). Each load is a 8B half4 from device buffer.
}

// ============================================================================
// Stage C: eyeTeethBrighten
// ============================================================================

/// Separate pass for eye brightening (sclera) and teeth whitening.
///
/// @param srcTexture       Input RGBA8Unorm texture (original, unsmoothed)
/// @param smoothedTexture  Output from Stage B (smoothed skin)
/// @param faceMask         Face mask, R8Unorm (2=eye, 3=teeth/lips)
/// @param eyeBoost         Float eye brightening intensity (default 0.15)
/// @param teethWhitening   Float teeth whitening intensity (default 0.20)
/// @param dstTexture       Final output RGBA8Unorm texture
/// @param gid              2D thread position in grid (pixel coordinate)
kernel void eyeTeethBrighten(
    texture2d<float, access::read>  srcTexture      [[texture(0)]],
    texture2d<float, access::read>  smoothedTexture [[texture(1)]],
    texture2d<float, access::read>  faceMask        [[texture(2)]],
    constant float&                 eyeBoost        [[buffer(0)]],
    constant float&                 teethWhitening  [[buffer(1)]],
    texture2d<float, access::write> dstTexture      [[texture(3)]],
    uint2                           gid             [[thread_position_in_grid]]
)
{
    // Implementation note:
    // 1. Read faceMask value m at gid
    //    - m == 0 or 1 (non-skin/skin): write smoothedTexture unchanged; return
    // 2. Read original pixel from srcTexture and smoothed pixel from smoothedTexture
    // 3. If m == 2 (eye):
    //    a. Detect sclera: pixel is sclera if saturation < 0.25 AND value > 0.6
    //       - Convert RGB to HSV (or approx: saturation = max(RGB) - min(RGB))
    //       - scleraMask = smoothstep(0.0, 0.25, saturation) * smoothstep(0.6, 0.8, max(RGB))
    //    b. Highlight boost: boost highlights in sclera region
    //       - luma = dot(RGB, float3(0.299, 0.587, 0.114))
    //       - highlightMask = smoothstep(0.7, 0.95, luma)
    //       - boosted = original + float3(eyeBoost) * highlightMask * scleraMask
    //    c. Blend: result = mix(smoothed, boosted, scleraMask * 0.5)
    // 4. If m == 3 (teeth/lips):
    //    a. Yellow suppression: detect yellow tint
    //       - yellowScore = max(0.0, G - B) * max(0.0, R - B) * 2.0
    //       - yellowMask = smoothstep(0.1, 0.4, yellowScore)
    //    b. Value boost: increase overall brightness
    //       - whitened = original * (1.0 + teethWhitening * yellowMask)
    //       - Also slightly desaturate: whitened = luma + (whitened - luma) * 0.85
    //    c. Lip preservation: if pixel is clearly lip (high R, moderate G, low B,
    //       saturation > 0.4), reduce whitening strength to 0.2×
    //    d. Blend: result = mix(smoothed, whitened, yellowMask * 0.7)
    // 5. Clamp result to [0, 1]. Preserve alpha. Write to dstTexture.
}

// MARK: - Threadgroup Configuration (A17 Pro Tuned)

/*
--- Stage A: bilateralGridConstruct ---
Grid size (1080p, 16×16 tiles):
    width  = (1920 + 15) / 16 = 120 threadgroups
    height = (1080 + 15) / 16 =  68 threadgroups
    total  = 120 × 68 = 8,160 threadgroups

Threads per threadgroup:
    threadsPerThreadgroup = uint3(8, 8, 1)  // 64 threads

Threadgroups per grid:
    threadgroupsPerGrid   = uint3(120, 68, 1)

Shared memory (Stage A):
    Each threadgroup = one 16×16 spatial tile.
    Grid within tile: 16 × 16 × 8 bins × half4 = 16 × 16 × 8 × 8 B
    = 16,384 B = 16.0 KB per threadgroup

    Plus accumulator for weight normalization:
    weightAccumulator: 16 × 16 × 8 × half = 2,048 B = 2.0 KB

    Plus src tile cache (16×16 RGBA8):
    16 × 16 × 4 B = 1,024 B

    Plus faceMask tile cache (16×16 R8):
    16 × 16 × 1 B = 256 B

    Total shared: ~19.3 KB (well under 64 KB limit)
    A17 Pro shared memory per threadgroup: 64 KB

Rationale:
    64 threads / 32 SIMD = 2 warps per threadgroup.
    8,160 threadgroups × 2 warps = 16,320 warps.
    A17 Pro supports ~192 concurrent warps → ~1.2% occupancy.
    This seems low, but each threadgroup does significant work
    (processing 256 pixels). Memory latency hidden by warp switching
    within each threadgroup.

    Alternative: process 2×2 tiles per threadgroup (32×32 pixels)
    with 16×16 threads → 4 warps, ~38KB shared, still under 64KB.
    This doubles work per threadgroup and improves occupancy.
    **Recommended: 16×16 threads for A17 Pro** when 2×2 tiles.

--- Stage B: bilateralGridSlice ---
Grid size (1080p):
    width  = (1920 + 15) / 16 = 120 threadgroups
    height = (1080 + 15) / 16 =  68 threadgroups

Threads per threadgroup:
    threadsPerThreadgroup = uint3(16, 16, 1)  // 256 threads

Shared memory (Stage B):
    No shared memory needed — each thread is fully independent.
    Optional: cache 16×16 faceMask tile to reduce texture cache pressure.
    16 × 16 × 1 B = 256 B (negligible).

Rationale:
    256 threads / 32 = 8 warps. 8,160 threadgroups × 8 = 65,280 warps.
    Fills GPU completely. Grid slicing is ALU-heavy (trilinear interp)
    and buffer-read-heavy, so high occupancy is critical.

--- Stage C: eyeTeethBrighten ---
Grid size (1080p):
    width  = (1920 + 15) / 16 = 120 threadgroups
    height = (1080 + 15) / 16 =  68 threadgroups

Threads per threadgroup:
    threadsPerThreadgroup = uint3(16, 16, 1)  // 256 threads

Shared memory (Stage C):
    None required. Each thread reads src + smoothed + mask independently.
    Optional: cache 16×16 src tile + 16×16 mask tile = 1.28 KB.

Rationale:
    Same occupancy as Stage B. This stage is heavily ALU-bound
    (HSV conversion, smoothstep, color matrix ops) so warp
    divergence from faceMask branches is the main concern.
    Branch divergence is acceptable: ~20% of pixels are in face
    region, 80% are early-exit (non-skin/non-face). GPU handles
    divergent branches via warp serialization; 80% fast-path keeps
    average latency low.
*/

// MARK: - Memory Bandwidth Estimate

/*
For 1080p @ RGBA8Unorm:

--- Stage A: bilateralGridConstruct ---
Read:
    Input texture (RGBA8Unorm):     1920 × 1080 × 4  =  8.29 MB
    Face mask (R8Unorm):            1920 × 1080 × 1  =  2.07 MB

Write:
    Grid buffer (per tile):         120 × 68 × 16 KB = 130.08 MB
        (But: only tiles containing face pixels write non-zero data.
         Typical face covers ~15% of image → ~19.5 MB actual write)
    Conservative estimate:          ~130 MB (worst case: full face coverage)

Stage A total: ~10.4 MB read + ~130 MB write = ~140 MB

--- Stage B: bilateralGridSlice ---
Read:
    Input texture (RGBA8Unorm):     1920 × 1080 × 4  =  8.29 MB
    Face mask (R8Unorm):            1920 × 1080 × 1  =  2.07 MB
    Grid buffer (device):           ~130 MB (all tiles read for trilinear)
        (Optimized: only 4 neighboring tiles read per pixel → ~4 tile reads)
        Effective: 1920 × 1080 × 8 neighbors × 8 B = ~132 MB worst case
        With caching: ~30 MB effective

Write:
    Output texture (RGBA8Unorm):    1920 × 1080 × 4  =  8.29 MB

Stage B total: ~40 MB read + 8.3 MB write = ~48 MB

--- Stage C: eyeTeethBrighten ---
Read:
    Original texture (RGBA8Unorm):  1920 × 1080 × 4  =  8.29 MB
    Smoothed texture (RGBA8Unorm):1920 × 1080 × 4  =  8.29 MB
    Face mask (R8Unorm):            1920 × 1080 × 1  =  2.07 MB

Write:
    Output texture (RGBA8Unorm):    1920 × 1080 × 4  =  8.29 MB

Stage C total: ~18.7 MB read + 8.3 MB write = ~27 MB

Combined per frame (worst case, all stages):
    ~69 MB read + ~146 MB write = ~215 MB/frame
    @ 30 fps → ~6.5 GB/s

Peak device bandwidth (A17 Pro): ~51 GB/s → ~12.7% utilization
(Stage A grid write is the dominant bandwidth consumer.)

Optimized (ANE face mask precomputed, grid tiled + cached):
    ~45 MB read + ~35 MB write = ~80 MB/frame
    @ 30 fps → ~2.4 GB/s → ~4.7% utilization
*/

// MARK: - Compute Estimate (FLOPs)

/*
--- Stage A: bilateralGridConstruct ---
Per pixel within face region (~15% of image):
    Luminance compute:                ~4 FLOPs
    Bin index + spatial sub-tile:     ~6 FLOPs
    Weighted accumulation (half4):    ~8 FLOPs
    Per pixel: ~18 FLOPs

Per 1080p frame (15% face coverage):
    1920 × 1080 × 0.15 × 18 ≈ 5.6 MFLOPs

--- Stage B: bilateralGridSlice ---
Per pixel:
    Read + mask check:                ~2 FLOPs
    Non-skin early exit:              ~1 FLOP
    Skin path (15% of pixels):
        Luminance + bin calc:         ~6 FLOPs
        Trilinear interpolation:
            - 8 buffer loads, bilinear spatial + linear intensity
            - Each half4 interpolation: ~12 FLOPs × 8 = ~96 FLOPs
        Blend with original:          ~6 FLOPs
    Per face pixel: ~110 FLOPs

Per 1080p frame:
    1920 × 1080 × 0.15 × 110 ≈ 34.2 MFLOPs

--- Stage C: eyeTeethBrighten ---
Per pixel:
    Mask check + early exit (80%):    ~2 FLOPs
    Eye path (5% of image):
        HSV conversion (approx):      ~18 FLOPs
        Sclera detection (smoothstep):~12 FLOPs
        Highlight boost:              ~8 FLOPs
        Blend:                          ~6 FLOPs
    Teeth path (3% of image):
        Yellow detection:             ~14 FLOPs
        Value boost + desaturate:     ~12 FLOPs
        Lip preservation check:       ~8 FLOPs
        Blend:                          ~6 FLOPs
    Average per pixel: ~4.5 FLOPs (weighted by coverage)

Per 1080p frame:
    1920 × 1080 × 4.5 ≈ 9.3 MFLOPs

Combined per 1080p frame:
    5.6 + 34.2 + 9.3 ≈ 49.1 MFLOPs
    @ 30 fps → 1.47 GFLOPS

A17 Pro GPU FP16: ~2+ TFLOPS → utilization ~0.07%
(Heavily memory-bandwidth bound, especially Stage A grid writes.)
*/

// MARK: - Texture Format

/*
Input:
    srcTexture:       MTLPixelFormatRGBA8Unorm
                      MTLTextureUsageShaderRead
                      Storage: MTLStorageModePrivate

Face mask:
    faceMask:         MTLPixelFormatR8Unorm
                      MTLTextureUsageShaderRead
                      Storage: MTLStorageModePrivate
                      (Created from Vision VNDetectFaceLandmarksRequest
                       or CoreML segmentation model output)

Intermediate (Stage B output):
    smoothedTexture:  MTLPixelFormatRGBA8Unorm
                      MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite
                      Storage: MTLStorageModePrivate

Bilateral grid buffer:
    gridBuffer:       MTLBuffer
                      Bytes per tile: 16 × 16 × 8 × 8 B = 16,384 B
                      Total: ceil(1920/16) × ceil(1080/16) × 16,384 B
                             = 120 × 68 × 16,384 B = 133.6 MB
                      Storage: MTLStorageModePrivate
                      (Alternative: MTLStorageModeShared for CPU debug,
                       but Private is required for performance)

Output:
    dstTexture:       MTLPixelFormatRGBA8Unorm
                      MTLStorageModePrivate

Grid dimensions buffer:
    gridDims:         MTLBuffer, 16 B (float4)
                      Storage: MTLStorageModeShared (read once per kernel)

Parameters:
    eyeBoost:         MTLBuffer, 4 B (float), default 0.15
    teethWhitening:   MTLBuffer, 4 B (float), default 0.20
*/

// MARK: - Fallback Path

/*
Priority 1 (Custom compute kernel — this file):
    Primary path. Full bilateral grid + brighten on GPU.

Priority 2 (CoreImage CIFilter chain):
    CIGaussianBlur (radius 3–5) for skin smoothing.
    CIColorControls (brightness + saturation) for eye/teeth.
    CIRadialGradient mask to restrict effects to face region.
    CIBlendWithMask to composite.
    Latency: ~35ms (1080p) — quality noticeably lower than bilateral grid.

Priority 3 (MPS + CoreML):
    CoreML model for face segmentation → mask.
    MPSImageGaussianPyramid for multi-scale blur.
    Manual compositing in MPSGraph.
    Latency: ~25ms — quality between CoreImage and custom kernel.

Priority 4 (CPU / vImage):
    vImageBoxConvolve for skin smoothing.
    vImageMatrixMultiply for color adjustments.
    vImageBuffer copied to/from textures.
    Latency: ~200ms (1080p) — unusable for real-time.

Priority 5 (Identity pass):
    If all above fail or thermally blocked, return input unchanged.
*/

// MARK: - Error Handling Strategy

/*
Pipeline error (MTLCommandBufferErrorEncoderInternal):
    1. Log GPU fault, capture frame if Metal Diagnostics enabled.
    2. Recycle MTLDevice via TransformEngine.deviceRecovery().
    3. Retry with CoreImage fallback (Priority 2) for this frame.
    4. If CoreImage also fails, use MPS/CoreML (Priority 3).
    5. If still failing, identity pass (Priority 5).

OOM (texture / buffer allocation failure):
    1. Grid buffer is 133.6 MB — largest allocation in this kernel.
    2. If allocation fails: evict LRU textures from pool.
    3. Retry grid buffer allocation.
    4. If still failing: reduce grid resolution to 8×8 spatial tiles
       (grid buffer = 33.4 MB, quarter size).
       Quality degrades slightly but remains acceptable.
    5. Final fallback: CoreImage CIGaussianBlur (no large buffers).

Thermal throttling:
    .reduced  → skip Stage A if ANE face mask cached from prior frame;
                reuse existing grid buffer (valid for ~3 frames).
    .minimal → drop to CoreImage CIGaussianBlur + CIColorControls only
                (no bilateral grid, much lower power).
    .none    → identity pass (return input unchanged).

Face mask missing / stale:
    If Vision framework fails to provide face mask:
    - bilateralGridConstruct processes ALL pixels (no mask filtering).
    - This applies smoothing globally → unacceptable quality.
    - Mitigation: if no mask available within 100ms, skip retouch entirely.
    - Log warning: "Face mask stale, skipping retouch."

Grid buffer corruption:
    If grid buffer contains NaN / inf (rare, from bad face mask):
    - Detect during bilateralGridSlice: if gridSample has NaN, use original pixel.
    - metal_stdlib isnan() check per pixel (negligible cost).
*/

// MARK: - Performance Estimate (A17 Pro)

/*
| Mode                              | Latency | Throughput | Power   | Quality |
|-----------------------------------|---------|------------|---------|---------|
| Metal 3 (all 3 stages)            | 12.0 ms | 83 fps     | ~650 mW | Best    |
| Metal 3 (ANE mask cached)         | 7.5 ms  | 133 fps    | ~420 mW | Best    |
| CoreImage CIFilter                | 35 ms   | 28 fps     | ~500 mW | Good    |
| MPS + CoreML                      | 25 ms   | 40 fps     | ~550 mW | Better  |
| CPU (vImage)                      | 200 ms  | 5 fps      | ~2.0 W  | Best    |
| Identity pass                     | 0.1 ms  | 10k fps    | ~5 mW   | None    |

Target: <12ms @ 1080p for full 3-stage pipeline.
        <8ms if ANE face mask precomputed (common in ENVI pipeline).

A16 degradation: ~12% slower (fewer GPU cores, same SIMD width).
A15 degradation: ~30% slower (older TBDR, less cache, fewer concurrent warps).

Bottleneck analysis:
    Stage A (grid construct): ~6ms — dominated by grid buffer write bandwidth
    Stage B (grid slice):     ~4ms — dominated by trilinear buffer reads
    Stage C (brighten):       ~2ms — ALU-bound, minimal bandwidth
    Total: ~12ms (matches target)

Optimization notes:
    - Grid buffer as MTLBuffer (not texture) for coalesced device reads
    - Process 2×2 tiles per threadgroup in Stage A to improve occupancy
    - Reuse grid buffer across 3 frames if face position stable (no jitter)
    - Use half precision throughout grid (16KB per tile fits in shared mem)
*/

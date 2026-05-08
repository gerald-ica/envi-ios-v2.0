// ============================================================================
// ObjectRemoval.metal — AI-Powered Object Inpainting Kernel Spec
// ============================================================================
// Target: A17 Pro / M4 (Metal 3), graceful degradation to A16/A15/A14
// Input:  1080p RGBA texture (1920×1080) + R8Unorm mask
// Output: Inpainted RGBA texture (1920×1080)
// Approach: Two-pass kernel — Pass A: patch-match coarse fill; Pass B:
//           diffusion-based refinement (CoreML decode on ANE).
// ============================================================================

#include <metal_stdlib>
using namespace metal;

// MARK: - Data Structures

/// Patch-match candidate for a single pixel fill.
struct PatchCandidate {
    int2  offset;       // relative offset in search window
    float ssdScore;     // YUV-space SSD (lower is better)
};

// MARK: ─────────────────────────────────────────────────────────────────
//  PASS A — patchMatchFill
//  Coarse fill using patch-match algorithm.
// ──────────────────────────────────────────────────────────────────────

/// For each masked pixel, find best-matching 5×5 patch from the valid region
/// using SSD in YUV space. Search radius: 32 px initially, refine to 8 px.
///
/// @param srcTexture     Input RGBA8Unorm texture
/// @param maskTexture    Binary mask: 1.0 = pixel to remove, 0.0 = valid
/// @param dstTexture     Output RGBA8Unorm coarse-fill texture
/// @param searchRadius   Initial search radius (pixels), typically 32
/// @param refineRadius   Refined search radius (pixels), typically 8
/// @param gid            2D thread position in grid
kernel void patchMatchFill(
    texture2d<float, access::read>  srcTexture    [[texture(0)]],
    texture2d<float, access::read>  maskTexture   [[texture(1)]],
    texture2d<float, access::write> dstTexture    [[texture(2)]],
    constant int&                   searchRadius  [[buffer(0)]],
    constant int&                   refineRadius  [[buffer(1)]],
    uint2                           gid           [[thread_position_in_grid]]
)
{
    // Implementation note:
    // 1. Each thread handles one masked pixel within a 4×4 tile.
    // 2. Threadgroup = 8×8 threads → 32×32 pixel coverage.
    // 3. Load 16×16 source patch into threadgroup shared memory (includes halo).
    // 4. For each masked pixel, build 5×5 template from surrounding valid pixels.
    // 5. Search spiral: 64 candidates in initial 32px radius → 16 candidates in
    //    refined 8px radius (quarter-resolution coarse search first).
    // 6. Compute SSD in YUV space (RGB→YUV matrix in constant buffer).
    // 7. Best candidate wins; write RGBA directly to dstTexture.
    //
    // Branch divergence handled by early-exit for non-masked pixels.
}

// MARK: - Threadgroup Configuration (Pass A)

/*
Grid size (input space 1920×1080):
    width  = (1920 + 31) / 32 = 60  threadgroups
    height = (1080 + 31) / 32 = 34  threadgroups
    total  = 60 × 34 = 2,040 threadgroups

Threads per threadgroup:
    threadsPerThreadgroup = uint3(8, 8, 1)  // 64 threads

Threadgroups per grid:
    threadgroupsPerGrid   = uint3(60, 34, 1)

Per-thread work:
    Each thread covers a 4×4 tile of masked pixels (16 pixels total).
    If a pixel is not masked, thread skips (coherent within warp usually).

Shared memory layout (per threadgroup):
    16×16 source tile  = 256 pixels × 4 channels × 1 byte ≈ 1.0 KB
    5×5  template buf  =  25 pixels × 4 channels × 2 bytes (half) ≈ 200 B
    Candidate offsets  =  64 offsets × 8 bytes (int2 + float) ≈ 512 B
    Total: ~1.7 KB (well under 64 KB)

Rationale:
    8×8 threads × 4×4 pixels = 32×32 tile per threadgroup.
    Source patch 16×16 = 32×32 + 2×halo (5×5 search context) — covers all
    candidates within 32px radius for any pixel in the 32×32 output tile.
    TBDR tile memory on A17 Pro handles this efficiently.
*/

// MARK: - Memory Bandwidth Estimate (Pass A)

/*
For 1080p @ RGBA8Unorm with 10% mask coverage:

Read:
    Input texture (1080p):            1920 × 1080 × 4         =   8.29 MB
    Mask texture (R8Unorm):           1920 × 1080 × 1         =   2.07 MB
    Search buffer (candidate offsets): 64 × 2,040 threads    ≈ 128 KB
    YUV conversion matrix (constant):   9 × 4 bytes            ≈  36 B

Write:
    Coarse output texture:            1920 × 1080 × 4         =   8.29 MB
    Intermediate SSD scores (tile):   ~256 KB (shared, never off-chip)

Total off-chip bandwidth (frame):
    ~10.4 MB read + 8.3 MB write = 18.7 MB/frame
    @ 5 fps (heavy inpaint) → ~93 MB/s

Peak device bandwidth (A17 Pro): ~51 GB/s → ~0.2% utilization
Memory latency bound due to random-access search pattern.
*/

// MARK: - Compute Estimate (Pass A)

/*
SSD per 5×5 patch candidate in YUV space:
    RGB → YUV:        3 channels × 3 muls + 3 adds = 12 FLOPs per pixel
    Difference:       3 channels × 1 sub           =  3 FLOPs per pixel
    Square:           3 channels × 1 mul           =  3 FLOPs per pixel
    Accumulate:       3 channels × 1 add           =  3 FLOPs per pixel
    Total per pixel:  21 FLOPs
    5×5 patch:        25 pixels × 21               = 525 FLOPs per candidate

Candidate search per masked pixel:
    Initial spiral:   64 candidates  × 525 FLOPs  ≈ 33.6K FLOPs
    Refine spiral:    16 candidates  × 525 FLOPs  ≈  8.4K FLOPs
    Per-pixel total:                              ≈ 42.0K FLOPs

Per 1080p frame (10% masked = ~207K pixels):
    207,360 pixels × 42K FLOPs ≈ 8.7 GFLOPs

A17 Pro GPU FP16: ~2+ TFLOPS → utilization ~0.4%
(Heavily latency-bound; actual throughput ~200ms/frame)
*/

// MARK: ─────────────────────────────────────────────────────────────────
//  PASS B — diffusionRefine
//  Decode step of lightweight diffusion model (CoreML pipeline).
// ──────────────────────────────────────────────────────────────────────

/// Final decode step of a 64-channel latent diffusion model.
/// Takes latent tensor (64 × H/8 × W/8) + mask and runs 4 upsampling
/// convolutions to full resolution. Designed for ANE on A17 Pro;
/// falls back to GPU compute for A16/A15.
///
/// @param latentBuffer     Latent tensor: 64 × 240 × 135  (half4 or buffer)
/// @param maskTexture      Binary mask: R8Unorm (same dims as output)
/// @param coarseTexture    Coarse fill from Pass A (for blending)
/// @param dstTexture       Final inpainted output RGBA8Unorm
/// @param decodeWeights    4-layer decode conv weights (buffer)
/// @param gid              2D thread position in grid
kernel void diffusionRefine(
    device   half4*                 latentBuffer   [[buffer(0)]],
    texture2d<float, access::read>  maskTexture    [[texture(0)]],
    texture2d<float, access::read>  coarseTexture  [[texture(1)]],
    texture2d<float, access::write> dstTexture     [[texture(2)]],
    constant float*                 decodeWeights  [[buffer(1)]],
    uint2                           gid            [[thread_position_in_grid]]
)
{
    // Implementation note:
    // 1. Read latent position (gid / 8) from latentBuffer (64 channels).
    // 2. Run 4 transposed-convolution (deconv) layers:
    //    Layer 1: 64ch → 128ch, 4×4 stride 2 (upsample 2×)
    //    Layer 2: 128ch → 64ch, 4×4 stride 2 (upsample 2×)
    //    Layer 3: 64ch → 32ch, 3×3 stride 1
    //    Layer 4: 32ch → 3ch, 3×3 stride 1 (RGB output)
    // 3. Blend with coarseTexture based on maskTexture:
    //    out = mask * refined + (1-mask) * coarse
    // 4. Clamp and write RGBA to dstTexture.
    //
    // On A17 Pro, this kernel is NOT used — CoreML ANE handles the
    // entire diffusion pipeline. This kernel exists for A16/A15 GPU
    // fallback when ANE is unavailable.
}

// MARK: - Threadgroup Configuration (Pass B)

/*
Grid size (output space 1920×1080):
    width  = (1920 + 31) / 32 = 60  threadgroups
    height = (1080 + 31) / 32 = 34  threadgroups
    total  = 60 × 34 = 2,040 threadgroups

Threads per threadgroup:
    threadsPerThreadgroup = uint3(16, 16, 1)  // 256 threads

Threadgroups per grid:
    threadgroupsPerGrid   = uint3(60, 34, 1)

Per-thread work:
    Each thread processes 2×2 output pixels (coarse thread parallelism
    for deconvolution stride-2). 16×16 threads → 32×32 output tile.
    Each thread reads from latent at (gid/8) and performs 4 conv layers.

Shared memory layout (per threadgroup):
    Latent tile:         8×8 × 64ch × 2B (half)  ≈   8.2 KB
    Layer 1 output:      16×16 × 128ch × 2B      ≈  65.5 KB  → too large
    Instead: stream 2 layers at a time via ping-pong:
    Ping-pong buffers:   16×16 × 64ch × 2B × 2   ≈  65.5 KB
    Weights (layer 1):   64×128 × 4×4 × 2B       ≈  32.8 KB
    Total: ~106 KB  → EXCEEDS 64 KB limit.

Revised layout (A16/A15 GPU fallback):
    threadsPerThreadgroup = uint3(8, 8, 1)  // 64 threads
    Output tile: 16×16 pixels
    Latent tile: 4×4 × 64ch × 2B              ≈   2.0 KB
    Ping-pong intermediate: 16×16 × 32ch × 2B × 2 ≈  32.8 KB
    Weights (streamed per layer): ~8 KB
    Total: ~43 KB (within 64 KB)

Use 8×8 for Pass B GPU path. ANE path (A17) uses CoreML, not this kernel.
*/

// MARK: - Memory Bandwidth Estimate (Pass B)

/*
For 1080p decode (latent 240×135 × 64ch):

Read:
    Latent tensor:            240 × 135 × 64 × 2B            =   4.15 MB
    Mask texture (R8Unorm):   1920 × 1080 × 1                =   2.07 MB
    Coarse texture:           1920 × 1080 × 4                =   8.29 MB
    Decode weights:           ~4.5 MB (static, cached)

Write:
    Final output texture:     1920 × 1080 × 4                =   8.29 MB
    Intermediate activations: 1920 × 1080 × 32ch × 2B × 2    = 264.0 MB
        (tiled: only 2 layers resident = ~16.5 MB effective)

Total off-chip bandwidth (frame, GPU path):
    ~14.5 MB read + 8.3 MB write = 22.8 MB/frame
    @ 1 fps (diffusion heavy) → ~23 MB/s

ANE path (A17 Pro):
    Latent upload:    ~4.15 MB
    Output download:  ~8.29 MB
    On-chip compute:  ~95% of work (ANE internal bandwidth ~500 GB/s)
    Off-chip: ~12.4 MB/frame → negligible
*/

// MARK: - Compute Estimate (Pass B)

/*
Decode network: 4 upsampling convolution layers
    Layer 1: 64ch → 128ch, 4×4 kernel, stride 2, 240×135 → 480×270
             480×270 × 128 × (4×4 × 64) = ~1.7B MACs
    Layer 2: 128ch → 64ch, 4×4 kernel, stride 2, 480×270 → 960×540
             960×540 × 64 × (4×4 × 128) = ~5.1B MACs
    Layer 3: 64ch → 32ch, 3×3 kernel, stride 1, 960×540
             960×540 × 32 × (3×3 × 64)  = ~2.9B MACs
    Layer 4: 32ch → 3ch, 3×3 kernel, stride 1, 1920×1080
             1920×1080 × 3 × (3×3 × 32)  = ~1.8B MACs
    Total: ~11.5B MACs = ~23 GFLOPs

A17 Pro ANE: ~35 TOPS → ~0.66 ms theoretical
A17 Pro GPU: ~2+ TFLOPS → ~11.5 ms theoretical
    (Memory bandwidth bound in practice: ~800ms–1.5s per image)

Note: Full diffusion includes 4–8 denoising steps before decode.
    Total diffusion: 8 steps × 23 GFLOPs = 184 GFLOPs
    ANE: ~5–25 ms per step → 40–200 ms total
    GPU: ~200–400 ms per step → 1.6–3.2 s total
*/

// MARK: - Texture Format

/*
Input:
    MTLPixelFormatRGBA8Unorm
    MTLTextureUsageShaderRead
    Storage: MTLStorageModePrivate

Mask:
    MTLPixelFormatR8Unorm
    MTLTextureUsageShaderRead
    Storage: MTLStorageModePrivate

Coarse fill (Pass A output):
    MTLPixelFormatRGBA8Unorm
    MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite
    Storage: MTLStorageModePrivate

Intermediate (Pass A search):
    MTLPixelFormatR16Float  (SSD score buffer per candidate)
    MTLBuffer with stride = numCandidates × sizeof(half)

Latent tensor (Pass B input):
    MTLPixelFormatRGBA16Float (pack 4 half channels per pixel)
    Or MTLBuffer: 64 × 240 × 135 × 2B = 4.15 MB
    Storage: MTLStorageModeShared (ANE requires shared memory)

Final output:
    MTLPixelFormatRGBA8Unorm
    MTLTextureUsageShaderWrite
    Storage: MTLStorageModePrivate

CoreML model (ANE path):
    MLMultiArray of shape [1, 64, 135, 240], MLMultiArrayDataTypeFloat16
    Compiled with MLComputeUnitsAll (ANE + GPU fallback within CoreML)
*/

// MARK: - Fallback Path

/*
ANE vs GPU split strategy:

A17 Pro (primary):
    Pass A: patchMatchFill on GPU (this kernel)
    Pass B: CoreML ANE for full diffusion pipeline
        Model: envi_inpaint_64ch_4step.mlmodelc
        Compute: MLComputeUnitsAll (ANE primary, GPU backup)
        Latency: patch-match ~200ms + diffusion ~800ms–1.5s = 1–2s/image

A16 / A15 (graceful degradation):
    Pass A: patchMatchFill on GPU (this kernel)
    Pass B: SKIP diffusion. Use Poisson blending kernel instead.
        PoissonBlend.metal solves ∇²u = ∇²v with Dirichlet boundary.
        Shared mem: 16×16 tile + 2px halo.
        Iterations: 50–100 Jacobi steps (~50ms).
        Quality: Good but not diffusion-level.
        Total: ~250ms/image.

A14 and below (remote API fallback):
    OracleAPIClient.upload(image, mask) → ENVIBrain inpaint endpoint.
    Response: inpainted image + metadata.
    Latency: 2–5s depending on network + server queue.
    Retry: 3 attempts with exponential backoff (1s, 2s, 4s).

Priority cascade:
    1. A17 Pro: GPU patch-match + ANE diffusion
    2. A16/A15: GPU patch-match + GPU Poisson blend
    3. A14: OracleAPIClient remote inpaint
    4. Network down: CoreImage CIHoleFilter (fast, low quality)
    5. All else: return masked region as transparent
*/

// MARK: - Error Handling Strategy

/*
Pipeline error (MTLCommandBufferErrorEncoderInternal / GPU fault):
    1. Capture GPU frame via MTLCaptureManager if diagnostics enabled.
    2. TransformEngine recycles MTLDevice via deviceRecovery().
    3. Retry Pass A with reduced search radius (32→16, 8→4).
    4. If still failing, skip Pass A and use mask blur as coarse fill.
    5. Pass B: if ANE fails, retry with CoreML GPU fallback.
    6. If all local paths fail → OracleAPIClient remote.

CoreML model error (ANE compilation / inference failure):
    1. Log model version and ANE availability.
    2. Recompile model with MLComputeUnitsCPUAndGPU.
    3. If recompilation fails, fall back to MPSGraph GPU decode.
    4. If MPSGraph fails, use Poisson blending (A16/A15 path).
    5. If Poisson fails, remote API.

OOM (texture / buffer allocation failure):
    1. TransformEngine evicts LRU texture pool entries.
    2. Retry with 720p resolution (scale input to 1280×720).
    3. If still OOM, reduce latent channels: 64→32.
    4. If still OOM, skip diffusion, use Poisson only.
    5. Final: remote API (server has more RAM).

Thermal throttling:
    .reduced  → skip diffusion, use Poisson blending (~250ms, cooler).
    .minimal  → skip Pass A too; use CIHoleFilter (~30ms).
    .none     → return original image with mask unchanged.

Model missing / not downloaded:
    GenerationEngine queues background download.
    Meanwhile: Poisson blending or CIHoleFilter.
    Progress reported via TransformEngine.delegate.

Mask entirely covers image (>95%):
    Detect in preflight: if coverage > 95%, skip patch-match.
    Use remote API (server has larger context) or return error.
    Log metric: "inpaint_mask_coverage_excessive".
*/

// MARK: - Performance Estimate

/*
┌──────────────────────┬─────────────┬────────────┬─────────┬────────────────┐
│ Mode                 │ Patch-Match │ Refinement │ Total   │ Quality        │
├──────────────────────┼─────────────┼────────────┼─────────┼────────────────┤
│ A17 Pro ANE          │ ~200 ms     │ ~800ms–1.5s│ 1–2 s   │ Excellent      │
│ A17 Pro GPU only     │ ~200 ms     │ ~1.6–3.2 s │ 2–3.5 s │ Excellent      │
│ A16/A15 GPU          │ ~220 ms     │ ~50 ms (P) │ ~270 ms │ Good           │
│ A14 GPU              │ —           │ —          │ 2–5 s   │ Remote API     │
│ CoreImage CIHole     │ —           │ —          │ ~30 ms  │ Poor           │
│ Remote API           │ —           │ —          │ 2–5 s   │ Excellent      │
│ CPU (vDSP+vImage)    │ ~3 s        │ ~15 s      │ ~18 s   │ Good           │
└──────────────────────┴─────────────┴────────────┴─────────┴────────────────┘

(P) = Poisson blending instead of diffusion.

Target: 1–2s per 1080p image on A17 Pro (acceptable for user-triggered
object removal). Real-time preview uses Poisson blending (~270ms) while
diffusion refines in background.

Memory footprint per image:
    A17 Pro: ~45 MB (textures + latent + intermediate)
    A16/A15: ~20 MB (textures + Poisson buffers)
    A14 remote: ~8 MB (input + mask upload buffers)
*/

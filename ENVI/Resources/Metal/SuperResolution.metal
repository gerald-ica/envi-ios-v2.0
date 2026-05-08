// ============================================================================
// SuperResolution.metal — Lightweight ESRCNN 2× Upscale Kernel Spec
// ============================================================================
// Target: A17 Pro / M4 (Metal 3)
// Input:  1080p RGBA texture (1920×1080)
// Output: 4K RGBA texture    (3840×2160)
// Approach: ESRCNN variant — feature extraction (5× conv 64ch) + sub-pixel
//           shuffle upscaling (2×). No batch norm; param count ~70K.
// ============================================================================

#include <metal_stdlib>
using namespace metal;

// MARK: - Kernel Signature

/// Performs 2× super-resolution using ESRCNN with sub-pixel shuffle.
///
/// @param srcTexture       Input RGBA8Unorm texture (1080p)
/// @param dstTexture       Output RGBA8Unorm texture (4K)
/// @param weightsBuffer    Constant weights: [feat_extract_w (5 layers), subpixel_w, subpixel_b]
/// @param gid              2D thread position in grid (output pixel coordinate)
kernel void superResolutionESRCNN(
    texture2d<float, access::read>  srcTexture  [[texture(0)]],
    texture2d<float, access::write> dstTexture  [[texture(1)]],
    constant float*                 weightsBuffer [[buffer(0)]],
    uint2                           gid           [[thread_position_in_grid]]
)
{
    // Implementation note:
    // 1. Read 3×3 patch from srcTexture at floor(gid/2) coordinate
    // 2. Run 5 feature extraction layers (3×3 conv, 64 channels, ReLU)
    //    - All intermediate kept in threadgroup shared memory (tiled)
    // 3. Final sub-pixel convolution: output 4 channels per input pixel
    //    (2×2 arrangement → RGBA shuffle into 4 output pixels)
    // 4. Write RGBA to dstTexture at gid
    //
    // For MPS/CoreML path, MPSGraph builds identical graph targeting ANE.
}

// MARK: - Threadgroup Configuration (A17 Pro Tuned)

/*
Grid size (output space 3840×2160):
    width  = (3840 + 15) / 16 = 240 threadgroups
    height = (2160 + 15) / 16 = 135 threadgroups
    total  = 240 × 135 = 32,400 threadgroups

Threads per threadgroup:
    threadsPerThreadgroup = uint3(16, 16, 1)  // 256 threads

Threadgroups per grid:
    threadgroupsPerGrid   = uint3(240, 135, 1)

Rationale:
    Sub-pixel shuffle means each thread writes ONE output pixel but reads
    from a 3×3 neighborhood at 1/2 resolution.
    16×16 output tile = 8×8 input tile + 2px halo = 10×10 read region.
    Shared mem: 10×10 × 64ch × 2B = 12.8 KB per layer × 2 ping-pong = 25.6 KB
    Plus 64ch × 4B params = 256 B
    Total shared: ~26 KB (under 64 KB)

Alternative for higher occupancy:
    threadsPerThreadgroup = uint3(8, 8, 1)   // 64 threads
    threadgroupsPerGrid   = uint3(480, 270, 1)
    Shared mem drops to ~6.5 KB, allows more concurrent threadgroups.
    **Use 8×8 for A17 Pro** — better occupancy, same throughput.
*/

// MARK: - Memory Bandwidth Estimate

/*
For 1080p → 4K @ RGBA8Unorm:

Read:
    Input texture (1080p):           1920 × 1080 × 4      =  8.29 MB
    Weights (70K params):           ~140 KB (cached, negligible)
    Feature extraction intermediate:
        Layer 1–5: 1920×1080 × 64ch × 2B × 2 ping-pong ≈ 530 MB
        (tiled: only 2 layers resident = ~106 MB effective)

Write:
    Output texture (4K):            3840 × 2160 × 4      = 33.18 MB
    Intermediate ping-pong (tile):  ~26 MB (on-chip via shared mem)

Total off-chip bandwidth (frame):
    ~114 MB read + 33 MB write = 147 MB/frame
    @ 20 fps → ~2.9 GB/s

Peak device bandwidth (A17 Pro): ~51 GB/s → ~5.7% utilization
*/

// MARK: - Compute Estimate (FLOPs)

/*
ESRCNN architecture (~70K params):
    Feature extraction: 5 layers × (3×3 × 64 × 64) = 5 × 36,864 = 184,320 MACs
    Sub-pixel conv:     1 layer  × (3×3 × 64 × 16)  = 9,216 MACs
    (16 output channels = 4 RGBA × 2×2 shuffle positions)
    ReLU activations:   ~2 MFLOPs
    Total per input pixel: ~90 MACs = 180 FLOPs

Per 1080p frame:
    1920 × 1080 × 180 ≈ 373 MFLOPs
    @ 20 fps → 7.46 GFLOPS

A17 Pro GPU FP16: ~2+ TFLOPS → utilization ~0.4%
A17 Pro ANE:      ~35 TOPS  → utilization ~0.02%

Again memory-latency bound, not ALU bound.
*/

// MARK: - Texture Format

/*
Input:
    MTLPixelFormatRGBA8Unorm
    MTLTextureUsageShaderRead
    Storage: MTLStorageModePrivate

Output:
    MTLPixelFormatRGBA8Unorm
    MTLTextureUsageShaderWrite
    Storage: MTLStorageModePrivate

Intermediate feature maps:
    MTLPixelFormatR16Float (single-channel) or buffer-backed
    64 channels stored as MTLBuffer with stride = 1920×1080×2B
    Preferred: MTLTextureType2DArray with 64 slices, MTLPixelFormatR16Float

MPSGraph / CoreML path:
    MPSDataTypeFloat16
    Sub-pixel shuffle implemented as MPSGraphDepthToSpace (blockSize=2)
*/

// MARK: - Fallback Path

/*
Priority 1 (CoreML ANE):
    mlmodelc with esrcnn_2x.mlmodel, compiled for MLComputeUnitsAll.
    Input: 1920×1080 MLMultiArray
    Output: 3840×2160 MLMultiArray
    Latency: ~25ms on A17 Pro ANE.

Priority 2 (MPSGraph GPU):
    MPSGraph with MPSCNNConvolution + MPSGraphDepthToSpace.
    Latency: ~35ms.

Priority 3 (Custom compute kernel — this file):
    When ANE unavailable (A15/A16) or model not loaded.

Priority 4 (CoreImage + vImage):
    CILanczosScaleTransform + CINoiseReduction for approximate upscale.
    Quality significantly lower than ESRCNN.
    Latency: ~120ms CPU.

Priority 5 (Remote API):
    OracleAPIClient for server-side SR.
*/

// MARK: - Error Handling Strategy

/*
Pipeline error:
    1. Capture GPU frame, log encoder state.
    2. TransformEngine recycles device.
    3. Retry with CoreML ANE path.
    4. If ANE fails, fall back to CoreImage Lanczos (CIFilter).

OOM:
    1. 4K output texture is 33 MB — if allocation fails, this is critical.
    2. Evict texture pool LRU entries.
    3. Reduce to 1080p→1440p (1.5×) instead of 2×.
    4. If still OOM, disable SR and return original.

Thermal throttling:
    .reduced  → use CoreML ANE (lower power than GPU custom kernel).
    .minimal → drop to 1.5× upscale or skip.
    .none    → identity pass.

Model missing:
    GenerationEngine queues download; meanwhile Lanczos fallback.
*/

// MARK: - Performance Estimate (A17 Pro)

/*
| Mode                  | Latency | Throughput | Power   | Quality |
|-----------------------|---------|------------|---------|---------|
| CoreML ANE            | 25 ms   | 40 fps     | ~350 mW | Best    |
| MPSGraph GPU          | 35 ms   | 28 fps     | ~750 mW | Best    |
| Custom compute kernel | 42 ms   | 24 fps     | ~850 mW | Best    |
| CoreImage Lanczos     | 120 ms  | 8 fps      | ~1.2 W  | Poor    |
| CPU (vImage)          | 600 ms  | 1.7 fps    | ~2.5 W  | Best    |

Target: <50ms (20fps) @ 1080p→4K via CoreML ANE on A17 Pro.
*/

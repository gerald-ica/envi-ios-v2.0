// ============================================================================
// StyleTransfer.metal — Neural Style Transfer Kernel Spec
// ============================================================================
// Target: A17 Pro / M4 (Metal 3)
// Input:  1080p RGBA texture (1920×1080)
// Output: Stylized RGBA texture (1920×1080)
// Approach: Separable convolution blocks on MPS fallback; custom compute
//           kernel when MPS path unavailable. 3 encoder blocks + 5 residual
//           blocks + 3 decoder blocks.
// ============================================================================

#include <metal_stdlib>
using namespace metal;

// MARK: - Kernel Signature

/// Performs one forward pass of a lightweight style transfer network.
///
/// @param srcTexture       Input RGBA8Unorm texture (1080p)
/// @param dstTexture       Output RGBA8Unorm texture (1080p)
/// @param weightsBuffer    Constant block: [conv1_w, conv1_b, ... , residual_w, instance_gamma, instance_beta]
/// @param styleParams      Float4 style latent (mean/std per channel)
/// @param gid              2D thread position in grid (pixel coordinate)
kernel void styleTransfer(
    texture2d<float, access::read>  srcTexture  [[texture(0)]],
    texture2d<float, access::write> dstTexture  [[texture(1)]],
    constant float*                 weightsBuffer [[buffer(0)]],
    constant float4&                styleParams   [[buffer(1)]],
    uint2                           gid           [[thread_position_in_grid]]
)
{
    // Implementation note:
    // 1. Read 3×3 or 9×9 patch from srcTexture (with edge clamp)
    // 2. Apply instance normalization using precomputed gamma/beta from weightsBuffer
    // 3. Run separable conv: depthwise (spatial) then pointwise (channel mix)
    // 4. Add residual connection every 2 blocks
    // 5. Write clamped RGBA to dstTexture
    //
    // For MPS accelerated path, this kernel is NOT used. Instead,
    // MPSGraph builds the same network graph and runs on ANE/GPU.
}

// MARK: - Threadgroup Configuration (A17 Pro Tuned)

/*
Grid size:
    width  = (1920 + 15) / 16 = 120 threadgroups
    height = (1080 + 15) / 16 =  68 threadgroups
    total  = 120 × 68 = 8,160 threadgroups

Threads per threadgroup:
    threadsPerThreadgroup = uint3(16, 16, 1)  // 256 threads

Threadgroups per grid:
    threadgroupsPerGrid   = uint3(120, 68, 1)

Rationale:
    A17 Pro GPU has 6 cores × 32 SIMD-groups = 192 concurrent warps.
    256 threads / 32 = 8 warps per threadgroup.
    8,160 threadgroups × 8 warps = 65,280 total warps → heavily occupancy-bound,
    which is correct for a memory-heavy style transfer network.

Shared memory (threadgroup):
    16×16 tile + 2-pixel halo for 3×3 kernel = 18×18 × 4 channels × 2 bytes (half)
    = ~2.6 KB per threadgroup (well under 64 KB limit)
    + 128 bytes for instance norm params
    Total: ~2.8 KB
*/

// MARK: - Memory Bandwidth Estimate

/*
For 1080p @ RGBA8Unorm (4 bytes/pixel):

Read:
    Input texture read:            1920 × 1080 × 4  =  8.29 MB
    Weights read (per frame):      ~2.1 MB (static, cached in TBDR tile memory)
    Intermediate activations:      1920 × 1080 × 64ch × 2B × 11 layers ≈ 290 MB
        (but tiled: only 2–3 layers resident at once via deferred encoding)
    Resident memory estimate:      ~45 MB effective

Write:
    Output texture:                1920 × 1080 × 4  =  8.29 MB
    Intermediate ping-pong:        ~20 MB (tile-local, never off-chip)

Total off-chip bandwidth (frame):
    ~16.6 MB read + 8.3 MB write = 24.9 MB/frame
    @ 30 fps → ~748 MB/s

Peak device bandwidth (A17 Pro): ~51 GB/s → ~1.5% utilization (compute bound)
*/

// MARK: - Compute Estimate (FLOPs)

/*
Network architecture (lightweight, ~1.2M parameters):
    Encoder:  3 blocks × (3×3 conv, 64→128→256 ch, stride 2) = 0.4M ops
    Residual: 5 blocks × (3×3 conv, 256 ch, ReLU)          = 2.5M ops
    Decoder:  3 blocks × (3×3 conv transpose, 256→128→64) = 0.4M ops
    Instance norm + style modulation per block              = 0.1M ops
    Total per pixel: ~18 FLOPs (mostly MACs counted as 2)

Per 1080p frame:
    1920 × 1080 × 18 ≈ 37.3 MFLOPs
    @ 30 fps → 1.12 GFLOPS

A17 Pro GPU: ~2+ TFLOPS (FP16) → utilization ~0.05%
A17 Pro ANE: ~35 TOPS → utilization ~0.003%

The kernel is heavily memory-latency bound, not compute bound.
*/

// MARK: - Texture Format

/*
Input / Output:
    MTLPixelFormatRGBA8Unorm
    MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite
    Storage: MTLStorageModePrivate (device-local)

Intermediate activations (when custom kernel):
    MTLPixelFormatRGBA16Float  (half4) for 64-channel intermediate tensors
    Stored as array of textures or buffer-backed 2D texture

MPSGraph path (preferred):
    MPSGraphTensor dataType = MPSDataTypeFloat16
    Let MPS handle internal layout (NHWC or NCHW)
*/

// MARK: - Fallback Path

/*
Priority 1 (MPSGraph / CoreML):
    Build graph with MPSGraph, target ANE if available (A17+).
    CoreML model compiled with MLComputeUnitsAll.

Priority 2 (MPS neural network):
    MPSCNNSeparableConvolution + MPSCNNInstanceNormalization kernels.

Priority 3 (CPU / CoreImage):
    CIFilter chain: CIPhotoEffect + CIDissolveTransition approximating style.
    vImage convolution on CPU for exact match (slow: ~800ms/frame).

Priority 4 (Remote):
    OracleAPIClient upload/download (existing ENVIBrain path).
*/

// MARK: - Error Handling Strategy

/*
Pipeline error (MTLCommandBufferErrorEncoderInternal):
    1. Log GPU fault, capture GPU frame if Metal Diagnostics enabled.
    2. Recycle MTLDevice via TransformEngine.deviceRecovery().
    3. Retry with MPSGraph path (ANE instead of GPU).
    4. If ANE also fails, fall back to CPU path for this frame.

OOM (texture allocation failure):
    1. TransformEngine evicts LRU textures from pool.
    2. Retry with reduced resolution: 1080p → 720p.
    3. If still OOM, reduce channels: 256 → 128 intermediate.
    4. Final fallback: remote API.

Thermal throttling:
    ThermalAwareScheduler signals .reduced budget.
    TransformEngine reduces to MPSGraph ANE path (lower power).
    If .minimal: skip style transfer (identity pass).
    If .none: return input unchanged.
*/

// MARK: - Performance Estimate (A17 Pro)

/*
| Mode            | Latency | Throughput | Power   |
|-----------------|---------|------------|---------|
| MPSGraph + ANE  | 28 ms   | 36 fps     | ~450 mW |
| MPSGraph + GPU  | 33 ms   | 30 fps     | ~800 mW |
| Custom kernel   | 45 ms   | 22 fps     | ~900 mW |
| CPU (vImage)    | 850 ms  | 1.2 fps    | ~3 W    |
| Remote API      | 2–5 s   | 0.2 fps    | ~200 mW |

Target: <33ms (30fps) @ 1080p via MPSGraph/ANE.
*/

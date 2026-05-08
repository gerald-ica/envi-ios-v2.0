// ============================================================================
// BeatSync.metal — Audio Waveform Analysis + Visual Beat Marker Generation
// ============================================================================
// Target: A17 Pro / M4 (Metal 3)
// Input:  Float audio buffer (interleaved stereo, 44.1kHz, 16-bit or 32-bit float)
// Output: Array of BeatMarker structs { timeOffsetMs, intensityScore, confidence }
// Approach: 2-stage — (A) STFT-like frequency decomposition via MPSMatrixFFT or
//           vDSP fallback, (B) onset detection + beat tracking in Metal compute.
// ============================================================================

#include <metal_stdlib>
using namespace metal;

// MARK: - Output Struct

/// Beat marker output — one per detected beat.
/// Aligned to 16 bytes for Metal buffer compatibility.
struct BeatMarker {
    float timeOffsetMs;    // Beat position in milliseconds from song start
    float intensityScore;  // 0.0–1.0, peak magnitude of onset
    float confidence;      // 0.0–1.0, detection confidence
    float padding;         // Struct padding to 16 bytes
};

// MARK: - Stage A: Audio Spectrogram (MPSMatrixFFT Bridge)

/// Note: Stage A is primarily documented as an MPSMatrix / vDSP path.
/// Metal's native FFT (via MPSMatrixDecomposition or vDSP in Accelerate)
/// is preferred over a custom compute kernel for correctness and performance.
///
/// This kernel spec documents the Metal-side data preparation and
/// the expected buffer layout for Stage B.
///
/// Parameters:
///   - audioBuffer:     MTLBuffer of float2 (interleaved stereo), length = samples
///   - spectrogramBuffer: MTLBuffer of half2 (real, imag), length = (fftSize/2+1) × numFrames
///   - fftSize:         Typically 1024 or 2048 (power of 2)
///   - hopSize:         Typically 512 (50% overlap)
///   - sampleRate:      44100.0
///
/// The actual FFT is performed via:
///   Option 1 (preferred): vDSP_DFT_Execute on CPU — fastest for 44.1kHz audio
///   Option 2: MPSMatrixFFT (if available, iOS 16+) on GPU
///   Option 3: Custom radix-2/4 FFT in Metal (documented below for completeness)

// MARK: - Custom FFT Kernel (Optional, for reference)

/// Radix-2 Cooley-Tukey FFT — one butterfly per thread.
/// Used only when MPSMatrixFFT unavailable and vDSP not desired.
///
/// @param dataBuffer    Complex interleaved float2 buffer (in-place)
/// @param twiddleBuffer Precomputed twiddle factors (float2)
/// @param stage         Current FFT stage (0 to log2(N)-1)
/// @param N             FFT size (power of 2)
/// @param gid           Thread index (one per butterfly)
kernel void radix2FFT(
    device float2*       dataBuffer    [[buffer(0)]],
    constant float2*     twiddleBuffer [[buffer(1)]],
    constant uint&         stage         [[buffer(2)]],
    constant uint&         N             [[buffer(3)]],
    uint                   gid           [[thread_position_in_grid]]
)
{
    // Implementation note (reference only — use vDSP in production):
    // 1. Compute stride = 1 << stage
    // 2. Compute pair distance = stride << 1
    // 3. twiddle = twiddleBuffer[gid % stride]
    // 4. idx0 = (gid / stride) * pairDistance + (gid % stride)
    // 5. idx1 = idx0 + stride
    // 6. Butterfly: temp = data[idx1] * twiddle
    //    data[idx0] = data[idx0] + temp
    //    data[idx1] = data[idx0] - temp
    //
    // For 1024-point FFT: 10 stages × 512 butterflies = 5120 threads.
    // Use threadgroup shared memory for in-place shuffle to reduce global memory traffic.
}

// MARK: - Stage B: Onset Detection + Beat Tracking

/// Compute spectral flux onset detection and beat tracking.
///
/// @param magnitudeBuffer  MTLBuffer of half values: spectrogram magnitude per bin per frame.
///                         Layout: [frame0_bin0..binM, frame1_bin0..binM, ...]
/// @param beatMarkerBuffer Output MTLBuffer of BeatMarker structs
/// @param beatCountBuffer  Atomic counter (uint) — number of beats detected
/// @param numFrames        Total number of STFT frames
/// @param numBins          Number of frequency bins per frame (fftSize/2 + 1)
/// @param hopSizeMs        Time between consecutive frames in ms (typically 11.6ms for 512 hop @ 44.1kHz)
/// @param tempoMinBPM      Minimum tempo to detect (e.g., 60)
/// @param tempoMaxBPM      Maximum tempo to detect (e.g., 200)
/// @param onsetThreshold   Minimum spectral flux to register as onset (e.g., 0.15)
/// @param gid              Thread index (one thread per frequency bin)
kernel void onsetDetection(
    device half*           magnitudeBuffer  [[buffer(0)]],
    device BeatMarker*     beatMarkerBuffer [[buffer(1)]],
    device atomic_uint*    beatCountBuffer  [[buffer(2)]],
    constant uint&         numFrames        [[buffer(3)]],
    constant uint&         numBins          [[buffer(4)]],
    constant float&        hopSizeMs        [[buffer(5)]],
    constant float&        tempoMinBPM      [[buffer(6)]],
    constant float&        tempoMaxBPM      [[buffer(7)]],
    constant float&        onsetThreshold   [[buffer(8)]],
    uint                   gid              [[thread_position_in_grid]]
)
{
    // Implementation note:
    // 1. Each thread processes one frequency bin across all time frames
    // 2. Compute spectral flux for this bin:
    //    flux[t] = max(0, magnitude[t] - magnitude[t-1])
    //    (half-wave rectified difference)
    // 3. Accumulate flux into shared memory reduction buffer (one float per frame)
    // 4. After all bins processed, compute total flux per frame via atomic add
    // 5. Detect local peaks in total flux: peak if flux[t] > flux[t-1] && flux[t] > flux[t+1] && flux[t] > threshold
    // 6. For each peak, estimate tempo using comb filter / autocorrelation on inter-onset intervals
    // 7. Match peaks to best-fitting tempo grid (dynamic programming — Viterbi-style)
    // 8. For each confirmed beat, write BeatMarker to beatMarkerBuffer with atomic increment of beatCountBuffer
    //
    // Tempo estimation: test 4–8 tempo hypotheses in 60–200 BPM range.
    // For each hypothesis, compute alignment score with detected onsets.
    // Best score = selected tempo. Beat positions = phase-locked grid.
}

// MARK: - Stage B Alternate: Comb Filter Tempo Kernel

/// Separate kernel for tempo estimation if DP-style tracking is too heavy
/// for single dispatch. Lightweight alternative for real-time preview.
///
/// @param onsetBuffer     MTLBuffer of uint8: 1=onset, 0=no onset per frame
/// @param tempoScoreBuffer Output MTLBuffer of float scores per BPM candidate
/// @param numFrames       Total frames
/// @param candidateBPMs   MTLBuffer of float BPM values to test
/// @param numCandidates   Number of BPM candidates
/// @param gid             Thread index (one thread per candidate BPM)
kernel void combFilterTempo(
    device uint8*          onsetBuffer      [[buffer(0)]],
    device float*          tempoScoreBuffer [[buffer(1)]],
    constant uint&         numFrames        [[buffer(2)]],
    constant float*        candidateBPMs    [[buffer(3)]],
    constant uint&         numCandidates    [[buffer(4)]],
    constant float&        hopSizeMs        [[buffer(5)]],
    uint                   gid              [[thread_position_in_grid]]
)
{
    // Implementation note:
    // 1. Each thread tests one BPM candidate
    // 2. Convert BPM to frame period: periodFrames = 60000.0 / (bpm * hopSizeMs)
    // 3. Build comb filter kernel: [0.5, 1.0, 0.5] at period spacing
    // 4. Convolve comb filter with onsetBuffer
    // 5. Normalize score by number of expected beats
    // 6. Write score to tempoScoreBuffer[gid]
    // 7. Post-processing on CPU: argmax over tempoScoreBuffer = best tempo
    //
    // This kernel is embarrassingly parallel — one thread per candidate.
    // Typical: 32 candidates (60–200 BPM in ~4 BPM steps).
}

// MARK: - Threadgroup Configuration (A17 Pro Tuned)

/*
Stage A (STFT / Spectrogram):
    NOT a custom kernel — uses vDSP or MPSMatrixFFT.
    If custom radix-2 FFT:
        threadsPerThreadgroup = uint3(256, 1, 1)  // 256 threads
        threadgroupsPerGrid   = uint3(fftSize/512, 1, 1)
        Shared memory: 2 × fftSize × sizeof(float2) for ping-pong buffers
        For 1024-point: 2 × 1024 × 8B = 16 KB (under 64 KB)
        For 2048-point: 2 × 2048 × 8B = 32 KB (under 64 KB)

Stage B (onsetDetection):
    threadsPerThreadgroup = uint3(256, 1, 1)  // 256 threads
        - One thread per frequency bin
        - Typical numBins = 513 (for 1024-point FFT)
        - So 3 threadgroups (513 / 256 = 2.0 → ceil to 3)

    threadgroupsPerGrid = uint3((numBins + 255) / 256, 1, 1)
        - At most 3 threadgroups for standard audio

    Shared memory:
        - Spectral flux accumulation: numFrames × sizeof(float)
        - For 10s song @ 11.6ms hop: ~860 frames × 4B = ~3.4 KB
        - Onset peak buffer: numFrames × sizeof(uint8) = ~0.9 KB
        - Tempo hypothesis scores: 8 candidates × 4B = 32 B
        - Total: ~4.4 KB (well under 64 KB)

Stage B alt (combFilterTempo):
    threadsPerThreadgroup = uint3(32, 1, 1)  // 32 threads
    threadgroupsPerGrid   = uint3((numCandidates + 31) / 32, 1, 1)
        - Typical: 32 candidates → 1 threadgroup

    Shared memory: None (each thread independent)
*/

// MARK: - Memory Bandwidth Estimate

/*
For 10-second song @ 44.1kHz stereo:

Stage A — STFT (vDSP on CPU, or MPSMatrixFFT on GPU):
    Audio buffer (input):
        44,100 samples/sec × 10s × 2 channels × 4B = 3.53 MB
    Spectrogram (intermediate):
        860 frames × 513 bins × 2 (real, imag) × 2B (half) = ~1.77 MB
    Magnitude buffer (output of Stage A):
        860 frames × 513 bins × 2B (half) = ~0.88 MB

    Total read (audio): 3.53 MB
    Total write (spectrogram): 2.65 MB
    Peak bandwidth: low — audio processing is not bandwidth-bound

Stage B — Onset Detection:
    Read:  magnitudeBuffer 0.88 MB
    Write: beatMarkerBuffer ~200 beats × 16B = ~3.2 KB
           beatCountBuffer 4 B
    Total: ~0.88 MB read + ~4 KB write

Stage B alt — Comb Filter Tempo:
    Read:  onsetBuffer 860 B
           candidateBPMs 32 × 4B = 128 B
    Write: tempoScoreBuffer 32 × 4B = 128 B
    Total: ~1 KB read + ~0.3 KB write (negligible)

Full pipeline total:
    ~3.5 MB audio + 2.7 MB spectrogram + 0.9 MB magnitude + 4 KB output
    = ~7.1 MB for 10-second song
    @ realtime (process while streaming): ~710 KB/s sustained
*/

// MARK: - Compute Estimate (FLOPs)

/*
Stage A — STFT (vDSP):
    1024-point complex FFT: ~5 × 1024 × log2(1024) = ~51,200 complex operations
    Per 10s song: 860 frames × 51,200 = ~44 M complex ops
    = ~176 MFLOPs (each complex op ≈ 4 real FLOPs)
    vDSP on A17 Pro NEON: ~10–20 GFLOPS → ~9–18 ms

    If MPSMatrixFFT on GPU:
    Similar order of magnitude, but with dispatch overhead.
    Estimate: ~15–25 ms for full song.

Stage B — Onset Detection (per frequency bin thread):
    Per bin across 860 frames:
        Spectral flux: 860 diffs + 860 max(0,) = ~1,720 FLOPs
        Accumulation to shared memory: 860 atomic adds (hardware)
    Per 513 bins: 513 × 1,720 = ~882K FLOPs

    Post-reduction (single thread after sync):
        Peak detection: 860 comparisons = ~860 FLOPs
        Tempo DP/Viterbi: 860 frames × 8 hypotheses × 10 ops = ~68.8K FLOPs
        Beat alignment: 200 beats × 10 ops = ~2K FLOPs
    Total Stage B: ~954K FLOPs

    A17 Pro GPU: ~2+ TFLOPS → utilization ~0.05%
    (Completely memory-latency bound — almost no ALU work)

Stage B alt — Comb Filter Tempo (per candidate thread):
    Per candidate BPM (32 candidates):
        Comb convolution: 860 frames × 3 taps = ~2,580 FLOPs
        Normalization: ~10 FLOPs
    Total: 32 × 2,590 = ~82.9K FLOPs

    Negligible compute — bound by memory latency of onsetBuffer.
*/

// MARK: - Texture / Buffer Format

/*
Audio input buffer:
    MTLBuffer, length = numSamples × sizeof(float2) (interleaved stereo)
    Or: MTLBuffer, length = numSamples × sizeof(float) for mono downmix
    Storage: MTLStorageModeShared (CPU writes audio data from AVAssetReader)

Spectrogram buffer (intermediate):
    MTLBuffer, length = numFrames × numBins × sizeof(half2)
    Storage: MTLStorageModePrivate (GPU-only during MPSMatrixFFT)

Magnitude buffer:
    MTLBuffer, length = numFrames × numBins × sizeof(half)
    Layout: row-major, [frame0_bin0..binM, frame1_bin0..binM, ...]
    Storage: MTLStorageModePrivate

Onset buffer (optional intermediate):
    MTLBuffer, length = numFrames × sizeof(uint8)
    Storage: MTLStorageModePrivate

Beat marker output buffer:
    MTLBuffer, length = maxBeats × sizeof(BeatMarker)
    sizeof(BeatMarker) = 16 bytes (4 × float, aligned)
    maxBeats = numFrames (worst case: every frame is a beat)
    Storage: MTLStorageModeShared (CPU reads for UI/timeline rendering)

Beat count atomic:
    MTLBuffer, length = sizeof(uint32_t)
    Storage: MTLStorageModeShared

Tempo score buffer (Stage B alt):
    MTLBuffer, length = numCandidates × sizeof(float)
    Storage: MTLStorageModeShared
*/

// MARK: - Fallback Path

/*
Priority 1 (vDSP + Accelerate on CPU):
    vDSP_DFT_Execute for FFT + vDSP_magnitudes for magnitude spectrum.
    vDSP for onset detection: vDSP_vsub + vDSP_vthres.
    Beat tracking: custom Swift/ObjC DP on CPU using detected onsets.
    Latency: ~25–40 ms for 10s song.
    Power: ~150–250 mW (CPU only, no GPU/ANE wake).
    This is the RECOMMENDED production path for audio analysis.

Priority 2 (MPSMatrixFFT + Metal GPU):
    If vDSP unavailable or user explicitly requests GPU processing.
    MPSMatrixFFT for spectrogram + custom onset kernel.
    Latency: ~30–50 ms for 10s song.
    Power: ~300–500 mW (GPU wake cost dominates).

Priority 3 (Custom Metal FFT + onset kernel):
    Documented in this file for completeness.
    Higher latency than vDSP due to kernel dispatch overhead.
    Use only as educational reference or if MPS/vDSP both unavailable.

Priority 4 (Remote API):
    OracleAPIClient for server-side beat detection.
    Latency: 200ms–1s (network dependent).
    Used for longer songs (>60s) where on-device processing is prohibitive.

Priority 5 (Simplified heuristic):
    Energy-based onset detection (no FFT):
    - Compute RMS energy in 43ms windows
    - Peak = onset if RMS > 1.5× local mean
    - Tempo = median inter-peak interval
    Latency: ~5 ms. Quality: poor but functional for basic cut suggestions.
*/

// MARK: - Error Handling Strategy

/*
Pipeline error (any stage):
    1. Audio analysis is non-destructive — log error, return empty beat array.
    2. UI shows "Beat sync unavailable — manual editing enabled."
    3. Retry with vDSP fallback if Metal path failed.
    4. If all fallbacks fail, use simplified heuristic (RMS energy peaks).

Audio format unsupported:
    - Not stereo 44.1kHz? Convert using AVAudioEngine format conversion.
    - Not float? Convert using vDSP_vfixr (int16 → float).
    - Sample rate mismatch? Resample using AVAudioConverter.

Buffer allocation failure (OOM):
    - Spectrogram for 60s song: 5,100 frames × 513 bins × 2B = ~5.2 MB
    - If allocation fails, process in chunks (e.g., 10s windows).
    - Stitch beat markers across chunk boundaries.

Thermal throttling:
    .reduced  → use vDSP CPU path (lower power than GPU wake).
    .minimal → use simplified heuristic only (RMS energy, no FFT).
    .none    → skip beat detection entirely. Return empty array.

Model missing (AudioAnalysisPipeline CoreML):
    If beatnet.mlmodelc not downloaded, fall back to vDSP immediately.
    Queue model download in background for future use.

Cancelation:
    - Cooperative: check atomic flag between frames.
    - If Task.isCancelled, write current beatCount and return partial results.
    - UI shows partial beat markers with "processing..." indicator.
*/

// MARK: - Performance Estimate (A17 Pro)

/*
| Mode                        | Latency  | Throughput    | Power   | Quality |
|-----------------------------|----------|---------------|---------|---------|
| vDSP CPU (recommended)    | 25 ms    | 40 songs/sec  | ~180 mW | Best    |
| MPSMatrixFFT + Metal GPU    | 35 ms    | 28 songs/sec  | ~450 mW | Best    |
| Custom Metal FFT + kernel   | 50 ms    | 20 songs/sec  | ~550 mW | Best    |
| Simplified heuristic        | 5 ms     | 200 songs/sec | ~50 mW  | Fair    |
| Remote API                  | 500 ms   | 2 songs/sec   | ~30 mW  | Best    |

Per-song latency breakdown (10s audio, vDSP path):
    Audio decode (AVAssetReader):      ~3 ms
    Mono downmix:                      ~1 ms
    STFT (vDSP FFT × 860 frames):      ~15 ms
    Magnitude extraction:              ~2 ms
    Onset detection:                   ~3 ms
    Tempo estimation + beat align:     ~2 ms
    Total:                              ~26 ms

Target: <30ms per 10s song on A17 Pro via vDSP.
       <50ms via Metal GPU path.
       Real-time capable for live preview (process in 1s sliding windows).

Memory budget per 10s song:
    Audio buffer:    3.5 MB
    Spectrogram:     2.7 MB
    Magnitude:       0.9 MB
    Beat markers:    3 KB
    Working total:   ~7.1 MB
    Safe for 8GB device with other app memory pressure.
*/

// MARK: - Integration Notes

/*
TransformEngine integration:
    BeatSync is NOT a visual kernel — it feeds the video editing timeline.
    TransformEngine.submit(audioURL:graph:) should dispatch audio analysis
    to a separate audio queue (not the visual texture pipeline).

    Result: [BeatMarker] passed to VideoEditService or timeline controller.
    Timeline UI renders vertical beat markers at timeOffsetMs positions.
    User can snap cut points to nearest beat with 50ms tolerance.

GenerationEngine integration:
    AudioAnalysisPipeline (CoreML beatnet.mlmodelc) can replace or augment
    the vDSP path. If model available AND thermal >= .reduced:
        → Use CoreML for higher accuracy (learned tempo + downbeat detection).
    If model unavailable OR thermal < .reduced:
        → Use vDSP heuristic path.

    Model input:  44.1kHz mono float buffer, 6s window
    Model output: BeatMarker array + tempoBPM + timeSignature
    Model latency: ~8ms per 6s window on ANE
*/

// MARK: - SIMD Optimization Notes

/*
For the vDSP production path, use these Accelerate routines:

    // FFT setup (once, reuse across songs)
    let setup = vDSP_DFT_zop_CreateSetup(
        nil, vDSP_Length(fftSize), .FORWARD
    )!

    // Windowing (Hann window)
    var window = [Float](repeating: 0, count: fftSize)
    vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_DENORM))

    // FFT per frame
    vDSP_DFT_Execute(setup, real, imag, realOut, imagOut)

    // Magnitude
    vDSP_zvmags(&complexBuffer, 1, &magnitude, 1, vDSP_Length(numBins))

    // Spectral flux (half-wave rectified difference)
    vDSP_vsub(prevMagnitude, 1, magnitude, 1, &diff, 1, vDSP_Length(numBins))
    vDSP_vthres(diff, 1, &threshold, &flux, 1, vDSP_Length(numBins))

    // Onset peak detection (custom loop — not vectorizable due to peak condition)

Metal GPU path uses equivalent compute shaders but with half-precision
for 2× memory bandwidth savings on spectrogram buffers.
*/

# Test Fixtures

## `test-video.mp4` (Phase 08 — TikTok integration)

A 15-second, 720p, H.264 MP4 (≤5 MB) must be placed at:

```
ENVITests/Fixtures/test-video.mp4
```

before running the TikTok end-to-end integration test
(`TikTokIntegrationTests.testEndToEndSandboxPublish`).

### Why it's not committed

- GitHub storage + LFS are not configured for this repo.
- Binary media causes noisy diffs and bloats clone times.
- TikTok's sandbox accepts the first few seconds of ANY valid 720p+ clip,
  so there's no need for a shared "golden" fixture.

### How to generate one (ffmpeg one-liner)

```bash
ffmpeg -f lavfi -i "color=c=black:s=1280x720:d=15" \
       -f lavfi -i "sine=frequency=1000:duration=15" \
       -c:v libx264 -pix_fmt yuv420p -profile:v high \
       -c:a aac -shortest \
       ENVITests/Fixtures/test-video.mp4
```

Verify the output:

```bash
ffprobe -v error -show_entries format=size,duration \
        -of default=nk=1 ENVITests/Fixtures/test-video.mp4
```

### Integration test gate

The integration test is skipped unless `ENVI_RUN_TIKTOK_INTEGRATION=1` is
set in the Xcode test scheme's environment:

```
Product > Scheme > Edit Scheme > Test > Arguments > Environment Variables
   ENVI_RUN_TIKTOK_INTEGRATION = 1
```

Run only the integration tests with:

```bash
ENVI_RUN_TIKTOK_INTEGRATION=1 xcodebuild test \
    -scheme ENVI \
    -only-testing:ENVITests/TikTokIntegrationTests
```

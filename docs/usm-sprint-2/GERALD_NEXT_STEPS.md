# USM Sprint 2 — What Gerald Needs to Do

Everything the Cowork sandbox couldn't do, ordered by dependency. Do 1 → 2 → 3 → 4 → 5 → 6 → 7. Estimated ~45–60 minutes of hands-on work plus Cloud Run + TestFlight background time.

**Repos referenced below:**
- Brain: `ENVI-OUS-BRAIN` (FastAPI, Python 3.11+)
- iOS: `envi-ios-v2` (Swift 6, Xcode 16)
- Cowork workspace paths: `/sessions/adoring-happy-dirac/mnt/…`

---

## 0. Sprint 1 Gerald-side prerequisites (MANDATORY — check first)

If you haven't finished the checklist in `../usm-sprint-1/GERALD_NEXT_STEPS.md`, do that first. Sprint 2's `/recompute` endpoint fails at the encrypted-persist step without:

- [ ] `terraform apply` in `ENVI-OUS-BRAIN/terraform/usm/` (KMS keyring + secret)
- [ ] `GOOGLE_CLOUD_KMS_KEY_NAME` set in staging env (`.env.production` or Cloud Run env var)
- [ ] Migration `011_user_self_model.sql` applied to staging Cloud SQL
- [ ] Sprint 1 feature branches merged in both repos

If any of the above is missing, stop and finish Sprint 1 first.

---

## 1. Verify backend tests pass on your Mac (5 min)

The sandbox is Python 3.10; your Mac has 3.11. Run the new tests against the real stack:

```bash
cd ENVI-OUS-BRAIN
source .venv/bin/activate   # or create with: uv venv --python 3.11 && pip install -e '.[dev]'
pip install pycryptodome google-cloud-kms google-cloud-secret-manager

export USM_LOCAL_DEK_BASE64="dGVzdC1kZWstMzItYnl0ZXMtZm9yLWNpLW9ubHktMTIzNDU2Nzg="
pytest tests/plugins/usm/ tests/api/routes/test_user_self_model_recompute.py -v
```

Expected: **10 tests green** (3 schema + 2 crypto + 3 assembler + 4 recompute — note some of these overlap with Sprint 1's passes; the new ones for Sprint 2 are the 3 assembler + 4 recompute).

Do NOT merge if any test fails.

---

## 2. Add the new Swift files to Xcode (10 min)

All new `.swift` files exist on disk but are not referenced by `ENVI.xcodeproj`. Open Xcode and add them to the correct target.

**ENVI app target (12 files):**
```
ENVI/Features/USM/Onboarding/USMOnboardingViewModel.swift
ENVI/Features/USM/Onboarding/USMOnboardingCoordinator.swift
ENVI/Features/USM/Onboarding/USMOnboardingNameView.swift
ENVI/Features/USM/Onboarding/USMOnboardingDOBView.swift
ENVI/Features/USM/Onboarding/USMOnboardingBirthPlaceView.swift
ENVI/Features/USM/Onboarding/USMOnboardingCurrentLocationView.swift
ENVI/Features/USM/Onboarding/USMOnboardingLoadingView.swift
ENVI/Features/USM/Onboarding/USMOnboardingEntry.swift
ENVI/Features/USM/Network/USMRecomputeClient.swift
ENVI/Features/USM/Network/CitySearchClient.swift
```

**ENVITests target (3 files):**
```
ENVITests/Core/USM/USMOnboardingCoordinatorTests.swift
ENVITests/Core/USM/CitySearchClientTests.swift
ENVITests/Core/USM/TestSupport/StubUSMRecomputeClient.swift
```

Easiest path: in Xcode, right-click `ENVI/Features` → "Add Files to ENVI…", multi-select the whole `USM/` subtree, confirm target membership = `ENVI`. Repeat for `ENVITests/Core/USM/`.

---

## 3. SceneDelegate integration — 2-line change (2 min)

`USMOnboardingEntry.swift` contains a `TODO(gerald)` comment showing the exact edit. In `ENVI/App/SceneDelegate.swift`, wherever legacy onboarding currently renders (search for `OnboardingContainerView()` or the current onboarding entry), replace the one line with:

```swift
if USMOnboardingEntry.shouldUse {
    // existing navigation setup, but render:
    USMOnboardingEntry.makeView(onComplete: { [weak self] in self?.dismissOnboarding() })
} else {
    // legacy path unchanged
    OnboardingContainerView()
}
```

Do **not** delete the legacy code. Feature flags off → legacy path still runs. This is deliberate — rollback is instant by flipping the flag.

---

## 4. Verify XCTest on simulator (5 min)

```bash
cd envi-ios-v2
xcodebuild test \
  -scheme ENVI \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  -only-testing:ENVITests/USMOnboardingCoordinatorTests \
  -only-testing:ENVITests/CitySearchClientTests
```

Expected: **14 tests green** (8 coordinator + 6 city search).

The existing `UserSelfModelTests` from Sprint 1 should still pass — run the full `-only-testing:ENVITests` if you want a full-suite check.

---

## 5. Firebase staging alias + TestFlight internal push (10–15 min)

### 5a. Confirm staging alias
`.firebaserc` now includes `staging` and `production` project aliases. Verify:

```bash
cd envi-ios-v2
firebase use staging
# expected: Now using alias staging (envi-by-informal-staging)
```

If it errors on "unknown alias", you're on an older local clone — `git pull` first.

### 5b. Remote Config keys (optional but recommended)

Add two keys in Firebase Remote Config for `envi-by-informal-staging`:
- `usmEnabled` (Boolean, default `false`)
- `usmOnboardingEnabled` (Boolean, default `false`)

Turn both to `true` for staging to exercise the new flow without rebuilding. DEBUG builds default to `true` already.

### 5c. TestFlight internal push

```bash
# In envi-ios-v2, with feature/usm-2-onboarding-assembler merged to main (or pushed to TestFlight directly)
# 1. Bump build number in ENVI.xcodeproj target settings (or via agvtool)
agvtool next-version -all

# 2. Archive
xcodebuild archive \
  -scheme ENVI \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/ENVI.xcarchive

# 3. Export + upload
xcodebuild -exportArchive \
  -archivePath build/ENVI.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export

xcrun altool --upload-app --type ios \
  --file build/export/ENVI.ipa \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
```

Then go to App Store Connect → TestFlight → Internal Testing → add the new build to your internal group.

---

## 6. Commit + push + open PRs (10 min)

The sandbox has a stuck `.git/index.lock` in the iOS repo and no `gh` binary. On your Mac:

### Brain repo
```bash
cd ENVI-OUS-BRAIN
git checkout main
git pull
git checkout -b feature/usm-2-onboarding-assembler

git add src/envious_brain/plugins/usm/assembler.py \
        src/envious_brain/api/routes/user_self_model.py \
        tests/plugins/usm/test_assembler.py \
        tests/api/routes/ \
        .github/workflows/usm-ci.yml \
        docs/usm-sprint-2

git commit -m "USM Sprint 2: assembler real impl + /recompute fan-out + tests"
git push -u origin feature/usm-2-onboarding-assembler
gh pr create --base main --head feature/usm-2-onboarding-assembler \
  --title "USM Sprint 2: assembler + /recompute fan-out" \
  --body-file docs/usm-sprint-2/PR_BODY.md
```

### iOS repo
```bash
cd envi-ios-v2
rm -f .git/index.lock   # may not exist on your Mac; harmless if it does
git checkout main
git pull
git checkout -b feature/usm-2-onboarding-assembler

git add ENVI/Features/USM \
        ENVITests/Core/USM/USMOnboardingCoordinatorTests.swift \
        ENVITests/Core/USM/CitySearchClientTests.swift \
        ENVITests/Core/USM/TestSupport/StubUSMRecomputeClient.swift \
        ENVI/Core/Config/FeatureFlags.swift \
        .firebaserc \
        docs/usm-sprint-2

# IMPORTANT — do NOT git add these (they are unrelated in-flight work that was on main when Sprint 2 started):
#   ENVI/App/ENVIApp.swift
#   ENVI/App/SceneDelegate.swift      (except for your Step 3 change above — add that as its own commit)
#   ENVI/Core/Auth/ASWebAuthenticationSessionAdapter.swift
#   ENVITests/ForYouGalleryViewModelTests.swift
#   .tmp-*.sh, .tmp-*.png, .tmp-*.txt

git commit -m "USM Sprint 2: 4-screen onboarding + city search + loading + flags"

# SceneDelegate change lands as a second commit on the same branch
git add ENVI/App/SceneDelegate.swift
git commit -m "USM Sprint 2: route new users through USMOnboardingEntry when flag is on"

git push -u origin feature/usm-2-onboarding-assembler
gh pr create --base main --head feature/usm-2-onboarding-assembler \
  --title "USM Sprint 2: 4-screen onboarding + city search + loading (iOS)" \
  --body-file docs/usm-sprint-2/PR_BODY.md
```

Merge order: **Brain PR first, iOS PR second.** iOS `/recompute` calls will fail until Brain is deployed.

---

## 7. Exit criteria (mirrors `SPRINT_2_STATUS.md`)

- [ ] `pytest tests/plugins/usm/ tests/api/routes/test_user_self_model_recompute.py` green on your Mac
- [ ] `xcodebuild test` (USM-scoped) green on iPhone 16 Pro simulator
- [ ] New user completes onboarding in <90 s and Home opens with a first personalized header (manual sim run)
- [ ] Both `usm-ci.yml` and `usm-ios-ci.yml` green on feature-branch PRs
- [ ] `firebase use staging` resolves without error
- [ ] `FeatureFlags.shared.usmEnabled` OFF in release, ON in DEBUG (verified by building both configurations)
- [ ] Sprint 1's KMS keyring + migration 011 in place (prerequisite — tracked in Sprint 1 checklist)

Hit all seven boxes and Sprint 2 is done. Sprint 3 (weekly recompute job + profile-screen reads) is unblocked.

---

## If something goes wrong

- Backend tests fail on your Mac but AST parse clean → likely a `pytest-asyncio` or fixture wiring issue. Paste the failing output into a new Cowork session for the backend agent to diagnose.
- `xcodebuild test` fails with "cannot find USMCity in scope" → the file wasn't added to the test target. Recheck Step 2.
- Recompute returns 500 in staging → check that `GOOGLE_CLOUD_KMS_KEY_NAME` is set in Cloud Run env. Fall back to local KMS (`USM_LOCAL_DEK_BASE64`) for local Mac testing.
- Onboarding crashes at step 3 ("birth place") with "CitySearchError.server" → staging API might not have `/api/v1/cities/search` deployed. Check `ENVI-OUS-BRAIN/src/envious_brain/api/routes/cities.py` is included in `app.py`.

All agent notes are in `SPRINT_2_STATUS.md` — each agent left a detailed trail of design choices and file-by-file changes for debugging.

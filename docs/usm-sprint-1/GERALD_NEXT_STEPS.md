# USM Sprint 1 — What Gerald Needs to Do

Everything the sandbox couldn't do, consolidated into one checklist. Ordered by dependency: do 1 → 2 → 3 → 4 → 5. Estimated total: 30-45 minutes of hands-on time + background CI / terraform time.

**Repos / paths referenced below:**
- Brain: `ENVI-OUS-BRAIN` (FastAPI, Python 3.11+)
- iOS: `envi-ios-v2` (Swift 6, Xcode 16)
- Local workspace in Cowork: `/sessions/zealous-admiring-pascal/mnt/…`

---

## 1. GCP KMS + Secret Manager (5-10 min)

All USM ciphertext is encrypted with a DEK wrapped by a Cloud KMS key. Nothing else works until this key exists.

```bash
cd ENVI-OUS-BRAIN/terraform/usm
gcloud auth application-default login  # once per workstation
gcloud config set project informal-brain
gcloud services enable cloudkms.googleapis.com secretmanager.googleapis.com

terraform init
terraform apply -var="gcp_project_id=informal-brain"
# review the plan, type 'yes'
```

Copy the `kms_key_name` output. It looks like:
```
projects/informal-brain/locations/us-central1/keyRings/usm-keyring/cryptoKeys/usm-dek-wrapper
```

Set it as `GOOGLE_CLOUD_KMS_KEY_NAME` wherever the FastAPI service reads env vars:
- `.env.production` (Cloud Run / container)
- Your local shell for running tests against real GCP: `export GOOGLE_CLOUD_KMS_KEY_NAME=projects/...`

For local dev without GCP, set `USM_LOCAL_DEK_BASE64=<32-byte base64 string>` instead — the crypto module falls back to that.

**Guardrail:** the DEK wrapper has `lifecycle { prevent_destroy = true }`. If you ever need to destroy it, you'll need to edit `main.tf` first. Destroying the key makes every existing ciphertext unrecoverable.

---

## 2. Apply the database migration (2 min)

```bash
cd ENVI-OUS-BRAIN
export DATABASE_URL="postgresql://<user>:<pw>@<staging-host>:5432/oracle_staging"
psql "$DATABASE_URL" -f src/envious_brain/core/migrations/011_user_self_model.sql
```

Verify:
```bash
psql "$DATABASE_URL" -c "\dt oracle_users.user_self_model*"
# expect: user_self_model, user_self_model_history, user_self_model_audit
```

Roll back if needed (nothing reads from these tables yet, so a DROP is safe):
```sql
DROP TABLE oracle_users.user_self_model_audit;
DROP TABLE oracle_users.user_self_model_history;
DROP TABLE oracle_users.user_self_model;
DROP FUNCTION oracle_users.usm_history_insert();
```

---

## 3. Verify backend tests pass on your Mac (5 min)

The sandbox only has Python 3.10, so pytest wasn't run here. Your Mac has the 3.11 toolchain the repo needs.

```bash
cd ENVI-OUS-BRAIN
uv venv --python 3.11   # or: python3.11 -m venv .venv
source .venv/bin/activate
pip install -e '.[dev]'
pip install pycryptodome google-cloud-kms google-cloud-secret-manager

export USM_LOCAL_DEK_BASE64="dGVzdC1kZWstMzItYnl0ZXMtZm9yLWNpLW9ubHktMTIzNDU2Nzg="
pytest tests/plugins/usm/ -v
```

Expect **all green**. If any test fails, do NOT merge — ping the backend agent to diagnose.

---

## 4. Add the new Swift files to the Xcode project + verify XCTest green (10 min)

The iOS files exist on disk but are not yet referenced by `ENVI.xcodeproj`. Xcode needs them added to the target.

```
# Files to add to the ENVI target:
ENVI/Core/USM/UserSelfModel.swift
ENVI/Core/USM/USMCache.swift
ENVI/Core/USM/USMSyncActor.swift

# Files to add to the ENVITests target:
ENVITests/Core/USM/UserSelfModelTests.swift
```

Open `ENVI.xcodeproj`, right-click `ENVI/Core` → "Add Files to ENVI…", select the `USM/` folder, make sure **Target Membership = ENVI**. Repeat for `ENVITests/Core/USM/UserSelfModelTests.swift` with target membership `ENVITests`.

Run tests:
```bash
cd envi-ios-v2
xcodebuild test \
  -scheme ENVI \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  -only-testing:ENVITests/UserSelfModelTests
```

Expect **all 9 tests green** (3 schema + 2 cache + 3 sync + 1 upgrade).

---

## 5. Commit + push + open PRs (5 min)

The sandbox held a stuck `.git/index.lock` and had no `gh` binary, so commits were not made here. On your Mac:

**Brain repo:**
```bash
cd ENVI-OUS-BRAIN
rm -f .git/index.lock   # may not exist on your machine; harmless if it does
git checkout -b feature/usm-1-schema
git add src/envious_brain/plugins/usm \
        src/envious_brain/core/migrations/011_user_self_model.sql \
        src/envious_brain/api/routes/user_self_model.py \
        src/envious_brain/api/app.py \
        pyproject.toml \
        tests/plugins/usm \
        terraform/usm \
        .github/workflows/usm-ci.yml \
        docs/usm-sprint-1
git commit -m "USM Sprint 1: schema + crypto + migration + routes + CI"
git push -u origin feature/usm-1-schema
gh pr create --base main --head feature/usm-1-schema \
  --title "USM Sprint 1: User Self-Model v1 foundation" \
  --body-file docs/usm-sprint-1/PR_BODY.md
```

**iOS repo:**
```bash
cd envi-ios-v2
git checkout -b feature/usm-1-schema
git add ENVI/Core/USM \
        ENVITests/Core/USM \
        .github/workflows/usm-ios-ci.yml \
        docs/usm-sprint-1
# IMPORTANT: do NOT git add ENVIApp.swift, SceneDelegate.swift, ASWebAuthenticationSessionAdapter.swift
# Those are unrelated uncommitted edits that were on main when Sprint 1 started.
git commit -m "USM Sprint 1: UserSelfModel + USMCache + USMSyncActor + tests"
git push -u origin feature/usm-1-schema
gh pr create --base main --head feature/usm-1-schema \
  --title "USM Sprint 1: User Self-Model v1 (iOS)" \
  --body-file docs/usm-sprint-1/PR_BODY.md
```

After both PRs merge, delete the branches:
```bash
git push origin --delete feature/usm-1-schema  # run in each repo
```

---

## Exit criteria (same as `SPRINT_1_STATUS.md`)

- [ ] `pytest tests/plugins/usm/` green on your Mac.
- [ ] `xcodebuild test -only-testing:ENVITests/UserSelfModelTests` green on your Mac.
- [ ] Migration 011 applied to staging Cloud SQL.
- [ ] KMS keyring + secret created in `informal-brain` GCP project; `GOOGLE_CLOUD_KMS_KEY_NAME` set.
- [ ] Both `usm-ci.yml` and `usm-ios-ci.yml` show green on the feature-branch PRs.

Hit all five boxes and Sprint 1 is done. Sprint 2 (assembler wiring + profile screens) is unblocked.

---

## If something goes wrong

Each task in `SPRINT_1_STATUS.md` has an `Owner` column. The backend agent wrote every Python + SQL file and left its notes inline in the PR body. The devops agent left a detailed log under the "devops agent notes" section of `SPRINT_1_STATUS.md`. If a test fails, paste the failing output into a new Cowork session and ask for a diagnosis — the agents have full context on what they built.

# ENVI Execution Backlog (GSD)

Generated: 2026-04-03 23:46:44Z (UTC)

## Priority waves

### Wave 1 (Immediate, 1-2 weeks)
| ID | Task | Size | Depends on | Acceptance criteria |
|---|---|---|---|---|
| ENVI-T001 | Replace/remove GKE template workflow | S | None | ✅ No stale deploy template running on push |
| ENVI-T002 | Add iOS CI workflow | M | T001 | ✅ PR builds and tests run on macOS |
| ENVI-T003 | Add env strategy doc + config matrix | S | None | ✅ `dev/staging/prod` values mapped in repo docs |
| ENVI-T004 | ADR: backend truth path (Firebase/Data Connect/API) | S | None | ✅ Decision recorded in `.planning/PROJECT.md` references |
| ENVI-T005 | Add `firebase.json` + deploy script doc | M | T004 | ✅ Team can run documented deploy path in staging |

### Wave 2 (2-4 weeks)
| ID | Task | Size | Depends on | Acceptance criteria |
|---|---|---|---|---|
| ENVI-T006 | Integrate Firebase Auth SDK + session handling | L | T003, T004 | ✅ Sign-in/out works against staging auth |
| ENVI-T007 | Replace `APIClient` stub with typed client | M | T006 | ✅ Production paths no longer throw `.notImplemented` |
| ENVI-T008 | Secure Data Connect public operations | S | T005 | ✅ No unsafe public seed endpoints in prod path |
| ENVI-T009 | Define repository/data layer boundaries | M | T007 | ✅ Features use protocol-backed repositories |
| ENVI-T010 | Add crash + analytics SDK baseline | M | T002 | ✅ Crashes/events visible per release build |

### Wave 3 (4-7 weeks)
| ID | Task | Size | Depends on | Acceptance criteria |
|---|---|---|---|---|
| ENVI-T011 | Implement real photo ingest/upload queue | L | T007, T009 | ✅ Assets upload and persist with retries |
| ENVI-T012 | Wire `ContentPieceAssembler` to backend | L | T011 | ✅ Assembled content returns to app and persists |
| ENVI-T013 | Replace Library and Explore mock content with real data | L | T012 | ✅ Core browsing paths run from backend records |
| ENVI-T014 | Add first end-to-end integration test | M | T011-T013 | ✅ Onboarding/import path validated in CI/nightly |

### Wave 4 (7-10 weeks)
| ID | Task | Size | Depends on | Acceptance criteria |
|---|---|---|---|---|
| ENVI-T015 | Oracle API contract and iOS integration path | L | T007, T012 | ✅ Chat/insight path uses server response behind flag |
| ENVI-T016 | First social OAuth + token lifecycle | L | T006 | ✅ Account can connect/reconnect cleanly |
| ENVI-T017 | First publish and status reconciliation loop | L | T016 | ✅ Published post status appears in app |
| ENVI-T018 | Analytics dashboard real payload integration | M | T017 | ✅ KPI cards show non-mock metrics |

### Wave 5 (10-14 weeks)
| ID | Task | Size | Depends on | Acceptance criteria |
|---|---|---|---|---|
| ENVI-T019 | Replace critical editor placeholders (trim/export) | L | T012 | ✅ Real editing operation produces output file |
| ENVI-T020 | RevenueCat entitlements tied to premium features | M | T006, T015 | ✅ Gated features enforce entitlement state |
| ENVI-T021 | TestFlight automation + release checklist | M | T002, T020 | ✅ Candidate build ship process is repeatable |

### Follow-on deliverables
| Deliverable | Status |
|---|---|
| Content Planning CRUD (create/edit/reorder/delete plan items via API + optimistic UI) | ✅ Done |
| Template apply flow (bridge templates to export/composer path) | ✅ Done |
| Analytics retention cohorts (weekly cohort retention model + chart) | ✅ Done |
| Source attribution (channel/source attribution model + dashboard section) | ✅ Done |
| Creator growth analytics (follower growth + channel breakdown) | ✅ Done |
| Template duplicate/delete operations | ✅ Done |
| Incident runbook (`docs/ops/INCIDENT_RUNBOOK.md`) | ✅ Done |
| Deployment cutover checklist (`docs/ops/DEPLOYMENT_CUTOVER_CHECKLIST.md`) | ✅ Done |
| Secret policy CI check (`scripts/check-secrets.sh` + CI integration) | ✅ Done |
| Scheduled publishing support | ✅ Done |

## First 20 must-do tasks (next 30 days)
ENVI-T001 through ENVI-T020 are the mandatory 30-day program.

## GitHub issue mapping recommendation
- Create one issue per ENVI-T00x task.
- Use labels: `phase:foundation`, `area:gitops`, `area:ios`, `area:backend`, `area:ai`, `area:analytics`, `priority:p0/p1`.

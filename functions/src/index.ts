/**
 * ENVI Cloud Functions — barrel.
 *
 * Every exported symbol becomes a deployable function under its export name.
 * Keep exports flat and named (`export { fooFn } from "./foo"`) so
 * `firebase deploy --only functions:fooFn` works.
 *
 * Phase 6 surface:
 *   - health  (06-01) — reachability probe, App Check gated (06-07)
 */
export { health } from "./health";

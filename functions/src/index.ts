/**
 * ENVI Cloud Functions — barrel.
 *
 * Every exported symbol becomes a deployable function under its export name.
 * Keep exports flat and named (`export { fooFn } from "./foo"`) so
 * `firebase deploy --only functions:fooFn` works.
 *
 * Phase 6 surface:
 *   - health  (06-01) — reachability probe, App Check gated (06-07)
 *
 * Phase 7 surface (OAuth broker, provider-agnostic):
 *   - oauthStart      POST /oauth/:provider/start
 *   - oauthCallback   GET  /oauth/:provider/callback
 *   - oauthRefresh    POST /oauth/:provider/refresh
 *   - oauthDisconnect POST /oauth/:provider/disconnect
 *   - oauthStatus     GET  /oauth/:provider/status
 *
 * Provider adapters register themselves in Phases 8+. Phase 7 ships the
 * broker core with NO adapters wired — a `start` call against an
 * unregistered provider returns 404 PROVIDER_NOT_REGISTERED.
 */
export { health } from "./health";

export {
  oauthStart,
  oauthCallback,
  oauthRefresh,
  oauthDisconnect,
  oauthStatus,
} from "./oauth";

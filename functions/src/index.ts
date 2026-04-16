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

/**
 * Phase 8 surface (TikTok sandbox connector):
 *   - connectorsTikTokPublishInit      POST /connectors/tiktok/publish/init
 *   - connectorsTikTokPublishComplete  POST /connectors/tiktok/publish/complete
 *   - connectorsTikTokVideos           GET  /connectors/tiktok/videos
 *
 * Side-effectful import: `./providers/tiktok` registers its
 * `ProviderOAuthAdapter` with the Phase 7 broker registry at module load.
 * Failure to register crashes the function boot (fail-fast vs. 404 at
 * request time).
 */
import "./providers/tiktok";

export {
  connectorsTikTokPublishInit,
  connectorsTikTokPublishComplete,
  connectorsTikTokVideos,
} from "./providers/tiktok.routes";

/**
 * Phase 9 surface (X / Twitter proxy routes):
 *   - connectorsX     POST /connectors/x/tweet
 *                     POST /connectors/x/media
 *                     GET  /connectors/x/account
 *
 * The adapter registers itself with the Phase 7 broker registry at
 * module load — importing the module is sufficient to make `:provider=x`
 * resolve in the generic `/oauth/:provider/*` routes.
 */
export { connectorsX } from "./providers/x";

/**
 * Phase 11 surface (LinkedIn connector):
 *   - connectorsLinkedInOrganizations  GET  /connectors/linkedin/organizations
 *   - publishLinkedIn                  POST /publish/linkedin
 *
 * Importing `./providers/linkedin-register` has the side effect of
 * registering the LinkedIn adapter with the Phase 7 broker registry, so
 * `:provider=linkedin` resolves in the generic `/oauth/:provider/*`
 * routes without any further wiring.
 */
import "./providers/linkedin-register";

export {
  connectorsLinkedInOrganizations,
  publishLinkedIn,
} from "./providers/linkedin.routes";

/**
 * Phase 10 surface (Meta family — Facebook Pages, Instagram, Threads):
 *   - metaPages            GET  /meta/pages            (FB only)
 *   - metaIGAccountType    POST /meta/ig-account-type  (IG only)
 *   - metaSelectPage       POST /oauth/facebook/select-page
 *   - refreshMetaTokens    scheduled — every 50 days
 *
 * Importing `./providers/meta` has the side effect of registering three
 * `ProviderOAuthAdapter`s with the broker registry (facebook, instagram,
 * threads), so all three resolve in `/oauth/:provider/*`.
 */
import "./providers/meta";

export {
  metaPages,
  metaIGAccountType,
  metaSelectPage,
} from "./oauth/metaRoutes";

export { refreshMetaTokens } from "./crons/refreshMetaTokens";

/**
 * Phase 12 surface (publish lifecycle hardening):
 *   - publishDispatch              callable — create job + fan-out Pub/Sub
 *   - publishWorker{Tiktok,X,...}  onMessagePublished — one per platform
 *   - replayDLQ                    callable — admin-only DLQ replay
 *   - dispatchScheduled            scheduled — cron for future-dated jobs
 *   - refreshTokens                scheduled — daily OAuth refresh cron
 *   - instagramWebhook /
 *     facebookWebhook              onRequest — Meta webhook receivers
 */
export { publishDispatch } from "./publish/dispatch";
export { publishWorkerTikTok } from "./publish/workers/tiktokWorker";
export { publishWorkerX } from "./publish/workers/xWorker";
export { publishWorkerInstagram } from "./publish/workers/instagramWorker";
export { publishWorkerFacebook } from "./publish/workers/facebookWorker";
export { publishWorkerThreads } from "./publish/workers/threadsWorker";
export { publishWorkerLinkedIn } from "./publish/workers/linkedinWorker";
export { replayDLQ } from "./publish/replayDLQ";
export { dispatchScheduled } from "./crons/dispatchScheduled";
export { refreshTokens } from "./crons/refreshTokens";
export { instagramWebhook } from "./webhooks/instagram";
export { facebookWebhook } from "./webhooks/facebook";

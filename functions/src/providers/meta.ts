/**
 * meta.ts — `ProviderOAuthAdapter` implementation for Meta's family of apps
 * (Facebook Pages, Instagram Business/Creator, Threads).
 *
 * Phase 10. Single `MetaProvider` class that branches on a
 * `MetaSubPlatform` discriminator rather than three sibling adapters so
 * the 80% shared flow (token endpoint shape, long-lived exchange, profile
 * fetch) lives in one place. Three singleton instances self-register with
 * the broker registry at module load.
 *
 * References (verified 2026-04-16)
 * --------------------------------
 * FB / IG:
 *   Auth:    GET  https://www.facebook.com/dialog/oauth
 *   Token:   GET  https://graph.facebook.com/oauth/access_token
 *   Long:    GET  https://graph.facebook.com/oauth/access_token
 *              grant_type=fb_exchange_token & fb_exchange_token=<short>
 *   Profile: GET  https://graph.facebook.com/me?fields=id,name
 *   Pages:   GET  https://graph.facebook.com/me/accounts
 *   IG type: GET  https://graph.facebook.com/{ig-user-id}?fields=account_type,username,media_count
 * Threads:
 *   Auth:    GET  https://threads.net/oauth/authorize
 *   Token:   POST https://graph.threads.net/oauth/access_token
 *   Long:    GET  https://graph.threads.net/oauth/access_token
 *              grant_type=th_exchange_token
 *
 * Token lifecycle
 * ---------------
 * FB/IG short-lived tokens last ~1h. We immediately exchange for a
 * long-lived token via `fb_exchange_token`, which extends to 60 days.
 * Threads mirrors the pattern with its own exchange grant. Refresh within
 * the 60-day window preserves the token; past the window the provider
 * returns an error and we surface `needsReauth: true`.
 *
 * Secret Manager lookups
 * ----------------------
 * - `staging-meta-app-secret`        — FB Pages client secret.
 * - `staging-instagram-app-secret`   — Instagram Graph client secret.
 * - `staging-threads-app-secret`     — Threads standalone client secret.
 *
 * No client secrets in source. App IDs are public identifiers (shipped in
 * iOS binary, logged on request to help debug misrouted auth URLs).
 */
import type {
  BuildAuthUrlParams,
  ExchangeCodeParams,
  ProviderOAuthAdapter,
  ProviderProfile,
  RawTokenSet,
  RefreshParams,
  RevokeParams,
} from "../oauth/adapter";
import type { SupportedProvider } from "../lib/firestoreSchema";
import { getSecret } from "../lib/secrets";
import { logger } from "../lib/logger";

const log = logger.withContext({ phase: "10", module: "meta" });

// ---------------------------------------------------------------------------
// Sub-platform discrimination
// ---------------------------------------------------------------------------

/** Which Meta product a `MetaProvider` instance wraps. */
export type MetaSubPlatform = "facebook" | "instagram" | "threads";

/** Public App IDs. Not secrets — ship in client binaries + log freely. */
export const META_APP_IDS = {
  facebook: "1233228574968466",
  instagram: "1811522229543951",
  threads: "1604969460421980",
  /** Parent app group used as Secret Manager discriminator only. */
  threadsParent: "1649869446444171",
} as const;

/** Secret Manager key names, one per sub-platform. */
export const META_SECRET_NAMES: Record<MetaSubPlatform, string> = {
  facebook: "staging-meta-app-secret",
  instagram: "staging-instagram-app-secret",
  threads: "staging-threads-app-secret",
};

// ---------------------------------------------------------------------------
// API hosts
// ---------------------------------------------------------------------------

/** Graph API base for Facebook + Instagram. */
export const FB_GRAPH_BASE = "https://graph.facebook.com/v21.0";

/** Graph API base for Threads — DIFFERENT host. */
export const THREADS_GRAPH_BASE = "https://graph.threads.net/v1.0";

/** Authorization endpoint used by FB + IG (share the Facebook login dialog). */
export const FB_AUTH_URL = "https://www.facebook.com/dialog/oauth";

/** Authorization endpoint used by Threads standalone. */
export const THREADS_AUTH_URL = "https://threads.net/oauth/authorize";

/** Token endpoints — FB/IG share, Threads has its own. */
export const FB_TOKEN_URL = "https://graph.facebook.com/oauth/access_token";
export const THREADS_TOKEN_URL = "https://graph.threads.net/oauth/access_token";

// ---------------------------------------------------------------------------
// Scope sets
// ---------------------------------------------------------------------------

export const META_DEFAULT_SCOPES: Record<MetaSubPlatform, readonly string[]> = {
  facebook: [
    "pages_show_list",
    "pages_manage_posts",
    "pages_read_engagement",
    "public_profile",
  ],
  instagram: [
    "instagram_basic",
    "instagram_content_publish",
    "pages_read_engagement",
    "pages_show_list",
  ],
  threads: [
    "threads_basic",
    "threads_content_publish",
    "threads_manage_replies",
  ],
};

// ---------------------------------------------------------------------------
// Long-lived token TTL
// ---------------------------------------------------------------------------

/** 60 days. Matches Meta's documented long-lived user token lifetime. */
export const LONG_LIVED_TOKEN_TTL_SECONDS = 60 * 24 * 60 * 60;

// ---------------------------------------------------------------------------
// Wire types
// ---------------------------------------------------------------------------

interface MetaTokenResponse {
  access_token: string;
  token_type?: "bearer" | "Bearer";
  expires_in?: number;
}

interface MetaProfileResponse {
  id: string;
  name?: string;
  username?: string;
}

interface MetaAccountsResponse {
  data: Array<{
    id: string;
    name: string;
    category?: string;
    access_token: string;
    tasks?: string[];
  }>;
  paging?: { next?: string };
}

interface IGAccountTypeResponse {
  id: string;
  account_type?: "BUSINESS" | "MEDIA_CREATOR" | "PERSONAL";
  username?: string;
  media_count?: number;
}

// ---------------------------------------------------------------------------
// Shapes surfaced to the broker's Meta-specific routes
// ---------------------------------------------------------------------------

/** One Page the user administers. Returned by `getPages`. */
export interface MetaPage {
  pageId: string;
  pageName: string;
  category: string | null;
  tasks: string[];
  /** Per-Page access token. Encrypt + persist server-side. */
  pageAccessToken: string;
}

/** IG account-type detection result. */
export interface IGAccountTypeResult {
  accountType: "BUSINESS" | "MEDIA_CREATOR" | "PERSONAL" | "UNKNOWN";
  username: string | null;
  mediaCount: number | null;
}

/** Refresh result — either fresh tokens or a `needsReauth` signal. */
export type MetaRefreshResult =
  | { needsReauth: false; tokens: RawTokenSet }
  | { needsReauth: true };

// ---------------------------------------------------------------------------
// MetaProvider
// ---------------------------------------------------------------------------

/**
 * Concrete provider implementation. One instance per sub-platform — three
 * are exported + registered at module bottom. Each instance satisfies the
 * `ProviderOAuthAdapter` contract AND exposes Meta-specific helpers
 * (`getPages`, `detectIGAccountType`, `publish*`) that the broker's
 * `/meta/*` routes call directly.
 */
export class MetaProvider implements ProviderOAuthAdapter {
  readonly subPlatform: MetaSubPlatform;
  readonly provider: SupportedProvider;
  readonly defaultScopes: string[];

  private readonly appID: string;
  private readonly authURL: string;
  private readonly tokenURL: string;
  private readonly graphBase: string;
  private readonly secretName: string;

  constructor(subPlatform: MetaSubPlatform) {
    this.subPlatform = subPlatform;
    this.provider = subPlatform satisfies SupportedProvider;
    this.defaultScopes = [...META_DEFAULT_SCOPES[subPlatform]];
    this.appID = META_APP_IDS[subPlatform];
    this.secretName = META_SECRET_NAMES[subPlatform];

    if (subPlatform === "threads") {
      this.authURL = THREADS_AUTH_URL;
      this.tokenURL = THREADS_TOKEN_URL;
      this.graphBase = THREADS_GRAPH_BASE;
    } else {
      this.authURL = FB_AUTH_URL;
      this.tokenURL = FB_TOKEN_URL;
      this.graphBase = FB_GRAPH_BASE;
    }
  }

  // -------------------------------------------------------------------------
  // ProviderOAuthAdapter
  // -------------------------------------------------------------------------

  buildAuthUrl(params: BuildAuthUrlParams): string {
    const scopes = (params.scopes ?? this.defaultScopes).join(",");
    const url = new URL(this.authURL);
    url.searchParams.set("client_id", this.appID);
    url.searchParams.set("redirect_uri", params.redirectUri);
    url.searchParams.set("state", params.state);
    url.searchParams.set("scope", scopes);
    url.searchParams.set("response_type", "code");
    return url.toString();
  }

  async exchangeCode(params: ExchangeCodeParams): Promise<RawTokenSet> {
    const secret = await getSecret(this.secretName);

    // Step 1 — code → short-lived access token.
    const shortLived = await this.fetchToken({
      client_id: this.appID,
      client_secret: secret,
      redirect_uri: params.redirectUri,
      code: params.code,
    });

    // Step 2 — short-lived → long-lived via fb_exchange_token grant.
    // Threads uses the same grant name under its own host.
    const longLived = await this.exchangeForLongLived(
      shortLived.access_token,
      secret
    );

    return {
      accessToken: longLived.access_token,
      refreshToken: null, // Meta doesn't issue refresh tokens; we use long-lived.
      expiresIn: longLived.expires_in ?? LONG_LIVED_TOKEN_TTL_SECONDS,
      scopes: [...this.defaultScopes],
      rawPayload: {
        subPlatform: this.subPlatform,
      },
    };
  }

  async refresh(params: RefreshParams): Promise<RawTokenSet> {
    // Meta doesn't use refresh tokens. We re-run `fb_exchange_token` on
    // the long-lived access token — `params.refreshToken` here carries the
    // prior long-lived access token (broker repurposes the slot).
    const secret = await getSecret(this.secretName);
    const longLived = await this.exchangeForLongLived(params.refreshToken, secret);

    return {
      accessToken: longLived.access_token,
      refreshToken: null,
      expiresIn: longLived.expires_in ?? LONG_LIVED_TOKEN_TTL_SECONDS,
      scopes: [...this.defaultScopes],
      rawPayload: { subPlatform: this.subPlatform, rotated: true },
    };
  }

  async revoke(params: RevokeParams): Promise<void> {
    // FB / IG: DELETE /{user-id}/permissions — requires `user_id` from
    // profile fetch. Threads: no documented revoke endpoint.
    if (!params.accessToken) {
      log.warn("meta revoke skipped — no access token", {
        subPlatform: this.subPlatform,
      });
      return;
    }

    if (this.subPlatform === "threads") {
      log.info("meta revoke no-op (threads has no revoke endpoint)");
      return;
    }

    // Resolve user id first.
    const profile = await this.fetchUserProfile(params.accessToken);
    const url = new URL(`${this.graphBase}/${profile.providerUserId}/permissions`);
    url.searchParams.set("access_token", params.accessToken);

    const res = await fetch(url.toString(), { method: "DELETE" });
    if (!res.ok) {
      const body = await res.text();
      throw new Error(
        `meta: revoke responded HTTP ${res.status}: ${body.slice(0, 200)}`
      );
    }
  }

  async fetchUserProfile(accessToken: string): Promise<ProviderProfile> {
    const fields =
      this.subPlatform === "threads"
        ? "id,username,name"
        : "id,name";
    const url = new URL(`${this.graphBase}/me`);
    url.searchParams.set("fields", fields);
    url.searchParams.set("access_token", accessToken);

    const res = await fetch(url.toString(), { method: "GET" });
    const body = (await res.json()) as MetaProfileResponse;
    if (!res.ok || !body.id) {
      throw new Error(
        `meta: /me responded HTTP ${res.status}: ${JSON.stringify(body).slice(
          0,
          200
        )}`
      );
    }

    return {
      providerUserId: body.id,
      handle: body.username ?? body.name ?? null,
      followerCount: null,
    };
  }

  // -------------------------------------------------------------------------
  // Meta-specific helpers
  // -------------------------------------------------------------------------

  /**
   * List Pages the user administers. FB-only. Called by the broker's
   * `GET /meta/pages` route. Per-Page tokens come back here and the
   * broker encrypts + stores them in Firestore under
   * `users/{uid}/connections/facebook/pages/{pageId}`.
   */
  async getPages(userAccessToken: string): Promise<MetaPage[]> {
    if (this.subPlatform !== "facebook") {
      throw new Error(
        `meta: getPages only valid for facebook subPlatform (got ${this.subPlatform})`
      );
    }

    const url = new URL(`${this.graphBase}/me/accounts`);
    url.searchParams.set("access_token", userAccessToken);
    url.searchParams.set("fields", "id,name,category,access_token,tasks");

    const res = await fetch(url.toString(), { method: "GET" });
    const body = (await res.json()) as MetaAccountsResponse;
    if (!res.ok) {
      throw new Error(
        `meta: /me/accounts responded HTTP ${res.status}: ${JSON.stringify(
          body
        ).slice(0, 200)}`
      );
    }

    return (body.data ?? []).map((row) => ({
      pageId: row.id,
      pageName: row.name,
      category: row.category ?? null,
      tasks: row.tasks ?? [],
      pageAccessToken: row.access_token,
    }));
  }

  /**
   * Detect the connected IG account's type. IG-only. Called by the
   * broker's `POST /meta/ig-account-type` route.
   *
   * @param igUserId   The IG Business/Creator user id (resolved from the
   *                   connected Facebook Page's `instagram_business_account`
   *                   field — the broker handles that lookup).
   * @param accessToken Page access token (IG Content Publishing uses the
   *                    Page token, not the user token).
   */
  async detectIGAccountType(
    igUserId: string,
    accessToken: string
  ): Promise<IGAccountTypeResult> {
    if (this.subPlatform !== "instagram") {
      throw new Error(
        `meta: detectIGAccountType only valid for instagram subPlatform (got ${this.subPlatform})`
      );
    }

    const url = new URL(`${this.graphBase}/${igUserId}`);
    url.searchParams.set("fields", "account_type,username,media_count");
    url.searchParams.set("access_token", accessToken);

    const res = await fetch(url.toString(), { method: "GET" });
    const body = (await res.json()) as IGAccountTypeResponse;
    if (!res.ok) {
      throw new Error(
        `meta: /${igUserId} responded HTTP ${res.status}: ${JSON.stringify(
          body
        ).slice(0, 200)}`
      );
    }

    return {
      accountType: body.account_type ?? "UNKNOWN",
      username: body.username ?? null,
      mediaCount: typeof body.media_count === "number" ? body.media_count : null,
    };
  }

  /**
   * Publish a post to a specific Facebook Page.
   *
   * @param pageId           Target Page id.
   * @param pageAccessToken  Per-Page access token (NOT the user token).
   * @param payload          Publish payload — `caption`, optional media.
   * @returns Graph `post_id`.
   */
  async publishFacebookPost(
    pageId: string,
    pageAccessToken: string,
    payload: { caption: string; mediaURL?: string; mediaType: "text" | "photo" | "video" }
  ): Promise<string> {
    if (this.subPlatform !== "facebook") {
      throw new Error(
        `meta: publishFacebookPost only valid for facebook (got ${this.subPlatform})`
      );
    }

    const endpoint =
      payload.mediaType === "video"
        ? `${this.graphBase}/${pageId}/videos`
        : `${this.graphBase}/${pageId}/feed`;

    const body = new URLSearchParams({
      message: payload.caption,
      access_token: pageAccessToken,
    });

    if (payload.mediaType === "photo" && payload.mediaURL) {
      body.set("url", payload.mediaURL);
    } else if (payload.mediaType === "video" && payload.mediaURL) {
      body.set("file_url", payload.mediaURL);
    }

    const res = await fetch(endpoint, { method: "POST", body });
    const json = (await res.json()) as { id?: string; post_id?: string };
    if (!res.ok) {
      throw new Error(
        `meta: publishFacebookPost responded HTTP ${res.status}: ${JSON.stringify(
          json
        ).slice(0, 200)}`
      );
    }
    return json.id ?? json.post_id ?? "";
  }

  /**
   * Publish Instagram media via the container + publish two-step dance.
   *
   * Container creation → poll `status_code` once a minute up to 5 times →
   * media_publish. Carousel items go through their own sub-containers
   * before being composed into a parent CAROUSEL container.
   */
  async publishInstagramMedia(
    igUserId: string,
    pageAccessToken: string,
    payload: {
      caption: string;
      kind: "single" | "carousel" | "reel";
      mediaURL?: string;
      mediaType?: "image" | "video" | "reel";
      items?: Array<{ mediaURL: string; mediaType: "image" | "video" }>;
    }
  ): Promise<string> {
    if (this.subPlatform !== "instagram") {
      throw new Error(
        `meta: publishInstagramMedia only valid for instagram (got ${this.subPlatform})`
      );
    }

    const containerId = await this.createIGContainer(
      igUserId,
      pageAccessToken,
      payload
    );
    await this.waitForIGContainer(containerId, pageAccessToken);

    const publishURL = new URL(`${this.graphBase}/${igUserId}/media_publish`);
    const body = new URLSearchParams({
      creation_id: containerId,
      access_token: pageAccessToken,
    });
    const res = await fetch(publishURL.toString(), { method: "POST", body });
    const json = (await res.json()) as { id?: string };
    if (!res.ok || !json.id) {
      throw new Error(
        `meta: media_publish responded HTTP ${res.status}: ${JSON.stringify(
          json
        ).slice(0, 200)}`
      );
    }
    return json.id;
  }

  /**
   * Publish a Threads post. Text / media / carousel all go through the
   * same container → wait → publish dance, at the Threads Graph host.
   *
   * Threads recommends a ~30s wait between container creation and publish
   * to let media processing complete; text posts can publish immediately.
   */
  async publishThreadsPost(
    threadsUserId: string,
    accessToken: string,
    payload: {
      kind: "text" | "media" | "carousel";
      text?: string;
      mediaURL?: string;
      mediaType?: "image" | "video";
      items?: Array<{ mediaURL: string; mediaType: "image" | "video" }>;
    }
  ): Promise<string> {
    if (this.subPlatform !== "threads") {
      throw new Error(
        `meta: publishThreadsPost only valid for threads (got ${this.subPlatform})`
      );
    }

    const body = new URLSearchParams({ access_token: accessToken });

    if (payload.kind === "text") {
      body.set("media_type", "TEXT");
      if (payload.text) body.set("text", payload.text);
    } else if (payload.kind === "media" && payload.mediaURL && payload.mediaType) {
      body.set("media_type", payload.mediaType.toUpperCase());
      body.set(payload.mediaType === "image" ? "image_url" : "video_url", payload.mediaURL);
      if (payload.text) body.set("text", payload.text);
    } else if (payload.kind === "carousel" && payload.items) {
      body.set("media_type", "CAROUSEL");
      if (payload.text) body.set("text", payload.text);
      // Carousel children are created separately, then joined via
      // `children` query param. Broker composes the child ids before this
      // helper runs — we accept them pre-composed via `items`.
      body.set(
        "children",
        payload.items.map((i) => i.mediaURL).join(",")
      );
    }

    const containerURL = `${this.graphBase}/${threadsUserId}/threads`;
    const containerRes = await fetch(containerURL, { method: "POST", body });
    const containerJSON = (await containerRes.json()) as { id?: string };
    if (!containerRes.ok || !containerJSON.id) {
      throw new Error(
        `meta: threads container responded HTTP ${containerRes.status}: ${JSON.stringify(
          containerJSON
        ).slice(0, 200)}`
      );
    }

    // 30s settle window for media; text can publish immediately.
    if (payload.kind !== "text") {
      await new Promise((resolve) => setTimeout(resolve, 30_000));
    }

    const publishURL = `${this.graphBase}/${threadsUserId}/threads_publish`;
    const publishBody = new URLSearchParams({
      creation_id: containerJSON.id,
      access_token: accessToken,
    });
    const publishRes = await fetch(publishURL, { method: "POST", body: publishBody });
    const publishJSON = (await publishRes.json()) as { id?: string };
    if (!publishRes.ok || !publishJSON.id) {
      throw new Error(
        `meta: threads_publish responded HTTP ${publishRes.status}: ${JSON.stringify(
          publishJSON
        ).slice(0, 200)}`
      );
    }
    return publishJSON.id;
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  /** Token endpoint POST. Handles FB/IG + Threads in one path. */
  private async fetchToken(params: {
    client_id: string;
    client_secret: string;
    redirect_uri: string;
    code: string;
  }): Promise<MetaTokenResponse> {
    const body = new URLSearchParams({
      client_id: params.client_id,
      client_secret: params.client_secret,
      redirect_uri: params.redirect_uri,
      code: params.code,
    });

    // FB/IG accepts GET with query params OR POST; Threads is POST-only
    // with a grant_type=authorization_code.
    let url = this.tokenURL;
    let init: RequestInit;
    if (this.subPlatform === "threads") {
      body.set("grant_type", "authorization_code");
      init = { method: "POST", body };
    } else {
      url = `${this.tokenURL}?${body.toString()}`;
      init = { method: "GET" };
    }

    const res = await fetch(url, init);
    const json = (await res.json()) as MetaTokenResponse & { error?: unknown };
    if (!res.ok || (json as { error?: unknown }).error) {
      throw new Error(
        `meta: token endpoint HTTP ${res.status}: ${JSON.stringify(json).slice(
          0,
          200
        )}`
      );
    }
    return json;
  }

  /**
   * Exchange a short-lived access token for a long-lived (~60 day) one.
   * FB/IG: `grant_type=fb_exchange_token`. Threads: `grant_type=th_exchange_token`.
   */
  private async exchangeForLongLived(
    shortToken: string,
    clientSecret: string
  ): Promise<MetaTokenResponse> {
    const grantType =
      this.subPlatform === "threads" ? "th_exchange_token" : "fb_exchange_token";

    const url = new URL(this.tokenURL);
    url.searchParams.set("grant_type", grantType);
    url.searchParams.set("client_id", this.appID);
    url.searchParams.set("client_secret", clientSecret);
    if (this.subPlatform === "threads") {
      url.searchParams.set("access_token", shortToken);
    } else {
      url.searchParams.set("fb_exchange_token", shortToken);
    }

    const res = await fetch(url.toString(), { method: "GET" });
    const json = (await res.json()) as MetaTokenResponse & { error?: unknown };
    if (!res.ok || (json as { error?: unknown }).error) {
      throw new Error(
        `meta: long-lived exchange HTTP ${res.status}: ${JSON.stringify(
          json
        ).slice(0, 200)}`
      );
    }
    // Meta sometimes omits `expires_in` on long-lived — assume 60d.
    if (typeof json.expires_in !== "number") {
      json.expires_in = LONG_LIVED_TOKEN_TTL_SECONDS;
    }
    return json;
  }

  /** Create an IG media container. Single / reel / carousel. */
  private async createIGContainer(
    igUserId: string,
    pageAccessToken: string,
    payload: {
      caption: string;
      kind: "single" | "carousel" | "reel";
      mediaURL?: string;
      mediaType?: "image" | "video" | "reel";
      items?: Array<{ mediaURL: string; mediaType: "image" | "video" }>;
    }
  ): Promise<string> {
    const url = `${this.graphBase}/${igUserId}/media`;
    const body = new URLSearchParams({
      caption: payload.caption,
      access_token: pageAccessToken,
    });

    if (payload.kind === "reel") {
      body.set("media_type", "REELS");
      if (payload.mediaURL) body.set("video_url", payload.mediaURL);
    } else if (payload.kind === "single" && payload.mediaType && payload.mediaURL) {
      if (payload.mediaType === "video") {
        body.set("media_type", "VIDEO");
        body.set("video_url", payload.mediaURL);
      } else {
        body.set("image_url", payload.mediaURL);
      }
    } else if (payload.kind === "carousel" && payload.items) {
      body.set("media_type", "CAROUSEL");
      // Children must be pre-created (own containers); broker composes
      // them before this helper is invoked. Here we accept the child ids
      // as joined strings in `mediaURL` fields, comma-separated.
      body.set(
        "children",
        payload.items.map((i) => i.mediaURL).join(",")
      );
    }

    const res = await fetch(url, { method: "POST", body });
    const json = (await res.json()) as { id?: string };
    if (!res.ok || !json.id) {
      throw new Error(
        `meta: container HTTP ${res.status}: ${JSON.stringify(json).slice(0, 200)}`
      );
    }
    return json.id;
  }

  /**
   * Poll the IG container until `status_code = FINISHED`. Max 5 attempts,
   * 60s apart — matches Graph API's documented processing window for most
   * assets. Videos > 90s may need a longer window but that's a Phase 13+
   * concern.
   */
  private async waitForIGContainer(
    containerId: string,
    pageAccessToken: string
  ): Promise<void> {
    const url = new URL(`${this.graphBase}/${containerId}`);
    url.searchParams.set("fields", "status_code");
    url.searchParams.set("access_token", pageAccessToken);

    for (let attempt = 0; attempt < 5; attempt++) {
      const res = await fetch(url.toString(), { method: "GET" });
      const json = (await res.json()) as { status_code?: string };
      if (json.status_code === "FINISHED") return;
      if (json.status_code === "ERROR" || json.status_code === "EXPIRED") {
        throw new Error(`meta: IG container ${json.status_code}`);
      }
      await new Promise((resolve) => setTimeout(resolve, 60_000));
    }

    throw new Error("meta: IG container never reached FINISHED");
  }
}

// ---------------------------------------------------------------------------
// Singleton + self-register at module load
// ---------------------------------------------------------------------------

export const metaFacebookAdapter = new MetaProvider("facebook");
export const metaInstagramAdapter = new MetaProvider("instagram");
export const metaThreadsAdapter = new MetaProvider("threads");

import { register } from "../oauth/registry";

register(metaFacebookAdapter);
register(metaInstagramAdapter);
register(metaThreadsAdapter);

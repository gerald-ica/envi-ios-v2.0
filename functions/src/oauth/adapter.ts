/**
 * adapter.ts — the single contract every provider plugin must satisfy.
 *
 * Phase 07 ships the INTERFACE only. Concrete implementations land in
 * Phases 8+ under `functions/src/connectors/<provider>/adapter.ts`:
 *   - 08: tiktok
 *   - 09: x
 *   - 10: meta (facebook, instagram, threads)
 *   - 11: linkedin
 *
 * Design rationale
 * ----------------
 * The broker core (start/callback/refresh/disconnect/status handlers) is
 * provider-AGNOSTIC: it handles PKCE, state signing, encryption, rotation
 * detection. All provider-specific shapes (auth URLs, token endpoints,
 * revocation semantics, user profile schemas) live behind this interface.
 *
 * Consequence: adding a 7th provider means creating one new adapter file
 * and calling `register(new WhateverAdapter())` from its entry point — no
 * changes to broker handlers.
 *
 * Contract invariants
 * -------------------
 * 1. `provider` MUST match exactly one entry in `SupportedProvider`
 *    (see `functions/src/lib/firestoreSchema.ts`). Register-time check in
 *    `registry.ts` enforces this.
 * 2. `buildAuthUrl` is pure (no side effects, no network) — we call it
 *    inside `start.ts` AFTER we've already persisted PKCE state.
 * 3. `exchangeCode` / `refresh` / `revoke` perform one HTTP round-trip
 *    to the provider and are expected to throw on non-2xx responses.
 * 4. `RawTokenSet.expiresIn` is expressed in SECONDS from "now" (per RFC
 *    6749). The broker layer converts this to an absolute `expiresAt`
 *    Firestore Timestamp before persisting.
 * 5. None of these methods touch Firestore, KMS, or Secret Manager
 *    directly — secrets come in via adapter constructor; storage is the
 *    broker layer's responsibility.
 */
import type { SupportedProvider } from "../lib/firestoreSchema";

/**
 * Token set as returned by a provider's token endpoint (normalized shape).
 * Individual adapters map their provider's wire format onto this type.
 */
export interface RawTokenSet {
  /** Bearer access token, unencrypted. Short-lived in memory only. */
  accessToken: string;

  /**
   * Refresh token. Nullable because some providers (e.g. X OAuth 1.0a)
   * don't issue one, or issue one only conditionally.
   */
  refreshToken: string | null;

  /** Seconds from "now" until the access token expires. */
  expiresIn: number;

  /** Space-separated scope string echoed back by the provider. Array form. */
  scopes: string[];

  /**
   * Opaque provider-specific extras the broker itself doesn't need, but a
   * specific adapter might (e.g. TikTok's `open_id` is echoed here).
   * Never persisted in plaintext — adapters that need this across calls
   * must add their own Firestore field with explicit encryption.
   */
  rawPayload?: Record<string, unknown>;
}

/**
 * User-facing profile fields we persist alongside the encrypted tokens.
 * Everything here is public metadata that Firestore rules allow the
 * owning user to read directly (see `firestore.rules`).
 */
export interface ProviderProfile {
  /**
   * Stable, provider-issued user ID. This is the primary key we use to
   * detect account switches during a reconnect flow. MUST be non-empty.
   */
  providerUserId: string;

  /** @ handle / username. Nullable if the provider doesn't surface one. */
  handle: string | null;

  /** Integer follower count. Nullable if the provider gates this behind scopes. */
  followerCount: number | null;
}

/**
 * Input to `buildAuthUrl`. The broker computes `state` and `codeChallenge`
 * and passes them verbatim — the adapter concatenates them into the
 * provider-specific authorize URL.
 */
export interface BuildAuthUrlParams {
  /** JWT state token issued by `state.ts`. Opaque to the adapter. */
  state: string;

  /** PKCE S256 challenge (base64url-encoded SHA-256 digest). */
  codeChallenge: string;

  /** Absolute redirect URI the provider will 302 back to. */
  redirectUri: string;

  /** Explicit scope override. When `undefined`, adapter uses `defaultScopes`. */
  scopes?: string[];
}

export interface ExchangeCodeParams {
  code: string;
  codeVerifier: string;
  redirectUri: string;
}

export interface RefreshParams {
  refreshToken: string;
}

export interface RevokeParams {
  accessToken: string;
  refreshToken?: string | null;
}

/**
 * The plugin contract. Concrete adapters are registered at module load via
 * `registry.register(new FooAdapter())`. Mis-registration (wrong provider
 * string, duplicate registration) panics at startup — see registry.ts.
 */
export interface ProviderOAuthAdapter {
  /**
   * Canonical provider slug. Must be one of the SupportedProvider enum
   * values. The registry rejects anything else at registration time.
   */
  readonly provider: SupportedProvider;

  /**
   * Default OAuth scopes this provider needs for the ENVI permission set.
   * Treated as the source of truth unless a caller explicitly overrides.
   */
  readonly defaultScopes: string[];

  buildAuthUrl(params: BuildAuthUrlParams): string;

  exchangeCode(params: ExchangeCodeParams): Promise<RawTokenSet>;

  refresh(params: RefreshParams): Promise<RawTokenSet>;

  revoke(params: RevokeParams): Promise<void>;

  fetchUserProfile(accessToken: string): Promise<ProviderProfile>;
}

/**
 * errors.ts — typed error surface for the OAuth broker.
 *
 * Phase 07. Every handler in `functions/src/oauth/` throws `OAuthBrokerError`
 * with a code from `OAuthBrokerErrorCode` when something goes wrong. The
 * top-level handler is responsible for mapping the error onto an HTTP
 * response (JSON body for JSON endpoints, 302-to-app-scheme for the
 * browser-driven callback endpoint).
 *
 * Invariant: error messages NEVER include token material, PKCE verifiers,
 * state JWTs, or provider secrets. The `detail` field is an opaque string
 * safe to log and safe (with a short `code`) to surface to iOS.
 */

export enum OAuthBrokerErrorCode {
  PROVIDER_NOT_REGISTERED = "PROVIDER_NOT_REGISTERED",
  STATE_EXPIRED = "STATE_EXPIRED",
  STATE_MISMATCH = "STATE_MISMATCH",
  STATE_INVALID = "STATE_INVALID",
  CODE_EXCHANGE_FAILED = "CODE_EXCHANGE_FAILED",
  CODE_MISSING = "CODE_MISSING",
  REFRESH_TOKEN_REUSE = "REFRESH_TOKEN_REUSE",
  REFRESH_FAILED = "REFRESH_FAILED",
  REVOCATION_FAILED = "REVOCATION_FAILED",
  ENCRYPTION_ERROR = "ENCRYPTION_ERROR",
  UNAUTHENTICATED = "UNAUTHENTICATED",
  CONNECTION_NOT_FOUND = "CONNECTION_NOT_FOUND",
  INTERNAL = "INTERNAL",
}

/**
 * Default HTTP status codes per broker error code. Used by JSON endpoints.
 * Callback endpoint maps every error onto a 302 redirect instead.
 */
const DEFAULT_STATUS: Record<OAuthBrokerErrorCode, number> = {
  [OAuthBrokerErrorCode.PROVIDER_NOT_REGISTERED]: 404,
  [OAuthBrokerErrorCode.STATE_EXPIRED]: 400,
  [OAuthBrokerErrorCode.STATE_MISMATCH]: 400,
  [OAuthBrokerErrorCode.STATE_INVALID]: 400,
  [OAuthBrokerErrorCode.CODE_EXCHANGE_FAILED]: 502,
  [OAuthBrokerErrorCode.CODE_MISSING]: 400,
  [OAuthBrokerErrorCode.REFRESH_TOKEN_REUSE]: 401,
  [OAuthBrokerErrorCode.REFRESH_FAILED]: 502,
  [OAuthBrokerErrorCode.REVOCATION_FAILED]: 502,
  [OAuthBrokerErrorCode.ENCRYPTION_ERROR]: 500,
  [OAuthBrokerErrorCode.UNAUTHENTICATED]: 401,
  [OAuthBrokerErrorCode.CONNECTION_NOT_FOUND]: 404,
  [OAuthBrokerErrorCode.INTERNAL]: 500,
};

export class OAuthBrokerError extends Error {
  readonly code: OAuthBrokerErrorCode;
  readonly httpStatus: number;
  readonly detail: string | null;
  readonly cause: unknown;

  constructor(
    code: OAuthBrokerErrorCode,
    detail?: string | null,
    options?: { cause?: unknown; httpStatus?: number }
  ) {
    super(`${code}${detail ? `: ${detail}` : ""}`);
    this.name = "OAuthBrokerError";
    this.code = code;
    this.detail = detail ?? null;
    this.httpStatus = options?.httpStatus ?? DEFAULT_STATUS[code];
    this.cause = options?.cause ?? null;
  }

  /** Serializable JSON body safe to return to iOS. */
  toResponseBody(): { error: string; detail: string | null } {
    return { error: this.code, detail: this.detail };
  }
}

/**
 * Narrow helper — returns true if `err` is an OAuthBrokerError. Avoids
 * `instanceof` pitfalls across the ESM/CommonJS boundary (shouldn't bite us
 * in CommonJS but defensive).
 */
export function isOAuthBrokerError(err: unknown): err is OAuthBrokerError {
  return (
    err instanceof OAuthBrokerError ||
    (typeof err === "object" &&
      err !== null &&
      (err as { name?: string }).name === "OAuthBrokerError")
  );
}

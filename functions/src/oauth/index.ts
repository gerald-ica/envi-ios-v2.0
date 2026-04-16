/**
 * oauth barrel — re-exports the 5 HTTP functions so the top-level
 * `functions/src/index.ts` can declare them without reaching into every
 * handler file.
 */
export { oauthStart } from "./start";
export { oauthCallback } from "./callback";
export { oauthRefresh } from "./refresh";
export { oauthDisconnect } from "./disconnect";
export { oauthStatus } from "./status";

export { register, resolve, listRegistered } from "./registry";
export type {
  ProviderOAuthAdapter,
  RawTokenSet,
  ProviderProfile,
  BuildAuthUrlParams,
  ExchangeCodeParams,
  RefreshParams,
  RevokeParams,
} from "./adapter";
export { OAuthBrokerError, OAuthBrokerErrorCode } from "./errors";

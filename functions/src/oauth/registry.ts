/**
 * registry.ts — module-level Map of registered `ProviderOAuthAdapter`s.
 *
 * Phase 07. Adapters call `register(adapter)` at module load (typically from
 * their own entry point). Broker handlers call `resolve(provider)` to fetch
 * the adapter at request time; unregistered providers 404.
 *
 * Fail-fast semantics
 * -------------------
 * - `register` throws if the same provider is registered twice — surfacing
 *   wiring bugs at deploy instead of runtime.
 * - `register` throws if the adapter's `provider` field is not a known
 *   `SupportedProvider`. This keeps the surface tight and prevents typos.
 *
 * Thread-safety
 * -------------
 * Node is single-threaded per container. The registry Map is populated
 * synchronously at module init time; we treat it as frozen from the first
 * HTTP request onwards. A guard in `register` tolerates repeat registrations
 * that happen during jest hot-reload (same object identity → no-op).
 */
import type { ProviderOAuthAdapter } from "./adapter";
import {
  SUPPORTED_PROVIDERS,
  type SupportedProvider,
} from "../lib/firestoreSchema";
import { OAuthBrokerError, OAuthBrokerErrorCode } from "./errors";

const registry = new Map<SupportedProvider, ProviderOAuthAdapter>();

/**
 * Register an adapter. Safe to call at module load.
 *
 * @throws {Error} if `adapter.provider` is not a SupportedProvider.
 * @throws {Error} if a different adapter is already registered for that
 *                 provider.
 */
export function register(adapter: ProviderOAuthAdapter): void {
  if (!SUPPORTED_PROVIDERS.includes(adapter.provider)) {
    throw new Error(
      `oauth/registry: cannot register adapter for unknown provider "${String(
        adapter.provider
      )}". Known providers: ${SUPPORTED_PROVIDERS.join(", ")}`
    );
  }

  const existing = registry.get(adapter.provider);
  if (existing !== undefined && existing !== adapter) {
    throw new Error(
      `oauth/registry: a different adapter is already registered for provider "${adapter.provider}"`
    );
  }

  registry.set(adapter.provider, adapter);
}

/**
 * Look up an adapter by provider slug. The lookup is case-sensitive; HTTP
 * handlers are expected to normalize the URL path segment before calling.
 *
 * @throws {OAuthBrokerError} PROVIDER_NOT_REGISTERED if not found.
 */
export function resolve(provider: string): ProviderOAuthAdapter {
  const adapter = registry.get(provider as SupportedProvider);
  if (!adapter) {
    throw new OAuthBrokerError(
      OAuthBrokerErrorCode.PROVIDER_NOT_REGISTERED,
      `no adapter registered for "${provider}"`
    );
  }
  return adapter;
}

/**
 * Snapshot of registered provider slugs. Useful for health endpoints and
 * tests. Order follows insertion order of the underlying Map.
 */
export function listRegistered(): SupportedProvider[] {
  return Array.from(registry.keys());
}

/**
 * Test-only: wipe the registry. Production code MUST NOT call this.
 * @internal
 */
export function __resetRegistryForTests(): void {
  registry.clear();
}

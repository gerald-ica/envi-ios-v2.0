/**
 * linkedin-register.ts — side-effect module that wires the LinkedIn
 * `ProviderOAuthAdapter` into the Phase 7 OAuth broker registry.
 *
 * Phase 11. Importing this module exactly once is enough — the registry
 * guards against double-registration (see `oauth/registry.ts`). The
 * extraction into its own file keeps `providers/linkedin.ts` free of
 * side effects so jest's module cache doesn't produce "already
 * registered" errors when tests repeatedly import the adapter.
 */
import { register } from "../oauth/registry";
import { linkedInAdapter } from "./linkedin";

register(linkedInAdapter);

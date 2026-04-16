---
phase: 06-connector-foundation
milestone: v1.1-real-social-connectors
type: execute
depends-on: v1.0 complete
---

# Phase 6 — Connector Foundation

**Goal:** Firebase backend shell + iOS OAuth session abstraction. After this phase: Functions project compiles/deploys, 8 provider secrets in Secret Manager, Firestore rules enforce per-user isolation, iOS `OAuthSession` protocol + `ASWebAuthenticationSession` adapter compile, env plumbing wired, 6 sandbox redirect URIs registered (human-gated checklist), token fields encrypted via Cloud KMS envelope encryption with Firebase App Check.

**Constraint:** Zero changes to `SocialOAuthManager` public API. `useMockOAuth` stays `true` until Phase 7.

---

## Dependency Graph

```
06-01 (Functions bootstrap) ──► 06-02 (Secret Manager, needs SA email)
                            ──► 06-03 stub (Firestore rules, needs firebase.json functions section)
                            ──► 06-05 (env plumbing, needs functions/ dir)
06-04 (iOS OAuthSession) — independent, parallelize
06-02 + 06-03 + 06-05 ──► 06-07 (KMS + App Check)
06-06 — pure documentation
```

---

## 06-01  Firebase Cloud Functions bootstrap

**New files:**
- `functions/package.json` (Node 20, deps: firebase-admin, firebase-functions v2, @google-cloud/secret-manager, @google-cloud/kms)
- `functions/tsconfig.json` (strict, ES2022, outDir lib)
- `functions/.eslintrc.js`, `functions/.gitignore`
- `functions/src/index.ts` (barrel; exports `health`)
- `functions/src/health.ts` (`onRequest`, region `us-central1`, returns `{ status: "ok", phase: "06-01", env }`)
- `functions/src/lib/logger.ts` (wraps `firebase-functions/logger`, adds `phase` + `provider` fields)
- `functions/src/__tests__/health.test.ts`

**Modify:** `firebase.json` — add `"functions": { "source": "functions", "runtime": "nodejs20", "ignore": ["node_modules", "lib", ".git"] }` (preserve existing `dataconnect`).

**Acceptance:** `npm run build` 0 errors, emulator reachable, `firebase deploy --only functions` succeeds.

---

## 06-02  Secret Manager provisioning + rotation

**New files:**
- `scripts/provision-secrets.sh` (idempotent; `--project`, `--env`; grants `secretmanager.secretAccessor` to Functions SA)
- `docs/ops/secret-rotation-checklist.md` (per-provider rotation instructions; documents 2026-04-16 incident)
- `functions/src/lib/secrets.ts` — `getSecret(name)` lazy-load + module cache, `SecretNotFoundError`
- `functions/src/__tests__/secrets.test.ts`

**Secret names (staging-* prefix):**
```
staging-tiktok-sandbox-client-secret
staging-x-oauth1-consumer-secret
staging-x-oauth1-access-token-secret
staging-x-bearer-token
staging-x-oauth2-client-secret
staging-meta-app-secret
staging-envi-threads-app-secret
staging-threads-app-secret
staging-instagram-app-secret
staging-instagram-client-token
staging-linkedin-primary-client-secret
```

**Human gate:** All secrets rotated per checklist BEFORE `useMockOAuth = false`. Record completion date in STATE.md.

---

## 06-03  Firestore schema + security rules

**New files:**
- `functions/src/lib/firestoreSchema.ts` — `ConnectionDocument` interface:
  ```typescript
  interface ConnectionDocument {
    provider: SupportedProvider;   // "tiktok"|"x"|"instagram"|"facebook"|"threads"|"linkedin"
    providerUserId: string;
    handle: string | null;
    followerCount: number | null;
    scopes: string[];
    expiresAt: Timestamp;
    revokedAt: Timestamp | null;
    connectedAt: Timestamp;
    lastRefreshedAt: Timestamp | null;
    accessTokenCiphertext: string;        // base64(AES-256-GCM)
    refreshTokenCiphertext: string | null;
    dekCiphertext: string;                // base64(KMS.encrypt(DEK))
  }
  ```
  `connectionDocRef(uid, provider)` helper + Zod runtime validation.
- `firestore.rules`:
  ```
  match /users/{uid}/connections/{provider} {
    allow read: if request.auth != null && request.auth.uid == uid;
    allow write: if false;  // Admin SDK only
  }
  ```
- `firestore.indexes.json` (empty baseline)
- `functions/src/__tests__/firestore.rules.test.ts` (4 cases: own-read, other-uid-denied, client-write-denied, unauth-denied)

**Modify:** `firebase.json` — add `"firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" }`.

---

## 06-04  iOS OAuthSession protocol + ASWebAuthenticationSession adapter

**New files:**
- `ENVI/Core/Auth/OAuthSession.swift`:
  ```swift
  protocol OAuthSession: AnyObject {
      func start(authorizationURL: URL, callbackScheme: String) async throws -> URL
      func cancel()
  }
  enum OAuthSessionError: Error { case userCancelled, callbackURLInvalid(URL), sessionAlreadyActive }
  struct OAuthCallbackURL { let provider: SocialPlatform; let code, state, error: String?; let rawURL: URL }
  ```
- `ENVI/Core/Auth/ASWebAuthenticationSessionAdapter.swift` — `@MainActor final class` wrapping ASWebAuthenticationSession; `prefersEphemeralWebBrowserSession = false`
- `ENVI/Core/Auth/OAuthCallbackHandler.swift` — parses `enviapp://oauth-callback/{provider}?...`; posts `ENVIOAuthCallbackReceived` notification
- `ENVI/Resources/Info.plist` — full generated Info.plist replacing `GENERATE_INFOPLIST_FILE = YES`; includes `CFBundleURLTypes` for `enviapp` scheme
- `ENVITests/OAuthCallbackHandlerTests.swift` (6 URL parsing cases)
- `ENVITests/ASWebAuthenticationSessionAdapterTests.swift`

**Modify:**
- `ENVI.xcconfig`: `INFOPLIST_FILE = ENVI/Resources/Info.plist`, remove `GENERATE_INFOPLIST_FILE`, add `ENVI_CONNECTOR_ENV = sandbox`
- `ENVI/App/ENVIApp.swift`: `.onOpenURL { url in OAuthCallbackHandler.handle(url) }`

**URL scheme (Info.plist):**
```xml
<key>CFBundleURLTypes</key><array><dict>
  <key>CFBundleURLSchemes</key><array><string>enviapp</string></array>
  <key>CFBundleURLName</key><string>com.weareinformal.envi.staging.oauth</string>
</dict></array>
```

---

## 06-05  Environment plumbing

**New files:**
- `functions/src/lib/config.ts` — `getConnectorEnv(): "sandbox"|"prod"` reads `process.env.ENVI_CONNECTOR_ENV`; `getRegion()`
- `functions/.env.staging` — `ENVI_CONNECTOR_ENV=sandbox`

**Modify — `ENVI/Core/Config/AppEnvironment.swift`:**
```swift
extension AppConfig {
    static let connectorEnvKey = "ENVI_CONNECTOR_ENV"
    enum ConnectorEnvironment: String { case sandbox, prod }
    static var currentConnector: ConnectorEnvironment {
        guard let raw = ProcessInfo.processInfo.environment[connectorEnvKey],
              let env = ConnectorEnvironment(rawValue: raw) else { return .sandbox }
        return env
    }
    static var connectorFunctionsBaseURL: URL { /* emulator or cloudfunctions.net */ }
    private static var firebaseProjectID: String { FirebaseApp.app()?.options.projectID ?? "envi-staging" }
}
```

---

## 06-06  Sandbox redirect URI registration (human-gated)

**New file:** `docs/ops/06-06-sandbox-redirect-checklist.md`

Per-provider rows with exact redirect URIs to register:
- TikTok Sandbox → `enviapp://oauth-callback/tiktok`
- X → `enviapp://oauth-callback/x`
- Facebook → `enviapp://oauth-callback/facebook`
- Instagram → `enviapp://oauth-callback/instagram`
- Threads → `enviapp://oauth-callback/threads`
- LinkedIn → `enviapp://oauth-callback/linkedin`

Plus: TikTok Sandbox Target Users add step; Meta OAuth redirect URI locations (FB Login settings + Advanced iOS); LinkedIn Auth tab; X Callback URI field.

---

## 06-07  Security — App Check + KMS envelope encryption

**New files:**
- `scripts/provision-kms.sh` — creates key ring `envi-oauth-tokens`, key `token-kek` (AES-256); grants `cloudkms.cryptoKeyEncrypterDecrypter`
- `functions/src/lib/kmsEncryption.ts`:
  ```typescript
  interface EncryptedTokenPair { accessTokenCiphertext, refreshTokenCiphertext, dekCiphertext: string }
  encryptTokenPair(accessToken, refreshToken, kmsKeyName): Promise<EncryptedTokenPair>
  decryptTokenPair(encrypted, kmsKeyName): Promise<{accessToken, refreshToken}>
  ```
  Envelope pattern: random 32-byte DEK → AES-256-GCM encrypt token + IV + authTag → KMS.encrypt(DEK) → store base64.
- `functions/src/lib/appCheck.ts` — `requireAppCheck(handler)` middleware; validates `X-Firebase-AppCheck` header, rejects 401
- `functions/src/lib/tokenStorage.ts` — `writeConnection(uid, provider, tokens)`, `readConnection(uid, provider)` wraps encrypt/decrypt
- `functions/src/__tests__/kmsEncryption.test.ts`, `appCheck.test.ts`

**Modify:**
- `Package.swift` — add `FirebaseAppCheck` product to ENVI target
- `ENVI/Core/Auth/AuthManager.swift` — before `FirebaseApp.configure()`:
  ```swift
  #if DEBUG
  AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
  #else
  AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
  #endif
  ```
- `functions/src/health.ts` — wrap with `requireAppCheck`

**KMS key name:** `projects/{project}/locations/global/keyRings/envi-oauth-tokens/cryptoKeys/token-kek`

---

## Build Sequence

**Stage A (unblock):** 06-01 → deploy to staging → health endpoint reachable
**Stage B (parallel):** 06-02, 06-03, 06-04, 06-05, 06-06
**Stage C (security):** 06-07
**Stage D (verify):** `npm test` passes, `xcodebuild test` passes, `useMockOAuth` still `true`, `enviapp` in compiled plist, no plaintext tokens in emulator Firestore

---

## Phase Exit Criteria

- [ ] `cd functions && npm run build` 0 errors
- [ ] `npm test` passes (all 7 test files)
- [ ] `firebase deploy --only functions,firestore:rules` succeeds
- [ ] `xcodebuild test -scheme ENVI` passes
- [ ] `enviapp` URL scheme visible via `plutil` on compiled `.app`
- [ ] 11 staging secrets exist in Secret Manager
- [ ] 4-case Firestore rules tests pass against emulator
- [ ] KMS key ring `envi-oauth-tokens` + key `token-kek` exist
- [ ] Both checklist docs exist
- [ ] `SocialOAuthManager.useMockOAuth` still `true`
- [ ] STATE.md updated with Phase 6 complete + Phase 7 blockers (redirect URI registration + rotation)

## Open Questions

1. What is the staging Firebase project ID? (needed for `connectorFunctionsBaseURL` + provision scripts)
2. Functions service account email assigned? (`provision-secrets.sh` needs it)
3. Is `ENVIApp.swift` the correct scene entry, or is there a `SceneDelegate`?

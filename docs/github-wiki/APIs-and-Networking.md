# APIs & networking

**Last updated:** 2026-04-03 UTC

## REST (`APIClient.swift`)

| Item | Value |
|------|--------|
| **Base URL** | `https://api.envi.app/v1` |
| **Implementation** | **Placeholder only** |
| **`mockRequest`** | Always throws `APIError.notImplemented` |
| **Errors** | `networkError`, `decodingError`, `unauthorized`, `notImplemented` |

**Future work:** Define real endpoints (auth, content assembly, analytics ingestion), request/response `Codable` types, and replace stub with `URLSession` (or Alamofire, etc.).

## Content assembly queue (`ContentPieceAssembler.swift`)

**Intended product behavior (from comments):** Queue `PHAsset` local identifiers → upload → backend AI → receive `ContentPiece` for World Explorer.

**Current behavior:** **Stub** — `enqueueForAssembly` increments queue, stores completion handlers, **no** upload or network. Delegate callbacks exist for future wiring.

## GraphQL (Firebase Data Connect)

Not called from iOS today. Operations live under `dataconnect/example/queries.gql`. See [Firebase Data Connect](Firebase-Data-Connect).

## Third-party SDKs (network-capable)

| SDK | Use |
|-----|-----|
| **RevenueCat** | App Store purchases, customer info — not “ENVI REST” |
| **SDWebImage** | Image URLs when used |

## Security note

Do **not** commit production API keys or `GoogleService-Info.plist` secrets into the wiki. Reference file locations only.

---

Append new endpoints here when `APIClient` is implemented; log changes in `docs/WIKI_CHANGELOG.md`.

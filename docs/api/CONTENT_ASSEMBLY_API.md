# Content Assembly API Contract

Last updated: 2026-04-04 UTC

## Purpose

Defines the backend contract used by `ContentPieceAssembler` for media upload + content piece assembly.

## Auth

- All endpoints require authenticated bearer token from Firebase Auth.

## Endpoints

### `POST /v1/media/assets`

Request:

```json
{
  "mediaID": "phasset-local-id",
  "fileName": "ABC123.mov",
  "fileUrl": "envi://local/ABC123",
  "fileType": "video",
  "duration": 12.34
}
```

Response:

```json
{
  "id": "media_asset_id"
}
```

### `POST /v1/content/assemble`

Request:

```json
{
  "mediaAssetID": "media_asset_id"
}
```

Response:

```json
{
  "id": "content_piece_id"
}
```

## Client behavior

- `ContentPieceAssembler` enqueues media IDs and processes in async order.
- Failed items retry up to 3 attempts before final failure.
- Queue completion and per-item success/failure are emitted via delegate callbacks.

/**
 * linkedin-publish.ts — LinkedIn Posts API publishing helpers.
 *
 * Phase 11. Implements the three post variants on LinkedIn's `/rest/posts`
 * endpoint (the successor to LinkedIn's legacy user-generated-content
 * endpoint, which was sunset in June 2023 and MUST NOT appear anywhere
 * in this codebase).
 *
 * Endpoint catalog (all under `https://api.linkedin.com`)
 * -------------------------------------------------------
 *   POST /rest/posts                                  text / attach-media post
 *   POST /rest/images?action=initializeUpload         image upload init
 *   PUT  {presignedUrl}                               image upload bytes
 *   POST /rest/videos?action=initializeUpload         video upload init
 *   PUT  {presignedUrl}  (each 4MB chunk)             video upload part
 *   POST /rest/videos?action=finalizeUpload           video upload finalize
 *   GET  /rest/videos/{encodedUrn}                    video processing status
 *
 * Header invariants
 * -----------------
 * Every call to a `/rest/*` path (but NOT the pre-signed upload PUTs — those
 * carry no auth header at all and use Content-Type: application/octet-stream)
 * must carry:
 *   - Authorization: Bearer {accessToken}
 *   - Linkedin-Version: 202505 (pinned; review 2027-04-01)
 *   - X-Restli-Protocol-Version: 2.0.0
 *
 * Post body invariants
 * --------------------
 * A minimal text post shape is:
 *   {
 *     "author":            "{authorUrn}",
 *     "commentary":        "{caption}",
 *     "visibility":        "PUBLIC",
 *     "distribution":      { "feedDistribution": "MAIN_FEED",
 *                            "targetEntities": [],
 *                            "thirdPartyDistributionChannels": [] },
 *     "lifecycleState":    "PUBLISHED",
 *     "isReshareDisabledByAuthor": false
 *   }
 *
 * Media posts add:  "content": { "media": { "id": "{assetUrn}" } }
 *
 * Media validation (enforced here BEFORE the round-trip)
 * ------------------------------------------------------
 *   Image:  JPEG or PNG. No extension whitelist on the server —
 *           LinkedIn infers from bytes — but we enforce JPEG / PNG
 *           up-front to match Posts API docs.
 *   Video:  MP4 container, 3s–30min duration, 75KB–500MB file size.
 *           Duration isn't something we can check from the buffer
 *           alone; iOS validates duration before upload and the Cloud
 *           Function re-checks size here.
 *
 * Retries
 * -------
 *   - 409 Conflict on POST /rest/posts → retry once after 1s. Surfaces
 *     when LinkedIn's author-URN rate limit trips on rapid back-to-back
 *     posts.
 *   - Upload URL expired (`uploadUrlExpiresAt < now+60s`) → re-initialize
 *     once. This beats racing the clock on slow client networks.
 */
import { Buffer } from "node:buffer";

import { LINKEDIN_API_HEADERS } from "./linkedin";
import { logger } from "../lib/logger";

const log = logger.withContext({ phase: "11", module: "linkedin-publish" });

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const LINKEDIN_API_BASE = "https://api.linkedin.com";

/** Posts API path. NEVER replace with the legacy user-generated-content
 *  endpoint — that was deprecated 2023-06 and is now a hard 410 in 2026. */
const POSTS_ENDPOINT = `${LINKEDIN_API_BASE}/rest/posts`;

const IMAGES_INIT_ENDPOINT = `${LINKEDIN_API_BASE}/rest/images?action=initializeUpload`;
const VIDEOS_INIT_ENDPOINT = `${LINKEDIN_API_BASE}/rest/videos?action=initializeUpload`;
const VIDEOS_FINALIZE_ENDPOINT = `${LINKEDIN_API_BASE}/rest/videos?action=finalizeUpload`;

/** Image upload: JPEG + PNG only per Posts API docs. */
const IMAGE_MIME_WHITELIST = new Set(["image/jpeg", "image/png"]);

/** Video upload: MP4 only. 75KB–500MB, 3s–30min. */
const VIDEO_MIME_WHITELIST = new Set(["video/mp4"]);
const VIDEO_MIN_BYTES = 75 * 1024;
const VIDEO_MAX_BYTES = 500 * 1024 * 1024;

/** 4MB parts for the multipart video upload. */
const VIDEO_PART_SIZE = 4 * 1024 * 1024;

/** Poll budget on the AVAILABLE state. 12 × 2s = 24s worst case. */
const VIDEO_POLL_MAX_ATTEMPTS = 12;
const VIDEO_POLL_INTERVAL_MS = 2000;

/** Treat upload URL as expired if it's within 60s of the current time. */
const UPLOAD_URL_EXPIRY_GRACE_MS = 60 * 1000;

/** Retry budget for 409 Conflict on POST /rest/posts. */
const POST_CONFLICT_RETRY_DELAY_MS = 1000;

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

export class LinkedInPublishError extends Error {
  readonly httpStatus?: number;
  readonly bodyPreview?: string;
  constructor(
    message: string,
    opts?: { httpStatus?: number; bodyPreview?: string }
  ) {
    super(message);
    this.name = "LinkedInPublishError";
    this.httpStatus = opts?.httpStatus;
    this.bodyPreview = opts?.bodyPreview;
  }
}

// ---------------------------------------------------------------------------
// Fetch injection (for tests)
// ---------------------------------------------------------------------------

type FetchLike = typeof fetch;
let fetchImpl: FetchLike = fetch;

/** @internal test-only override */
export function __setFetchForTests(impl: FetchLike | null): void {
  fetchImpl = impl ?? fetch;
}

/** @internal test-only: override the sleeper so the 2s poll doesn't burn
 *  wall-clock seconds in unit tests. */
let sleepImpl: (ms: number) => Promise<void> = (ms) =>
  new Promise((resolve) => setTimeout(resolve, ms));

export function __setSleepForTests(
  impl: ((ms: number) => Promise<void>) | null
): void {
  sleepImpl = impl ?? ((ms) => new Promise((r) => setTimeout(r, ms)));
}

// ---------------------------------------------------------------------------
// Text post
// ---------------------------------------------------------------------------

/**
 * Publish a text-only post. Returns the post URN parsed from the
 * `x-restli-id` response header — LinkedIn does NOT echo it in the
 * JSON body for /rest/posts.
 */
export async function publishTextPost(
  accessToken: string,
  authorUrn: string,
  caption: string
): Promise<string> {
  const body = buildPostBody(authorUrn, caption);
  return await postWithConflictRetry(accessToken, body);
}

// ---------------------------------------------------------------------------
// Image post (3-step)
// ---------------------------------------------------------------------------

/**
 * Publish an image post in three steps:
 *   1. `POST /rest/images?action=initializeUpload` → `{uploadUrl, image}`.
 *   2. `PUT uploadUrl` with raw bytes (octet-stream, no auth header).
 *   3. `POST /rest/posts` with `content.media.id = imageUrn`.
 */
export async function publishImagePost(
  accessToken: string,
  authorUrn: string,
  caption: string,
  imageBuffer: Buffer,
  mimeType: string
): Promise<string> {
  if (!IMAGE_MIME_WHITELIST.has(mimeType)) {
    throw new LinkedInPublishError(
      `image mime ${mimeType} not supported — use image/jpeg or image/png`
    );
  }

  const imageUrn = await uploadImageWithReinitOnExpiry(
    accessToken,
    authorUrn,
    imageBuffer
  );

  const body = buildPostBody(authorUrn, caption, {
    content: { media: { id: imageUrn } },
  });

  return await postWithConflictRetry(accessToken, body);
}

async function uploadImageWithReinitOnExpiry(
  accessToken: string,
  authorUrn: string,
  imageBuffer: Buffer
): Promise<string> {
  const attempt = async (): Promise<{
    imageUrn: string;
    expired: boolean;
  }> => {
    const init = await initializeImageUpload(accessToken, authorUrn);
    if (isUploadUrlExpired(init.uploadUrlExpiresAt)) {
      return { imageUrn: init.image, expired: true };
    }
    await putPresignedUpload(init.uploadUrl, imageBuffer);
    return { imageUrn: init.image, expired: false };
  };

  const first = await attempt();
  if (!first.expired) return first.imageUrn;
  log.warn("linkedin image upload url expired; re-initializing once");
  const second = await attempt();
  if (second.expired) {
    throw new LinkedInPublishError(
      "linkedin image upload url expired twice in a row"
    );
  }
  return second.imageUrn;
}

interface ImageInitializeResult {
  uploadUrl: string;
  image: string;
  uploadUrlExpiresAt: number;
}

async function initializeImageUpload(
  accessToken: string,
  authorUrn: string
): Promise<ImageInitializeResult> {
  const response = await fetchImpl(IMAGES_INIT_ENDPOINT, {
    method: "POST",
    headers: authorizedHeaders(accessToken),
    body: JSON.stringify({
      initializeUploadRequest: { owner: authorUrn },
    }),
  });
  if (!response.ok) {
    throw await throwFromResponse(response, "initializeImageUpload");
  }
  const payload = (await response.json()) as {
    value?: {
      uploadUrl?: string;
      image?: string;
      uploadUrlExpiresAt?: number;
    };
  };
  const v = payload.value;
  if (!v?.uploadUrl || !v.image) {
    throw new LinkedInPublishError(
      "initializeImageUpload response missing uploadUrl or image"
    );
  }
  return {
    uploadUrl: v.uploadUrl,
    image: v.image,
    uploadUrlExpiresAt: v.uploadUrlExpiresAt ?? 0,
  };
}

// ---------------------------------------------------------------------------
// Video post (4-step + poll)
// ---------------------------------------------------------------------------

/**
 * Publish a video post in four + one steps:
 *   1. `POST /rest/videos?action=initializeUpload` → `{video, uploadInstructions[], uploadToken}`.
 *   2. `PUT` each 4MB part to its pre-signed URL; collect ETags.
 *   3. `POST /rest/videos?action=finalizeUpload` with ordered ETag list.
 *   4. Poll `GET /rest/videos/{encodedUrn}` until `status: AVAILABLE`.
 *   5. `POST /rest/posts` with `content.media.id = videoUrn`.
 */
export async function publishVideoPost(
  accessToken: string,
  authorUrn: string,
  caption: string,
  videoBuffer: Buffer,
  mimeType: string
): Promise<string> {
  if (!VIDEO_MIME_WHITELIST.has(mimeType)) {
    throw new LinkedInPublishError(
      `video mime ${mimeType} not supported — use video/mp4`
    );
  }
  if (videoBuffer.length < VIDEO_MIN_BYTES) {
    throw new LinkedInPublishError(
      `video file ${videoBuffer.length}B below LinkedIn minimum (75KB)`
    );
  }
  if (videoBuffer.length > VIDEO_MAX_BYTES) {
    throw new LinkedInPublishError(
      `video file ${videoBuffer.length}B exceeds LinkedIn maximum (500MB)`
    );
  }

  const videoUrn = await uploadVideoWithReinitOnExpiry(
    accessToken,
    authorUrn,
    videoBuffer
  );
  await pollVideoStatus(accessToken, videoUrn);

  const body = buildPostBody(authorUrn, caption, {
    content: { media: { id: videoUrn } },
  });
  return await postWithConflictRetry(accessToken, body);
}

async function uploadVideoWithReinitOnExpiry(
  accessToken: string,
  authorUrn: string,
  videoBuffer: Buffer
): Promise<string> {
  const attempt = async (): Promise<{ videoUrn: string; expired: boolean }> => {
    const init = await initializeVideoUpload(
      accessToken,
      authorUrn,
      videoBuffer.length
    );
    if (isUploadUrlExpired(init.uploadUrlsExpireAt)) {
      return { videoUrn: init.video, expired: true };
    }
    const etags = await uploadVideoParts(init.uploadInstructions, videoBuffer);
    await finalizeVideoUpload(
      accessToken,
      init.video,
      init.uploadToken,
      etags
    );
    return { videoUrn: init.video, expired: false };
  };

  const first = await attempt();
  if (!first.expired) return first.videoUrn;
  log.warn("linkedin video upload url expired; re-initializing once");
  const second = await attempt();
  if (second.expired) {
    throw new LinkedInPublishError(
      "linkedin video upload url expired twice in a row"
    );
  }
  return second.videoUrn;
}

interface VideoInitializeResult {
  video: string;
  uploadInstructions: Array<{
    uploadUrl: string;
    firstByte: number;
    lastByte: number;
  }>;
  uploadToken: string;
  uploadUrlsExpireAt: number;
}

async function initializeVideoUpload(
  accessToken: string,
  authorUrn: string,
  fileSizeBytes: number
): Promise<VideoInitializeResult> {
  const response = await fetchImpl(VIDEOS_INIT_ENDPOINT, {
    method: "POST",
    headers: authorizedHeaders(accessToken),
    body: JSON.stringify({
      initializeUploadRequest: {
        owner: authorUrn,
        fileSizeBytes,
        uploadCaptions: false,
        uploadThumbnail: false,
      },
    }),
  });
  if (!response.ok) {
    throw await throwFromResponse(response, "initializeVideoUpload");
  }
  const payload = (await response.json()) as {
    value?: {
      video?: string;
      uploadInstructions?: Array<{
        uploadUrl?: string;
        firstByte?: number;
        lastByte?: number;
      }>;
      uploadToken?: string;
      uploadUrlsExpireAt?: number;
    };
  };
  const v = payload.value;
  if (!v?.video || !v.uploadInstructions || v.uploadInstructions.length === 0) {
    throw new LinkedInPublishError(
      "initializeVideoUpload response missing video or uploadInstructions"
    );
  }
  return {
    video: v.video,
    uploadInstructions: v.uploadInstructions.map((u) => ({
      uploadUrl: u.uploadUrl ?? "",
      firstByte: u.firstByte ?? 0,
      lastByte: u.lastByte ?? 0,
    })),
    uploadToken: v.uploadToken ?? "",
    uploadUrlsExpireAt: v.uploadUrlsExpireAt ?? 0,
  };
}

async function uploadVideoParts(
  instructions: Array<{ uploadUrl: string; firstByte: number; lastByte: number }>,
  videoBuffer: Buffer
): Promise<string[]> {
  const etags: string[] = [];
  for (const part of instructions) {
    // `lastByte` from LinkedIn is inclusive; Buffer.subarray is exclusive.
    const slice = videoBuffer.subarray(part.firstByte, part.lastByte + 1);
    const etag = await putPresignedUpload(part.uploadUrl, slice);
    if (!etag) {
      throw new LinkedInPublishError(
        `linkedin upload PUT succeeded but returned no ETag for bytes ${part.firstByte}-${part.lastByte}`
      );
    }
    etags.push(etag);
  }
  // LinkedIn quirks: each part is assumed to be <= 4MB but we don't
  // enforce that size here — the server already chose the slice bounds
  // via uploadInstructions, so honoring them byte-for-byte is safer
  // than imposing a second boundary.
  void VIDEO_PART_SIZE;
  return etags;
}

async function finalizeVideoUpload(
  accessToken: string,
  videoUrn: string,
  uploadToken: string,
  uploadedPartIds: string[]
): Promise<void> {
  const response = await fetchImpl(VIDEOS_FINALIZE_ENDPOINT, {
    method: "POST",
    headers: authorizedHeaders(accessToken),
    body: JSON.stringify({
      finalizeUploadRequest: {
        video: videoUrn,
        uploadToken,
        uploadedPartIds,
      },
    }),
  });
  if (!response.ok) {
    throw await throwFromResponse(response, "finalizeVideoUpload");
  }
}

async function pollVideoStatus(
  accessToken: string,
  videoUrn: string
): Promise<void> {
  const encoded = encodeURIComponent(videoUrn);
  for (let attempt = 0; attempt < VIDEO_POLL_MAX_ATTEMPTS; attempt++) {
    const response = await fetchImpl(
      `${LINKEDIN_API_BASE}/rest/videos/${encoded}`,
      {
        method: "GET",
        headers: authorizedHeaders(accessToken),
      }
    );
    if (!response.ok) {
      throw await throwFromResponse(response, "pollVideoStatus");
    }
    const payload = (await response.json()) as {
      status?: string;
    };
    const status = payload.status ?? "UNKNOWN";
    if (status === "AVAILABLE") return;
    if (status === "PROCESSING_FAILED") {
      throw new LinkedInPublishError(
        "linkedin video processing failed",
        { bodyPreview: JSON.stringify(payload).slice(0, 200) }
      );
    }
    await sleepImpl(VIDEO_POLL_INTERVAL_MS);
  }
  throw new LinkedInPublishError(
    `linkedin video did not reach AVAILABLE after ${VIDEO_POLL_MAX_ATTEMPTS} attempts`
  );
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/** POST /rest/posts with one retry on 409 Conflict. */
async function postWithConflictRetry(
  accessToken: string,
  body: Record<string, unknown>
): Promise<string> {
  const first = await doPostPost(accessToken, body);
  if (first.status !== 409) {
    return extractPostUrn(first);
  }
  log.warn("linkedin POST /rest/posts 409 — retrying once after 1s");
  await sleepImpl(POST_CONFLICT_RETRY_DELAY_MS);
  const second = await doPostPost(accessToken, body);
  return extractPostUrn(second);
}

async function doPostPost(
  accessToken: string,
  body: Record<string, unknown>
): Promise<Response> {
  return fetchImpl(POSTS_ENDPOINT, {
    method: "POST",
    headers: authorizedHeaders(accessToken),
    body: JSON.stringify(body),
  });
}

function extractPostUrn(response: Response): string {
  if (!response.ok) {
    throw new LinkedInPublishError(
      `linkedin POST /rest/posts returned ${response.status}`,
      { httpStatus: response.status }
    );
  }
  const urn = response.headers.get("x-restli-id");
  if (!urn) {
    throw new LinkedInPublishError(
      "linkedin POST /rest/posts succeeded but omitted x-restli-id"
    );
  }
  return urn;
}

function buildPostBody(
  authorUrn: string,
  caption: string,
  extras: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    author: authorUrn,
    commentary: caption,
    visibility: "PUBLIC",
    distribution: {
      feedDistribution: "MAIN_FEED",
      targetEntities: [],
      thirdPartyDistributionChannels: [],
    },
    lifecycleState: "PUBLISHED",
    isReshareDisabledByAuthor: false,
    ...extras,
  };
}

function authorizedHeaders(accessToken: string): Record<string, string> {
  return {
    Authorization: `Bearer ${accessToken}`,
    "Linkedin-Version": LINKEDIN_API_HEADERS["Linkedin-Version"],
    "X-Restli-Protocol-Version":
      LINKEDIN_API_HEADERS["X-Restli-Protocol-Version"],
    "Content-Type": LINKEDIN_API_HEADERS["Content-Type"],
  };
}

function isUploadUrlExpired(expiresAtMs: number): boolean {
  if (!expiresAtMs) return false;
  return expiresAtMs < Date.now() + UPLOAD_URL_EXPIRY_GRACE_MS;
}

/**
 * PUT a Buffer to a pre-signed URL. Per the LinkedIn docs these URLs
 * carry their own signature in the query string and MUST NOT receive an
 * `Authorization: Bearer` header — including one causes a 400.
 */
async function putPresignedUpload(
  uploadUrl: string,
  payload: Buffer
): Promise<string | null> {
  const response = await fetchImpl(uploadUrl, {
    method: "PUT",
    headers: { "Content-Type": "application/octet-stream" },
    body: payload,
  });
  if (!response.ok) {
    throw await throwFromResponse(response, "putPresignedUpload");
  }
  // LinkedIn returns etag unquoted (contrast S3, which wraps in quotes).
  // Strip any stray quotes defensively.
  const raw = response.headers.get("etag");
  if (!raw) return null;
  return raw.replace(/"/g, "");
}

async function throwFromResponse(
  response: Response,
  op: string
): Promise<LinkedInPublishError> {
  let preview = "";
  try {
    preview = (await response.text()).slice(0, 200);
  } catch {
    // ignore
  }
  return new LinkedInPublishError(
    `linkedin ${op} returned ${response.status}`,
    { httpStatus: response.status, bodyPreview: preview }
  );
}

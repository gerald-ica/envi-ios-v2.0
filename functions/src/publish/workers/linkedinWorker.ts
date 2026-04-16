/**
 * linkedinWorker.ts — Phase 12 Pub/Sub worker for LinkedIn publishes.
 *
 * Delegates to `dispatchLinkedInPost` (Phase 11). That helper owns author-URN
 * resolution, scope validation, media download, and the publishText/Image/Video
 * branches. The worker only translates its `ConnectorDispatchError` codes to
 * the Phase 12 sanitized-error vocabulary.
 */
import { createProviderWorker, PublishProviderError } from "../providerWorker";
import {
  dispatchLinkedInPost,
  ConnectorDispatchError,
  type LinkedInDispatchPayload,
} from "../linkedin-dispatch";
import { logger } from "../../lib/logger";

const log = logger.withContext({ phase: "12-03", worker: "linkedin" });

export const publishWorkerLinkedIn = createProviderWorker(
  "linkedin",
  async (msg, _ctx) => {
    // Phase 12 doesn't yet round-trip authorType from iOS; member posts are
    // the default, matching the existing ExportSheet contract. A follow-up
    // will pipe organization posts through `msg.mediaRefs` metadata.
    const payload: LinkedInDispatchPayload = {
      caption: msg.caption,
      mediaType: msg.mediaRefs.length > 0 ? inferMediaType(msg.mediaRefs[0]) : "none",
      mediaStoragePath: msg.mediaRefs[0],
      authorType: "member",
    };

    try {
      const result = await dispatchLinkedInPost(msg.uid, payload);
      log.info("linkedin publish succeeded", {
        jobId: msg.jobId, postUrn: result.postUrn,
      });
      return { providerPostId: result.postUrn };
    } catch (err) {
      if (err instanceof ConnectorDispatchError) {
        throw new PublishProviderError(mapLinkedInError(err.code), {
          retryable: isRetryable(err.code),
          message: err.message,
        });
      }
      throw err;
    }
  }
);

function inferMediaType(path: string): "image" | "video" {
  const ext = path.toLowerCase().split(".").pop() ?? "";
  return ext === "mp4" || ext === "mov" ? "video" : "image";
}

function mapLinkedInError(
  code: ConnectorDispatchError["code"]
): "rate_limited" | "media_rejected" | "auth_expired" | "unknown" {
  switch (code) {
    case "not_connected":
    case "token_expired":
    case "insufficient_scopes":
      return "auth_expired";
    case "not_organization_admin":
      return "auth_expired";
    case "media_missing":
    case "media_mime_unsupported":
      return "media_rejected";
    case "publish_failed":
    default:
      return "unknown";
  }
}

function isRetryable(code: ConnectorDispatchError["code"]): boolean {
  // Anything auth-related is terminal — the refresh cron (12-04) owns
  // recovery. Media mime mismatches aren't going to resolve on retry either.
  return code === "publish_failed";
}

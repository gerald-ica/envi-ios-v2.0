/**
 * firestore.rules.test.ts — exercises firestore.rules against the emulator.
 *
 * Four cases (per Phase 06-03 spec):
 *   1. Owner reads own connection doc → ALLOWED
 *   2. Another user reads someone else's connection doc → DENIED
 *   3. Authenticated client writes a connection doc → DENIED
 *   4. Unauthenticated request → DENIED
 *
 * Prerequisite: `firebase emulators:exec --only firestore "npm test"` or a
 * running emulator on :8080. We auto-skip when the emulator isn't reachable
 * so the suite stays runnable on CI without the emulator.
 */
import * as fs from "node:fs";
import * as path from "node:path";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080";
const PROJECT_ID = "envi-rules-test";

async function isEmulatorReachable(): Promise<boolean> {
  const [host, port] = EMULATOR_HOST.split(":");
  try {
    const response = await fetch(`http://${host}:${port}/`, {
      method: "GET",
    });
    return response.status < 500;
  } catch {
    return false;
  }
}

describe("firestore.rules — users/{uid}/connections/{provider}", () => {
  let testEnv: RulesTestEnvironment | null = null;
  let emulatorOnline = false;

  beforeAll(async () => {
    emulatorOnline = await isEmulatorReachable();
    if (!emulatorOnline) {
      // eslint-disable-next-line no-console
      console.warn(
        `[firestore.rules.test] Firestore emulator not reachable at ${EMULATOR_HOST}; skipping rules tests.`
      );
      return;
    }
    const [host, portRaw] = EMULATOR_HOST.split(":");
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: fs.readFileSync(RULES_PATH, "utf8"),
        host,
        port: Number(portRaw),
      },
    });
  });

  afterAll(async () => {
    await testEnv?.cleanup();
  });

  beforeEach(async () => {
    if (!testEnv) return;
    await testEnv.clearFirestore();
    // Seed docs through the bypass-rules admin context.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc("users/alice/connections/tiktok").set({
        provider: "tiktok",
        providerUserId: "alice-tt",
        handle: "alice",
        scopes: ["user.info.basic"],
      });
      await db.doc("users/bob/connections/tiktok").set({
        provider: "tiktok",
        providerUserId: "bob-tt",
        handle: "bob",
        scopes: ["user.info.basic"],
      });
    });
  });

  it("allows the owning user to read their own connection doc", async () => {
    if (!testEnv) return;
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(alice.doc("users/alice/connections/tiktok").get());
  });

  it("denies cross-user reads", async () => {
    if (!testEnv) return;
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(alice.doc("users/bob/connections/tiktok").get());
  });

  it("denies all client writes", async () => {
    if (!testEnv) return;
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      alice.doc("users/alice/connections/tiktok").set({
        provider: "tiktok",
        providerUserId: "alice-tt",
        handle: "alice-spoofed",
        scopes: [],
      })
    );
  });

  it("denies unauthenticated reads", async () => {
    if (!testEnv) return;
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(anon.doc("users/alice/connections/tiktok").get());
  });
});

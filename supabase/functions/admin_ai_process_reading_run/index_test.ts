import {
  assertEquals,
  assertObjectMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { handleRequest } from "./index.ts";

function requestWithBody(body: Record<string, unknown>): Request {
  return new Request("http://localhost/admin_ai_process_reading_run", {
    method: "POST",
    headers: {
      Authorization: "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

function createRunSummary(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    id: "run-1",
    job_type: "cover_backfill",
    status: "running",
    provider: "gemini_image",
    model: "gemini-2.5-flash-image",
    question_count: 3,
    total_count: 2,
    processed_count: 0,
    succeeded_count: 0,
    failed_count: 0,
    skipped_count: 0,
    failure_samples: [],
    ...overrides,
  };
}

Deno.test("paused run returns immediately without claiming items", async () => {
  let claimed = false;

  const response = await handleRequest(
    requestWithBody({ run_id: "run-1", batch_size: 3 }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      createClient: () => ({}) as never,
      fetchRunSummary: async () =>
        createRunSummary({
          status: "paused",
          pause_reason: "user_paused",
        }) as never,
      claimRunItems: async () => {
        claimed = true;
        return [];
      },
    },
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.status, "paused");
  assertEquals(claimed, false);
});

Deno.test("cover backfill forwards selected provider and model", async () => {
  const calledBodies: Array<Record<string, unknown>> = [];
  const marked: Array<{ itemId: string; status: string }> = [];
  let fetchRunSummaryCount = 0;

  const response = await handleRequest(
    requestWithBody({ run_id: "run-1", batch_size: 3 }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      createClient: () => ({}) as never,
      fetchRunSummary: async () => {
        fetchRunSummaryCount += 1;
        if (fetchRunSummaryCount >= 3) {
          return createRunSummary({
            status: "completed",
            processed_count: 1,
            succeeded_count: 1,
          }) as never;
        }
        return createRunSummary({
          provider: "openai_images",
          model: "gpt-image-1.5",
        }) as never;
      },
      claimRunItems: async () => [
        {
          item_id: "item-1",
          passage_id: "reading-1",
          passage_title: "Ocean Science",
        },
      ],
      fetchReadingDetail: async () => ({
        id: "reading-1",
        title: "Ocean Science",
        sentences: [{ idx: 1, sentence_en: "Waves carry energy." }],
      }),
      callFunction: async (functionName, body) => {
        assertEquals(functionName, "admin_ai_generate_reading_cover");
        calledBodies.push(body);
        return { status: 200, payload: { ok: true } };
      },
      markItem: async (_client, itemId, status) => {
        marked.push({ itemId, status });
      },
    },
  );

  assertEquals(response.status, 200);
  assertEquals(calledBodies.length, 1);
  assertObjectMatch(calledBodies[0], {
    reading_id: "reading-1",
    provider: "openai_images",
    model: "gpt-image-1.5",
  });
  assertEquals(marked, [{ itemId: "item-1", status: "succeeded" }]);
});

Deno.test("processor stops after run auto-pauses on repeated failures", async () => {
  const functionCalls: string[] = [];
  const marked: Array<{ itemId: string; status: string; error?: string }> = [];
  let fetchRunSummaryCount = 0;

  const response = await handleRequest(
    requestWithBody({ run_id: "run-1", batch_size: 3 }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      createClient: () => ({}) as never,
      fetchRunSummary: async () => {
        fetchRunSummaryCount += 1;
        if (fetchRunSummaryCount >= 3) {
          return createRunSummary({
            status: "paused",
            processed_count: 1,
            failed_count: 1,
            consecutive_failure_count: 5,
            pause_reason: "auto_failure_threshold",
          }) as never;
        }
        return createRunSummary() as never;
      },
      claimRunItems: async () => [
        {
          item_id: "item-1",
          passage_id: "reading-1",
          passage_title: "Ocean Science",
        },
        {
          item_id: "item-2",
          passage_id: "reading-2",
          passage_title: "Forest Life",
        },
      ],
      fetchReadingDetail: async (client, readingId) => ({
        id: readingId,
        title: readingId,
        sentences: [{ idx: 1, sentence_en: "Sentence" }],
      }),
      callFunction: async (functionName) => {
        functionCalls.push(functionName);
        return {
          status: 422,
          payload: { message: "provider rejected request" },
        };
      },
      markItem: async (_client, itemId, status, errorMessage) => {
        marked.push({ itemId, status, error: errorMessage });
      },
    },
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.status, "paused");
  assertEquals(functionCalls.length, 1);
  assertEquals(marked.length, 1);
  assertEquals(marked[0].itemId, "item-1");
  assertEquals(marked[0].status, "failed");
});

Deno.test("cancelled run does not process newly claimed items", async () => {
  let functionCalled = false;
  let fetchRunSummaryCount = 0;

  const response = await handleRequest(
    requestWithBody({ run_id: "run-1", batch_size: 3 }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      createClient: () => ({}) as never,
      fetchRunSummary: async () => {
        fetchRunSummaryCount += 1;
        if (fetchRunSummaryCount >= 2) {
          return createRunSummary({ status: "cancelled" }) as never;
        }
        return createRunSummary() as never;
      },
      claimRunItems: async () => [
        {
          item_id: "item-1",
          passage_id: "reading-1",
          passage_title: "Ocean Science",
        },
      ],
      fetchReadingDetail: async () => ({
        id: "reading-1",
        title: "Ocean Science",
        sentences: [{ idx: 1, sentence_en: "Sentence" }],
      }),
      callFunction: async () => {
        functionCalled = true;
        return { status: 200, payload: { ok: true } };
      },
      markItem: async () => undefined,
    },
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.status, "cancelled");
  assertEquals(functionCalled, false);
});

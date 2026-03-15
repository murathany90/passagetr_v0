import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import {
  corsHeaders,
  createCallerClient,
  json,
  resolveAdminCaller,
  shortErrorText,
  type AdminCaller,
  type EnvGetter,
} from "../_shared/admin_runtime.ts";

interface ReadingRunSummary {
  id: string;
  job_type: string;
  status: string;
  provider: string;
  model: string;
  question_count: number;
  filter_snapshot?: Record<string, unknown>;
  total_count: number;
  processed_count: number;
  succeeded_count: number;
  failed_count: number;
  skipped_count: number;
  failure_samples?: string[];
  pause_reason?: string | null;
  last_error_message?: string | null;
  consecutive_failure_count?: number;
}

interface RunItem {
  item_id: string;
  passage_id: string;
  passage_title: string;
}

function unwrapRpcResult(payload: unknown): unknown {
  if (!payload || typeof payload !== "object" || !("data" in payload)) {
    return payload;
  }

  const result = payload as {
    data?: unknown;
    error?: { message?: string } | null;
  };
  if (result.error != null) {
    throw new Error(String(result.error.message ?? result.error));
  }
  return result.data;
}

function rpcInvoker(
  callerClient: Exclude<ReturnType<typeof createCallerClient>, Response>,
): (
  fn: string,
  args?: Record<string, unknown>,
) => Promise<unknown> {
  return callerClient.rpc.bind(callerClient) as unknown as (
    fn: string,
    args?: Record<string, unknown>,
  ) => Promise<unknown>;
}

export interface HandlerDeps {
  env: EnvGetter;
  fetchFn: typeof fetch;
  resolveCaller: (
    req: Request,
    authHeader: string,
    env: EnvGetter,
  ) => Promise<AdminCaller | Response>;
  fetchRunSummary: (
    callerClient: Exclude<ReturnType<typeof createCallerClient>, Response>,
    runId: string,
  ) => Promise<ReadingRunSummary>;
  claimRunItems: (
    callerClient: Exclude<ReturnType<typeof createCallerClient>, Response>,
    runId: string,
    batchSize: number,
  ) => Promise<RunItem[]>;
  markItem: (
    callerClient: Exclude<ReturnType<typeof createCallerClient>, Response>,
    itemId: string,
    status: "succeeded" | "failed" | "skipped",
    errorMessage?: string,
  ) => Promise<void>;
  fetchReadingDetail: (
    callerClient: Exclude<ReturnType<typeof createCallerClient>, Response>,
    readingId: string,
  ) => Promise<Record<string, unknown>>;
  callFunction: (
    functionName: string,
    body: Record<string, unknown>,
    authHeader: string,
    env: EnvGetter,
    fetchFn: typeof fetch,
  ) => Promise<{ status: number; payload: Record<string, unknown> }>;
  createClient: (
    authHeader: string,
    env: EnvGetter,
  ) => Exclude<ReturnType<typeof createCallerClient>, Response> | Response;
}

function normalizeNullableText(value: unknown): string | null {
  const text = String(value ?? "").trim();
  return text.length > 0 ? text : null;
}

function validateRequest(
  body: unknown,
): { ok: true; runId: string; batchSize: number } | {
  ok: false;
  response: Response;
} {
  if (!body || typeof body !== "object") {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Request body must be a JSON object.",
      }),
    };
  }

  const record = body as Record<string, unknown>;
  const runId = String(record.run_id ?? "").trim();
  const batchSize = Math.max(
    1,
    Math.min(10, Number(record.batch_size ?? 3) || 3),
  );
  if (!runId) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Run ID is required.",
      }),
    };
  }
  return { ok: true, runId, batchSize };
}

async function fetchRunSummary(
  callerClient: Exclude<ReturnType<typeof createCallerClient>, Response>,
  runId: string,
): Promise<ReadingRunSummary> {
  const rpc = rpcInvoker(callerClient);
  const payload = unwrapRpcResult(await rpc("admin_get_reading_ai_run", {
    p_run_id: runId,
  }));
  return payload as ReadingRunSummary;
}

async function claimRunItems(
  callerClient: Exclude<ReturnType<typeof createCallerClient>, Response>,
  runId: string,
  batchSize: number,
): Promise<RunItem[]> {
  const rpc = rpcInvoker(callerClient);
  const payload = unwrapRpcResult(await rpc("admin_claim_reading_ai_run_items", {
    p_run_id: runId,
    p_limit: batchSize,
  }));
  const rows = Array.isArray(payload) ? payload : [];
  return rows
    .filter((item) => item && typeof item === "object")
    .map((item) => {
      const row = item as Record<string, unknown>;
      return {
        item_id: String(row.item_id ?? ""),
        passage_id: String(row.passage_id ?? ""),
        passage_title: String(row.passage_title ?? ""),
      };
    })
    .filter((item) => item.item_id && item.passage_id);
}

async function markItem(
  callerClient: Exclude<ReturnType<typeof createCallerClient>, Response>,
  itemId: string,
  status: "succeeded" | "failed" | "skipped",
  errorMessage?: string,
): Promise<void> {
  const rpc = rpcInvoker(callerClient);
  await unwrapRpcResult(await rpc("admin_mark_reading_ai_run_item", {
    p_payload: {
      item_id: itemId,
      status,
      error_message: normalizeNullableText(errorMessage),
    },
  }));
}

async function fetchReadingDetail(
  callerClient: Exclude<ReturnType<typeof createCallerClient>, Response>,
  readingId: string,
): Promise<Record<string, unknown>> {
  const rpc = rpcInvoker(callerClient);
  const payload = unwrapRpcResult(await rpc("admin_get_reading_detail", {
    p_passage_id: readingId,
  }));
  return payload as Record<string, unknown>;
}

async function callFunction(
  functionName: string,
  body: Record<string, unknown>,
  authHeader: string,
  env: EnvGetter,
  fetchFn: typeof fetch,
): Promise<{ status: number; payload: Record<string, unknown> }> {
  const supabaseUrl = env("SUPABASE_URL")?.trim() ?? "";
  if (!supabaseUrl) {
    throw new Error("SUPABASE_URL is required.");
  }

  const response = await fetchFn(
    `${supabaseUrl}/functions/v1/${functionName}`,
    {
      method: "POST",
      headers: {
        Authorization: authHeader,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );
  const payload = await response.json() as Record<string, unknown>;
  return { status: response.status, payload };
}

function extractErrorMessage(payload: Record<string, unknown>): string {
  return shortErrorText(
    String(payload.message ?? payload.error ?? "Bilinmeyen AI hata cevabi."),
  );
}

export async function handleRequest(
  req: Request,
  deps: Partial<HandlerDeps> = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const authHeader = req.headers.get("Authorization")?.trim() ?? "";
  if (!authHeader) {
    return json(401, {
      error: "missing_authorization",
      message: "Authorization header is required.",
    });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch (_error) {
    return json(400, {
      error: "invalid_request",
      message: "Request body must be valid JSON.",
    });
  }

  const validated = validateRequest(body);
  if (!validated.ok) {
    return validated.response;
  }

  const env = deps.env ?? Deno.env.get.bind(Deno.env);
  const caller = await (deps.resolveCaller ?? resolveAdminCaller)(
    req,
    authHeader,
    env,
  );
  if (caller instanceof Response) {
    return caller;
  }

  const callerClient = (deps.createClient ?? createCallerClient)(authHeader, env);
  if (callerClient instanceof Response) {
    return callerClient;
  }

  try {
    let run = await (deps.fetchRunSummary ?? fetchRunSummary)(
      callerClient,
      validated.runId,
    );
    if (
      run.status === "paused" ||
      run.status === "completed" ||
      run.status === "failed" ||
      run.status === "cancelled"
    ) {
      return json(200, run);
    }

    const items = await (deps.claimRunItems ?? claimRunItems)(
      callerClient,
      validated.runId,
      validated.batchSize,
    );

    for (const item of items) {
      run = await (deps.fetchRunSummary ?? fetchRunSummary)(
        callerClient,
        validated.runId,
      );
      if (run.status === "paused" || run.status === "cancelled") {
        break;
      }

      try {
        const detail = await (deps.fetchReadingDetail ?? fetchReadingDetail)(
          callerClient,
          item.passage_id,
        );
        if (run.job_type === "question_backfill") {
          const existingQuestions = Array.isArray(detail.questions)
            ? detail.questions
            : [];
          if (existingQuestions.length > 0) {
            await (deps.markItem ?? markItem)(
              callerClient,
              item.item_id,
              "skipped",
            );
            continue;
          }

          const generated = await (deps.callFunction ?? callFunction)(
            "admin_ai_generate_reading_questions",
            {
              reading_id: item.passage_id,
              provider: run.provider,
              model: run.model,
              question_count: run.question_count,
            },
            authHeader,
            env,
            deps.fetchFn ?? fetch,
          );

          if (generated.status >= 400) {
            await (deps.markItem ?? markItem)(
              callerClient,
              item.item_id,
              "failed",
              extractErrorMessage(generated.payload),
            );
            continue;
          }

          detail.questions = generated.payload.questions;
          const rpc = rpcInvoker(callerClient);
          await unwrapRpcResult(await rpc("admin_upsert_reading_detail", {
            p_payload: detail,
          }));
          await (deps.markItem ?? markItem)(
            callerClient,
            item.item_id,
            "succeeded",
          );
          continue;
        }

        const hasCover =
          normalizeNullableText(detail.cover_bucket_name) != null &&
          normalizeNullableText(detail.cover_storage_path) != null;
        if (hasCover) {
          await (deps.markItem ?? markItem)(
            callerClient,
            item.item_id,
            "skipped",
          );
          continue;
        }

        const generated = await (deps.callFunction ?? callFunction)(
          "admin_ai_generate_reading_cover",
          {
            reading_id: item.passage_id,
            provider: run.provider,
            model: run.model,
          },
          authHeader,
          env,
          deps.fetchFn ?? fetch,
        );

        if (generated.status >= 400) {
          await (deps.markItem ?? markItem)(
            callerClient,
            item.item_id,
            "failed",
            extractErrorMessage(generated.payload),
          );
          continue;
        }

        await (deps.markItem ?? markItem)(
          callerClient,
          item.item_id,
          "succeeded",
        );
      } catch (error) {
        await (deps.markItem ?? markItem)(
          callerClient,
          item.item_id,
          "failed",
          shortErrorText(String(error)),
        );
      }

      run = await (deps.fetchRunSummary ?? fetchRunSummary)(
        callerClient,
        validated.runId,
      );
      if (run.status === "paused" || run.status === "cancelled") {
        break;
      }
    }

    return json(
      200,
      await (deps.fetchRunSummary ?? fetchRunSummary)(
        callerClient,
        validated.runId,
      ),
    );
  } catch (error) {
    return json(500, {
      error: "internal_error",
      message: shortErrorText(String(error)),
    });
  }
}

if (import.meta.main) {
  serve((req: Request) => handleRequest(req));
}

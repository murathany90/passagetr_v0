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

interface ReadingSentencePayload {
  idx: number;
  sentence_en: string;
}

interface ReadingDetailPayload {
  id: string;
  title: string;
  level?: string | null;
  category?: string | null;
  tags_raw?: string | null;
  cover_bucket_name?: string | null;
  cover_storage_path?: string | null;
  sentences: ReadingSentencePayload[];
}

interface GeneratedCoverAsset {
  bytes: Uint8Array;
  mimeType: string;
  provider: string;
  model: string;
  style: string;
  prompt: string;
}

interface GenerateCoverRequest {
  reading_id: string;
  provider: string;
  model: string;
}

interface CoverModelStatusPayload {
  provider: string;
  model: string;
  enabled?: boolean;
  priority?: number;
  daily_cap?: number;
  lifetime_cap?: number | null;
}

interface CoverPoolStatusPayload {
  usage_date_utc?: string;
  local_caps_enabled?: boolean;
  models: CoverModelStatusPayload[];
}

interface ReserveCoverAttemptResult {
  allowed: boolean;
  reason?: string | null;
  daily_cap?: number | null;
  lifetime_cap?: number | null;
  attempt_count?: number | null;
}

interface CoverAttemptCandidate {
  provider: string;
  model: string;
  priority: number;
}

const providerCoverAuto = "cover_auto";
const providerImageRouter = "imagerouter";
const providerHuggingFace = "huggingface";
const modelAuto = "auto";
const coverStyle = "editorial illustration";

const imageRouterModels = [
  "google/nano-banana-2:free",
  "openai/gpt-image-1.5:free",
  "black-forest-labs/FLUX-2-klein-4b:free",
  "z-image/turbo:free",
  "qwen/qwen-image:free",
  "google/gemini-2.5-flash:free",
];

const huggingFaceModels = [
  "stabilityai/stable-diffusion-xl-base-1.0",
  "black-forest-labs/FLUX.1-dev",
  "stabilityai/stable-diffusion-3.5-large",
  "playgroundai/playground-v2.5-1024px-aesthetic",
];

type MarkAttemptResult = "success" | "failed" | "rate_limited";

export interface HandlerDeps {
  env: EnvGetter;
  fetchFn: typeof fetch;
  now: () => Date;
  sleep: (ms: number) => Promise<void>;
  resolveCaller: (
    req: Request,
    authHeader: string,
    env: EnvGetter,
  ) => Promise<AdminCaller | Response>;
  fetchReadingDetail: (
    readingId: string,
    authHeader: string,
    env: EnvGetter,
  ) => Promise<ReadingDetailPayload>;
  fetchCoverPoolStatus: (
    authHeader: string,
    env: EnvGetter,
  ) => Promise<CoverPoolStatusPayload>;
  reserveAttempt: (
    provider: string,
    model: string,
    authHeader: string,
    env: EnvGetter,
  ) => Promise<ReserveCoverAttemptResult>;
  markAttemptResult: (
    provider: string,
    model: string,
    result: MarkAttemptResult,
    authHeader: string,
    env: EnvGetter,
  ) => Promise<void>;
  generateImageRouter: (
    model: string,
    prompt: string,
    env: EnvGetter,
    fetchFn: typeof fetch,
  ) => Promise<GeneratedCoverAsset>;
  generateHuggingFace: (
    model: string,
    prompt: string,
    env: EnvGetter,
    fetchFn: typeof fetch,
  ) => Promise<GeneratedCoverAsset>;
  persistCover: (
    detail: ReadingDetailPayload,
    cover: GeneratedCoverAsset,
    authHeader: string,
    env: EnvGetter,
    now: () => Date,
  ) => Promise<Record<string, unknown>>;
}

class CoverGenerationError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly result: MarkAttemptResult,
    readonly retryable: boolean,
  ) {
    super(message);
    this.name = "CoverGenerationError";
  }
}

function normalizeNullableText(value: unknown): string | null {
  const text = String(value ?? "").trim();
  return text.length > 0 ? text : null;
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

function buildCoverPrompt(detail: ReadingDetailPayload): string {
  const excerpt = detail.sentences
    .slice(0, 3)
    .map((sentence) => sentence.sentence_en)
    .join(" ");
  return [
    "Create a clean editorial illustration style reading cover.",
    "Landscape composition, visually strong, no text, no letters, no watermark, no logo.",
    "The image should feel suitable for an English learning reading passage cover.",
    `Title theme: ${detail.title}`,
    `Category: ${detail.category ?? "general"}`,
    `Tags: ${detail.tags_raw ?? "general education"}`,
    `Level: ${detail.level ?? "B1"}`,
    excerpt ? `Story context: ${excerpt}` : "",
    "Preferred style: editorial illustration, modern, polished, readable at small sizes.",
  ].filter((line) => line.trim().length > 0).join("\n");
}

function isImageRouterModel(model: string): boolean {
  return imageRouterModels.includes(model);
}

function isHuggingFaceModel(model: string): boolean {
  return huggingFaceModels.includes(model);
}

function normalizeProvider(provider: string | null | undefined): string {
  const normalized = String(provider ?? "").trim().toLowerCase();
  return normalized || providerCoverAuto;
}

function normalizeModel(model: string | null | undefined): string {
  const normalized = String(model ?? "").trim();
  return normalized || modelAuto;
}

async function parseResponsePayload(response: Response): Promise<unknown> {
  const raw = await response.text();
  if (!raw.trim()) {
    return null;
  }
  try {
    return JSON.parse(raw);
  } catch (_error) {
    return raw;
  }
}

function payloadMessage(payload: unknown, fallback: string): string {
  if (payload == null) {
    return fallback;
  }
  if (typeof payload === "string" && payload.trim().length > 0) {
    return payload.trim();
  }
  if (typeof payload === "object") {
    const record = payload as Record<string, unknown>;
    const candidate = record.error;
    if (candidate && typeof candidate === "object") {
      const nested = candidate as Record<string, unknown>;
      const nestedMessage = normalizeNullableText(nested.message);
      if (nestedMessage != null) {
        return nestedMessage;
      }
    }
    const direct = normalizeNullableText(record.message) ??
      normalizeNullableText(record.error);
    if (direct != null) {
      return direct;
    }
  }
  return fallback;
}

function createProviderError(
  status: number,
  message: string,
): CoverGenerationError {
  if (status === 429 || status === 503) {
    return new CoverGenerationError(
      message,
      status,
      "rate_limited",
      true,
    );
  }
  return new CoverGenerationError(
    message,
    status,
    "failed",
    false,
  );
}

function classifyCoverError(
  error: unknown,
): { status: number; error: string; message: string } {
  if (error instanceof CoverGenerationError) {
    if (error.result === "rate_limited") {
      return {
        status: 429,
        error: "rate_limited",
        message: error.message,
      };
    }
    if (error.status === 401 || error.status === 403) {
      return {
        status: 422,
        error: "invalid_ai_response",
        message:
          "AI cover saglayicisi yetki hatasi verdi. ImageRouter veya Hugging Face API ayarlarini kontrol edin.",
      };
    }
    return {
      status: 422,
      error: "invalid_ai_response",
      message: error.message,
    };
  }

  const text = shortErrorText(String(error));
  const lowered = text.toLowerCase();
  if (
    lowered.includes("429") ||
    lowered.includes("503") ||
    lowered.includes("rate limit") ||
    lowered.includes("too many requests")
  ) {
    return {
      status: 429,
      error: "rate_limited",
      message:
        "AI cover havuzundaki modeller gunluk limite ulasti veya gecici olarak kullanilamiyor.",
    };
  }
  if (
    lowered.includes("api key") ||
    lowered.includes("unauthorized") ||
    lowered.includes("forbidden")
  ) {
    return {
      status: 422,
      error: "invalid_ai_response",
      message:
        "AI cover saglayicisi yetki hatasi verdi. ImageRouter veya Hugging Face API ayarlarini kontrol edin.",
      };
  }
  return {
    status: 422,
    error: "invalid_ai_response",
    message: text,
  };
}

function validateRequest(
  body: unknown,
): { ok: true; value: GenerateCoverRequest } | {
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
  const readingId = String(record.reading_id ?? "").trim();
  let provider = normalizeProvider(record.provider?.toString());
  let model = normalizeModel(record.model?.toString());

  if (!readingId) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Reading ID is required.",
      }),
    };
  }

  if (provider === providerCoverAuto && model !== modelAuto) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Auto cover provider only supports the auto model selector.",
      }),
    };
  }

  if (![providerCoverAuto, providerImageRouter, providerHuggingFace].includes(provider)) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Cover AI provider is invalid.",
      }),
    };
  }

  if (provider === providerImageRouter && !isImageRouterModel(model)) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "ImageRouter model is invalid.",
      }),
    };
  }

  if (provider === providerHuggingFace && !isHuggingFaceModel(model)) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Hugging Face model is invalid.",
      }),
    };
  }

  return {
    ok: true,
    value: { reading_id: readingId, provider, model },
  };
}

async function defaultFetchReadingDetail(
  readingId: string,
  authHeader: string,
  env: EnvGetter,
): Promise<ReadingDetailPayload> {
  const callerClient = createCallerClient(authHeader, env);
  if (callerClient instanceof Response) {
    throw new Error("Supabase environment variables are missing.");
  }
  const rpc = rpcInvoker(callerClient);
  const payload = unwrapRpcResult(await rpc("admin_get_reading_detail", {
    p_passage_id: readingId,
  }));
  const record = payload as Record<string, unknown>;
  const rawSentences = Array.isArray(record.sentences) ? record.sentences : [];
  return {
    id: String(record.id ?? readingId),
    title: String(record.title ?? "").trim(),
    level: normalizeNullableText(record.level),
    category: normalizeNullableText(record.category),
    tags_raw: normalizeNullableText(record.tags_raw),
    cover_bucket_name: normalizeNullableText(record.cover_bucket_name),
    cover_storage_path: normalizeNullableText(record.cover_storage_path),
    sentences: rawSentences
      .filter((item) => item && typeof item === "object")
      .map((item, index) => {
        const row = item as Record<string, unknown>;
        return {
          idx: Math.max(1, Number(row.idx ?? index + 1) || index + 1),
          sentence_en: String(row.sentence_en ?? "").trim(),
        };
      })
      .filter((item) => item.sentence_en.length > 0),
  };
}

async function defaultFetchCoverPoolStatus(
  authHeader: string,
  env: EnvGetter,
): Promise<CoverPoolStatusPayload> {
  const callerClient = createCallerClient(authHeader, env);
  if (callerClient instanceof Response) {
    throw new Error("Supabase environment variables are missing.");
  }
  const rpc = rpcInvoker(callerClient);
  const payload = unwrapRpcResult(await rpc("admin_get_ai_cover_pool_status"));
  const record = payload as Record<string, unknown>;
  const rawModels = Array.isArray(record.models) ? record.models : [];
  const usageDateUtc = normalizeNullableText(record.usage_date_utc);
  return {
    usage_date_utc: usageDateUtc ?? undefined,
    local_caps_enabled: Boolean(record.local_caps_enabled ?? true),
    models: rawModels
      .filter((item) => item && typeof item === "object")
      .map((item) => {
        const row = item as Record<string, unknown>;
        return {
          provider: String(row.provider ?? "").trim().toLowerCase(),
          model: String(row.model ?? row.model_id ?? "").trim(),
          enabled: Boolean(row.enabled ?? true),
          priority: Number(row.priority ?? 0) || 0,
          daily_cap: Number(row.daily_cap ?? 0) || 0,
          lifetime_cap: row.lifetime_cap == null
            ? null
            : Number(row.lifetime_cap),
        };
      })
      .filter((item) => item.provider.length > 0 && item.model.length > 0),
  };
}

async function defaultReserveAttempt(
  provider: string,
  model: string,
  authHeader: string,
  env: EnvGetter,
): Promise<ReserveCoverAttemptResult> {
  const callerClient = createCallerClient(authHeader, env);
  if (callerClient instanceof Response) {
    throw new Error("Supabase environment variables are missing.");
  }
  const rpc = rpcInvoker(callerClient);
  const payload = unwrapRpcResult(await rpc("admin_reserve_ai_cover_model_attempt", {
    p_provider: provider,
    p_model: model,
  }));
  const record = payload as Record<string, unknown>;
  return {
    allowed: Boolean(record.allowed ?? false),
    reason: normalizeNullableText(record.reason),
    daily_cap: record.daily_cap == null ? null : Number(record.daily_cap),
    lifetime_cap: record.lifetime_cap == null
      ? null
      : Number(record.lifetime_cap),
    attempt_count: record.attempt_count == null
      ? null
      : Number(record.attempt_count),
  };
}

async function defaultMarkAttemptResult(
  provider: string,
  model: string,
  result: MarkAttemptResult,
  authHeader: string,
  env: EnvGetter,
): Promise<void> {
  const callerClient = createCallerClient(authHeader, env);
  if (callerClient instanceof Response) {
    throw new Error("Supabase environment variables are missing.");
  }
  const rpc = rpcInvoker(callerClient);
  await unwrapRpcResult(await rpc("admin_mark_ai_cover_model_attempt_result", {
    p_provider: provider,
    p_model: model,
    p_result: result,
  }));
}

async function downloadImageBytes(
  url: string,
  fetchFn: typeof fetch,
): Promise<{ bytes: Uint8Array; mimeType: string }> {
  const response = await fetchFn(url);
  if (!response.ok) {
    const payload = await parseResponsePayload(response);
    throw createProviderError(
      response.status,
      payloadMessage(
        payload,
        `Image download failed with ${response.status}.`,
      ),
    );
  }

  const mimeType = normalizeNullableText(response.headers.get("content-type")) ??
    "image/png";
  if (mimeType.toLowerCase().includes("json")) {
    const payload = await parseResponsePayload(response);
    throw new CoverGenerationError(
      payloadMessage(payload, "Image provider returned JSON instead of binary image data."),
      422,
      "failed",
      false,
    );
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.length === 0) {
    throw new CoverGenerationError(
      "Image provider returned an empty image response.",
      422,
      "failed",
      false,
    );
  }

  return { bytes, mimeType };
}

async function defaultGenerateImageRouter(
  model: string,
  prompt: string,
  env: EnvGetter,
  fetchFn: typeof fetch,
): Promise<GeneratedCoverAsset> {
  const apiKey = env("IMAGEROUTER_API_KEY")?.trim() ?? "";
  if (!apiKey) {
    throw new CoverGenerationError(
      "ImageRouter API key is missing.",
      401,
      "failed",
      false,
    );
  }

  const baseUrl = (env("IMAGEROUTER_BASE_URL")?.trim() ??
    "https://api.imagerouter.io").replace(/\/+$/, "");
  const response = await fetchFn(
    `${baseUrl}/v1/openai/images/generations`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        prompt,
        n: 1,
        quality: "auto",
        size: "auto",
        response_format: "url",
        output_format: "png",
      }),
    },
  );

  const payload = await parseResponsePayload(response);
  if (!response.ok) {
    throw createProviderError(
      response.status,
      payloadMessage(
        payload,
        `ImageRouter request failed with ${response.status}.`,
      ),
    );
  }

  const data = (payload as Record<string, unknown> | null)?.["data"];
  const firstImage = Array.isArray(data) && data.length > 0 && data[0] &&
      typeof data[0] === "object"
    ? data[0] as Record<string, unknown>
    : null;
  const imageUrl = normalizeNullableText(firstImage?.url);
  if (imageUrl == null) {
    throw new CoverGenerationError(
      "ImageRouter response did not include a usable image URL.",
      422,
      "failed",
      false,
    );
  }

  const downloaded = await downloadImageBytes(imageUrl, fetchFn);
  return {
    bytes: downloaded.bytes,
    mimeType: downloaded.mimeType,
    provider: providerImageRouter,
    model,
    style: coverStyle,
    prompt,
  };
}

function huggingFaceModelPath(model: string): string {
  return model.split("/").map((segment) => encodeURIComponent(segment)).join("/");
}

async function defaultGenerateHuggingFace(
  model: string,
  prompt: string,
  env: EnvGetter,
  fetchFn: typeof fetch,
): Promise<GeneratedCoverAsset> {
  const token = env("HUGGINGFACE_API_TOKEN")?.trim() ?? "";
  if (!token) {
    throw new CoverGenerationError(
      "Hugging Face API token is missing.",
      401,
      "failed",
      false,
    );
  }

  const response = await fetchFn(
    `https://router.huggingface.co/hf-inference/models/${huggingFaceModelPath(model)}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        inputs: prompt,
        parameters: {
          width: 1024,
          height: 1024,
          num_inference_steps: 30,
        },
      }),
    },
  );

  if (!response.ok) {
    const payload = await parseResponsePayload(response);
    throw createProviderError(
      response.status,
      payloadMessage(
        payload,
        `Hugging Face request failed with ${response.status}.`,
      ),
    );
  }

  const mimeType = normalizeNullableText(response.headers.get("content-type")) ??
    "image/png";
  if (mimeType.toLowerCase().includes("json")) {
    const payload = await parseResponsePayload(response);
    throw new CoverGenerationError(
      payloadMessage(payload, "Hugging Face response did not include binary image data."),
      422,
      "failed",
      false,
    );
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.length === 0) {
    throw new CoverGenerationError(
      "Hugging Face returned an empty image response.",
      422,
      "failed",
      false,
    );
  }

  return {
    bytes,
    mimeType,
    provider: providerHuggingFace,
    model,
    style: coverStyle,
    prompt,
  };
}

async function defaultPersistCover(
  detail: ReadingDetailPayload,
  cover: GeneratedCoverAsset,
  authHeader: string,
  env: EnvGetter,
  now: () => Date,
): Promise<Record<string, unknown>> {
  const callerClient = createCallerClient(authHeader, env);
  if (callerClient instanceof Response) {
    throw new Error("Supabase environment variables are missing.");
  }

  const bucketName = "reading-covers";
  const assetId = crypto.randomUUID();
  const storagePath = `readings/${detail.id}/${assetId}.png`;
  const previousBucket = detail.cover_bucket_name?.trim() ?? "";
  const previousPath = detail.cover_storage_path?.trim() ?? "";

  const uploadResult = await callerClient.storage.from(bucketName).upload(
    storagePath,
    cover.bytes,
    {
      contentType: cover.mimeType,
      upsert: false,
    },
  );
  if (uploadResult.error) {
    throw new Error(String(uploadResult.error.message ?? uploadResult.error));
  }

  try {
    const rpc = rpcInvoker(callerClient);
    const payload = unwrapRpcResult(await rpc("admin_set_reading_cover", {
      p_payload: {
        reading_id: detail.id,
        bucket_name: bucketName,
        storage_path: storagePath,
        mime_type: cover.mimeType,
        alt_text: detail.title,
        generation_meta: {
          provider: cover.provider,
          model: cover.model,
          style: cover.style,
          prompt: cover.prompt,
          generated_at: now().toISOString(),
        },
      },
    }));

    if (
      previousBucket &&
      previousPath &&
      (previousBucket !== bucketName || previousPath !== storagePath)
    ) {
      await callerClient.storage.from(previousBucket).remove([previousPath]);
    }

    return payload as Record<string, unknown>;
  } catch (error) {
    await callerClient.storage.from(bucketName).remove([storagePath]);
    throw error;
  }
}

function orderedAutoCandidates(
  poolStatus: CoverPoolStatusPayload,
): CoverAttemptCandidate[] {
  return poolStatus.models
    .filter((item) =>
      Boolean(item.enabled ?? true) &&
      (item.provider === providerImageRouter ||
        item.provider === providerHuggingFace) &&
      item.model.trim().length > 0
    )
    .map((item) => ({
      provider: item.provider,
      model: item.model,
      priority: Number(item.priority ?? 0) || 0,
    }))
    .sort((left, right) => {
      const leftGroup = left.provider === providerImageRouter ? 0 : 1;
      const rightGroup = right.provider === providerImageRouter ? 0 : 1;
      if (leftGroup != rightGroup) {
        return leftGroup - rightGroup;
      }
      return left.priority - right.priority;
    });
}

function toProviderError(error: unknown): CoverGenerationError {
  if (error instanceof CoverGenerationError) {
    return error;
  }

  const text = shortErrorText(String(error));
  const lowered = text.toLowerCase();
  if (
    lowered.includes("429") ||
    lowered.includes("503") ||
    lowered.includes("too many requests") ||
    lowered.includes("rate limit") ||
    lowered.includes("model is loading")
  ) {
    return new CoverGenerationError(text, 429, "rate_limited", true);
  }
  if (
    lowered.includes("api key") ||
    lowered.includes("unauthorized") ||
    lowered.includes("forbidden")
  ) {
    return new CoverGenerationError(text, 401, "failed", false);
  }
  return new CoverGenerationError(text, 422, "failed", false);
}

async function attemptCandidate(
  candidate: CoverAttemptCandidate,
  prompt: string,
  request: GenerateCoverRequest,
  authHeader: string,
  env: EnvGetter,
  fetchFn: typeof fetch,
  deps: HandlerDeps,
): Promise<GeneratedCoverAsset | null> {
  const allowFallback = request.provider === providerCoverAuto &&
    request.model === modelAuto;
  const maxAttempts = candidate.provider === providerHuggingFace ? 2 : 1;

  for (let index = 0; index < maxAttempts; index += 1) {
    const reservation = await deps.reserveAttempt(
      candidate.provider,
      candidate.model,
      authHeader,
      env,
    );
    if (!reservation.allowed) {
      if (allowFallback) {
        return null;
      }
      throw new CoverGenerationError(
        `Secilen AI cover modeli kullanilamiyor: ${reservation.reason ?? "model_unavailable"}.`,
        429,
        "rate_limited",
        true,
      );
    }

    try {
      const cover = candidate.provider === providerImageRouter
        ? await deps.generateImageRouter(candidate.model, prompt, env, fetchFn)
        : await deps.generateHuggingFace(candidate.model, prompt, env, fetchFn);
      await deps.markAttemptResult(
        candidate.provider,
        candidate.model,
        "success",
        authHeader,
        env,
      );
      return cover;
    } catch (error) {
      const providerError = toProviderError(error);
      await deps.markAttemptResult(
        candidate.provider,
        candidate.model,
        providerError.result,
        authHeader,
        env,
      );

      if (
        candidate.provider === providerHuggingFace &&
        providerError.status === 503 &&
        index === 0
      ) {
        await deps.sleep(1200);
        continue;
      }

      if (allowFallback && providerError.retryable) {
        return null;
      }

      throw providerError;
    }
  }

  if (allowFallback) {
    return null;
  }
  throw new CoverGenerationError(
    "Secilen AI cover modeli gecici olarak kullanilamiyor.",
    429,
    "rate_limited",
    true,
  );
}

async function generateCoverFromPool(
  request: GenerateCoverRequest,
  detail: ReadingDetailPayload,
  authHeader: string,
  env: EnvGetter,
  fetchFn: typeof fetch,
  deps: HandlerDeps,
): Promise<GeneratedCoverAsset> {
  const prompt = buildCoverPrompt(detail);
  const isAutoMode = request.provider === providerCoverAuto &&
    request.model === modelAuto;
  const skippedProviders = new Set<string>();
  const candidates = isAutoMode
    ? orderedAutoCandidates(await deps.fetchCoverPoolStatus(authHeader, env))
    : [{
      provider: request.provider,
      model: request.model,
      priority: 0,
    }];

  if (candidates.length === 0) {
    throw new CoverGenerationError(
      "AI cover icin uygun aktif model bulunamadi.",
      429,
      "rate_limited",
      true,
    );
  }

  for (const candidate of candidates) {
    if (isAutoMode && skippedProviders.has(candidate.provider)) {
      continue;
    }

    try {
      const cover = await attemptCandidate(
        candidate,
        prompt,
        request,
        authHeader,
        env,
        fetchFn,
        deps,
      );
      if (cover != null) {
        return cover;
      }
    } catch (error) {
      const providerError = toProviderError(error);
      if (
        isAutoMode &&
        (providerError.status === 401 || providerError.status === 403)
      ) {
        skippedProviders.add(candidate.provider);
        continue;
      }
      throw providerError;
    }
  }

  if (isAutoMode && skippedProviders.size > 0) {
    const providerLabels = [...skippedProviders].map((provider) =>
      provider === providerImageRouter ? "ImageRouter" : "Hugging Face"
    );
    throw new CoverGenerationError(
      `Otomatik AI cover havuzunda ${providerLabels.join(" ve ")} yetki veya konfigurasyon hatasi nedeniyle atlandi. Kalan uygun modeller cover uretemedi.`,
      422,
      "failed",
      false,
    );
  }

  throw new CoverGenerationError(
    "Otomatik AI cover havuzundaki modeller gunluk limite ulasti veya gecici olarak kullanilamiyor.",
    429,
    "rate_limited",
    true,
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
  const handlerDeps: HandlerDeps = {
    env,
    fetchFn: deps.fetchFn ?? fetch,
    now: deps.now ?? (() => new Date()),
    sleep: deps.sleep ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms))),
    resolveCaller: deps.resolveCaller ?? resolveAdminCaller,
    fetchReadingDetail: deps.fetchReadingDetail ?? defaultFetchReadingDetail,
    fetchCoverPoolStatus: deps.fetchCoverPoolStatus ?? defaultFetchCoverPoolStatus,
    reserveAttempt: deps.reserveAttempt ?? defaultReserveAttempt,
    markAttemptResult: deps.markAttemptResult ?? defaultMarkAttemptResult,
    generateImageRouter: deps.generateImageRouter ?? defaultGenerateImageRouter,
    generateHuggingFace: deps.generateHuggingFace ?? defaultGenerateHuggingFace,
    persistCover: deps.persistCover ?? defaultPersistCover,
  };

  const caller = await handlerDeps.resolveCaller(req, authHeader, env);
  if (caller instanceof Response) {
    return caller;
  }

  try {
    const detail = await handlerDeps.fetchReadingDetail(
      validated.value.reading_id,
      authHeader,
      env,
    );
    if (detail.title.trim().length === 0 || detail.sentences.length === 0) {
      return json(422, {
        error: "invalid_source_reading",
        message: "Reading detail is not complete enough for cover generation.",
      });
    }

    const cover = await generateCoverFromPool(
      validated.value,
      detail,
      authHeader,
      env,
      handlerDeps.fetchFn,
      handlerDeps,
    );
    const persisted = await handlerDeps.persistCover(
      detail,
      cover,
      authHeader,
      env,
      handlerDeps.now,
    );
    return json(200, persisted);
  } catch (error) {
    const classified = classifyCoverError(error);
    return json(classified.status, {
      error: classified.error,
      message: classified.message,
    });
  }
}

if (import.meta.main) {
  serve((req: Request) => handleRequest(req));
}

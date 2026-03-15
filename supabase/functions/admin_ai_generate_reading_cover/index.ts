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

const defaultGeminiImageProvider = "gemini_image";
const defaultOpenAiImageProvider = "openai_images";
const defaultGeminiImageModel = "gemini-2.5-flash-image";
const defaultOpenAiImageModel = "gpt-image-1.5";

interface GenerateCoverRequest {
  reading_id: string;
  provider: string;
  model: string;
}

export interface HandlerDeps {
  env: EnvGetter;
  fetchFn: typeof fetch;
  now: () => Date;
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
  generateCover: (
    request: GenerateCoverRequest,
    detail: ReadingDetailPayload,
    env: EnvGetter,
    fetchFn: typeof fetch,
  ) => Promise<GeneratedCoverAsset>;
  persistCover: (
    detail: ReadingDetailPayload,
    cover: GeneratedCoverAsset,
    authHeader: string,
    env: EnvGetter,
  ) => Promise<Record<string, unknown>>;
}

function normalizeNullableText(value: unknown): string | null {
  const text = String(value ?? "").trim();
  return text.length > 0 ? text : null;
}

function decodeBase64ToBytes(value: string): Uint8Array {
  const decoded = atob(value);
  return Uint8Array.from(decoded, (char) => char.charCodeAt(0));
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

function classifyCoverError(
  error: unknown,
): { status: number; error: string; message: string } {
  const text = shortErrorText(String(error));
  const lowered = text.toLowerCase();

  if (
    lowered.includes("quota") ||
    lowered.includes("billing") ||
    lowered.includes("rate limit") ||
    lowered.includes("insufficient_quota") ||
    lowered.includes("resource exhausted") ||
    lowered.includes("429")
  ) {
    return {
      status: 429,
      error: "rate_limited",
      message:
        "AI cover saglayicisi kota veya billing sinirina takildi. Gemini veya OpenAI planini kontrol edin.",
    };
  }

  if (
    lowered.includes("api key") ||
    lowered.includes("unauthorized") ||
    lowered.includes("forbidden") ||
    lowered.includes("permission denied") ||
    lowered.includes("authentication")
  ) {
    return {
      status: 422,
      error: "invalid_ai_response",
      message:
        "AI cover saglayicisi yetki hatasi verdi. API key ayarlarini kontrol edin.",
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
  let provider = String(record.provider ?? "").trim().toLowerCase();
  let model = String(record.model ?? "").trim();
  if (!readingId) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Reading ID is required.",
      }),
    };
  }

  if (!provider) {
    provider = model == defaultOpenAiImageModel
      ? defaultOpenAiImageProvider
      : defaultGeminiImageProvider;
  }

  if (!model) {
    model = provider == defaultOpenAiImageProvider
      ? defaultOpenAiImageModel
      : defaultGeminiImageModel;
  }

  if (
    provider != defaultGeminiImageProvider &&
    provider != defaultOpenAiImageProvider
  ) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Cover AI provider is invalid.",
      }),
    };
  }

  if (
    provider == defaultGeminiImageProvider &&
    model != defaultGeminiImageModel
  ) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Gemini image model is invalid.",
      }),
    };
  }

  if (
    provider == defaultOpenAiImageProvider &&
    model != defaultOpenAiImageModel
  ) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "OpenAI image model is invalid.",
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
  const rpc = callerClient.rpc.bind(callerClient) as unknown as (
    fn: string,
    args?: Record<string, unknown>,
  ) => Promise<unknown>;
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

async function defaultGenerateCover(
  request: GenerateCoverRequest,
  detail: ReadingDetailPayload,
  env: EnvGetter,
  fetchFn: typeof fetch,
): Promise<GeneratedCoverAsset> {
  const style = "editorial illustration";
  const prompt = buildCoverPrompt(detail);
  const geminiApiKey = env("GEMINI_API_KEY")?.trim() ?? "";
  const openAiApiKey = env("OPENAI_API_KEY")?.trim() ?? "";

  if (request.provider == defaultGeminiImageProvider) {
    if (!geminiApiKey) {
      throw new Error("Gemini image API key is missing.");
    }

    const response = await fetchFn(
      `https://generativelanguage.googleapis.com/v1beta/models/${
        encodeURIComponent(request.model)
      }:generateContent`,
      {
        method: "POST",
        headers: {
          "x-goog-api-key": geminiApiKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [{ text: prompt }],
            },
          ],
          generationConfig: {
            imageConfig: {
              aspectRatio: "16:9",
            },
          },
        }),
      },
    );

    const payload = await response.json();
    if (!response.ok) {
      throw new Error(
        String(
          payload?.error?.message ?? payload?.message ??
            `Gemini image request failed with ${response.status}.`,
        ),
      );
    }

    const candidates = Array.isArray(payload?.candidates)
      ? payload.candidates
      : [];
    for (const candidate of candidates) {
      const parts = Array.isArray(candidate?.content?.parts)
        ? candidate.content.parts
        : [];
      for (const part of parts) {
        const inlineData = part?.inlineData ?? part?.inline_data;
        const b64 = typeof inlineData?.data === "string"
          ? inlineData.data.trim()
          : "";
        if (!b64) {
          continue;
        }
        const mimeType = String(
          inlineData?.mimeType ?? inlineData?.mime_type ?? "image/png",
        );
        return {
          bytes: decodeBase64ToBytes(b64),
          mimeType,
          provider: defaultGeminiImageProvider,
          model: request.model,
          style,
          prompt,
        };
      }
    }

    throw new Error("Gemini image response did not contain inline image data.");
  }

  if (!openAiApiKey) {
    throw new Error("OpenAI image API key is missing.");
  }

  const response = await fetchFn(
    "https://api.openai.com/v1/images/generations",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAiApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: request.model,
        prompt,
        size: "1536x1024",
        output_format: "png",
        quality: "high",
      }),
    },
  );

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(
      String(
        payload?.error?.message ?? payload?.message ??
          `OpenAI Images request failed with ${response.status}.`,
      ),
    );
  }

  const b64 = payload?.data?.[0]?.b64_json;
  if (typeof b64 !== "string" || !b64.trim()) {
    throw new Error("OpenAI Images did not return b64_json data.");
  }

  return {
    bytes: decodeBase64ToBytes(b64),
    mimeType: "image/png",
    provider: defaultOpenAiImageProvider,
    model: request.model,
    style,
    prompt,
  };
}

async function defaultPersistCover(
  detail: ReadingDetailPayload,
  cover: GeneratedCoverAsset,
  authHeader: string,
  env: EnvGetter,
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
    const rpc = callerClient.rpc.bind(callerClient) as unknown as (
      fn: string,
      args?: Record<string, unknown>,
    ) => Promise<unknown>;
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
          generated_at: new Date().toISOString(),
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

  try {
    const detail = await (deps.fetchReadingDetail ?? defaultFetchReadingDetail)(
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

    const cover = await (deps.generateCover ?? defaultGenerateCover)(
      validated.value,
      detail,
      env,
      deps.fetchFn ?? fetch,
    );
    const persisted = await (deps.persistCover ?? defaultPersistCover)(
      detail,
      cover,
      authHeader,
      env,
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

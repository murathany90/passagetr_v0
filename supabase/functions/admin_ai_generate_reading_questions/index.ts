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

const supportedProviders = ["gemini", "openrouter"] as const;
const geminiAllowedModels = ["gemini-2.5-flash"] as const;
const openRouterAllowedModels = [
  "arcee-ai/trinity-large-preview:free",
  "nvidia/nemotron-3-super-120b-a12b:free",
  "z-ai/glm-4.5-air:free",
  "qwen/qwen3-coder:free",
  "stepfun/step-3.5-flash:free",
] as const;

type AiProvider = (typeof supportedProviders)[number];

const defaultGeminiModel = geminiAllowedModels[0];

function canonicalGeminiModel(model: string | null): string {
  const normalized = String(model ?? "").trim().toLowerCase();
  return normalized === "gemini-2.0-flash" ||
      normalized === "gemini-2.0-flash-001"
    ? defaultGeminiModel
    : (model ?? defaultGeminiModel);
}

interface GenerateQuestionsRequest {
  reading_id: string;
  provider: AiProvider;
  model: string;
  question_count: number;
}

interface ReadingSentencePayload {
  idx: number;
  sentence_en: string;
  sentence_tr?: string | null;
}

interface ReadingDetailPayload {
  id: string;
  title: string;
  level?: string | null;
  category?: string | null;
  tags_raw?: string | null;
  sentences: ReadingSentencePayload[];
}

interface GeneratedQuestion {
  sort_order: number;
  question: string;
  options: string[];
  correct_option_index: number;
  explanation?: string | null;
}

interface GeneratedQuestionSet {
  questions: GeneratedQuestion[];
}

interface GeneratedProviderQuestions {
  provider: AiProvider;
  model: string;
  questions: GeneratedQuestion[];
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
  generateQuestions: (
    request: GenerateQuestionsRequest,
    detail: ReadingDetailPayload,
    env: EnvGetter,
    fetchFn: typeof fetch,
  ) => Promise<GeneratedProviderQuestions>;
}

function normalizeNullableText(value: unknown): string | null {
  const text = String(value ?? "").trim();
  return text.length > 0 ? text : null;
}

function normalizeProvider(value: unknown): AiProvider | null {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (normalized === "gemini" || normalized === "openrouter") {
    return normalized;
  }
  return null;
}

function stripCodeFences(text: string): string {
  const trimmed = text.trim();
  if (!trimmed.startsWith("```")) {
    return trimmed;
  }
  return trimmed.replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
}

function providerLabel(provider: AiProvider): string {
  return provider === "openrouter" ? "OpenRouter" : "Gemini";
}

function classifyProviderError(
  error: unknown,
  provider: AiProvider,
): { status: number; error: string; message: string } {
  const text = shortErrorText(String(error));
  const lowered = text.toLowerCase();
  const label = providerLabel(provider);

  if (
    lowered.includes("quota") ||
    lowered.includes("billing") ||
    lowered.includes("rate limit") ||
    lowered.includes("resource_exhausted") ||
    lowered.includes("credits")
  ) {
    return {
      status: 429,
      error: "rate_limited",
      message:
        "Secilen AI saglayicisi kota veya billing hatasi verdi. API planini kontrol edin.",
    };
  }

  if (
    lowered.includes("api key") ||
    lowered.includes("permission denied") ||
    lowered.includes("forbidden") ||
    lowered.includes("unauthorized")
  ) {
    return {
      status: 422,
      error: "invalid_ai_response",
      message:
        `${label} istegi yetki hatasi verdi. API key ayarlarini kontrol edin.`,
    };
  }

  if (lowered.includes("json") || lowered.includes("schema")) {
    return {
      status: 422,
      error: "invalid_ai_response",
      message: "AI servisi beklenen mini test JSON semasini donmedi.",
    };
  }

  if (
    lowered.includes("no longer available to new users") ||
    lowered.includes("not found for api version") ||
    lowered.includes("model is invalid")
  ) {
    return {
      status: 422,
      error: "invalid_ai_response",
      message:
        "Secilen Gemini modeli artik kullanilamiyor. Varsayilan Gemini 2.5 Flash modeliyle tekrar deneyin.",
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
): { ok: true; value: GenerateQuestionsRequest } | {
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
  const rawProvider = normalizeNullableText(record.provider);
  const provider = rawProvider == null
    ? "gemini"
    : normalizeProvider(rawProvider);
  const model = normalizeNullableText(record.model);
  const questionCount = Number(record.question_count ?? 0);

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
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "AI provider is invalid.",
      }),
    };
  }
  if (!Number.isFinite(questionCount) || questionCount < 1) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Question count must be at least 1.",
      }),
    };
  }

  if (provider === "gemini") {
    const geminiModel = canonicalGeminiModel(model ?? defaultGeminiModel);
    if (
      !geminiAllowedModels.includes(
        geminiModel as (typeof geminiAllowedModels)[number],
      )
    ) {
      return {
        ok: false,
        response: json(400, {
          error: "invalid_request",
          message: "Gemini model is invalid.",
        }),
      };
    }
    return {
      ok: true,
      value: {
        reading_id: readingId,
        provider,
        model: geminiModel,
        question_count: Math.round(questionCount),
      },
    };
  }

  if (!model) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "OpenRouter model is required.",
      }),
    };
  }
  if (
    !openRouterAllowedModels.includes(
      model as (typeof openRouterAllowedModels)[number],
    )
  ) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "OpenRouter model is invalid.",
      }),
    };
  }

  return {
    ok: true,
    value: {
      reading_id: readingId,
      provider,
      model,
      question_count: Math.round(questionCount),
    },
  };
}

function validateQuestions(
  body: unknown,
): { ok: true; value: GeneratedQuestionSet } | {
  ok: false;
  message: string;
} {
  if (!body || typeof body !== "object") {
    return { ok: false, message: "AI service did not return a JSON object." };
  }

  const record = body as Record<string, unknown>;
  const rawQuestions = Array.isArray(record.questions) ? record.questions : [];
  const questions: GeneratedQuestion[] = [];

  for (const [index, item] of rawQuestions.entries()) {
    if (!item || typeof item !== "object") {
      return { ok: false, message: "AI service returned an invalid question." };
    }

    const row = item as Record<string, unknown>;
    const question = String(row.question ?? "").trim();
    const options = Array.isArray(row.options)
      ? row.options.map((option) => String(option).trim()).filter(Boolean)
      : [];
    const correctOptionIndex = Number(row.correct_option_index ?? -1);

    if (!question || options.length < 2) {
      return {
        ok: false,
        message: "AI service returned an incomplete question.",
      };
    }
    if (
      !Number.isInteger(correctOptionIndex) ||
      correctOptionIndex < 0 ||
      correctOptionIndex >= options.length
    ) {
      return {
        ok: false,
        message: "AI service returned an invalid correct option index.",
      };
    }

    questions.push({
      sort_order: Math.max(1, Number(row.sort_order ?? index + 1) || index + 1),
      question,
      options,
      correct_option_index: correctOptionIndex,
      explanation: normalizeNullableText(row.explanation),
    });
  }

  if (questions.length === 0) {
    return { ok: false, message: "AI service returned no questions." };
  }

  return { ok: true, value: { questions } };
}

export function buildQuestionsPrompt(
  request: GenerateQuestionsRequest,
  detail: ReadingDetailPayload,
): string {
  const sentences = detail.sentences
    .map((sentence) => `${sentence.idx}. ${sentence.sentence_en}`)
    .join("\n");

  return [
    "You are generating a mini reading quiz for a Turkish learning product.",
    "Return plain JSON only. Do not wrap the response in markdown or code fences.",
    "Use this exact top-level shape:",
    JSON.stringify({
      questions: [
        {
          sort_order: 1,
          question: "string",
          options: ["string", "string", "string", "string"],
          correct_option_index: 0,
          explanation: "string|null",
        },
      ],
    }),
    `Reading title: ${detail.title}`,
    `CEFR level: ${detail.level ?? "null"}`,
    `Category: ${detail.category ?? "null"}`,
    `Tags raw: ${detail.tags_raw ?? "null"}`,
    `Question count: ${request.question_count}`,
    "Passage sentences:",
    sentences,
    "Rules:",
    "- Questions must be answerable from the passage only.",
    "- Keep language aligned with the passage CEFR level.",
    "- Each question must have at least 2 options and exactly one correct option.",
    "- Prefer comprehension questions over grammar trivia.",
  ].join("\n");
}

function parseQuestionJson(rawText: string): GeneratedQuestionSet {
  if (!rawText.trim()) {
    throw new Error("AI service did not return any question content.");
  }

  let decoded: unknown;
  try {
    decoded = JSON.parse(stripCodeFences(rawText));
  } catch (_error) {
    throw new Error("AI service returned invalid JSON.");
  }

  const validated = validateQuestions(decoded);
  if (!validated.ok) {
    throw new Error(validated.message);
  }
  return validated.value;
}

function openRouterContentToText(content: unknown): string {
  if (typeof content === "string") {
    return content;
  }
  if (!Array.isArray(content)) {
    return "";
  }
  return content
    .map((part) => {
      if (typeof part === "string") {
        return part;
      }
      if (!part || typeof part !== "object") {
        return "";
      }
      const text = (part as Record<string, unknown>).text;
      return typeof text === "string" ? text : "";
    })
    .join("");
}

async function generateWithGemini(
  request: GenerateQuestionsRequest,
  detail: ReadingDetailPayload,
  env: EnvGetter,
  fetchFn: typeof fetch,
): Promise<GeneratedProviderQuestions> {
  const apiKey = env("GEMINI_API_KEY")?.trim() ?? "";
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is required.");
  }

  const prompt = buildQuestionsPrompt(request, detail);
  const response = await fetchFn(
    `https://generativelanguage.googleapis.com/v1beta/models/${request.model}:generateContent`,
    {
      method: "POST",
      headers: {
        "x-goog-api-key": apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.5,
          responseMimeType: "application/json",
        },
      }),
    },
  );

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(
      String(
        payload?.error?.message ?? payload?.message ??
          `Gemini request failed with ${response.status}.`,
      ),
    );
  }

  const candidates = Array.isArray(payload?.candidates) ? payload.candidates : [];
  const firstCandidate = candidates[0];
  const parts = Array.isArray(firstCandidate?.content?.parts)
    ? firstCandidate.content.parts
    : [];
  const rawText = parts
    .map((part: Record<string, unknown>) => String(part?.text ?? ""))
    .join("");
  const questions = parseQuestionJson(rawText);
  return { provider: "gemini", model: request.model, questions: questions.questions };
}

async function generateWithOpenRouter(
  request: GenerateQuestionsRequest,
  detail: ReadingDetailPayload,
  env: EnvGetter,
  fetchFn: typeof fetch,
): Promise<GeneratedProviderQuestions> {
  const apiKey = env("OPENROUTER_API_KEY")?.trim() ?? "";
  if (!apiKey) {
    throw new Error("OPENROUTER_API_KEY is required.");
  }

  const headers: Record<string, string> = {
    Authorization: `Bearer ${apiKey}`,
    "Content-Type": "application/json",
  };
  const httpReferer = env("OPENROUTER_HTTP_REFERER")?.trim() ?? "";
  const xTitle = env("OPENROUTER_X_TITLE")?.trim() ?? "";
  if (httpReferer) {
    headers["HTTP-Referer"] = httpReferer;
  }
  if (xTitle) {
    headers["X-Title"] = xTitle;
  }

  const response = await fetchFn("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers,
    body: JSON.stringify({
      model: request.model,
      messages: [{ role: "user", content: buildQuestionsPrompt(request, detail) }],
      response_format: { type: "json_object" },
      temperature: 0.5,
    }),
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(
      String(
        payload?.error?.message ?? payload?.message ??
          `OpenRouter request failed with ${response.status}.`,
      ),
    );
  }

  const rawText = openRouterContentToText(payload?.choices?.[0]?.message?.content);
  const questions = parseQuestionJson(rawText);
  return {
    provider: "openrouter",
    model: request.model,
    questions: questions.questions,
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
    sentences: rawSentences
      .filter((item) => item && typeof item === "object")
      .map((item, index) => {
        const row = item as Record<string, unknown>;
        return {
          idx: Math.max(1, Number(row.idx ?? index + 1) || index + 1),
          sentence_en: String(row.sentence_en ?? "").trim(),
          sentence_tr: normalizeNullableText(row.sentence_tr),
        };
      })
      .filter((item) => item.sentence_en.length > 0),
  };
}

async function defaultGenerateQuestions(
  request: GenerateQuestionsRequest,
  detail: ReadingDetailPayload,
  env: EnvGetter,
  fetchFn: typeof fetch,
): Promise<GeneratedProviderQuestions> {
  if (request.provider === "openrouter") {
    return generateWithOpenRouter(request, detail, env, fetchFn);
  }
  return generateWithGemini(request, detail, env, fetchFn);
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
  const resolveCaller = deps.resolveCaller ?? resolveAdminCaller;
  const caller = await resolveCaller(req, authHeader, env);
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
        message: "Reading detail is not complete enough for question generation.",
      });
    }

    const generated = await (deps.generateQuestions ?? defaultGenerateQuestions)(
      validated.value,
      detail,
      env,
      deps.fetchFn ?? fetch,
    );

    return json(200, {
      questions: generated.questions,
      provider: generated.provider,
      model: generated.model,
      generated_at: (deps.now ?? (() => new Date()))().toISOString(),
    });
  } catch (error) {
    const classified = classifyProviderError(error, validated.value.provider);
    return json(classified.status, {
      error: classified.error,
      message: classified.message,
    });
  }
}

if (import.meta.main) {
  serve((req: Request) => handleRequest(req));
}

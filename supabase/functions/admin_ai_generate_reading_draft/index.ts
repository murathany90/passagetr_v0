import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const validCefrLevels = new Set(["A1", "A2", "B1", "B2", "C1", "C2"]);
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

export interface GenerateReadingDraftRequest {
  topic: string;
  cefr_level: "A1" | "A2" | "B1" | "B2" | "C1" | "C2";
  target_word_count: number;
  focus_word_count: number;
  question_count: number;
  provider: AiProvider;
  model: string;
  extra_instructions?: string | null;
}

interface GeneratedSentence {
  idx: number;
  sentence_en: string;
  sentence_tr: string | null;
}

interface GeneratedLinkedWord {
  en_word: string;
  tr_meaning: string;
  pos: string;
  notes?: string | null;
}

interface GeneratedQuestion {
  sort_order: number;
  question: string;
  options: string[];
  correct_option_index: number;
  explanation?: string | null;
}

interface GenerateReadingDraftContent {
  title: string;
  level: string | null;
  category: string | null;
  tags_raw: string | null;
  sentences: GeneratedSentence[];
  suggested_linked_words: GeneratedLinkedWord[];
  questions: GeneratedQuestion[];
}

interface GeneratedProviderDraft {
  provider: AiProvider;
  model: string;
  content: GenerateReadingDraftContent;
}

export interface GenerateReadingDraftResponse
  extends GenerateReadingDraftContent {
  generation_meta: {
    provider: AiProvider | string;
    model: string;
    topic: string;
    cefr_level: string;
    target_word_count: number;
    focus_word_count: number;
    question_count: number;
    actual_word_count: number;
    generated_at: string;
  };
}

export interface HandlerDeps {
  env: (name: string) => string | undefined;
  fetchFn: typeof fetch;
  now: () => Date;
  resolveCaller: (
    req: Request,
    authHeader: string,
    env: (name: string) => string | undefined,
  ) => Promise<{ role: string; userId: string } | Response>;
  generateDraft: (
    request: GenerateReadingDraftRequest,
    env: (name: string) => string | undefined,
    fetchFn: typeof fetch,
  ) => Promise<GeneratedProviderDraft>;
}

function json(status: number, payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: corsHeaders,
  });
}

function shortErrorText(text: string): string {
  const cleaned = text.replaceAll(/\s+/g, " ").trim();
  if (cleaned.length <= 240) {
    return cleaned;
  }
  return `${cleaned.slice(0, 240)}...`;
}

function providerLabel(provider: AiProvider): string {
  return provider === "openrouter" ? "OpenRouter" : "Gemini";
}

function classifyDraftError(
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
      message: "AI servisi beklenen JSON draft semasini donmedi.",
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

function normalizeNullableText(value: unknown): string | null {
  const text = String(value ?? "").trim();
  return text.length > 0 ? text : null;
}

function normalizeProvider(value: unknown): AiProvider | null {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (
    normalized === "gemini" ||
    normalized === "openrouter"
  ) {
    return normalized;
  }
  return null;
}

function stripCodeFences(text: string): string {
  const trimmed = text.trim();
  if (!trimmed.startsWith("```")) {
    return trimmed;
  }

  return trimmed
    .replace(/^```(?:json)?/i, "")
    .replace(/```$/i, "")
    .trim();
}

function countWords(sentences: GeneratedSentence[]): number {
  return sentences.reduce((total, sentence) => {
    const matches = sentence.sentence_en.match(/[A-Za-z0-9']+/g) ?? [];
    return total + matches.length;
  }, 0);
}

function validateRequest(
  body: unknown,
): { ok: true; value: GenerateReadingDraftRequest } | {
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
  const topic = String(record.topic ?? "").trim();
  const cefrLevel = String(record.cefr_level ?? "").trim().toUpperCase();
  const targetWordCount = Number(record.target_word_count ?? 0);
  const focusWordCount = Number(record.focus_word_count ?? 0);
  const questionCount = Number(record.question_count ?? 0);
  const rawProvider = normalizeNullableText(record.provider);
  const provider = rawProvider == null
    ? "gemini"
    : normalizeProvider(rawProvider);
  const model = normalizeNullableText(record.model);

  if (!topic) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Topic is required.",
      }),
    };
  }
  if (!validCefrLevels.has(cefrLevel)) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "CEFR level is invalid.",
      }),
    };
  }
  if (!Number.isFinite(targetWordCount) || targetWordCount < 30) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Target word count must be at least 30.",
      }),
    };
  }
  if (!Number.isFinite(focusWordCount) || focusWordCount < 1) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "Focus word count must be at least 1.",
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

  if (provider == null) {
    return {
      ok: false,
      response: json(400, {
        error: "invalid_request",
        message: "AI provider is invalid.",
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
        topic,
        cefr_level: cefrLevel as GenerateReadingDraftRequest["cefr_level"],
        target_word_count: Math.round(targetWordCount),
        focus_word_count: Math.round(focusWordCount),
        question_count: Math.round(questionCount),
        provider,
        model: geminiModel,
        extra_instructions: normalizeNullableText(record.extra_instructions),
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
      topic,
      cefr_level: cefrLevel as GenerateReadingDraftRequest["cefr_level"],
      target_word_count: Math.round(targetWordCount),
      focus_word_count: Math.round(focusWordCount),
      question_count: Math.round(questionCount),
      provider,
      model,
      extra_instructions: normalizeNullableText(record.extra_instructions),
    },
  };
}

function validateGeneratedContent(
  body: unknown,
): { ok: true; value: GenerateReadingDraftContent } | {
  ok: false;
  message: string;
} {
  if (!body || typeof body !== "object") {
    return { ok: false, message: "AI service did not return a JSON object." };
  }

  const record = body as Record<string, unknown>;
  const title = String(record.title ?? "").trim();
  if (!title) {
    return { ok: false, message: "AI service returned an empty title." };
  }

  const rawSentences = Array.isArray(record.sentences) ? record.sentences : [];
  const sentences: GeneratedSentence[] = [];
  for (const [index, item] of rawSentences.entries()) {
    if (!item || typeof item !== "object") {
      return { ok: false, message: "AI service returned an invalid sentence." };
    }
    const row = item as Record<string, unknown>;
    const sentenceEn = String(row.sentence_en ?? "").trim();
    if (!sentenceEn) {
      return { ok: false, message: "AI service returned an empty sentence." };
    }
    sentences.push({
      idx: Math.max(1, Number(row.idx ?? index + 1) || index + 1),
      sentence_en: sentenceEn,
      sentence_tr: normalizeNullableText(row.sentence_tr),
    });
  }
  if (sentences.length === 0) {
    return { ok: false, message: "AI service returned no sentences." };
  }

  const rawLinkedWords = Array.isArray(record.suggested_linked_words)
    ? record.suggested_linked_words
    : [];
  const suggestedLinkedWords: GeneratedLinkedWord[] = [];
  for (const item of rawLinkedWords) {
    if (!item || typeof item !== "object") {
      return {
        ok: false,
        message: "AI service returned an invalid linked word suggestion.",
      };
    }
    const row = item as Record<string, unknown>;
    const enWord = String(row.en_word ?? "").trim();
    const trMeaning = String(row.tr_meaning ?? "").trim();
    const pos = String(row.pos ?? "").trim();
    if (!enWord || !trMeaning || !pos) {
      return {
        ok: false,
        message: "AI service returned an incomplete linked word suggestion.",
      };
    }
    suggestedLinkedWords.push({
      en_word: enWord,
      tr_meaning: trMeaning,
      pos,
      notes: normalizeNullableText(row.notes),
    });
  }

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

  return {
    ok: true,
    value: {
      title,
      level: normalizeNullableText(record.level),
      category: normalizeNullableText(record.category),
      tags_raw: normalizeNullableText(record.tags_raw),
      sentences,
      suggested_linked_words: suggestedLinkedWords,
      questions,
    },
  };
}

async function defaultResolveCaller(
  _req: Request,
  authHeader: string,
  env: (name: string) => string | undefined,
): Promise<{ role: string; userId: string } | Response> {
  const supabaseUrl = env("SUPABASE_URL")?.trim() ?? "";
  const supabaseAnonKey = env("SUPABASE_ANON_KEY")?.trim() ?? "";

  if (!supabaseUrl || !supabaseAnonKey) {
    return json(500, {
      error: "server_not_configured",
      message: "Supabase environment variables are missing.",
    });
  }

  const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const [
    { data: roleData, error: roleError },
    { data: userData, error: userError },
  ] = await Promise.all([
    callerClient.rpc("current_app_role"),
    callerClient.auth.getUser(),
  ]);

  if (roleError) {
    return json(403, {
      error: "role_lookup_failed",
      message: shortErrorText(String(roleError.message ?? roleError)),
    });
  }
  if (userError || !userData.user?.id) {
    return json(401, {
      error: "unauthenticated",
      message: "Authenticated admin session is required.",
    });
  }

  const role = String(roleData ?? "").trim().toLowerCase();
  if (!["admin", "developer"].includes(role)) {
    return json(403, {
      error: "forbidden",
      message: "Only admin or developer can generate AI drafts.",
    });
  }

  return { role, userId: userData.user.id };
}

export function buildPrompt(request: GenerateReadingDraftRequest): string {
  return [
    "You are generating an English reading draft for a Turkish learning product.",
    "Return plain JSON only. Do not wrap the response in markdown or code fences.",
    "Use this exact top-level shape:",
    JSON.stringify({
      title: "string",
      level: "string|null",
      category: "string|null",
      tags_raw: "string|null",
      sentences: [{
        idx: 1,
        sentence_en: "string",
        sentence_tr: "string|null",
      }],
      suggested_linked_words: [
        {
          en_word: "string",
          tr_meaning: "string",
          pos: "string",
          notes: "string|null",
        },
      ],
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
    `Topic: ${request.topic}`,
    `CEFR level: ${request.cefr_level}`,
    `Target word count: ${request.target_word_count}`,
    `Focus word count: ${request.focus_word_count}`,
    `Question count: ${request.question_count}`,
    `Extra instructions: ${request.extra_instructions ?? "null"}`,
    "Rules:",
    "- Write a coherent reading passage split into sentences.",
    "- Keep Turkish translations natural and concise.",
    "- Infer a short category from the final passage and return it in category.",
    "- Infer a concise comma-separated tags_raw value from the topic and passage.",
    "- Suggested linked words must be candidates only; do not invent IDs.",
    "- Questions must be answerable from the passage.",
    "- Each question must have at least 2 options and exactly one correct index.",
  ].join("\n");
}

function parseDraftJson(
  rawText: string,
  provider: AiProvider,
): GenerateReadingDraftContent {
  if (!rawText.trim()) {
    throw new Error(
      `${providerLabel(provider)} did not return any draft content.`,
    );
  }

  let decoded: unknown;
  try {
    decoded = JSON.parse(stripCodeFences(rawText));
  } catch (_error) {
    throw new Error(`${providerLabel(provider)} returned invalid JSON.`);
  }

  const validated = validateGeneratedContent(decoded);
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
  request: GenerateReadingDraftRequest,
  env: (name: string) => string | undefined,
  fetchFn: typeof fetch,
): Promise<GeneratedProviderDraft> {
  const apiKey = env("GEMINI_API_KEY")?.trim() ?? "";
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is required.");
  }

  const response = await fetchFn(
    `https://generativelanguage.googleapis.com/v1beta/models/${request.model}:generateContent`,
    {
      method: "POST",
      headers: {
        "x-goog-api-key": apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [{ text: buildPrompt(request) }],
          },
        ],
        generationConfig: {
          temperature: 0.7,
          responseMimeType: "application/json",
        },
      }),
    },
  );

  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    const message = payload?.error?.message?.toString().trim() ||
      "Gemini request failed.";
    throw new Error(message);
  }

  const rawText = payload?.candidates?.[0]?.content?.parts?.map(
    (part: { text?: string }) => part?.text ?? "",
  ).join("") ?? "";

  return {
    provider: "gemini",
    model: request.model,
    content: parseDraftJson(rawText, "gemini"),
  };
}

async function generateWithOpenRouter(
  request: GenerateReadingDraftRequest,
  env: (name: string) => string | undefined,
  fetchFn: typeof fetch,
): Promise<GeneratedProviderDraft> {
  const apiKey = env("OPENROUTER_API_KEY")?.trim() ?? "";
  if (!apiKey) {
    throw new Error("OPENROUTER_API_KEY is required.");
  }

  const headers: Record<string, string> = {
    "Authorization": `Bearer ${apiKey}`,
    "Content-Type": "application/json",
  };
  const httpReferer = env("OPENROUTER_HTTP_REFERER")?.trim();
  const appTitle = env("OPENROUTER_X_TITLE")?.trim();
  if (httpReferer) {
    headers["HTTP-Referer"] = httpReferer;
  }
  if (appTitle) {
    headers["X-Title"] = appTitle;
  }

  const response = await fetchFn(
    "https://openrouter.ai/api/v1/chat/completions",
    {
      method: "POST",
      headers,
      body: JSON.stringify({
        model: request.model,
        messages: [{ role: "user", content: buildPrompt(request) }],
        response_format: { type: "json_object" },
        temperature: 0.7,
      }),
    },
  );

  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    const message = payload?.error?.message?.toString().trim() ||
      payload?.message?.toString().trim() ||
      "OpenRouter request failed.";
    throw new Error(message);
  }

  const rawText = openRouterContentToText(
    payload?.choices?.[0]?.message?.content,
  );
  return {
    provider: "openrouter",
    model: request.model,
    content: parseDraftJson(rawText, "openrouter"),
  };
}

async function dispatchGenerateDraft(
  request: GenerateReadingDraftRequest,
  env: (name: string) => string | undefined,
  fetchFn: typeof fetch,
): Promise<GeneratedProviderDraft> {
  return request.provider === "openrouter"
    ? await generateWithOpenRouter(request, env, fetchFn)
    : await generateWithGemini(request, env, fetchFn);
}

const defaultDeps: HandlerDeps = {
  env: (name: string) => Deno.env.get(name),
  fetchFn: fetch,
  now: () => new Date(),
  resolveCaller: defaultResolveCaller,
  generateDraft: dispatchGenerateDraft,
};

export async function handleRequest(
  req: Request,
  deps: Partial<HandlerDeps> = {},
): Promise<Response> {
  const runtime = { ...defaultDeps, ...deps } satisfies HandlerDeps;

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

  const validatedRequest = validateRequest(body);
  if (!validatedRequest.ok) {
    return validatedRequest.response;
  }

  const caller = await runtime.resolveCaller(req, authHeader, runtime.env);
  if (caller instanceof Response) {
    return caller;
  }

  try {
    const generated = await runtime.generateDraft(
      validatedRequest.value,
      runtime.env,
      runtime.fetchFn,
    );
    const validatedContent = validateGeneratedContent(generated.content);
    if (!validatedContent.ok) {
      return json(422, {
        error: "invalid_ai_response",
        message: validatedContent.message,
      });
    }

    const actualWordCount = countWords(validatedContent.value.sentences);
    const response: GenerateReadingDraftResponse = {
      ...validatedContent.value,
      generation_meta: {
        provider: generated.provider,
        model: generated.model,
        topic: validatedRequest.value.topic,
        cefr_level: validatedRequest.value.cefr_level,
        target_word_count: validatedRequest.value.target_word_count,
        focus_word_count: validatedRequest.value.focus_word_count,
        question_count: validatedRequest.value.question_count,
        actual_word_count: actualWordCount,
        generated_at: runtime.now().toISOString(),
      },
    };
    return json(200, response);
  } catch (error) {
    const classified = classifyDraftError(
      error,
      validatedRequest.value.provider,
    );
    return json(classified.status, {
      error: classified.error,
      message: classified.message,
    });
  }
}

if (import.meta.main) {
  serve((req: Request) => handleRequest(req));
}

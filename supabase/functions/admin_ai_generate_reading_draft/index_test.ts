import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { buildPrompt, handleRequest } from "./index.ts";

const validBody = {
  topic: "Space travel",
  cefr_level: "B1",
  target_word_count: 120,
  focus_word_count: 5,
  question_count: 3,
};

function requestWithBody(body: Record<string, unknown>): Request {
  return new Request("http://localhost/admin_ai_generate_reading_draft", {
    method: "POST",
    headers: {
      Authorization: "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

Deno.test("gemini request returns 200 and valid JSON", async () => {
  const response = await handleRequest(
    requestWithBody(validBody),
    {
      now: () => new Date("2026-03-13T10:00:00.000Z"),
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      generateDraft: async () => ({
        provider: "gemini",
        model: "gemini-2.5-flash",
        content: {
          title: "Journey to Mars",
          level: "B1",
          category: "science",
          tags_raw: "space, mars",
          sentences: [
            {
              idx: 1,
              sentence_en: "Astronauts train for long missions.",
              sentence_tr: "Astronotlar uzun gorevler icin egitim alir.",
            },
            {
              idx: 2,
              sentence_en: "They also learn how to solve problems calmly.",
              sentence_tr: "Ayrica sorunlari sakin sekilde cozmeyi ogrenirler.",
            },
          ],
          suggested_linked_words: [
            {
              en_word: "mission",
              tr_meaning: "gorev",
              pos: "noun",
              notes: null,
            },
          ],
          questions: [
            {
              sort_order: 1,
              question: "What do astronauts train for?",
              options: ["Long missions", "Short walks", "Cooking", "Driving"],
              correct_option_index: 0,
              explanation: "The passage says they train for long missions.",
            },
          ],
        },
      }),
    },
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.title, "Journey to Mars");
  assertEquals(payload.generation_meta.provider, "gemini");
  assertEquals(payload.generation_meta.model, "gemini-2.5-flash");
  assertEquals(payload.generation_meta.actual_word_count, 13);
  assertEquals(payload.questions.length, 1);
});

Deno.test("openrouter request returns 200 and valid JSON", async () => {
  const response = await handleRequest(
    requestWithBody({
      ...validBody,
      provider: "openrouter",
      model: "arcee-ai/trinity-large-preview:free",
    }),
    {
      now: () => new Date("2026-03-13T10:00:00.000Z"),
      resolveCaller: async () => ({ role: "developer", userId: "dev-1" }),
      generateDraft: async () => ({
        provider: "openrouter",
        model: "arcee-ai/trinity-large-preview:free",
        content: {
          title: "Journey to Mars",
          level: "B1",
          category: "science",
          tags_raw: "space, mars",
          sentences: [
            {
              idx: 1,
              sentence_en: "Astronauts train for long missions.",
              sentence_tr: "Astronotlar uzun gorevler icin egitim alir.",
            },
          ],
          suggested_linked_words: [],
          questions: [
            {
              sort_order: 1,
              question: "What do astronauts train for?",
              options: ["Long missions", "Short walks"],
              correct_option_index: 0,
              explanation: null,
            },
          ],
        },
      }),
    },
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.generation_meta.provider, "openrouter");
  assertEquals(
    payload.generation_meta.model,
    "arcee-ai/trinity-large-preview:free",
  );
});

Deno.test("unauthorized role returns 403", async () => {
  const response = await handleRequest(
    requestWithBody(validBody),
    {
      resolveCaller: async () =>
        new Response(
          JSON.stringify({
            error: "forbidden",
            message: "Only admin or developer can generate AI drafts.",
          }),
          {
            status: 403,
            headers: { "Content-Type": "application/json" },
          },
        ),
    },
  );

  assertEquals(response.status, 403);
  const payload = await response.json();
  assertEquals(payload.error, "forbidden");
});

Deno.test("unsupported openrouter model returns 400", async () => {
  const response = await handleRequest(
    requestWithBody({
      ...validBody,
      provider: "openrouter",
      model: "unsupported/model:free",
    }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
    },
  );

  assertEquals(response.status, 400);
  const payload = await response.json();
  assertEquals(payload.error, "invalid_request");
});

Deno.test("legacy gemini model alias is normalized to gemini 2.5 flash", async () => {
  const response = await handleRequest(
    requestWithBody({
      ...validBody,
      provider: "gemini",
      model: "gemini-2.0-flash",
    }),
    {
      now: () => new Date("2026-03-13T10:00:00.000Z"),
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      generateDraft: async (request) => ({
        provider: "gemini",
        model: request.model,
        content: {
          title: "Journey to Mars",
          level: "B1",
          category: "science",
          tags_raw: "space, mars",
          sentences: [
            {
              idx: 1,
              sentence_en: "Astronauts train for long missions.",
              sentence_tr: "Astronotlar uzun gorevler icin egitim alir.",
            },
          ],
          suggested_linked_words: [],
          questions: [
            {
              sort_order: 1,
              question: "What do astronauts train for?",
              options: ["Long missions", "Short walks"],
              correct_option_index: 0,
              explanation: null,
            },
          ],
        },
      }),
    },
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.generation_meta.model, "gemini-2.5-flash");
});

Deno.test("invalid provider response returns controlled 422", async () => {
  const response = await handleRequest(
    requestWithBody({
      ...validBody,
      provider: "openrouter",
      model: "qwen/qwen3-coder:free",
    }),
    {
      resolveCaller: async () => ({ role: "developer", userId: "dev-1" }),
      generateDraft: async () => ({
        provider: "openrouter",
        model: "qwen/qwen3-coder:free",
        content: {
          title: "",
          level: "B1",
          category: "science",
          tags_raw: "weather",
          sentences: [],
          suggested_linked_words: [],
          questions: [],
        },
      }),
    },
  );

  assertEquals(response.status, 422);
  const payload = await response.json();
  assertEquals(payload.error, "invalid_ai_response");
  assertMatch(payload.message, /title|sentence|question/i);
});

Deno.test("quota style provider error returns 429", async () => {
  const response = await handleRequest(
    requestWithBody({
      ...validBody,
      provider: "openrouter",
      model: "stepfun/step-3.5-flash:free",
    }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      generateDraft: async () => {
        throw new Error("credits exhausted for this request");
      },
    },
  );

  assertEquals(response.status, 429);
  const payload = await response.json();
  assertEquals(payload.error, "rate_limited");
});

Deno.test("prompt infers category and tags instead of reading them from request", () => {
  const prompt = buildPrompt({
    provider: "gemini",
    model: "gemini-2.5-flash",
    topic: "Space travel",
    cefr_level: "B1",
    target_word_count: 120,
    focus_word_count: 5,
    question_count: 3,
  });

  assertMatch(prompt, /Infer a short category/i);
  assertMatch(prompt, /Infer a concise comma-separated tags_raw/i);
  assertEquals(prompt.includes("Category:"), false);
  assertEquals(prompt.includes("Tags raw:"), false);
});

Deno.test("gemini draft request uses x-goog-api-key header", async () => {
  let requestUrl = "";
  let requestApiKeyHeader = "";

  const response = await handleRequest(
    requestWithBody(validBody),
    {
      env: (name) => {
        if (name === "GEMINI_API_KEY") {
          return "gemini-key";
        }
        if (name === "SUPABASE_URL") {
          return "https://example.supabase.co";
        }
        if (name === "SUPABASE_ANON_KEY") {
          return "anon-key";
        }
        return undefined;
      },
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchFn: async (input, init) => {
        const requestInit = init as globalThis.RequestInit | undefined;
        requestUrl = String(input);
        requestApiKeyHeader = String(
          (requestInit?.headers as Record<string, string> | undefined)
              ?.["x-goog-api-key"] ?? "",
        );
        return new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text:
                        "{\"title\":\"Journey to Mars\",\"level\":\"B1\",\"category\":\"science\",\"tags_raw\":\"space, mars\",\"sentences\":[{\"idx\":1,\"sentence_en\":\"Astronauts train for long missions.\",\"sentence_tr\":\"Astronotlar uzun gorevler icin egitim alir.\"}],\"suggested_linked_words\":[],\"questions\":[{\"sort_order\":1,\"question\":\"What do astronauts train for?\",\"options\":[\"Long missions\",\"Short walks\"],\"correct_option_index\":0,\"explanation\":null}]}",
                    },
                  ],
                },
              },
            ],
          }),
          {
            status: 200,
            headers: { "Content-Type": "application/json" },
          },
        );
      },
    },
  );

  assertEquals(response.status, 200);
  assertEquals(
    requestUrl,
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
  );
  assertEquals(requestUrl.includes("?key="), false);
  assertEquals(requestApiKeyHeader, "gemini-key");
});


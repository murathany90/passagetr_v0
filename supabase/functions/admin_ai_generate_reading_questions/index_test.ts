import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { buildQuestionsPrompt, handleRequest } from "./index.ts";

function requestWithBody(body: Record<string, unknown>): Request {
  return new Request("http://localhost/admin_ai_generate_reading_questions", {
    method: "POST",
    headers: {
      Authorization: "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

Deno.test("buildQuestionsPrompt includes source reading fields", () => {
  const prompt = buildQuestionsPrompt(
    {
      reading_id: "reading-1",
      provider: "gemini",
      model: "gemini-2.5-flash",
      question_count: 3,
    },
    {
      id: "reading-1",
      title: "Ocean Science",
      level: "B1",
      category: "science",
      tags_raw: "ocean, waves",
      sentences: [
        { idx: 1, sentence_en: "Waves carry energy across the sea." },
      ],
    },
  );

  assertMatch(prompt, /Ocean Science/);
  assertMatch(prompt, /Question count: 3/);
  assertMatch(prompt, /Waves carry energy across the sea\./);
});

Deno.test("question generator returns validated payload", async () => {
  const response = await handleRequest(
    requestWithBody({
      reading_id: "reading-1",
      provider: "openrouter",
      model: "qwen/qwen3-coder:free",
      question_count: 2,
    }),
    {
      now: () => new Date("2026-03-14T11:00:00.000Z"),
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => ({
        id: "reading-1",
        title: "Ocean Science",
        level: "B1",
        category: "science",
        tags_raw: "ocean, waves",
        sentences: [
          {
            idx: 1,
            sentence_en: "Waves carry energy across the sea.",
          },
        ],
      }),
      generateQuestions: async () => ({
        provider: "openrouter",
        model: "qwen/qwen3-coder:free",
        questions: [
          {
            sort_order: 1,
            question: "What do waves carry?",
            options: ["Energy", "Wood"],
            correct_option_index: 0,
            explanation: "The passage says waves carry energy.",
          },
        ],
      }),
    },
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.provider, "openrouter");
  assertEquals(payload.model, "qwen/qwen3-coder:free");
  assertEquals(payload.questions.length, 1);
});

Deno.test("unsupported model returns 400", async () => {
  const response = await handleRequest(
    requestWithBody({
      reading_id: "reading-1",
      provider: "openrouter",
      model: "unsupported/model",
      question_count: 2,
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
      reading_id: "reading-1",
      provider: "gemini",
      model: "gemini-2.0-flash",
      question_count: 2,
    }),
    {
      now: () => new Date("2026-03-14T11:00:00.000Z"),
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => ({
        id: "reading-1",
        title: "Ocean Science",
        level: "B1",
        category: "science",
        tags_raw: "ocean, waves",
        sentences: [
          {
            idx: 1,
            sentence_en: "Waves carry energy across the sea.",
          },
        ],
      }),
      generateQuestions: async (request) => ({
        provider: "gemini",
        model: request.model,
        questions: [
          {
            sort_order: 1,
            question: "What do waves carry?",
            options: ["Energy", "Wood"],
            correct_option_index: 0,
            explanation: "The passage says waves carry energy.",
          },
        ],
      }),
    },
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.model, "gemini-2.5-flash");
});

Deno.test("gemini questions request uses x-goog-api-key header", async () => {
  let requestUrl = "";
  let requestApiKeyHeader = "";

  const response = await handleRequest(
    requestWithBody({
      reading_id: "reading-1",
      provider: "gemini",
      question_count: 2,
    }),
    {
      env: (name) => {
        if (name === "GEMINI_API_KEY") {
          return "gemini-key";
        }
        return undefined;
      },
      now: () => new Date("2026-03-14T11:00:00.000Z"),
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => ({
        id: "reading-1",
        title: "Ocean Science",
        level: "B1",
        category: "science",
        tags_raw: "ocean, waves",
        sentences: [
          {
            idx: 1,
            sentence_en: "Waves carry energy across the sea.",
          },
        ],
      }),
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
                        "{\"questions\":[{\"sort_order\":1,\"question\":\"What do waves carry?\",\"options\":[\"Energy\",\"Wood\"],\"correct_option_index\":0,\"explanation\":\"The passage says waves carry energy.\"}]}",
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


import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { handleRequest } from "./index.ts";

function requestWithBody(body: Record<string, unknown>): Request {
  return new Request("http://localhost/admin_ai_generate_reading_cover", {
    method: "POST",
    headers: {
      Authorization: "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

Deno.test("cover generator returns persisted detail payload", async () => {
  const response = await handleRequest(
    requestWithBody({ reading_id: "reading-1" }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => ({
        id: "reading-1",
        title: "Ocean Science",
        category: "science",
        tags_raw: "ocean, waves",
        sentences: [{ idx: 1, sentence_en: "Waves carry energy across the sea." }],
      }),
      generateCover: async () => ({
        bytes: new Uint8Array([1, 2, 3]),
        mimeType: "image/png",
        provider: "openai_images",
        model: "gpt-image-1.5",
        style: "editorial illustration",
        prompt: "Prompt text",
      }),
      persistCover: async () => ({
        id: "reading-1",
        title: "Ocean Science",
        sentences: [{ idx: 1, sentence_en: "Waves carry energy across the sea." }],
        cover_media_asset_id: "asset-1",
        cover_bucket_name: "reading-covers",
        cover_storage_path: "readings/reading-1/asset-1.png",
        cover_alt_text: "Ocean Science cover",
      }),
    },
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  assertEquals(payload.cover_bucket_name, "reading-covers");
  assertEquals(payload.cover_storage_path, "readings/reading-1/asset-1.png");
});

Deno.test("default cover generator prefers Gemini image output", async () => {
  let seenProvider = "";
  let seenModel = "";
  let requestUrl = "";
  let requestApiKeyHeader = "";
  let requestBody = "";

  const response = await handleRequest(
    requestWithBody({ reading_id: "reading-1" }),
    {
      env: (name) => {
        switch (name) {
          case "GEMINI_API_KEY":
            return "gemini-key";
          default:
            return undefined;
        }
      },
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => ({
        id: "reading-1",
        title: "Ocean Science",
        category: "science",
        tags_raw: "ocean, waves",
        sentences: [{ idx: 1, sentence_en: "Waves carry energy across the sea." }],
      }),
      fetchFn: async (input, init) => {
        const requestInit = init as globalThis.RequestInit | undefined;
        requestUrl = String(input);
        requestApiKeyHeader = String(
          (requestInit?.headers as Record<string, string> | undefined)
              ?.["x-goog-api-key"] ??
            "",
        );
        requestBody = String(requestInit?.body ?? "");
        return new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      inlineData: {
                        mimeType: "image/png",
                        data: btoa("png-bytes"),
                      },
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
      persistCover: async (_detail, cover) => {
        seenProvider = cover.provider;
        seenModel = cover.model;
        return {
          id: "reading-1",
          title: "Ocean Science",
          sentences: [{ idx: 1, sentence_en: "Waves carry energy across the sea." }],
          cover_media_asset_id: "asset-1",
          cover_bucket_name: "reading-covers",
          cover_storage_path: "readings/reading-1/asset-1.png",
          cover_alt_text: "Ocean Science cover",
        };
      },
    },
  );

  assertEquals(response.status, 200);
  assertEquals(seenProvider, "gemini_image");
  assertEquals(seenModel, "gemini-2.5-flash-image");
  assertEquals(
    requestUrl.includes("generativelanguage.googleapis.com"),
    true,
  );
  assertEquals(requestUrl.includes("?key="), false);
  assertEquals(requestApiKeyHeader, "gemini-key");
  assertEquals(requestBody.includes("responseModalities"), false);
});

Deno.test("cover generator respects explicit OpenAI model selection", async () => {
  let seenProvider = "";
  let seenModel = "";
  let requestUrl = "";

  const response = await handleRequest(
    requestWithBody({
      reading_id: "reading-1",
      provider: "openai_images",
      model: "gpt-image-1.5",
    }),
    {
      env: (name) => {
        switch (name) {
          case "OPENAI_API_KEY":
            return "openai-key";
          default:
            return undefined;
        }
      },
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => ({
        id: "reading-1",
        title: "Ocean Science",
        category: "science",
        tags_raw: "ocean, waves",
        sentences: [{ idx: 1, sentence_en: "Waves carry energy across the sea." }],
      }),
      fetchFn: async (input) => {
        requestUrl = String(input);
        return new Response(
          JSON.stringify({
            data: [
              {
                b64_json: btoa("png-bytes"),
              },
            ],
          }),
          {
            status: 200,
            headers: { "Content-Type": "application/json" },
          },
        );
      },
      persistCover: async (_detail, cover) => {
        seenProvider = cover.provider;
        seenModel = cover.model;
        return {
          id: "reading-1",
          title: "Ocean Science",
          sentences: [{ idx: 1, sentence_en: "Waves carry energy across the sea." }],
          cover_media_asset_id: "asset-1",
          cover_bucket_name: "reading-covers",
          cover_storage_path: "readings/reading-1/asset-1.png",
          cover_alt_text: "Ocean Science cover",
        };
      },
    },
  );

  assertEquals(response.status, 200);
  assertEquals(seenProvider, "openai_images");
  assertEquals(seenModel, "gpt-image-1.5");
  assertEquals(requestUrl, "https://api.openai.com/v1/images/generations");
});

Deno.test("empty reading body returns invalid request", async () => {
  const response = await handleRequest(
    requestWithBody({}),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
    },
  );

  assertEquals(response.status, 400);
  const payload = await response.json();
  assertEquals(payload.error, "invalid_request");
});

Deno.test("quota error is mapped to 429", async () => {
  const response = await handleRequest(
    requestWithBody({ reading_id: "reading-1" }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => ({
        id: "reading-1",
        title: "Ocean Science",
        category: "science",
        tags_raw: "ocean, waves",
        sentences: [{ idx: 1, sentence_en: "Waves carry energy across the sea." }],
      }),
      generateCover: async () => {
        throw new Error("insufficient_quota");
      },
    },
  );

  assertEquals(response.status, 429);
  const payload = await response.json();
  assertEquals(payload.error, "rate_limited");
});

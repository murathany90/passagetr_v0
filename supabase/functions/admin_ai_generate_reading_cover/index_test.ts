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

const readingDetail = {
  id: "reading-1",
  title: "Ocean Science",
  category: "science",
  tags_raw: "ocean, waves",
  sentences: [{ idx: 1, sentence_en: "Waves carry energy across the sea." }],
};

Deno.test("cover generator returns persisted detail payload", async () => {
  const response = await handleRequest(
    requestWithBody({
      reading_id: "reading-1",
      provider: "imagerouter",
      model: "google/nano-banana-2:free",
    }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => readingDetail,
      reserveAttempt: async () => ({ allowed: true }),
      markAttemptResult: async () => undefined,
      generateImageRouter: async () => ({
        bytes: new Uint8Array([1, 2, 3]),
        mimeType: "image/png",
        provider: "imagerouter",
        model: "google/nano-banana-2:free",
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

Deno.test("default ImageRouter request downloads URL response", async () => {
  const seenUrls: string[] = [];
  let seenAuthHeader = "";
  let seenBody = "";
  let seenProvider = "";
  let seenModel = "";

  const response = await handleRequest(
    requestWithBody({
      reading_id: "reading-1",
      provider: "imagerouter",
      model: "google/nano-banana-2:free",
    }),
    {
      env: (name) => {
        if (name === "IMAGEROUTER_API_KEY") {
          return "ir-key";
        }
        return undefined;
      },
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => readingDetail,
      reserveAttempt: async () => ({ allowed: true }),
      markAttemptResult: async () => undefined,
      fetchFn: async (input, init) => {
        const url = String(input);
        seenUrls.push(url);
        if (url.includes("/v1/openai/images/generations")) {
          const requestInit = init as globalThis.RequestInit | undefined;
          seenAuthHeader = String(
            (requestInit?.headers as Record<string, string> | undefined)
              ?.Authorization ?? "",
          );
          seenBody = String(requestInit?.body ?? "");
          return new Response(
            JSON.stringify({
              data: [{ url: "https://cdn.imagerouter.io/generated/test.png" }],
            }),
            {
              status: 200,
              headers: { "Content-Type": "application/json" },
            },
          );
        }
        return new Response(new Uint8Array([1, 2, 3]), {
          status: 200,
          headers: { "Content-Type": "image/png" },
        });
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
  assertEquals(seenProvider, "imagerouter");
  assertEquals(seenModel, "google/nano-banana-2:free");
  assertEquals(seenUrls[0], "https://api.imagerouter.io/v1/openai/images/generations");
  assertEquals(seenUrls[1], "https://cdn.imagerouter.io/generated/test.png");
  assertEquals(seenAuthHeader, "Bearer ir-key");
  assertEquals(seenBody.includes('"model":"google/nano-banana-2:free"'), true);
});

Deno.test("default Hugging Face request retries one 503 and then succeeds", async () => {
  const marked: string[] = [];
  let callCount = 0;

  const response = await handleRequest(
    requestWithBody({
      reading_id: "reading-1",
      provider: "huggingface",
      model: "stabilityai/stable-diffusion-xl-base-1.0",
    }),
    {
      env: (name) => {
        if (name === "HUGGINGFACE_API_TOKEN") {
          return "hf-token";
        }
        return undefined;
      },
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => readingDetail,
      reserveAttempt: async () => ({ allowed: true }),
      markAttemptResult: async (_provider, _model, result) => {
        marked.push(result);
      },
      sleep: async () => undefined,
      fetchFn: async (input) => {
        callCount += 1;
        const url = String(input);
        assertEquals(
          url,
          "https://router.huggingface.co/hf-inference/models/stabilityai/stable-diffusion-xl-base-1.0",
        );
        if (callCount == 1) {
          return new Response(
            JSON.stringify({ error: "Model is loading" }),
            {
              status: 503,
              headers: { "Content-Type": "application/json" },
            },
          );
        }
        return new Response(new Uint8Array([7, 8, 9]), {
          status: 200,
          headers: { "Content-Type": "image/png" },
        });
      },
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
  assertEquals(callCount, 2);
  assertEquals(marked, ["rate_limited", "success"]);
});

Deno.test("auto mode falls back from ImageRouter rate limit to Hugging Face", async () => {
  const attemptLog: string[] = [];
  const marked: string[] = [];
  let persistedProvider = "";

  const response = await handleRequest(
    requestWithBody({ reading_id: "reading-1" }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => readingDetail,
      fetchCoverPoolStatus: async () => ({
        usage_date_utc: "2026-03-15",
        local_caps_enabled: true,
        models: [
          {
            provider: "imagerouter",
            model: "google/nano-banana-2:free",
            enabled: true,
            priority: 1,
          },
          {
            provider: "huggingface",
            model: "stabilityai/stable-diffusion-xl-base-1.0",
            enabled: true,
            priority: 2,
          },
        ],
      }),
      reserveAttempt: async (provider, model) => {
        attemptLog.push(`reserve:${provider}:${model}`);
        return { allowed: true };
      },
      markAttemptResult: async (_provider, _model, result) => {
        marked.push(result);
      },
      generateImageRouter: async () => {
        throw new Error("429 Too Many Requests");
      },
      generateHuggingFace: async () => ({
        bytes: new Uint8Array([3, 2, 1]),
        mimeType: "image/png",
        provider: "huggingface",
        model: "stabilityai/stable-diffusion-xl-base-1.0",
        style: "editorial illustration",
        prompt: "Prompt text",
      }),
      persistCover: async (_detail, cover) => {
        persistedProvider = cover.provider;
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
  assertEquals(attemptLog, [
    "reserve:imagerouter:google/nano-banana-2:free",
    "reserve:huggingface:stabilityai/stable-diffusion-xl-base-1.0",
  ]);
  assertEquals(marked, ["rate_limited", "success"]);
  assertEquals(persistedProvider, "huggingface");
});

Deno.test("auto mode skips ImageRouter provider on auth failure and falls back to Hugging Face", async () => {
  const attemptLog: string[] = [];
  let huggingFaceCalled = false;

  const response = await handleRequest(
    requestWithBody({ reading_id: "reading-1" }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => readingDetail,
      fetchCoverPoolStatus: async () => ({
        usage_date_utc: "2026-03-15",
        local_caps_enabled: true,
        models: [
          {
            provider: "imagerouter",
            model: "google/nano-banana-2:free",
            enabled: true,
            priority: 1,
          },
          {
            provider: "imagerouter",
            model: "z-image/turbo:free",
            enabled: true,
            priority: 2,
          },
          {
            provider: "huggingface",
            model: "stabilityai/stable-diffusion-xl-base-1.0",
            enabled: true,
            priority: 3,
          },
        ],
      }),
      reserveAttempt: async (provider, model) => {
        attemptLog.push(`reserve:${provider}:${model}`);
        return { allowed: true };
      },
      markAttemptResult: async () => undefined,
      generateImageRouter: async () => {
        throw new Error("401 Unauthorized");
      },
      generateHuggingFace: async () => {
        huggingFaceCalled = true;
        return {
          bytes: new Uint8Array([1]),
          mimeType: "image/png",
          provider: "huggingface",
          model: "stabilityai/stable-diffusion-xl-base-1.0",
          style: "editorial illustration",
          prompt: "Prompt text",
        };
      },
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
  assertEquals(attemptLog, [
    "reserve:imagerouter:google/nano-banana-2:free",
    "reserve:huggingface:stabilityai/stable-diffusion-xl-base-1.0",
  ]);
  assertEquals(huggingFaceCalled, true);
});

Deno.test("auto mode reports clear error when both provider layers fail auth", async () => {
  const response = await handleRequest(
    requestWithBody({ reading_id: "reading-1" }),
    {
      resolveCaller: async () => ({ role: "admin", userId: "admin-1" }),
      fetchReadingDetail: async () => readingDetail,
      fetchCoverPoolStatus: async () => ({
        usage_date_utc: "2026-03-15",
        local_caps_enabled: true,
        models: [
          {
            provider: "imagerouter",
            model: "google/nano-banana-2:free",
            enabled: true,
            priority: 1,
          },
          {
            provider: "huggingface",
            model: "stabilityai/stable-diffusion-xl-base-1.0",
            enabled: true,
            priority: 2,
          },
        ],
      }),
      reserveAttempt: async () => ({ allowed: true }),
      markAttemptResult: async () => undefined,
      generateImageRouter: async () => {
        throw new Error("401 Unauthorized");
      },
      generateHuggingFace: async () => {
        throw new Error("403 Forbidden");
      },
    },
  );

  assertEquals(response.status, 422);
  const payload = await response.json();
  assertEquals(payload.error, "invalid_ai_response");
  assertEquals(
    String(payload.message).includes("ImageRouter ve Hugging Face"),
    true,
  );
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

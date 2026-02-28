import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function json(status: number, payload: Record<string, unknown>): Response {
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

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const deeplAuthKey = Deno.env.get("DEEPL_AUTH_KEY")?.trim() ?? "";
  if (deeplAuthKey.length === 0) {
    return json(500, {
      error: "server_not_configured",
      message: "DEEPL_AUTH_KEY secret is missing.",
    });
  }

  const deeplEndpoint = (Deno.env.get("DEEPL_API_URL")?.trim() ||
    "https://api-free.deepl.com/v2/translate");

  try {
    const body = await req.json();
    const text = String(body?.text ?? "").trim();
    const source = String(body?.source ?? "EN").trim().toUpperCase();
    const target = String(body?.target ?? "TR").trim().toUpperCase();

    if (text.length === 0) {
      return json(400, {
        error: "invalid_input",
        message: "text is required",
      });
    }

    const payload = new URLSearchParams();
    payload.append("text", text);
    payload.append("source_lang", source);
    payload.append("target_lang", target);

    const deeplResponse = await fetch(deeplEndpoint, {
      method: "POST",
      headers: {
        "Authorization": `DeepL-Auth-Key ${deeplAuthKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: payload.toString(),
    });

    const rawText = await deeplResponse.text();
    if (!deeplResponse.ok) {
      return json(deeplResponse.status, {
        error: "deepl_error",
        status: deeplResponse.status,
        message: shortErrorText(rawText),
      });
    }

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(rawText) as Record<string, unknown>;
    } catch (_) {
      return json(502, {
        error: "invalid_deepl_response",
        message: "DeepL response is not valid JSON.",
      });
    }

    const translations = parsed["translations"];
    if (!Array.isArray(translations) || translations.length === 0) {
      return json(502, {
        error: "invalid_deepl_response",
        message: "DeepL translations array is missing.",
      });
    }

    const first = translations[0] as Record<string, unknown>;
    const translatedText = String(first?.text ?? "").trim();
    if (translatedText.length === 0) {
      return json(502, {
        error: "invalid_deepl_response",
        message: "Translated text is empty.",
      });
    }

    return json(200, { translatedText });
  } catch (error) {
    return json(500, {
      error: "internal_error",
      message: shortErrorText(String(error)),
    });
  }
});

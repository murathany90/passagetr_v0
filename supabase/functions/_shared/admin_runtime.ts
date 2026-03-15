import { createClient } from "npm:@supabase/supabase-js@2";

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

export type EnvGetter = (name: string) => string | undefined;

export interface AdminCaller {
  role: string;
  userId: string;
}

export function json(status: number, payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: corsHeaders,
  });
}

export function shortErrorText(text: string): string {
  const cleaned = text.replaceAll(/\s+/g, " ").trim();
  if (cleaned.length <= 240) {
    return cleaned;
  }
  return `${cleaned.slice(0, 240)}...`;
}

export function requireSupabaseEnv(
  env: EnvGetter,
): { supabaseUrl: string; supabaseAnonKey: string } | Response {
  const supabaseUrl = env("SUPABASE_URL")?.trim() ?? "";
  const supabaseAnonKey = env("SUPABASE_ANON_KEY")?.trim() ?? "";
  if (!supabaseUrl || !supabaseAnonKey) {
    return json(500, {
      error: "server_not_configured",
      message: "Supabase environment variables are missing.",
    });
  }
  return { supabaseUrl, supabaseAnonKey };
}

export function createCallerClient(
  authHeader: string,
  env: EnvGetter,
): ReturnType<typeof createClient> | Response {
  const config = requireSupabaseEnv(env);
  if (config instanceof Response) {
    return config;
  }

  return createClient(config.supabaseUrl, config.supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
}

export async function resolveAdminCaller(
  _req: Request,
  authHeader: string,
  env: EnvGetter,
): Promise<AdminCaller | Response> {
  const callerClient = createCallerClient(authHeader, env);
  if (callerClient instanceof Response) {
    return callerClient;
  }

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
      message: "Only admin or developer can perform this action.",
    });
  }

  return { role, userId: userData.user.id };
}

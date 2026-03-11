import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

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

async function writeAuditLog(
  serviceClient: ReturnType<typeof createClient>,
  payload: {
    actorUserId: string;
    action: string;
    targetId?: string | null;
    details: Record<string, unknown>;
  },
): Promise<void> {
  const { error } = await serviceClient.from("audit_logs").insert({
    actor_user_id: payload.actorUserId,
    action: payload.action,
    target_type: "invite",
    target_id: payload.targetId ?? null,
    payload_json: payload.details,
  });

  if (error) {
    console.error("audit_log_insert_failed", error);
  }
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    ?.trim() ?? "";
  const authHeader = req.headers.get("Authorization")?.trim() ?? "";
  const adminConsoleUrl = Deno.env.get("ADMIN_CONSOLE_URL")?.trim() ?? "";

  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return json(500, {
      error: "server_not_configured",
      message: "Supabase environment variables are missing.",
    });
  }

  if (!authHeader) {
    return json(401, {
      error: "missing_authorization",
      message: "Authorization header is required.",
    });
  }

  const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false },
  });

  try {
    const [{ data: roleData, error: roleError }, { data: userData, error: userError }] =
      await Promise.all([
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

    const callerRole = String(roleData ?? "").trim().toLowerCase();
    if (!["admin", "developer"].includes(callerRole)) {
      return json(403, {
        error: "forbidden",
        message: "Only admin or developer can invite users.",
      });
    }

    const body = await req.json();
    const invites = Array.isArray(body?.invites) ? body.invites : [];
    if (invites.length === 0) {
      return json(400, {
        error: "invalid_input",
        message: "At least one invite payload is required.",
      });
    }

    const results: Array<Record<string, unknown>> = [];

    for (const rawInvite of invites) {
      const email = String(rawInvite?.email ?? "").trim().toLowerCase();
      const role = String(rawInvite?.role ?? "user").trim().toLowerCase();
      const plan = String(rawInvite?.plan ?? "free").trim().toLowerCase();
      const retryCount = Math.max(0, Number(rawInvite?.retry_count ?? 0) || 0);
      const inviteExpiryHours = Math.max(
        1,
        Number(rawInvite?.invite_expiry_hours ?? 48) || 48,
      );

      if (!email) {
        results.push({
          accepted: false,
          email,
          role,
          plan,
          retry_count: retryCount,
          error_code: "invalid_input",
          error_message: "Invite email is required.",
        });
        continue;
      }

      try {
        const { data: inviteData, error: inviteError } =
          await serviceClient.auth.admin.inviteUserByEmail(
            email,
            {
              redirectTo: adminConsoleUrl || undefined,
              data: {
                invited_by: userData.user.id,
                requested_role: role,
                requested_plan: plan,
                invite_expiry_hours: inviteExpiryHours,
              },
            },
          );

        if (inviteError) {
          throw inviteError;
        }

        const invitedUserId = inviteData.user?.id;
        if (!invitedUserId) {
          throw new Error(`invite failed for ${email}`);
        }

        const { error: accessError } = await serviceClient.rpc(
          "admin_assign_invited_user_access",
          {
            p_user_id: invitedUserId,
            p_role: role,
            p_plan: plan,
            p_actor_user_id: userData.user.id,
          },
        );
        if (accessError) {
          throw accessError;
        }

        const acceptedResult = {
          accepted: true,
          email,
          role,
          plan,
          invited_user_id: invitedUserId,
          retry_count: retryCount,
        };
        results.push(acceptedResult);
        await writeAuditLog(serviceClient, {
          actorUserId: userData.user.id,
          action: "admin.user_invite.accepted",
          targetId: invitedUserId,
          details: {
            email,
            role,
            plan,
            retry_count: retryCount,
            invite_expiry_hours: inviteExpiryHours,
            queued_via: "supabase_native",
          },
        });
      } catch (error) {
        const errorMessage = shortErrorText(String(error));
        results.push({
          accepted: false,
          email,
          role,
          plan,
          retry_count: retryCount,
          error_code: "invite_failed",
          error_message: errorMessage,
        });
        await writeAuditLog(serviceClient, {
          actorUserId: userData.user.id,
          action: "admin.user_invite.rejected",
          details: {
            email,
            role,
            plan,
            retry_count: retryCount,
            invite_expiry_hours: inviteExpiryHours,
            error_message: errorMessage,
            queued_via: "supabase_native",
          },
        });
      }
    }

    return json(200, { results });
  } catch (error) {
    return json(500, {
      error: "internal_error",
      message: shortErrorText(String(error)),
    });
  }
});

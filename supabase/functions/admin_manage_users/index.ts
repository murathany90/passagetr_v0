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
  serviceClient: any,
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
    target_type: "profiles",
    target_id: payload.targetId ?? null,
    payload_json: payload.details,
  });

  if (error) {
    console.error("audit_log_insert_failed", error);
  }
}

async function resolveUserSummary(
  serviceClient: any,
  userId: string,
): Promise<Record<string, unknown>> {
  const [
    { data: authUserData, error: authUserError },
    { data: profileData, error: profileError },
    { data: roleRows, error: roleError },
    { data: planRows, error: planError },
  ] = await Promise.all([
    serviceClient.auth.admin.getUserById(userId),
    serviceClient.from("profiles").select("display_name,updated_at").eq(
      "user_id",
      userId,
    ).maybeSingle(),
    serviceClient.from("user_roles").select("role").eq("user_id", userId).is(
      "revoked_at",
      null,
    ),
    serviceClient.from("entitlements").select("plan,starts_at").eq(
      "user_id",
      userId,
    ).is("revoked_at", null).order("starts_at", { ascending: false }).limit(1),
  ]);

  if (authUserError) {
    throw authUserError;
  }
  if (profileError) {
    throw profileError;
  }
  if (roleError) {
    throw roleError;
  }
  if (planError) {
    throw planError;
  }

  const activeRoles = Array.isArray(roleRows)
    ? roleRows.map((row) => String(row.role ?? "").trim().toLowerCase())
    : [];
  const appRole = activeRoles.includes("developer")
    ? "developer"
    : activeRoles.includes("admin")
    ? "admin"
    : "user";
  const plan = Array.isArray(planRows) && planRows.length > 0
    ? String(planRows[0]?.plan ?? "free").trim().toLowerCase()
    : "free";
  const user = authUserData.user;

  return {
    user_id: userId,
    email: user?.email ?? "",
    display_name:
      profileData?.display_name ??
      user?.user_metadata?.display_name ??
      "",
    app_role: appRole,
    plan,
    status_label: appRole === "user" ? "active" : "staff",
    last_seen_at: user?.last_sign_in_at ?? null,
    updated_at: profileData?.updated_at ?? user?.updated_at ?? null,
  };
}

type BulkDeleteItemResult = {
  user_id: string;
  status: "deleted" | "skipped" | "failed";
  message?: string;
};

type BulkDeleteDeps = {
  callerRole: string;
  callerUserId: string;
  resolveSummary: (userId: string) => Promise<Record<string, unknown>>;
  deleteUserById: (userId: string) => Promise<string | null>;
  writeAudit: (payload: {
    actorUserId: string;
    action: string;
    targetId?: string | null;
    details: Record<string, unknown>;
  }) => Promise<void>;
};

async function performDeleteUser(
  userId: string,
  deps: BulkDeleteDeps,
): Promise<{
  result: BulkDeleteItemResult;
  summary?: Record<string, unknown>;
}> {
  if (userId === deps.callerUserId) {
    return {
      result: {
        user_id: userId,
        status: "skipped",
        message: "You cannot delete the active admin session.",
      },
    };
  }

  try {
    const currentSummary = await deps.resolveSummary(userId);
    const currentRole = String(currentSummary.app_role ?? "user");
    if (currentRole === "developer" && deps.callerRole !== "developer") {
      return {
        result: {
          user_id: userId,
          status: "skipped",
          message: "Only developer can delete a developer account.",
        },
      };
    }

    const deleteErrorMessage = await deps.deleteUserById(userId);
    if (deleteErrorMessage) {
      return {
        result: {
          user_id: userId,
          status: "failed",
          message: deleteErrorMessage,
        },
      };
    }

    await deps.writeAudit({
      actorUserId: deps.callerUserId,
      action: "admin.user.deleted",
      targetId: userId,
      details: currentSummary as Record<string, unknown>,
    });
    return {
      result: { user_id: userId, status: "deleted" },
      summary: currentSummary,
    };
  } catch (error) {
    return {
      result: {
        user_id: userId,
        status: "failed",
        message: shortErrorText(String(error)),
      },
    };
  }
}

export async function deleteManyUsers(
  userIds: string[],
  deps: BulkDeleteDeps,
): Promise<{
  requested_count: number;
  deleted_count: number;
  skipped_count: number;
  failed_count: number;
  results: BulkDeleteItemResult[];
}> {
  const results: BulkDeleteItemResult[] = [];
  let deletedCount = 0;
  let skippedCount = 0;
  let failedCount = 0;

  for (const userId of userIds) {
    const outcome = await performDeleteUser(userId, deps);
    results.push(outcome.result);
    if (outcome.result.status === "deleted") {
      deletedCount += 1;
    } else if (outcome.result.status === "skipped") {
      skippedCount += 1;
    } else {
      failedCount += 1;
    }
  }

  await deps.writeAudit({
    actorUserId: deps.callerUserId,
    action: "admin.user.bulk_deleted",
    details: {
      requested_count: userIds.length,
      deleted_count: deletedCount,
      skipped_count: skippedCount,
      failed_count: failedCount,
    },
  });

  return {
    requested_count: userIds.length,
    deleted_count: deletedCount,
    skipped_count: skippedCount,
    failed_count: failedCount,
    results,
  };
}

export async function handleRequest(req: Request): Promise<Response> {
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
        message: "Only admin or developer can manage users.",
      });
    }

    const body = await req.json();
    const action = String(body?.action ?? "").trim().toLowerCase();
    const userId = String(body?.user_id ?? "").trim();

    if ((action === "update" || action === "delete") && !userId) {
      return json(400, {
        error: "invalid_input",
        message: "user_id is required.",
      });
    }

    if (action === "update") {
      const email = String(body?.email ?? "").trim().toLowerCase();
      const displayName = String(body?.display_name ?? "").trim();
      const nextRole = String(body?.role ?? "user").trim().toLowerCase();
      const nextPlan = String(body?.plan ?? "free").trim().toLowerCase();

      if (!email) {
        return json(400, {
          error: "invalid_input",
          message: "email is required.",
        });
      }

      const currentSummary = await resolveUserSummary(serviceClient, userId);
      const currentRole = String(currentSummary.app_role ?? "user");

      if (currentRole === "developer" && callerRole !== "developer") {
        return json(403, {
          error: "forbidden",
          message: "Only developer can edit a developer account.",
        });
      }
      if (nextRole === "developer" && callerRole !== "developer") {
        return json(403, {
          error: "forbidden",
          message: "Only developer can grant developer role.",
        });
      }

      const { data: targetUserData, error: targetUserError } =
        await serviceClient.auth.admin.getUserById(userId);
      if (targetUserError || !targetUserData.user) {
        return json(404, {
          error: "not_found",
          message: "Target user could not be resolved.",
        });
      }

      const existingMetadata = targetUserData.user.user_metadata ?? {};
      const { error: updateError } = await serviceClient.auth.admin
        .updateUserById(userId, {
          email,
          email_confirm: true,
          user_metadata: {
            ...existingMetadata,
            display_name: displayName,
          },
        });
      if (updateError) {
        return json(400, {
          error: "auth_update_failed",
          message: shortErrorText(String(updateError.message ?? updateError)),
        });
      }

      const { error: profileError } = await serviceClient.from("profiles")
        .upsert({
          user_id: userId,
          display_name: displayName,
          is_anonymous: false,
        }, { onConflict: "user_id" });
      if (profileError) {
        return json(400, {
          error: "profile_update_failed",
          message: shortErrorText(String(profileError.message ?? profileError)),
        });
      }

      const currentPlan = String(currentSummary.plan ?? "free");
      if (currentRole !== nextRole || currentPlan !== nextPlan) {
        const { error: accessError } = await callerClient.rpc(
          "admin_set_user_access",
          {
            p_user_id: userId,
            p_role: nextRole,
            p_plan: nextPlan,
          },
        );
        if (accessError) {
          return json(400, {
            error: "access_update_failed",
            message: shortErrorText(String(accessError.message ?? accessError)),
          });
        }
      }

      const summary = await resolveUserSummary(serviceClient, userId);
      await writeAuditLog(serviceClient, {
        actorUserId: userData.user.id,
        action: "admin.user_profile.updated",
        targetId: userId,
        details: {
          email,
          display_name: displayName,
          role: summary.app_role,
          plan: summary.plan,
        },
      });

      return json(200, { user: summary });
    }

    if (action === "delete") {
      const outcome = await performDeleteUser(userId, {
        callerRole,
        callerUserId: userData.user.id,
        resolveSummary: (targetUserId) =>
          resolveUserSummary(serviceClient, targetUserId),
        deleteUserById: async (targetUserId) => {
          const { error: deleteError } = await serviceClient.auth.admin
            .deleteUser(targetUserId);
          return deleteError
            ? shortErrorText(String(deleteError.message ?? deleteError))
            : null;
        },
        writeAudit: (payload) => writeAuditLog(serviceClient, payload),
      });

      if (outcome.result.status === "skipped") {
        return json(400, {
          error: "invalid_operation",
          message: outcome.result.message ?? "Kullanici silinemedi.",
        });
      }
      if (outcome.result.status === "failed") {
        return json(400, {
          error: "delete_failed",
          message: outcome.result.message ?? "Kullanici silinemedi.",
        });
      }

      return json(200, { deleted: true, user_id: userId });
    }

    if (action === "delete_many") {
      const userIds = Array.isArray(body?.user_ids)
        ? body.user_ids.map((value: unknown) => String(value ?? "").trim())
          .filter((value: string) => value.length > 0)
        : [];

      if (userIds.length === 0) {
        return json(400, {
          error: "invalid_input",
          message: "user_ids must contain at least one user.",
        });
      }

      const result = await deleteManyUsers(userIds, {
        callerRole,
        callerUserId: userData.user.id,
        resolveSummary: (targetUserId) =>
          resolveUserSummary(serviceClient, targetUserId),
        deleteUserById: async (targetUserId) => {
          const { error: deleteError } = await serviceClient.auth.admin
            .deleteUser(targetUserId);
          return deleteError
            ? shortErrorText(String(deleteError.message ?? deleteError))
            : null;
        },
        writeAudit: (payload) => writeAuditLog(serviceClient, payload),
      });

      return json(200, result as Record<string, unknown>);
    }

    return json(400, {
      error: "invalid_action",
      message: "Supported actions are update, delete and delete_many.",
    });
  } catch (error) {
    return json(500, {
      error: "internal_error",
      message: shortErrorText(String(error)),
    });
  }
}

if (import.meta.main) {
  serve((req: Request) => handleRequest(req));
}

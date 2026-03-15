import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import { deleteManyUsers } from "./index.ts";

Deno.test("deleteManyUsers deletes multiple normal users", async () => {
  const deletedUserIds: string[] = [];

  const result = await deleteManyUsers(
    ["user-1", "user-2"],
    {
      callerRole: "admin",
      callerUserId: "admin-1",
      resolveSummary: async (userId) => ({
        user_id: userId,
        app_role: "user",
        email: `${userId}@example.com`,
      }),
      deleteUserById: async (userId) => {
        deletedUserIds.push(userId);
        return null;
      },
      writeAudit: async () => undefined,
    },
  );

  assertEquals(result.requested_count, 2);
  assertEquals(result.deleted_count, 2);
  assertEquals(result.skipped_count, 0);
  assertEquals(result.failed_count, 0);
  assertEquals(deletedUserIds, ["user-1", "user-2"]);
});

Deno.test("deleteManyUsers skips active session user", async () => {
  const result = await deleteManyUsers(
    ["admin-1", "user-2"],
    {
      callerRole: "admin",
      callerUserId: "admin-1",
      resolveSummary: async (userId) => ({
        user_id: userId,
        app_role: "user",
      }),
      deleteUserById: async () => null,
      writeAudit: async () => undefined,
    },
  );

  assertEquals(result.deleted_count, 1);
  assertEquals(result.skipped_count, 1);
  assertEquals(result.results[0].status, "skipped");
});

Deno.test("deleteManyUsers skips developer account for non-developer caller", async () => {
  const result = await deleteManyUsers(
    ["dev-1"],
    {
      callerRole: "admin",
      callerUserId: "admin-1",
      resolveSummary: async () => ({
        user_id: "dev-1",
        app_role: "developer",
      }),
      deleteUserById: async () => null,
      writeAudit: async () => undefined,
    },
  );

  assertEquals(result.deleted_count, 0);
  assertEquals(result.skipped_count, 1);
  assertEquals(
    result.results[0].message,
    "Only developer can delete a developer account.",
  );
});

Deno.test("deleteManyUsers reports failed item when delete op errors", async () => {
  const result = await deleteManyUsers(
    ["user-1", "user-2"],
    {
      callerRole: "developer",
      callerUserId: "dev-admin",
      resolveSummary: async (userId) => ({
        user_id: userId,
        app_role: "user",
      }),
      deleteUserById: async (userId) =>
        userId === "user-2" ? "delete failed" : null,
      writeAudit: async () => undefined,
    },
  );

  assertEquals(result.deleted_count, 1);
  assertEquals(result.failed_count, 1);
  assertEquals(result.results[1].status, "failed");
  assertEquals(result.results[1].message, "delete failed");
});

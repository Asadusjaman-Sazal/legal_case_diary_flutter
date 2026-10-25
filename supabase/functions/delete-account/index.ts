/**
 * delete-account — the one server call that ends an account, avatar included.
 *
 * Why an Edge Function rather than the RPC alone: Supabase requires Storage
 * objects to be deleted through the Storage API; deleting a row from
 * `storage.objects` in SQL leaves the underlying file behind. The database
 * work stays in `delete_my_account()` — this function only adds the Storage
 * removal that the RPC cannot do.
 *
 * Order, and why:
 *   1. verify the caller's JWT (it is the account being deleted);
 *   2. run `delete_my_account()` as that caller, keeping its
 *      `{status, reason}` answer;
 *   3. only on `removed`, remove `{user_id}.jpg` from the
 *      `individual-avatars` bucket with
 *      the service role. A refusal (firm or administrator) touches no file.
 *
 * If the removal fails after the account is gone, the deletion still succeeds —
 * the account must be removable — and the failure is logged. The residue is at
 * most 50 KB and the object is no longer reachable by the deleted account.
 *
 * Deploy with the function's own name; no extra secrets are needed (Supabase
 * supplies SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY).
 */

import { createClient } from "npm:@supabase/supabase-js@2";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json(405, { status: "method_not_allowed" });

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const authorization = req.headers.get("Authorization") ?? "";
  if (!url || !anonKey || !serviceKey) {
    return json(500, { status: "failed", reason: "misconfigured" });
  }
  if (!authorization.startsWith("Bearer ")) {
    return json(401, { status: "unauthenticated" });
  }

  // The caller's own client: every database check runs as the account being
  // deleted, so the RPC can never be aimed at anybody else.
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const {
    data: { user },
    error: authError,
  } = await userClient.auth.getUser();
  if (authError || !user) return json(401, { status: "unauthenticated" });

  const { data, error } = await userClient.rpc("delete_my_account");
  if (error) {
    console.error("delete_my_account failed", error.message);
    return json(500, { status: "failed" });
  }

  const status = (data as { status?: string } | null)?.status;
  if (status !== "removed") {
    // Firm and administrator refusals arrive here; nothing was deleted, so
    // nothing is cleaned up.
    return json(200, data ?? { status: "failed" });
  }

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false },
  });
  const { error: removeError } = await admin.storage
    .from("individual-avatars")
    .remove([`${user.id}.jpg`]);
  if (removeError) {
    console.error("avatar removal failed", removeError.message);
  }

  return json(200, {
    ...(data as Record<string, unknown>),
    avatar_removed: !removeError,
  });
});

/**
 * send-admin-payment-alerts — the admin payment-alert sender.
 *
 * Who calls it: `public.notify_admin_payment_alerts()` in
 * supabase/migrations/20261012120000_admin_payment_alerts.sql, through pg_net,
 * whenever a payment submission appears or its status changes. The trigger sends
 * the shared secret in `x-webhook-secret` and this function refuses anything else,
 * so `verify_jwt` is off (a webhook has no user to sign in) and the gate below is
 * the whole of the authentication.
 *
 * What it does, in order:
 *   1. checks the secret;
 *   2. reads the pending count and the fan-set — admins with a registered device
 *      and the toggle left on — through two `service_role`-only RPCs, so the token
 *      list never passes through a client-facing path;
 *   3. buys an FCM access token from the service-account key
 *      (`FCM_SERVICE_ACCOUNT`), caching it until it is nearly expired;
 *   4. sends one **data-only** message per device: the numbers, with a sound and
 *      high priority only for the 0 → n arrival, and a quiet correction after it;
 *   5. deletes any token FCM reports as unregistered, so a dead device is not
 *      retried forever.
 *
 * What it never does: read the request body's word about anything it can check
 * itself. The count comes from the database, not the payload — a caller who could
 * guess the secret still cannot make this function say something untrue. The
 * payload is used for one thing only, deciding whether a change was an arrival or
 * a correction.
 *
 * Secrets it needs (Supabase → Project Settings → Edge Functions → Secrets):
 *   FCM_SERVICE_ACCOUNT  the downloaded service-account key, whole (Phase 1's doc)
 *   FCM_WEBHOOK_SECRET   the same value the Vault secret `fcm_webhook_secret` holds
 */

import {
  buildFcmMessage,
  classifySendFailure,
  createServiceAccountAssertion,
  parseServiceAccount,
  type ServiceAccount,
} from "./fcm.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };

/** The access token, kept between invocations of a warm isolate. */
let cachedAccessToken: { token: string; expiresAtSeconds: number } | null = null;

type AlertTarget = { user_id: string; token: string };

type WebhookBody = {
  type?: string;
  table?: string;
  record?: { status?: string } | null;
  old_record?: { status?: string } | null;
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "post_only" });
  }

  const expected = Deno.env.get("FCM_WEBHOOK_SECRET") ?? "";
  if (!expected) {
    // A misconfigured function must say so rather than look like a rejected
    // webhook: 500 means "fix the setup", 401 below means "wrong caller".
    return jsonResponse(500, { error: "missing_fcm_webhook_secret" });
  }
  if (!secretsMatch(req.headers.get("x-webhook-secret") ?? "", expected)) {
    return jsonResponse(401, { error: "unauthorized" });
  }

  try {
    const body = await readJsonBody(req);
    const pending = await rpc<number>("push_pending_payment_count");
    const targets = await rpc<AlertTarget[]>("push_alert_targets");

    // Nothing to tell anyone yet — and no reason to buy an FCM token to find out.
    if (targets.length === 0) {
      return jsonResponse(200, {
        ok: true,
        pending,
        targets: 0,
        sent: 0,
        failed: 0,
        pruned: 0,
      });
    }

    const account = parseServiceAccount(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "");
    const accessToken = await getAccessToken(account);
    const alert = wasArrival(body) && pending === 1;
    const endpoint = `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

    let sent = 0;
    let failed = 0;
    let pruned = 0;

    for (const target of targets) {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { ...JSON_HEADERS, Authorization: `Bearer ${accessToken}` },
        body: JSON.stringify(
          buildFcmMessage({ token: target.token, pending, alert }),
        ),
      });

      if (response.ok) {
        sent += 1;
        continue;
      }

      failed += 1;
      const text = await response.text();
      const verdict = classifySendFailure(response.status, text);
      console.error(
        JSON.stringify({
          event: "send_failed",
          status: response.status,
          verdict,
          token: maskToken(target.token),
          body: text.slice(0, 300),
        }),
      );

      if (verdict === "prune") {
        await deleteToken(target.token);
        pruned += 1;
      }
    }

    return jsonResponse(200, {
      ok: true,
      pending,
      alert,
      targets: targets.length,
      sent,
      failed,
      pruned,
    });
  } catch (error) {
    // The response body is what the trigger's pg_net row and the function logs
    // show, so the reason is passed through rather than swallowed.
    console.error(JSON.stringify({ event: "send_error", message: `${error}` }));
    return jsonResponse(500, { error: `${error}` });
  }
});

/** Constant-time compare, so the secret cannot be guessed one byte at a time. */
function secretsMatch(provided: string, expected: string): boolean {
  if (provided.length !== expected.length) {
    return false;
  }
  let difference = 0;
  for (let i = 0; i < expected.length; i += 1) {
    difference |= provided.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return difference === 0;
}

/** An empty or malformed body is not a reason to fail; it only means "not an arrival". */
async function readJsonBody(req: Request): Promise<WebhookBody> {
  try {
    const text = await req.text();
    return text ? (JSON.parse(text) as WebhookBody) : {};
  } catch {
    return {};
  }
}

/**
 * Whether this change brought a request in (as opposed to resolving one). An
 * INSERT always did; an UPDATE only when the row became pending, which is what
 * approval or rejection reverses.
 */
function wasArrival(body: WebhookBody): boolean {
  const type = (body.type ?? "").toUpperCase();
  if (type === "INSERT") {
    return true;
  }
  const now = body.record?.status ?? "";
  const before = body.old_record?.status ?? null;
  return before !== null && before !== now && now === "pending";
}

/** Last four characters only: enough to tell two devices apart in the logs. */
function maskToken(token: string): string {
  return token.length <= 4 ? "…" : `…${token.slice(-4)}`;
}

function jsonResponse(status: number, payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: JSON_HEADERS,
  });
}

/** PostgREST, as the service role — the only role the two RPCs admit. */
async function rpc<T>(name: string, args: unknown = {}): Promise<T> {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) {
    throw new Error("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is unavailable");
  }

  const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      ...JSON_HEADERS,
      apikey: key,
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify(args),
  });

  if (!response.ok) {
    throw new Error(`rpc ${name} failed: ${response.status} ${await response.text()}`);
  }
  return (await response.json()) as T;
}

/** The dead device leaves the fan-set; a later change will not aim at it again. */
async function deleteToken(token: string): Promise<void> {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const response = await fetch(
    `${url}/rest/v1/device_tokens?token=eq.${encodeURIComponent(token)}`,
    {
      method: "DELETE",
      headers: { apikey: key, Authorization: `Bearer ${key}` },
    },
  );
  if (!response.ok) {
    console.error(
      JSON.stringify({
        event: "prune_failed",
        status: response.status,
        token: maskToken(token),
      }),
    );
  }
}

/** One token per hour at most: Google's endpoint is the slow part of a send. */
async function getAccessToken(account: ServiceAccount): Promise<string> {
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAtSeconds - 60 > nowSeconds) {
    return cachedAccessToken.token;
  }

  const assertion = await createServiceAccountAssertion(account, nowSeconds);
  const response = await fetch(account.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }).toString(),
  });

  if (!response.ok) {
    throw new Error(
      `fcm_oauth_failed: ${response.status} ${(await response.text()).slice(0, 300)}`,
    );
  }

  const payload = (await response.json()) as {
    access_token?: string;
    expires_in?: number;
  };
  if (!payload.access_token) {
    throw new Error("fcm_oauth_failed: no access_token in the response");
  }

  cachedAccessToken = {
    token: payload.access_token,
    expiresAtSeconds: nowSeconds + (payload.expires_in ?? 3600),
  };
  return cachedAccessToken.token;
}

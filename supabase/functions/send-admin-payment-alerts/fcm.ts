/**
 * The admin payment-alert sender's pure half.
 *
 * Everything here is a plain function over strings and bytes — no `Deno` global,
 * no network, no environment — so the one piece of this feature that cannot be
 * exercised against the real project (the RS256 assertion that buys an FCM access
 * token) can still be checked: tool/check_fcm_jwt.mjs signs with a throwaway key
 * and verifies the signature with the matching public key.
 *
 * Intent of the pieces:
 *  - parseServiceAccount  turns the FCM_SERVICE_ACCOUNT secret into the four
 *                         fields the flow actually needs, refusing anything else
 *                         with a message that names what is missing.
 *  - createServiceAccountAssertion  the JWT Google's token endpoint exchanges for
 *                         an access token: RS256 over {alg,typ}.{iss,scope,aud,iat,exp}.
 *  - buildFcmMessage      one data-only message. Data only, because the words a
 *                         notification shows live in the app's ARB files; the
 *                         server sends numbers.
 *  - classifySendFailure  which failures mean "this device is gone" (delete the
 *                         token) and which mean "try again later".
 */

/** The fields of the downloaded service-account key that this function uses. */
export type ServiceAccount = {
  project_id: string;
  private_key: string;
  client_email: string;
  token_uri: string;
};

/** The only scope this function ever asks for. */
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

/**
 * Reads the service-account JSON. The value arrives as the raw file contents in
 * one environment variable, so a mistake here is almost always a truncated paste
 * or a key that was retyped rather than copied — say which, rather than failing
 * later inside the crypto call.
 */
export function parseServiceAccount(raw: string): ServiceAccount {
  if (!raw.trim()) {
    throw new Error("FCM_SERVICE_ACCOUNT is empty");
  }

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(raw) as Record<string, unknown>;
  } catch (error) {
    throw new Error(
      `FCM_SERVICE_ACCOUNT is not JSON (${(error as Error).message}); paste the downloaded file whole`,
    );
  }

  const required = ["project_id", "private_key", "client_email", "token_uri"];
  const missing = required.filter((name) => {
    const value = parsed[name];
    return typeof value !== "string" || value.length === 0;
  });
  if (missing.length > 0) {
    throw new Error(
      `FCM_SERVICE_ACCOUNT is missing ${missing.join(", ")}; the whole key file is the value, not one field of it`,
    );
  }

  const account: ServiceAccount = {
    project_id: parsed.project_id as string,
    private_key: parsed.private_key as string,
    client_email: parsed.client_email as string,
    token_uri: parsed.token_uri as string,
  };

  if (!account.private_key.includes("BEGIN PRIVATE KEY")) {
    throw new Error(
      "FCM_SERVICE_ACCOUNT's private_key is not a PEM block; retyping it loses the \\n escapes — copy the file instead",
    );
  }

  return account;
}

/** base64url, unpadded — the only encoding a JWS uses. */
function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

/** The PEM body, decoded to the DER bytes WebCrypto's importKey wants. */
export function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

/**
 * The signed assertion Google exchanges for an access token. `nowSeconds` is a
 * parameter rather than `Date.now()` so the claims can be asserted exactly.
 */
export async function createServiceAccountAssertion(
  account: ServiceAccount,
  nowSeconds: number,
): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: account.client_email,
    scope: FCM_SCOPE,
    aud: account.token_uri,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  };

  const signingInput = `${base64UrlJson(header)}.${base64UrlJson(claims)}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64Url(new Uint8Array(signature))}`;
}

/**
 * One message, carrying the count and nothing a person reads.
 *
 * `alert` is the 0 → n arrival: it is what the device uses for a sound and what
 * makes the wake high priority, so later corrections (a request being approved)
 * arrive quietly on normal priority and replace the notification in place — the
 * design decisions taken with the user. The collapse key keeps any that are
 * queued while a device is offline to one. ponytail: Android only for now, which
 * is the only platform this app ships; an iOS block joins it when an iOS build
 * exists.
 */
export function buildFcmMessage(options: {
  token: string;
  pending: number;
  alert: boolean;
}): unknown {
  return {
    message: {
      token: options.token,
      // FCM data values are strings; the app parses them.
      data: {
        pending: String(options.pending),
        alert: String(options.alert),
      },
      android: {
        priority: options.alert ? "high" : "normal",
        ttl: "3600s",
        collapse_key: "admin_payment_alerts",
      },
    },
  };
}

/**
 * What a failed send means for the token it was aimed at.
 *  - "prune": the device is gone or the token was rejected — delete the row, or
 *             every later send wastes a request on it.
 *  - "retry": Google is throttling or unwell — keep the token, the next change
 *             will try again.
 *  - "other": a malformed or unauthorised request — a defect on this side, which
 *             the logs must show rather than bury in a token deletion.
 */
export function classifySendFailure(
  status: number,
  body: string,
): "prune" | "retry" | "other" {
  if (status === 404) {
    return "prune";
  }
  if (status === 400) {
    const text = body.toUpperCase();
    if (text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT")) {
      return "prune";
    }
    return "other";
  }
  if (status === 429 || status === 500 || status === 503) {
    return "retry";
  }
  return "other";
}

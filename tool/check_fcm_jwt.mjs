/**
 * check_fcm_jwt.mjs — the one part of the admin payment-alert sender that cannot
 * be exercised against the real project.
 *
 * The sender signs an RS256 JWT with the service-account key to buy an FCM access
 * token. That call needs the real key and a live Google endpoint, so it is the
 * step most likely to be wrong and the least likely to be noticed before a real
 * notification fails. Here a throwaway keypair stands in for the service account:
 * the module that ships is asked to sign, and Node's own crypto verifies the
 * signature with the matching public key and checks every claim.
 *
 * Run it with:
 *
 *   node tool/check_fcm_jwt.mjs
 *
 * It touches nothing outside itself — no network, no project, no file.
 */

import { generateKeyPairSync, verify, createPublicKey } from "node:crypto";
import {
  buildFcmMessage,
  classifySendFailure,
  createServiceAccountAssertion,
  parseServiceAccount,
} from "../supabase/functions/send-admin-payment-alerts/fcm.ts";

let failures = 0;

function check(condition, message) {
  if (condition) {
    console.log(`  ok   ${message}`);
    return;
  }
  failures += 1;
  console.error(`  FAIL ${message}`);
}

function checkThrows(fn, expected, message) {
  try {
    fn();
  } catch (error) {
    check(
      `${error.message}`.includes(expected),
      `${message} (said: ${error.message})`,
    );
    return;
  }
  check(false, `${message} — nothing was thrown`);
}

const { privateKey, publicKey } = generateKeyPairSync("rsa", {
  modulusLength: 2048,
  publicKeyEncoding: { type: "spki", format: "pem" },
  privateKeyEncoding: { type: "pkcs8", format: "pem" },
});

const ACCOUNT = {
  type: "service_account",
  project_id: "smoke-project",
  private_key: privateKey,
  client_email: "smoke@smoke-project.iam.gserviceaccount.com",
  token_uri: "https://oauth2.googleapis.com/token",
};

console.log("parseServiceAccount");
const account = parseServiceAccount(JSON.stringify(ACCOUNT));
check(account.project_id === "smoke-project", "keeps project_id");
check(account.client_email.endsWith(".iam.gserviceaccount.com"), "keeps client_email");
check(account.token_uri.startsWith("https://"), "keeps token_uri");

checkThrows(
  () => parseServiceAccount(""),
  "empty",
  "an empty secret is refused by name",
);
checkThrows(
  () => parseServiceAccount('{"project_id": "x",'),
  "not JSON",
  "a truncated paste is refused by name",
);
checkThrows(
  () => parseServiceAccount(JSON.stringify({ ...ACCOUNT, client_email: "" })),
  "client_email",
  "a key missing a field names the field",
);
// The body without its header is exactly what retyping the field produces, and
// it is the failure this guard exists for: it would otherwise surface much later
// as an opaque crypto error.
checkThrows(
  () =>
    parseServiceAccount(
      JSON.stringify({ ...ACCOUNT, private_key: "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC" }),
    ),
  "PEM block",
  "a private_key that lost its PEM header is refused by name",
);

console.log("createServiceAccountAssertion");
const nowSeconds = 1_700_000_000;
const assertion = await createServiceAccountAssertion(account, nowSeconds);
const parts = assertion.split(".");
check(parts.length === 3, "produces a three-part JWT");

const decode = (part) =>
  JSON.parse(Buffer.from(part, "base64url").toString("utf8"));
const header = decode(parts[0]);
const claims = decode(parts[1]);
check(header.alg === "RS256", "the header says RS256");
check(header.typ === "JWT", "the header says JWT");
check(claims.iss === ACCOUNT.client_email, "iss is the service-account address");
check(claims.aud === ACCOUNT.token_uri, "aud is the key's own token endpoint");
check(
  claims.scope === "https://www.googleapis.com/auth/firebase.messaging",
  "asks for the messaging scope and nothing else",
);
check(claims.iat === nowSeconds, "iat is the time it was asked for");
check(claims.exp === nowSeconds + 3600, "exp is one hour later");

const signatureIsValid = verify(
  "sha256",
  Buffer.from(`${parts[0]}.${parts[1]}`),
  createPublicKey(publicKey),
  Buffer.from(parts[2], "base64url"),
);
check(signatureIsValid, "the signature verifies against the matching public key");
check(
  !verify(
    "sha256",
    Buffer.from(`${parts[0]}.${parts[1]}tampered`),
    createPublicKey(publicKey),
    Buffer.from(parts[2], "base64url"),
  ),
  "a tampered signing input does not verify",
);

console.log("buildFcmMessage");
const arrived = buildFcmMessage({ token: "device-token", pending: 3, alert: true });
check(arrived.message.token === "device-token", "addresses the device it was given");
check(arrived.message.data.pending === "3", "carries the count as a string");
check(arrived.message.data.alert === "true", "marks an arrival");
check(arrived.message.android.priority === "high", "an arrival is high priority");
check(
  arrived.message.android.collapse_key === "admin_payment_alerts",
  "collapses queued messages to one",
);
check(arrived.message.notification === undefined, "sends no words — the app owns them");

const correction = buildFcmMessage({ token: "device-token", pending: 2, alert: false });
check(correction.message.android.priority === "normal", "a correction is normal priority");
check(correction.message.data.alert === "false", "marks a correction");

console.log("classifySendFailure");
check(classifySendFailure(404, "NOT_FOUND") === "prune", "a missing device is pruned");
check(
  classifySendFailure(400, '{"errorCode":"UNREGISTERED"}') === "prune",
  "an unregistered token is pruned",
);
check(
  classifySendFailure(400, '{"errorCode":"INVALID_ARGUMENT"}') === "prune",
  "a token FCM rejects is pruned",
);
check(classifySendFailure(429, "quota") === "retry", "throttling is retried");
check(classifySendFailure(503, "unavailable") === "retry", "an outage is retried");
check(
  classifySendFailure(403, "forbidden") === "other",
  "a permissions failure is neither retried nor blamed on the device",
);

if (failures > 0) {
  console.error(`\n${failures} check(s) failed.`);
  process.exit(1);
}
console.log("\nAll FCM helper checks passed.");

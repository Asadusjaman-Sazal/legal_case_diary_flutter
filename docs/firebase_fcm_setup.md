# Firebase Cloud Messaging Setup — Admin Payment Notifications

A runbook for Legal Case Diary's admin notifications, written for someone who has never opened the
Firebase console. Follow it top to bottom.

This is the *other* Google console document. [google_oauth_setup.md](google_oauth_setup.md) covers
**Google sign-in**, which needs OAuth clients and does **not** use Firebase. This one covers
**Firebase Cloud Messaging (FCM)**, which is how an admin learns that a payment request is waiting
while the app is closed. The two share one Google Cloud project and nothing else.

> **FCM is free and needs no billing.** Google's pricing page lists Cloud Messaging as "No-cost", and
> the free *Spark* plan is enough — no credit card, no Blaze upgrade. It has throttling limits
> (600,000 messages/minute per project, 240/minute per device), not a paid allowance, so this feature
> cannot generate a bill.

---

## 1. The Mental Model (Read This Once)

| Party | What it is | What it does here |
| --- | --- | --- |
| **The payer's app** | Any signed-in phone | Inserts a row into `payment_submissions` when it submits a TrxID |
| **The database** | Supabase project `lsthasywrdrhuuxnykau` | A trigger calls an Edge Function, which reads the pending count and the admin device tokens |
| **FCM** | Google's push transport | Delivers one small message to each admin's phone — including while the app is closed |
| **The admin's app** | The APK on the admin's phone | Turns that message into one local notification, worded from the app's own ARB files |

Three consequences worth knowing before you start:

- **The phone never opens a connection.** FCM uses the one persistent connection Android already
  keeps for all apps, which is exactly why Android recommends it over an app holding its own socket.
  The message handler only posts a notification — it makes no network call, opens no database.
- **The notification's words live in the app, not on the server.** FCM carries *numbers*
  (`{"pending": "3"}`), and the app writes the sentence from `app_en.arb` / `app_bn.arb`. That is what
  keeps Bengali correct per device and keeps every visible label in the ARB files.
- **`google-services.json` is not a secret.** Google ships it inside every APK. It is git-ignored here
  for the same reason `env.json` is — it is a build input naming one Firebase project — not because it
  is sensitive. The **service-account key** in §6 *is* a secret and never leaves Supabase.

---

## 2. The Values You Will Need (Copy From Here)

| Name | Value |
| --- | --- |
| Google Cloud **project number** | `38386857573` (the project that already holds the Web client `…g0bkds`) |
| **Firebase project id** | `legalcasediary-17985` — the id paired with that number; the key in §6 and the send endpoint are built from it |
| Android **package name** | `com.legumsoft.legalcasediary` |
| Supabase project | `lsthasywrdrhuuxnykau` (**never** the other project) |

**Use the project you already have.** Do not create a new Google Cloud project for Firebase: the
project number above is the one whose Web client Supabase trusts for sign-in.

---

## 3. Step 1 — Add Firebase To Your Existing Google Cloud Project

1. Sign in to <https://console.firebase.google.com> with the **one** account that owns the project.
2. Click **Create a project** (the button reads that even when you intend to reuse one).
3. On the first step, choose **Add Firebase to an existing Google Cloud project** — a link or a
   dropdown near the project-name field — and pick the project whose number is `38386857573`.
   Only projects that do not already have Firebase are offered, so if the list is empty, the project
   already has Firebase and you can skip to §4.
4. Continue through the steps. **Analytics is not needed** — decline or remove Google Analytics if the
   wizard offers it. Nothing in this feature uses it.

If a wizard ever insists on creating a *new* project, stop: two projects would mean an FCM
configuration that does not match the sign-in clients, and this document's values would no longer
apply.

---

## 4. Step 2 — Register The Android App

1. On the project overview, click the **Android** icon (**Add app → Android**).
2. **Android package name**: `com.legumsoft.legalcasediary` — exactly, or FCM will not deliver.
3. **App nickname**: `Legal Case Diary`.
4. **Debug signing certificate SHA-1**: *leave it empty.* FCM does not use it — the SHA-1 is what
   Google sign-in matches against, and
   [google_oauth_setup.md §7](google_oauth_setup.md#7-step-3--create-the-android-clients) already
   registered those clients. Entering it here can raise the console's *"the Android package name and
   its fingerprint are already in use"* error, which is expected and does not need resolving.
5. Click **Register app**.

> **The package was renamed in 0.0.738 (`com.legalcasediary.app` → `com.legumsoft.legalcasediary`), and
> Firebase is keyed on the package name.** If the project already has the old Android app, add a
> **second** Android app with the new package in the same Firebase project, then download
> `google-services.json` again — it will carry both clients, and the Gradle plugin picks the one whose
> `package_name` matches `applicationId`. Replace the local copy and re-encode the CI secret (§5). Never
> edit the package name inside the file by hand: that is a registration, not a string.

---

## 5. Step 3 — Put `google-services.json` In Place

Download the file the console offers (`google-services.json`) and save it as:

```text
android/app/google-services.json
```

It is git-ignored, so every machine that builds for Android — yours, and the CI runner — needs its own
copy. The google-services Gradle plugin
([`android/settings.gradle.kts`](../android/settings.gradle.kts)) turns it into the resources the
Firebase SDK reads, and a build without it fails rather than shipping an app whose push is silently
dead.

For CI, encode it and store it as the repository secret `GOOGLE_SERVICES_JSON_BASE64`
(GitHub → Settings → Secrets and variables → Actions):

```bash
base64 -w0 android/app/google-services.json
```

Open the file and check `project_info.project_id` — the **Firebase project id**, which is what the send
endpoint in §6 is built from. This project's id is `legalcasediary-17985`, paired with the number above;
an id that differs means a second Firebase project was created, and §3 must be repeated rather than
worked around.

**Sanity check while the file is open:** it should list a `project_number` of `38386857573` and a
`package_name` of `com.legumsoft.legalcasediary`. If the package name differs, the app was registered wrong
— delete it in Firebase (**Project settings → Your apps**) and repeat §4 rather than editing the file
by hand.

---

## 6. Step 4 — The Admin Key (Server Side, Secret)

The server needs to be allowed to *send* messages. That permission is a service-account key.

1. Open the **[Firebase console](https://console.firebase.google.com) → ⚙ Project settings →
   Service accounts**.
2. Pick any of the **Node.js / Java / Python / Go** tabs. They choose the *sample code* shown on the
   page and nothing else: **Generate new private key** downloads the same JSON service-account key
   in all four cases, and no code from the page is ever copied into this project — the key is read by
   the FCM sender Edge Function, which sends its own request. Node.js is the shortest tab to read.
3. Click **Generate new private key**, confirm, and download the JSON file.
4. In the **Supabase dashboard for `lsthasywrdrhuuxnykau`** (never the other project), go to
   **Project Settings → Edge Functions → Secrets** and add one secret:
   - name: `FCM_SERVICE_ACCOUNT`
   - value: the entire contents of the downloaded JSON file (multiline is fine — paste the whole file)

**What exactly goes in that value:** the file, whole and untouched — the opening `{`, every field, the
closing `}`, and nothing else. Four ways to get it wrong:

- **Do not wrap it in quotes** or escape anything in it. The dashboard stores the raw string and the
  Edge Function runs `JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!)` over it.
- **Do not retype or reformat it — copy the file.** Inside `private_key` the `\n` stand for two
  characters each, not real line breaks, and `JSON.parse` is what turns them back into a PEM. Retyping
  the key, or replacing those escapes with real newlines, fails later as
  `Invalid PEM formatted message` / `DECODER routines::unsupported` at token time.
- **Do not paste `private_key` on its own**, and do not base64 the file. The sender needs
  `client_email`, `private_key` and `token_uri` together in the one object.
- **Never put it in `env.json`, in a GitHub secret, or in this repository.** Only
  `google-services.json`'s base64 (§5) belongs in GitHub; this one is genuinely sensitive, because it
  can send a notification to every admin device.

The key's `project_id` is the **Firebase project id** — the same string as `project_info.project_id` in
`google-services.json` (§5), `legalcasediary-17985` here — and the send endpoint is built from it:
`https://fcm.googleapis.com/v1/projects/legalcasediary-17985/messages:send` (shape:
`https://fcm.googleapis.com/v1/projects/<project-id>/messages:send`). If the two files disagree, the key
belongs to a different project than the app and no message will ever deliver; the fix is to repeat
§3/§4 against project number `38386857573`, never to hand-edit either file.

**Do not commit it, do not paste it into a chat.** Keep the downloaded copy out of this repository.

### 6.1 Confirm the Firebase Cloud Messaging API is enabled

Google's send endpoint rejects a call with `403 SERVICE_DISABLED` when `fcm.googleapis.com` is off,
so check this before the first real notification rather than debugging the Edge Function later. The
direct page is
<https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=38386857573>:

- The button reads **Manage** and the page says the API is enabled → nothing to do.
- The button reads **Enable** → click it and wait for it to finish.

The same fact in three other places, all showing one state:

- **Firebase console → ⚙ Project settings → Cloud Messaging → Firebase Cloud Messaging API (V1)** —
  says *Enabled*. If it instead offers an **Enable** button, that button opens this same page.
- **Google Cloud console → APIs & Services → Enabled APIs & services** for project `38386857573` —
  the list contains **Firebase Cloud Messaging API**.
- **The send path itself.** Once the Edge Function of Phase 2 exists, its first log line settles it:
  a send that fails with `403 SERVICE_DISABLED` ("… has not been used in project … before or it is
  disabled") means this API is off; any error about the token or the message means it is on.

Enabling it is free and needs no billing account. It is a *separate* switch from the Firebase
project, which is why Firebase's own setup wizard can be finished while this one is still off.

---

## 7. Step 5 — Verify, In Order

1. **Both halves exist.** Firebase console → **Project settings → Your apps** shows
   `com.legumsoft.legalcasediary`; Supabase → **Edge Functions → Secrets** shows `FCM_SERVICE_ACCOUNT`.
2. **A build still works.** `flutter build apk --debug` (or `dart run tool/flutter_with_env.dart run`)
   with `android/app/google-services.json` present. Missing-file errors at this point mean §5.
3. **Sign-in still works.** Sign in with Google after this change — it must behave exactly as before.
   If it stops working, nothing about FCM caused it: check §7 of
   [google_oauth_setup.md](google_oauth_setup.md) (the certificate's Android OAuth client). The app takes
   its Web client id from `GOOGLE_WEB_CLIENT_ID` in `env.json`, never from this file, and the file names
   that same Web client as `default_web_client_id` (`…g0bkds`, the id §2 of the OAuth doc registers) —
   so the two documents cannot silently drift onto different projects.
4. **The notification itself.** Sign in as an admin on a real device, put the app in the background,
   and submit a payment request from another account. One notification should appear, its text and
   digits in the device's language, and tapping it should open the Admin Panel's Payment Requests.
5. **The OEM check.** On Xiaomi/Oppo/Vivo/Realme phones, Android's own battery manager can defer push
   until the app is whitelisted — the app's OEM setup guide (Settings → Notifications) covers this,
   and it is the first thing to check if step 4 produces nothing.

---

## 8. Troubleshooting

| Symptom | Most likely cause |
| --- | --- |
| Gradle: *"File google-services.json is missing"* | §5 — the file is not at `android/app/`, or CI's `GOOGLE_SERVICES_JSON_BASE64` is unset |
| CI: *"Missing repository secret: GOOGLE_SERVICES_JSON_BASE64"* | The secret is not in GitHub, or was encoded from the wrong path |
| No notification, app open, admin signed in | The Edge Function or its secret (§6) — check the function's logs in Supabase |
| No notification, app closed | Battery manager (§7 step 5), or the app was force-stopped (nothing is delivered to a force-stopped app until it is opened again) |
| Notification appears but the number is stale | Expected: the push carries the count as it stood at send time, and the app re-reads it on open |
| Two notifications instead of one | The notification id changed — a defect, not a setting; the design is one notification, replaced in place |
| Notification is in the wrong language | The text is composed on the device, so this is a build/locale issue, never a server one |
| Google sign-in broke after adding Firebase | Not caused by this document — see §7 of [google_oauth_setup.md](google_oauth_setup.md) |

---

## 9. Checklist

- [x] Firebase added to the **existing** Google Cloud project `38386857573` (no new project) — the file
      pairs that number with the id `legalcasediary-17985`
- [x] Analytics declined, or removed (the `services` block has no `analytics_service`)
- [x] Android app registered as `com.legumsoft.legalcasediary`, SHA-1 field left empty (one client, no
      `certificate_hash`)
- [x] `android/app/google-services.json` in place locally — `project_number` `38386857573`,
      `package_name` `com.legumsoft.legalcasediary`, and an `api_key`/`current_key` the plugin needs
- [ ] `GOOGLE_SERVICES_JSON_BASE64` stored as a GitHub Actions secret
- [x] `google-services.json`'s `project_id` (`legalcasediary-17985`) equals the key's `project_id` (§6)
- [ ] **Firebase Cloud Messaging API** enabled on `38386857573` (§6.1 — the page reads *Manage*)
- [ ] Service-account key generated (any language tab, §6) and stored as the Supabase secret
      `FCM_SERVICE_ACCOUNT` — nowhere else
- [x] Debug build succeeds with the file present — `flutter build apk --debug` is green, and the
      plugin's generated `values.xml` carries `gcm_defaultSenderId` `38386857573` and `project_id`
      `legalcasediary-17985`
- [ ] Google sign-in verified unchanged
- [ ] Background notification received on a real device, in the correct language, opening Payment Requests
- [ ] OEM battery whitelisting checked on the admin's own phone

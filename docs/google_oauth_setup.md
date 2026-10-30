# Google Sign-In Setup — Every Client Type, Step by Step

A runbook for Legal Case Diary's native Google sign-in, written for someone who has never opened the
Google Cloud console. Follow it top to bottom; nothing here requires prior OAuth knowledge. All the
values specific to this app are already filled in for you.

If sign-in fails *after* the account picker closes with nothing happening, that is the symptom this
document fixes — see [Why this matters](#why-this-matters) and
[README.md's troubleshooting section](../README.md#google-sign-in-setup-and-troubleshooting).

---

## 1. The Mental Model (Read This Once)

Native Android sign-in involves **three separate parties**, and confusing them is the single most common
reason it breaks:

| Party | What it is | What it does in our flow |
| --- | --- | --- |
| **Your app on the phone** | The APK built from this repository, signed with a keystore | Asks Google for an ID token, then hands that token to Supabase |
| **Google** | The Google Cloud project's OAuth clients + consent screen | Decides whether the app is genuinely *our* app, and issues the token |
| **Supabase** | The "Legal Case Diary" project's Google provider | Verifies the token's signature and audience, then creates the session |

So:

- An **Android client** answers "is this really *our* app asking?" — Google matches the app's **package
  name** plus the **SHA-1 fingerprint of the certificate it was signed with**. One Android client per
  signing certificate. This is the part that is almost always missing or wrong.
- A **Web client** answers "who is this token *for*?" — our code passes the Web client's ID as
  `serverClientId`, so the token Google issues is addressed to the Web client. Supabase is configured
  with that same Web client (ID + secret). This is why a Web client is needed even though the app is not
  a website.
- The **consent screen** (now called *Branding* + *Audience*) decides **who is allowed to sign in at all**
  while the project is unpublished.

You do **not** need: an API key, a Firebase project, or a `google-services.json` file — **sign-in** uses
none of them. If a guide tells you to add one for Google sign-in, it is describing a different setup.

> **Updated for admin notifications.** The app now carries a Firebase project for **Cloud Messaging** only
> (admin payment alerts), so `android/app/google-services.json` exists and the google-services Gradle plugin
> is applied. That is a *separate* concern from sign-in: this flow still passes the Web client's ID as
> `serverClientId`, still matches the package name against the **Android OAuth clients** registered here, and
> never reads the Firebase config. Adding Firebase does not replace, widen or repair anything in this
> document — see [`firebase_fcm_setup.md`](firebase_fcm_setup.md) for that side.

```text
  Phone (signed APK):
    package name ─────┐
    SHA-1 cert   ─────┼──▶  Google Cloud project  ──▶  ID token  ──▶  Supabase  ──▶  session
    account      ─────┤       Android client(s)                  (verifies it)   created
    serverClientId ───┘       Web client (audience)
                              Consent screen (who may sign in)
```

---

## 2. The Values You Will Need (Copy From Here)

| Name | Value |
| --- | --- |
| Google Cloud **project number** | `38386857573` |
| **Web client ID** (already exists) | `38386857573-050dnjr3vd1lvli3kf134s7u81g0bkds.apps.googleusercontent.com` |
| Android **package name** | `com.legumsoft.legalcasediary` |
| **Debug** SHA-1 | `9D:8B:8E:D1:6A:52:C0:4B:B9:67:7B:C1:A2:71:3C:81:11:FD:B2:9D` |
| **Release** SHA-1 | `EB:7A:81:19:03:5C:EF:B0:D4:A3:2E:86:43:FB:09:F1:8A:25:9D:6B` |
| **Google Play app-signing** SHA-1 | *not known to the repository — read it from Play Console, §7* |
| Supabase **authorized redirect URI** | `https://lsthasywrdrhuuxnykau.supabase.co/auth/v1/callback` |
| Supabase project | `lsthasywrdrhuuxnykau` (**never** the other project) |

Treat the numbers above as the source of truth; if anything in a console disagrees with them, the console
is wrong, not this table.

---

## 3. Before You Start

- Sign in to the Google Cloud console with the **one** Google account that owns this project. If your
  browser is signed into several Google accounts at once, the project picker silently switches between
  them — this is a classic source of "but I already added it". Use an incognito window with the single
  correct account if you are unsure.
- Open <https://console.cloud.google.com/auth/clients>.
- Confirm you are in the right project: the picker at the top should show the project whose client ID
  starts with `38386857573`. You can verify by looking for a client ending in
  `…g0bkds.apps.googleusercontent.com` in the list. **Stop and switch project if it is not there.**
- If the page offers to "Get started" / "Configure consent screen", that is Step 5 — it is mandatory
  before any client can be created.
- Collect the fingerprints on your own machine first, so you are not hunting for them mid-flow:

```bash
# Debug keystore (created automatically by Android tooling on this machine)
keytool -list -v -keystore "$HOME/.android/debug.keystore" \
  -alias androiddebugkey -storepass android -keypass android

# Release keystore — the path and password live in android/key.properties (git-ignored)
keytool -list -v -keystore <path-from-android/key.properties> -alias upload
```

`keytool` ships with the JDK. In this project it is at
`C:\Program Files\Java\latest\jdk-21\bin\keytool.exe`; on Windows, Git Bash and PowerShell both run the
commands above unchanged. Copy the **SHA1** line exactly, including every colon. The **SHA256** line is
printed too — keep it in your notes (Play Console and some older guides ask for it), but the console's
Android client form takes the **SHA-1**.

---

## 4. What You Are Creating, and Why There Are Several Android Clients

| Client type | How many | Why |
| --- | --- | --- |
| **Web application** | 1 (already exists) | The audience Supabase trusts. `GOOGLE_WEB_CLIENT_ID` and Supabase's Google provider both use it. |
| **Android** | 1 per signing certificate | Lets the phone's Google Play services confirm the app's identity. Different certificates = different clients. |
| **iOS** | 0 today, 1 later | Only needed once an iOS build exists. See §8. |

You need **three Android clients over the life of the app**, and today at least the first two:

1. **Debug** — your development builds, signed by `~/.android/debug.keystore`. Without it, sign-in on
   a debug build always fails even though release works.
2. **Release** — APKs/AABs you build and install yourself, signed by the project release keystore.
3. **Google Play app-signing** — *only if you distribute through Play*. Play **re-signs** your upload
   with a certificate Google holds, so the installed app's fingerprint is *not* your release one. The
   console will not warn you; sign-in simply fails for Play-installed builds until you add it.

> A common, entirely correct configuration is to have **four** entries total: 1 Web + 3 Android. If you
> later rebuild the app on a second developer machine, that machine's debug keystore is *different* again —
> add a fifth Android client for it rather than trying to reuse one.

---

## 5. Step 1 — Register the App (Branding + Audience)

The console calls this "Google Auth Platform". Click **Get started** if prompted, otherwise use the
left-hand menu. The **Branding** page has two halves — *App domain* and *Authorized domains* — and most
of it is **optional while the project is in Testing**. This section walks every field.

### 5.1 Branding — the top fields

| Field | Required now? | What to put |
| --- | --- | --- |
| **App name** | Yes | `Legal Case Diary` — shown on the consent sheet. |
| **User support email** | Yes | Your own address (the one you actually read). |
| **App logo** | No | Leave empty. Adding a logo can trigger a separate brand review; add it only when publishing. |
| **Developer contact information** | Yes | Your own email address again. Google uses it to reach you about the project; it is **not** shown to users. The same address as above is fine. |

### 5.2 Branding — *App domain*

This is the block that confuses people, because a native Android app has **no website**. Google explains
it as: *"To protect you and your users, Google only allows apps using OAuth to use Authorized Domains.
The following information will be shown to your users on the consent screen."*

| Field | Required now? | What to put today |
| --- | --- | --- |
| **Application home page** | No (required for verification) | **Leave blank** while the app's pages live on Google Sites — see §5.2.1. |
| **Application privacy policy link** | No (required for verification) | **Leave blank** for the same reason. |
| **Application terms of service link** | No | **Leave blank.** |

Rules that matter here:

- Every one of these, if filled, must be a **URL on a domain you control** and that domain must also be
  listed under *Authorized domains* (§5.3). You cannot point at Google's or Supabase's own pages.
- **While the project is in Testing none of the three is required**, and sign-in works with all of them
  empty. They become mandatory only when you apply for **verification** to publish to Production — which
  is a later, deliberate decision (§5.4).
- **Do not invent a URL.** A privacy-policy or ToS link that 404s, or that points to a page you do not
  own, is worse than an empty field: verification will be rejected and, once published, users see a dead
  link on the consent sheet.

### 5.2.1 Do *not* use a `sites.google.com` URL here

A Google Sites site — e.g. `https://sites.google.com/view/legal-case-diary/privacy-policy` — looks like a
website but is hosted on a domain **Google owns**, not you. Google's *App Homepage* help page (which is
about exactly this) is explicit:

> *"Your homepage and privacy policy should not be hosted on a third-party platform where you can't
> verify that you own your subdomain. For example: **Google Sites**, Facebook, Instagram, Twitter."*

and the homepage must be *"Hosted on a verified domain you own"*.

So:

- The **App domain** fields stay **blank** while the app's pages are Google Sites pages. Filling them
  cannot pass verification, and `sites.google.com` cannot honestly be added to *Authorized domains*
  (§5.3) because you cannot prove ownership of it.
- Those pages are **not wasted**: keep them, and use the privacy-policy URL in the **Play Console
  listing**, which does accept it. Link them from inside the app as well.
- **The upgrade path, when you want them on the consent screen:** buy a domain (e.g.
  `legalcasediary.com`), connect it to the same Google Site (**Settings → Custom domains**), verify it in
  **Google Search Console**, then add it as an *Authorized domain* and point these three fields at
  `https://legalcasediary.com/…`. A Google Site **served on your own verified domain** is fine — it is the
  `sites.google.com` host that Google rejects.

### 5.3 Branding — *Authorized domains*

> *"When a domain is used on the consent screen or in an OAuth client's configuration, it must be
> pre-registered here. If your app needs to go through verification, please go to the Google Search
> Console to check if your domains are authorized."*

**This block cannot be left empty.** The console refuses to save with *"Invalid domain: must not be
empty"* — at least one authorised domain is mandatory, even in Testing and even though this is a native
Android app.

| Field | What to put |
| --- | --- |
| **Authorized domain 1** | `lsthasywrdrhuuxnykau.supabase.co` — the **full project host**, not `supabase.co` |
| **Authorized domain 2** | Leave blank — or, if you own a domain, put **yours** here and move it to box 1. |
| **Authorized domain 3** | Leave blank. (The limit is ten; the form shows three boxes and adds more as you fill them.) |

**Use the full project host.** `supabase.co` alone is rejected with *"Invalid domain: must be a top
private domain"*, and that error is correct: `supabase.co` sits on the **Public Suffix List**, so it is a
*public suffix*, not a domain anyone can register. The registrable — "top private" — domain of the
callback host `lsthasywrdrhuuxnykau.supabase.co` is therefore the subdomain itself, and Google's own
statement that an authorized domain covers *"any of its subdomains or pages"* does not apply here the
way it would on an ordinary domain.

Why this entry belongs here at all:

- Google's rule, in its own words: *"All domains used in your project, whether in the branding page or
  client configuration pages must be pre-registered here."* The one domain this project's OAuth client
  configuration uses is the Supabase callback host —
  `lsthasywrdrhuuxnykau.supabase.co/auth/v1/callback` — so that host is the value this field wants. It is
  also what Supabase users report putting here.
- **You do not own it, and that is expected.** Google does not check ownership at entry time; ownership
  only comes up if you later apply for **verification** to publish. At that point Google asks you to
  confirm the ownership of the domains listed: confirm your own, and for the Supabase host reply that it
  is your **third-party authentication provider** — Supabase users get this approved routinely, and the
  widely-followed community answer is to keep your own domain **first** in the list and explain the
  Supabase entry in the reply. Do not delete the Supabase entry to "clean up"; the redirect URI still
  needs it.
- Format: the **bare host** — no `https://`, no `www.`, no path, no port, no trailing slash.

**If you later own a domain** (a landing page, a company site), add it as a second entry and put it
**first**, then point the App-domain links in §5.2 at it. That is what eventually replaces
"Continue to *lsthasywrdrhuuxnykau.supabase.co*" on the consent sheet with your own brand.

### 5.4 Audience

1. **Audience** — choose **External** (the app is used by lawyers, not by one organisation's internal
   users). Leave *Publishing status* as **Testing**. Testing is fine and needs no Google review, but it
   has a hard rule: **only accounts listed under "Test users" may sign in.** Add every Google account
   that will sign in during development, including your own — `asad.msnd@gmail.com` is already in use by
   this project, so keep it listed. You can add up to 100.
2. **Contact information** — your email again.

You will come back here in §7 for the Play certificate only in the sense that nothing changes; Audience
stays as it is.

> **Testing status also shows an unverified-app warning** on the consent sheet ("Google hasn't verified
> this app"). That is expected and harmless for a small practitioner audience. Publishing to Production
> needs Google's verification and is a separate, later decision.

---

## 6. Step 2 — Data Access (Scopes)

Open **Data Access** and confirm exactly these scopes are present:

- `openid` — **add this one manually**; it is not there by default.
- `.../auth/userinfo.email` — added by default.
- `.../auth/userinfo.profile` — added by default.

Add nothing else. Any *sensitive* or *restricted* scope (Gmail, Drive, Calendar…) puts the project into a
verification queue that can take weeks, and this app only needs to know who the user is.

---

## 7. Step 3 — Create the Android Clients

Go to **Clients** → **Create client** → *Application type*: **Android**.

Fill in the form exactly:

- **Package name**: `com.legumsoft.legalcasediary`
  (the same value as `namespace`/`applicationId` in `android/app/build.gradle.kts`; a single typo here
  makes sign-in fail silently). **The package was renamed from `com.legalcasediary.app` in 0.0.738**, so
  every Android client registered under the old name is now obsolete: create the debug and release
  clients again with the new package, and leave the old ones in place (harmless) until the old build is
  gone from every test phone.
- **SHA-1 certificate fingerprint**: paste one fingerprint from §2, or from the Play Console for the
  Play client.
- *Name*: make it self-describing, e.g. `Legal Case Diary — Android Debug`.

Click **Create**. No client secret is shown for Android clients — that is correct, native clients are
"public" and have no secret. Repeat the whole step for each certificate:

1. Debug SHA-1 → `Legal Case Diary — Android Debug`
2. Release SHA-1 → `Legal Case Diary — Android Release`
3. Play app-signing SHA-1 → `Legal Case Diary — Android Play`

**Where to read the Play app-signing SHA-1** (only when you first publish to Play):

1. Open <https://play.google.com/console> and select the Legal Case Diary app.
2. **Test and release → Setup → App integrity → App signing key certificate**.
3. Copy its **SHA-1 certificate fingerprint** and use it for client 3.

If the console refuses with *"the Android package name and its fingerprint are already in use"*, that
pair is registered somewhere — usually in another project owned by the same account, or duplicated in
this one. Check this project's Clients list first; a duplicate in this project can simply be deleted.

**Optional but recommended:** the form offers to *verify ownership* of the Android application. Doing so
reduces the risk of someone else publishing an app that impersonates yours. Skip it for now; it is not
needed for sign-in to work.

---

## 8. Step 4 — The iOS Client (Only When an iOS Build Exists)

Skip this entirely until you actually build for iPhone. Nothing in the Android flow depends on it.

*Application type*: **iOS**. You need:

- **Bundle ID** — the iOS equivalent of the package name, read from `ios/Runner.xcodeproj` (or ask the
  developer who created the iOS target). It is *not* the Android package name; the iOS target carries
  `com.legumsoft.legalcasediary` unless someone deliberately set a different bundle id.
- **App Store ID** — optional, and only once the app is on the App Store.
- **Team ID** — the 10-character Apple team identifier; needed only if you enable App Check.

On the app side, an iOS build additionally needs that client ID passed in, because iOS does not accept
`serverClientId` the way Android does — that is a code change for the day iOS is built, not something
you can configure today.

---

## 9. Step 5 — Confirm the Web Client

The Web client already exists; you are only checking it.

Open **Clients** → the entry whose ID ends in `…g0bkds.apps.googleusercontent.com`.

- *Application type* must be **Web application**.
- **Authorized redirect URIs** must contain Supabase's callback:
  `https://lsthasywrdrhuuxnykau.supabase.co/auth/v1/callback`
  (Copy it from Supabase: **Authentication → Providers → Google** shows the callback URL for this exact
  project. Read it from there rather than trusting any transcription, including this document's.)
- **Authorized JavaScript origins**: leave empty. This app has no web front end, and adding an origin you
  do not use only widens the attack surface.
- **Client secret**: if you cannot read the current one, use **Add secret** on the client's detail page.
  Google keeps at most two secrets per client; both stay valid until you disable one, so adding a new one
  does not break the running app.

Note the principle: the Web client's **ID** is public and travels in the app build; its **secret** is a
password and belongs only in Supabase's dashboard. Never commit it, and never paste it into `env.json`.

---

## 10. Step 6 — Tell Supabase

In the Supabase dashboard for the **`lsthasywrdrhuuxnykau`** project only
(**never** the other project):

1. **Authentication → Providers → Google** → enable it.
2. **Client ID**: paste the Web client ID from §2.
   If you ever add iOS (or want the app to work without `serverClientId`), Supabase accepts several
   client IDs comma-separated **with the Web client first**. For the current app — which does pass
   `serverClientId` — the single Web client ID is what matters, because every ID token we send is
   addressed to the Web client's audience.
3. **Client Secret**: paste the Web client's secret.
4. Save.
5. **Authentication → URL Configuration** — two values matter, and both are dashboard-only:
   - **Site URL.** The fallback destination for *every* e-mail link that does not name its own redirect.
     The dashboard default is `http://localhost:3000`, which is a dead page the moment a link is opened
     on a phone — and the usual reason a link "goes to `localhost:3000` instead of the app". Point it at
     a real page you control (see §10.1).
   - **Redirect URLs.** An allow-list. Add `com.legumsoft.legalcasediary://login-callback` (see §10.1);
     without it Supabase silently discards the redirect the app asks for and falls back to the Site URL.
6. Confirm the Web client's **Authorized redirect URI** is the callback used in §9 — a different list
   from the one above, and the one that raises `redirect_uri_mismatch` when it is wrong.

The app side needs nothing new here: `GOOGLE_WEB_CLIENT_ID` in the git-ignored `env.json` already holds
the Web client ID, and `tool/flutter_with_env.dart` is what injects it into a build.

---

### 10.1 Email links — Sign-Up Confirmation and Password Reset

Supabase writes the destination into every link it mails. The app now names its own destination, so the
link opens the app instead of a browser page that is not there.

What the app does (`SupabaseConfig.authRedirectUrl`, `signUpIndividual`, `sendPasswordRecoveryCode`):
passes `emailRedirectTo` / `redirectTo` = `com.legumsoft.legalcasediary://login-callback`. The matching
`<intent-filter>` is already in `android/app/src/main/AndroidManifest.xml`, together with
`flutter_deeplinking_enabled = false`, which is what lets the app (not the Flutter engine) receive the
URI. **Nothing in the app needs editing for this to work** — only the dashboard values below.

Two things you must set in the Supabase dashboard for `lsthasywrdrhuuxnykau`:

1. **Redirect URLs** → add the exact string `com.legumsoft.legalcasediary://login-callback`.
   Scheme, host, no trailing slash, no path. Supabase matches it as a URL pattern; a typo means the
   redirect is dropped and the Site URL is used instead — the original symptom.
2. **Site URL** → a real page (not `http://localhost:3000`). It is still used for any link that carries no
   redirect of its own, so leaving it as the development default keeps a dead page in the chain.

What each link then does:

- **Sign-up confirmation.** Opening it verifies the address on Supabase's own URL, then hands the app a
  session through the custom scheme. The user lands signed in — there is no second step to explain.
- **Password reset.** The app's *primary* path is the **code**, not the link: the Reset Password template
  must contain `{{ .Token }}` and the user types that code into the app. If they tap the link instead,
  they now land on a screen that asks only for the new password, because the link already proved who they
  are. Both paths end in the same place, so neither has to be explained away.

Testing the deep link without waiting for a mail:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "com.legumsoft.legalcasediary://login-callback#error_code=otp_expired&error_description=test"
```

That is a *deliberately invalid* link: it opens the app and shows the failure path, which proves the
intent-filter and the handler are wired. A real mail is the only way to prove the success path.

---

## 11. Step 7 — Verify, In Order

Work down this list; each step has a clear pass/fail.

1. **Fingerprint sanity check.** Re-run the `keytool` command from §3 and compare the SHA-1 in the console
   against the terminal, character by character. They must be *identical*, colons included.
2. **Wait.** Google states that client configuration changes "may take 5 minutes to a few hours to take
   effect". If it fails immediately after you clicked Create, that alone may be the explanation. Test
   again after ~10 minutes before changing anything else.
3. **Build and run against the real backend** — a plain `flutter run` carries no credentials and will
   report "Sign-in is not available in this build", which is a different problem entirely:

   ```bash
   dart run tool/flutter_with_env.dart run -d M2101K6G
   ```

4. **Sign in.** The account picker appears, you choose the account, and you land signed in.
   If instead the picker closes and the screen shows *"Google Sign-In Could Not Complete. Please Try
   Again."*, the app is now telling you a Google-side failure occurred — go to §12 with that in hand.
5. **Confirm on the server.** A successful sign-in leaves an `id_token` grant in the project's Auth logs.
   An `id_token` grant is the definitive proof; `signup`, `recover` and `password` entries are not.

---

## 12. Troubleshooting: What Each Symptom Means

| Symptom | Most likely cause |
| --- | --- |
| Sheet closes, message now appears, log shows `[16] Account reauth failed.` | The signing certificate of **this exact build** is not registered: wrong SHA-1, wrong package name, or the build is a Play install whose app-signing certificate was never added. |
| Works on debug, fails on release (or the reverse) | Only one certificate is registered. Each build type needs its own Android client. |
| Works when installed directly, fails when installed from Play | The **Play app-signing** SHA-1 is missing (§7). |
| "Sign-in is not available in this build" | No credentials were compiled in — you ran `flutter run` instead of the wrapper. Unrelated to Google. |
| Consent sheet says "Google hasn't verified this app" | Expected while the project is in *Testing*. Add the account under **Audience → Test users**. |
| Account picker never appears at all | Consent screen not configured yet (§5), or the project has no Android client for this certificate. |
| `redirect_uri_mismatch` | Only relevant to web/browser flows; the Web client's authorized redirect URI does not match. |
| Error says the package name and fingerprint are already in use | Duplicate client — find it in this project's Clients list and delete it, or you are in the wrong project. |
| It fails, then works an hour later with no change | Propagation delay, §11 step 2. |
| An e-mail link opens a browser page (`localhost:3000`) instead of the app | Supabase **Site URL** is still the development default, or `com.legumsoft.legalcasediary://login-callback` is missing from **Redirect URLs**. §10.1. |
| Sheet closes with *"No Connection. Check Your Internet And Try Again."* | The new pre-flight probe could not reach the project. The phone's Wi-Fi has no uplink (the link is up, the internet is not) — switch to mobile data. `ConnectivityMonitor` reports the *link*, so only this probe can see it. |
| Sheet closes, no message, phone on a Wi-Fi network with no internet | A build without the pre-flight probe (older than 0.0.348) reported this as a dismissal and said nothing at all. Rebuild with the wrapper. |

---

## 13. Housekeeping

- **Secrets and paths.** `env.json` (Web client ID, Supabase URL + anon key), `android/key.properties`
  (keystore path + password) and `android/app/google-services.json` (Firebase config) are git-ignored — keep
  them that way. The Web client **secret** lives only in Supabase, and the Firebase service-account key lives
  only in Supabase's Edge Function secrets.
- **Keep the list of fingerprints in the repository up to date**, but never a secret. The debug and
  release fingerprints currently recorded in `README.md` should be updated the day either keystore
  changes.
- **Reinstalling Android Studio or moving machines changes the debug keystore** — the old debug client
  becomes useless and a new one is needed for the new machine.
- **Losing a keystore is unrecoverable.** Losing the release keystore means a new certificate, which means
  a new Android client ID, and — for Play — a permanent inability to update an app under the old signing
  key. Keep the offline backups the README already asks for.
- **Do not delete a client to "start clean"** unless you are certain nothing depends on it. Deleted clients
  are restorable for 30 days, then gone.

---

## 14. Checklist

- [ ] Right Google Cloud project (`38386857573`, Web client `…g0bkds`)
- [ ] Consent screen registered: name, support email, developer contact email, **External**, *Testing*, every signing-in account in **Test users**
- [ ] *App domain* links left blank (correct while in Testing; revisit only before publishing to Production)
- [ ] *Authorized domains* holds `lsthasywrdrhuuxnykau.supabase.co` (mandatory; `supabase.co` alone is rejected — it is a public suffix)
- [ ] Scopes: `openid` + `userinfo.email` + `userinfo.profile` only
- [ ] Web client present, with Supabase's callback in **Authorized redirect URIs**
- [ ] Android client for the **debug** SHA-1 + `com.legumsoft.legalcasediary`
- [ ] Android client for the **release** SHA-1 + `com.legumsoft.legalcasediary`
- [ ] Android client for the **Play app-signing** SHA-1 (when publishing via Play)
- [ ] Supabase Google provider enabled on `lsthasywrdrhuuxnykau` with the Web client ID + secret
- [ ] Supabase **Site URL** is a real page, not `http://localhost:3000`
- [ ] `com.legumsoft.legalcasediary://login-callback` is in Supabase **Redirect URLs**
- [ ] Reset Password e-mail template contains `{{ .Token }}` (the in-app code flow needs it)
- [ ] A sign-up confirmation mail opens the app when tapped on the device
- [ ] `dart run tool/flutter_with_env.dart run -d <device>` signs in successfully
- [ ] An `id_token` grant appears in the project's Auth logs

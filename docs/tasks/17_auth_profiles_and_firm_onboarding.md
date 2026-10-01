# Task 17 — Auth, Profiles & Firm Onboarding

> **Plan references:** "Resolved Design Clarifications" (Login Flow, Sign Up & Team Onboarding, Firm Mode Detection), Database Schema (`profiles`, `firm_invites`, `firm_members` notes), Sync Plan §5 (Offline Session Expiry), Folder & File Structure (`features/auth/`, `features/accounts_and_profile/`) in `docs/implementation_plan.md`.
> **Goal:** Supabase Auth wired into the app: unified login, sign-up with "Join Existing Firm" via invite code, runtime firm-mode detection from `profiles`, and offline-session behavior that never blocks local data.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Supabase Client Integration

1. Add `supabase_flutter` (and `connectivity_plus`, deferred from Task 01) to `pubspec.yaml` — this is the first task allowed to add networking packages.
2. Initialize Supabase in `main.dart`/`app.dart` with the project URL and anon key (loaded from a non-committed config — ask the user how they want to supply secrets: `--dart-define`, env file, etc.).
3. Implement `features/auth/data/` services: `auth_repository.dart` (fulfilling the `AuthRepository` interface from Task 01 Phase 4) and `local_auth_service.dart` (cached session/credentials store).
4. Session bootstrap on app start: restore any persisted Supabase session; **never block app start or local DB access on session validity** (see Phase 4).

**Phase 1 completion:** Run `flutter analyze`, fix all errors. Update `docs/version_history.md` (new version entry + `## Current Version`).

## Phase 2 — Login & Sign-Up Screens

1. **Login screen** (`login_screen.dart`): a unified, world-class single Email + Password screen for everyone — no "Owner vs Associate" separation. On success, read the user's `profiles` record to determine role and firm membership dynamically.
2. **Sign-up screen** (`signup_screen.dart`), two paths:
   - **Individual / future Firm Owner:** standard sign-up (full name, email, password). Account starts as Individual (`firm_id = null`, `role = 'individual'`); the sign-up trigger from Task 16 creates the `profiles` row.
   - **Join Existing Firm:** a "Join Existing Firm" option where the associate enters their details **plus the single-use Invite Code**. After account creation, redeem the code via the rate-limited `join_firm(code)` RPC. Handle RPC results: success (linked to firm), `invalid_code`, revoked/used code, and "Too many attempts — try again later".
3. No mockup HTML exists for these screens (they are not in the Part A mockup set) — follow the Justice Ledger design system (Task 02 tokens) and confirm layout choices with the user before building anything speculative.
4. Auth error states: wrong credentials, unconfirmed email (if enabled — ask the user whether email confirmation is on), network failure with retry.
5. Route guard in GoRouter: unauthenticated users land on Login; authenticated users land on their configured default landing page. **Existing local-only free users must not be locked out.** Before enabling authenticated writes, run one atomic identity-adoption transaction that rewrites placeholder ownership in domain rows, queue payloads/base snapshots, notification preferences, and attribution to the authenticated user/firm while preserving separate provenance. Fail closed if the local database is already bound to another account.

**Phase 2 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Profile & Firm-Mode Detection

1. Implement `ProfileRepository`: fetch/cache the user's `profiles` row locally; expose `role`, `firm_id`, `subscription_expiry`, `full_name`.
2. **Mode detection at runtime:** `firm_id != null` → Firm mode (`owner`/`associate`/`viewer`); `firm_id == null` → Individual mode. Drive all firm-conditional UI (drawer badges, Manage Associates entry, delete-request behavior) from this single provider.
3. Wire the **Profile** (`profile_screen.dart`, mockup `settings_profile\code.html`) and **Manage Account** (`manage_account_screen.dart`, mockup `settings_manageProfileAccount\code.html`) screens to real profile data (name, role, subscription state display).
4. On launch/resume/reconnect, refresh `firm_members` permissions and update `permissions_synced_at` (permission-freshness rule from the schema note — the rollback path is completed in Task 18/19).

**Phase 3 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 4 — Offline Session Handling

1. **Never gate local data on JWT validity:** Supabase access tokens expire in ~1 hour and refresh requires network. An offline lawyer must always reach their diary — local DB reads/writes work regardless of token state.
2. If a token refresh **ultimately fails while online** (revoked session, changed password): require re-login, but **never wipe local data while `sync_queue` has pending rows**. Route the re-login path through the branched logout flow (implemented fully in Task 19) so unsynced work is synced, exported, or explicitly discarded — never silently lost.
3. Distinguish "offline, token stale" (fully usable, sync paused) from "online, session invalid" (re-login required) in the auth state machine, with clear localized messaging.
4. Add tests: offline app open with expired token still reaches case data; online refresh failure triggers the re-login state without touching the local DB.

**Phase 4 completion:** `flutter analyze` clean; offline auth manual test (login → airplane mode → restart → data accessible). Update `docs/version_history.md`.

## Phase 5 — Invite Generation & Redemption (Owner Side, Minimal)

> Full Manage Associates UI arrives in Task 20; this phase delivers only the invite primitives it will reuse.

1. Owner-side invite service: generate a cryptographically random, normalized invite code with **≥ 50 bits of entropy** (e.g., 10 Crockford Base32 characters), display the plaintext **once**, and insert only its SHA-256 hash into `firm_invites`. Never store or log the plaintext.
2. Revoke-unused-invite call (sets `revoked = true`; RLS restricts to the owner).
3. **Online-only rule:** invite generation/revocation (and all firm administration) require connectivity — show "Connect to the internet to manage your firm" when offline.
4. `flutter test`: the Verification Plan's invite-onboarding test — valid code joins the firm; used or revoked codes are rejected.

**Phase 5 completion:** `flutter analyze` clean; invite tests pass. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Before authenticated repositories become writable, atomically adopt placeholder offline rows, queue payloads/base snapshots, notification preferences, and attribution into the authenticated identity/firm. Preserve separate provenance and fail closed against cross-account data.
- ProfileRepository caches full_name, role, firm_id, and subscription_expiry in the Task 03 pull-only cache, converting TIMESTAMPTZ to epoch ms; invalidate it on logout/account switch.
- A failed join_firm redemption keeps onboarding retryable. If the user abandons onboarding before success, invoke a protected server cleanup that removes the provisional profile/Auth account so it is treated as never created.
- Preferences remain per-user during individual-to-firm transitions and are never merged into firm-shared reference data.
- **Build-time credential injection (follow-up):** Phase 1 item 2's non-committed config is `--dart-define-from-file=env.json` (git-ignored). To stop a build silently shipping offline, `tool/flutter_with_env.dart` wraps `flutter` so debug (`run`) and release (`build`) both inject the flag and a missing `env.json` fails the build. Recorded in `docs/implementation_plan.md` and `README.md`.
- **Auth e-mail links open the app, and Google sign-in checks the network first (follow-up):** Supabase sends every mail link to the project's **Site URL** when the call that produced it passed no redirect, and that default is `http://localhost:3000` — so a sign-up confirmation or password-reset mail landed on a dead browser page rather than in the app. `SupabaseConfig.authRedirectUrl` (`com.legalcasediary.app://login-callback`) is now passed as `emailRedirectTo` by `signUpIndividual` and as `redirectTo` by `sendPasswordRecoveryCode`, and `AndroidManifest.xml` claims the scheme with an intent-filter plus `flutter_deeplinking_enabled="false"` so `supabase_flutter`'s own deep-link observer receives the URI. The verified link is a session, so `AuthSessionEvent.passwordRecovery` (from `AuthChangeEvent.passwordRecovery`) and the matching `AuthState` flag tell the router to keep the user on the reset screen until the new password is set; that screen then asks for the password alone. **The emailed-code flow is unchanged and remains the primary path** — this does not replace it, so Phase 2 item 4's reset step is unchanged apart from the extra way in. The same investigation found that Google sign-in also fails on a Wi-Fi network with no internet, which `ConnectivityMonitor` cannot see (it reports the link, not the internet), so `signInWithGoogle` now runs the four-second `probeSupabaseReachable` first and reports `AuthFailureKind.network` rather than opening a sheet that cannot succeed. Dashboard steps (**Redirect URLs**, a real **Site URL**, and `{{ .Token }}` in the Reset Password template) are in `docs/google_oauth_setup.md` §10.1 and `README.md`.
- **A Google sign-in failure is no longer silent (follow-up):** the login and sign-up screens show no message for `AuthFailureKind.cancelled`, and Android reports a Google-side configuration failure (unregistered signing certificate, wrong package name, or a `serverClientId` from another project) as exactly that cancellation — the account sheet closed and nothing happened. `mapAuthFailure` now detects the case (the GMS code shape `^\[\d+\]` on the exception description, plus the two configuration error codes) and raises the new `AuthFailureKind.googleSignInFailed` ("Google Sign-In Could Not Complete. Please Try Again." / Bengali in `app_en.arb`/`app_bn.arb`); a dismissal without that code remains silent. Registering the debug, release and Google Play app-signing certificates as Android clients in the Web client's project, with the account allowlisted while the consent screen is in testing, is documented in `README.md` (*Google Sign-In Setup and Troubleshooting*) and, as a novice-level walkthrough of every client type plus the Supabase side, in `docs/google_oauth_setup.md`. Recorded in `docs/implementation_plan.md`.

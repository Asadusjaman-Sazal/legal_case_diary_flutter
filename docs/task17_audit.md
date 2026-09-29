# Task 17 audit — is auth, profiles and firm onboarding what the task file asks for?

**Audited against:** [docs/tasks/17_auth_profiles_and_firm_onboarding.md](tasks/17_auth_profiles_and_firm_onboarding.md)
(all five phases, item by item) and the plan sections it cites — *Resolved Design
Clarifications* (Login Flow, Sign Up & Team Onboarding, Firm Mode Detection),
Database Schema (`profiles`, `firm_invites`, `firm_members`), Sync Plan §5 (Offline
Session Expiry) — in [implementation_plan.md](implementation_plan.md) (Revision 2.4).

**Method.** Three independent sources, not one reading:
1. the source as written — the auth/profile/firm services in `lib/features/`, the ARB
   copy, and the two screens compared **string by string** against
   `mockup_html_screens/settings_onlineSync_login` and `settings_onlineSync_signup`;
2. the live project `lsthasywrdrhuuxnykau` — catalogue queries (`pg_proc`,
   `pg_policies`, `pg_class`, `information_schema.column_privileges`, `pg_trigger`)
   plus four rolled-back behavioural runs: `ensure_firm` end to end, the full
   invite lifecycle (create under RLS → join → used → revoke → refused), the
   sign-in/`profiles` trigger path, and `abandon_provisional_account` against ten
   fixtures (one removal, nine refusals with their reasons);
3. the suites — 110 tests in the nine Task 17 files (14 + 11 + 14 + 12 + 9 + 19 + 6 +
   10 + 15), the whole repository at **922 passed**, and `flutter analyze` clean.

**Verdict.** Task 17 is implemented: **21 of 21 phase items pass** (one of them,
Phase 4 item 2's branched-logout half, passes only in the sense that nothing is
destroyed — see *Deviations* 6), all five phase gates pass, and **all four Addendum
items pass**. Addendum 3 was the single failure when this audit was written — its
retryability half was implemented and tested but the protected server cleanup did
not exist — and it was **closed the same day** by
`20260929120000_abandon_provisional_account.sql`, which was applied to the project
and then run against ten fixtures (see the Addendum table). Eight findings remain
below with what closing each one costs; two of them — the mockup contradiction that
Phase 2 item 3 asserts, and where role/subscription state is displayed — were closed
by **user ruling**, not by the code.

---

## Phase 1 — Supabase Client Integration

| # | Requirement | Verdict | Evidence |
|---|---|---|---|
| 1 | Add `supabase_flutter` (+ `connectivity_plus`, deferred from Task 01) to `pubspec.yaml` | **PASS** | `supabase_flutter: ^2.17.2`, `connectivity_plus: ^7.3.1`, plus `google_sign_in: ^7.2.0` for the native ID-token flow the user chose. Nothing else in the repo imports a networking package; `Part A`'s no-network rule is superseded for this task only. |
| 2 | Initialise Supabase with the project URL and anon key from a non-committed config; **ask the user** how to supply secrets | **PASS** | The user chose `--dart-define-from-file=env.json`; `env.json` is git-ignored (`.gitignore:70`) and untracked, `supabase/.env.local` likewise. `lib/core/constants/supabase_config.dart` reads the three values at compile time and exposes `isConfigured`. AGENTS.md rule 12 is enforced *in the app*: `isAllowedUrl` accepts only a URL naming `lsthasywrdrhuuxnykau` and refuses `ykbwzodadijtiizobehk`, so a wrong value runs the offline app instead of reaching the wrong project. No credential is committed anywhere — the only `eyJhbGciOi` in the tree is a negative assertion in `test/supabase/schema_contract_test.dart`. |
| 3 | Implement `features/auth/data/`: `auth_repository.dart` (fulfilling the Task 01 `AuthRepository` interface) and `local_auth_service.dart` | **PASS** | `AuthRepository` is the typed boundary (identity, `sessionEvents`, `restoreSession`, sign-in/up, Google, recovery, `signOut`, `isAvailable`) with `UnavailableAuthRepository` for an unconfigured build; `SupabaseAuthRepository` is the only file touching Supabase Auth or the Google SDK, and `mapAuthFailure` classifies SDK errors into `AuthFailureKind`. `LocalAuthService` caches only the last identity (id + email), the gate flag and a pending invite code — no password, token or recovery code is stored there. 14 tests in `test/features/auth_bootstrap_test.dart`, including the rule-12 refusal. |
| 4 | Session bootstrap on start: restore any persisted session; **never** block app start or local DB access on session validity | **PASS** | `main.dart:52` skips `Supabase.initialize` entirely when `!isConfigured`, and the init is wrapped in `catch` (`main.dart:71`) so a backend failure logs by error type and the diary opens anyway. The session lives in `SecureSessionStorage` behind the SDK; nothing in the open path awaits it. The gate reads local facts only (`auth_gate.dart`). |

**Phase 1 gate** — `flutter analyze` clean, version entry written: **PASS** (`0.0.301`).

## Phase 2 — Login & Sign-Up Screens

| # | Requirement | Verdict | Evidence |
|---|---|---|---|
| 1 | Unified Email + Password login, no Owner/Associate split; determine role and firm membership dynamically from `profiles` after sign-in | **PASS** | `login_screen.dart` renders exactly the mockup card (see item 3) and contains no role choice; role and firm come from the cached `profiles` row through `account_mode.dart` (`accountRoleProvider`, `firmModeProvider`), never from a login-time answer. |
| 2 | Two sign-up paths — Individual, and Join Existing Firm with the single-use Invite Code redeemed via `join_firm(code)`, handling success / `invalid_code` / used-or-revoked / too-many-attempts | **PASS** | `signup_screen.dart` offers Account Type (Individual / Join Existing Firm) and reveals the invite field; the individual path relies on the Task 16 sign-up trigger (`on_auth_user_created → handle_new_user`, verified live) for the `individual`/`free`/`firm_id = null` profile row. Redemption goes through `SupabaseFirmRepository.redeemInvite` → `join_firm`. All four outcomes are pinned: valid code joins, `invalid_code`, already-member, and the rate limit (`auth_signup_test.dart`, 14 tests). Behaviour proven live, not just mapped: a lower-case, space-padded code joins (`joined`, member row created, `profiles` relinked), the *same* code then answers `invalid_code` for a second account, a revoked code answers `invalid_code`, and `anon` is refused EXECUTE. |
| 3 | "No mockup HTML exists for these screens" — follow the design system and confirm layout with the user | **PASS, task file wrong** | Both mockups exist (`mockup_html_screens/settings_onlineSync_login/code.html`, `..._signup/code.html`, each carrying a `screen.png`), and the user ruled they win. The built screens reproduce the mockup copy: *Sign in to your legal workspace, Email, Password, Forgot Password?, Login, Or continue with, Login with Google, Don't have an account?, Sign Up*; *Create Account, Join the secure ledger for legal professionals., Full Name, Bar Association, Email Address, Password, Must be at least 8 characters long., I agree to the… Terms of Service and Privacy Policy, Sign Up, Or continue with, Sign Up with Google, Already have an account?, Login*. The only textual differences are AGENTS.md rule 11 (Title Case: "Or Continue With", "Login With Google", "Sign Up With Google") and the two deliberate additions the mockup could not draw — the Account Type choice, and the Check Your Email state. |
| 4 | Auth error states: wrong credentials, unconfirmed email (confirmation on/off — **ask the user**), network failure with retry | **PASS**, with one unverifiable input | Twelve kinds render their own sentence through `authErrorText` (`auth_widgets.dart`), including wrong credentials, email-not-confirmed, and the network case; a cancelled Google sheet renders nothing. Both confirmation outcomes are handled (`SignUpSignedIn` / `SignUpConfirmationRequired` → the Check Your Email state), and the Code Sent state exists for recovery. *"With retry"* is the form's own resubmit, not a separate retry button — the typed failure is shown above the intact form. **Unverified:** the live `mailer_autoconfirm` setting is not readable from Postgres here (`auth.config` is not exposed), so which of the two paths a real sign-up takes is the user's dashboard's answer; the app is correct either way. |
| 5 | Route guard: unauthenticated → Login, authenticated → their configured landing page; existing local-only users never locked out; **one atomic identity-adoption transaction** before authenticated writes; fail closed against another account | **PASS** | `app_router.dart` sets `initialLocation` from `defaultLandingRouteProvider` and forces `AppRoutes.login` only when `authGateRequiredProvider` says so; its `redirect` sends a signed-in user off the auth routes back to their landing page. The gate requires sign-in only when there is no session, no cached account, no satisfied flag **and nothing the user authored** (`cases`, `notes`, `case_references`) — and a database that cannot be read is never a lockout. `IdentityAdoptionService.adopt` is a single `_db.transaction` over the **12** push/pull domain tables, rewriting `user_id` and the audit columns in queue payload, base payload and pre-mutation snapshot, re-keying both per-user preference tables, emptying the pull-only caches, recording `auth.adoption_provenance` and binding `auth.bound_user_id`; a different bound account raises `accountMismatch` having written nothing. 12 tests in `auth_gate_test.dart`. |

**Phase 2 gate** — `flutter analyze` clean, version entry written: **PASS** (`0.0.302`).

## Phase 3 — Profile & Firm-Mode Detection

| # | Requirement | Verdict | Evidence |
|---|---|---|---|
| 1 | Implement `ProfileRepository`: fetch/cache the `profiles` row; expose `role`, `firm_id`, `subscription_expiry`, `full_name` | **PASS** | `profile_repository.dart` pulls `profiles` and, for a firm member, `firms` and this user's `firm_members` row into the three pull-only caches; `subscriptionExpiryToEpochMs` converts ISO-8601 / `Z` / offset / numeric / `DateTime` and yields **null rather than a guess** when unreadable; `permissions_synced_at` is stamped on success. A failed refresh is non-fatal and non-destructive (`UnavailableProfileRepository` for an unconfigured build). |
| 2 | Runtime mode detection: `firm_id != null` → Firm mode, else Individual; **all** firm-conditional UI from this single provider | **PASS** | `account_mode.dart` is the single source: `firmModeProvider` is `firm_id != null` verbatim, and `accountRoleProvider`, `firmRoleProvider`, `canAdd/canEdit/canDeleteDirectlyProvider`, `canManageFirmProvider` and `permissionsSyncedAtProvider` all derive from the same cached rows. A firm member with no cached membership row **fails closed** (no add/edit/delete). 19 tests. |
| 3 | Wire Profile and Manage Account to real data (name, role, subscription state display) | **PASS, with a user ruling** | The hardcoded sample name/email are gone; logout really signs out, empties the caches and returns to Settings; Change Password reuses the emailed-code reset; Purchase opens the existing paywall. Neither mockup has a row for role or subscription, and the mockup wins, so the user ruled those go behind the existing **Subscription Details** row in a sheet this task adds (Role, Firm in firm mode, Free / Premium Until 12/01/2027 from the single `subscription_expiry + 48h` rule). `profile_picture_test.dart` was moved off the mockup's sample name for the same reason. |
| 4 | On launch/resume/reconnect refresh `firm_members` permissions and update `permissions_synced_at` | **PASS** | `AccountRefreshScope` runs after the first frame, awaits `authViewModelProvider.future` first (a cold start's first frame has no identity — the test caught that), and listens for the false→true connectivity transition; `SessionStatus`'s provider and the scope both call the one `accountRefreshProvider`. Reconnect is Phase 4's `connectivity_plus` deferral, first used there. A redemption calls the same refresh so a new associate's flags are cached before the first case write. |

**Phase 3 gate** — `flutter analyze` clean, version entry written: **PASS** (`0.0.303`).

## Phase 4 — Offline Session Handling

| # | Requirement | Verdict | Evidence |
|---|---|---|---|
| 1 | Never gate local data on JWT validity | **PASS** | Nothing consults the token before opening the database: the router gate reads local facts (`auth_gate.dart`), and `SessionStatus` is only ever a *notice* mounted above the navigator. `connectivity_monitor.dart` reports the **link, not the internet** (a captive portal counts as connected) and answers "reachable" when the plugin is absent, so a wrong answer costs one failed request, never a wrong screen. |
| 2 | On an online refresh failure require re-login, **never wipe local data while `sync_queue` has pending rows**; route the re-login path through the branched logout flow (Task 19) | **PASS for the destructive half only** | Re-login is required (`SessionStatus.reLoginRequired`) and the notice's single action goes to Login; **nothing is removed** — a rejected session leaves `cases` and a pending `sync_queue` row exactly as they were (asserted by test). The *branched* half — sync-then-wipe / block-and-offer-export / auto-export — is not implemented and is Task 19's by the plan; see *Deviations* 6. |
| 3 | Distinguish "offline, token stale" from "online, session invalid", with clear localized messaging | **PASS** | `SessionStatus` = `signedOut` / `usable` / `staleOffline` / `reLoginRequired`, decided in one provider: the same rejection resolves to `reLoginRequired` online and `staleOffline` offline, unknown connectivity resolves to *online* (the actionable choice), and the notice appears only for the online rejection (`auth_sessionExpired` + `auth_sessionExpiredAction` in both ARBs). |
| 4 | Tests: offline open with an expired token still reaches case data; an online refresh failure triggers re-login without touching the local DB | **PASS** | 10 tests in `test/features/offline_session_test.dart`, green, covering all four states, the offline launch reading case data, the queue row surviving, the notice's routing, and the reconnect refresh. |

**Phase 4 gate** — `flutter analyze` clean, version entry written: **PASS** (`0.0.304`). The gate's **manual device step** (login → airplane mode → restart → data accessible) is **OWED by the user** — it cannot be run from here.

## Phase 5 — Invite Generation & Redemption (Owner Side, Minimal)

| # | Requirement | Verdict | Evidence |
|---|---|---|---|
| 1 | Owner-side invite service: cryptographically random, normalised code with **≥ 50 bits**, plaintext displayed **once**, only its SHA-256 hash inserted, never stored or logged | **PASS**, with the display surface deferred | `inviteCodeAlphabet` is Crockford Base32 (32 symbols, no `I`/`L`/`O`/`U`) and `inviteCodeLength` is 10, so the space is `32^10 = 2^50` exactly; symbols come from `Random.secure()`. `inviteCodeHash` is `sha256(trim+uppercase)`, byte-identical to the server's `sha256_hex(upper(btrim(code)))` — verified live, because a lower-case, space-padded code joined a real firm. `inviteInsertRow` is the only object that reaches `firm_invites` and carries `code_hash` with no shape of the plaintext; `GeneratedInvite.toString()` omits the code, and nothing caches, preferences or logs it. The plaintext is *returned* once for display — the display itself is Task 20's UI, as Phase 5's own preamble says. The owner insert was also exercised live under RLS (`firm_invites_insert_owner`). |
| 2 | Revoke-unused-invite (sets `revoked = true`; RLS restricts to the owner) | **PASS** | `revokeInvite(id)` does exactly the one update; live: `firm_invites` carries three policies (select/insert/update, all `is_firm_owner(firm_id)`, insert additionally `created_by = auth.uid()`) and **no DELETE policy** — an unused code is revoked, never removed. Proven live: after `revoked = true`, `join_firm` answers `invalid_code`. |
| 3 | Online-only rule for invite generation/revocation and all firm administration, showing "Connect to the internet to manage your firm" when offline | **PASS** | `_requireOnline()` runs **before** the request and raises `AuthFailureKind.firmAdminOffline`, whose sentence is `auth_errorFirmAdminOffline` in both ARBs; the Manage Associates surface renders it when offline and nothing new when online. Unknown connectivity counts as online (Phase 4's choice). Redemption is deliberately unguarded — see *Deviations* 2. |
| 4 | `flutter test`: valid code joins the firm; used or revoked codes are rejected | **PASS** | Both halves exist at the app boundary and on the server. App: the sign-up suite drives valid-join / invalid-code / already-member / rate-limit through the real screens and view model; `test/features/invite_onboarding_test.dart` (15 tests) pins the parse mapping that makes a used code and a revoked one indistinguishable (`invalid_code` → `AuthFailureKind.invalidCode`). Server, live: `joined` → member row + relinked profile; the same code for a second account → `invalid_code`; a revoked code → `invalid_code`. |

**Phase 5 gate** — `flutter analyze` clean, invite tests pass, version entry written: **PASS** (`0.0.305`).

---

## Alignment Addendum (Revision 2.4)

| # | Requirement | Verdict | Evidence |
|---|---|---|---|
| 1 | Before authenticated repositories become writable, atomically adopt placeholder rows, queue payloads/base snapshots, notification preferences and attribution; preserve provenance separately; fail closed cross-account | **PASS** | See Phase 2 item 5: one transaction, 12 domain tables, three JSON payload shapes rewritten, both preference tables re-keyed, caches emptied, `auth.adoption_provenance` recorded, `accountMismatch` raised with nothing written. 12 tests. |
| 2 | `ProfileRepository` caches `full_name`, `role`, `firm_id`, `subscription_expiry` in the Task 03 pull-only cache, converting TIMESTAMPTZ to epoch ms; invalidate on logout/account switch | **PASS** | Pull-only repository + the pure conversion function; `AuthViewModel.signOut()` calls `invalidate()` and adoption empties the caches on an account switch — one account's cached name can never be shown to another. |
| 3 | A failed `join_firm` keeps onboarding retryable; **an abandoned onboarding invokes a protected server cleanup that removes the provisional profile/Auth account so it is treated as never created** | **PASS** | Retryable: a rejected code leaves the account, the form and the code in place (`pendingInviteCode` still holds it), cleared only on success. **The cleanup is implemented and invoked**: `20260929120000_abandon_provisional_account.sql` adds the guarded `SECURITY DEFINER` function, `FirmRepository.abandonOnboarding()` calls it, and `AuthViewModel.signOut()` fires it best-effort *before* the session ends — only when an unredeemed invite code says this device has an unfinished join-firm onboarding, so a signed-in lawyer with a real diary can never reach it (and the server refuses on its own unless the account is provably empty). Live, ten fixtures: a provisional account is **removed** with its profile, per-user preferences and failed-attempt ledger cascaded away, while firm ownership, a firm on the profile, firm membership, cases, notes, custom courts, administrator rights, a payment and a subscription each returned `not_provisional` with that exact reason — nine of ten accounts survived. App-side: 5 new tests in `invite_onboarding_test.dart`. |
| 4 | Preferences stay per-user during individual→firm transitions and are never merged into firm-shared reference data | **PASS** | `_rekeyPreferences` moves `user_preferences` and `case_notification_preferences` from the placeholder id to `accountCacheUserIdProvider`'s id under the account, with the rule written where it is enforced ("preferences follow the *person*, never the firm"); nothing in the redeem path writes a preference into a domain table. |

---

## Completion gates

| Phase | Gate | Verdict |
|---|---|---|
| 1 | `flutter analyze` clean; version entry | **PASS** — `0.0.301` |
| 2 | `flutter analyze` clean; version entry | **PASS** — `0.0.302` |
| 3 | `flutter analyze` clean; version entry | **PASS** — `0.0.303` |
| 4 | `flutter analyze` clean; **offline auth manual test on a device**; version entry | **PASS on the code gate** (`0.0.304`); device test **OWED** |
| 5 | `flutter analyze` clean; invite tests pass; version entry | **PASS** — `0.0.305` |
| all | `python tool/record_version.py --check`; `dart run tool/generate_all_supabase_sql.dart --check`; full `flutter test` | **PASS** — version log clean, ledger clean (16 migrations), seed clean, **922 passed** |
| all | Supabase write path | **PASS** — 17 versions recorded on `lsthasywrdrhuuxnykau`; `ensure_firm` and `abandon_provisional_account` verified functionally |

---

## Deviations, and what each one costs

1. ~~**Addendum 3's abandoned-onboarding cleanup is not implemented.**~~ **Closed
   2026-09-29** by `20260929120000_abandon_provisional_account.sql`: a guarded
   `SECURITY DEFINER` that removes the caller's own account only while it is
   provably provisional (no firm, individual role, no subscription, no authored or
   custom rows, no firm/payment/admin/sync activity) and answers
   `{"status":"not_provisional","reason":…}` otherwise, invoked from sign-out while
   the session still exists. Applied, then verified against the live project; 5 app
   tests cover the offline guard, the wiring and the two failure paths.
2. **`redeemInvite` is not behind the offline guard.** Task item 3 says firm
   administration is online-only; redemption is the associate's onboarding, whose
   failure is already classified from the transport as `AuthFailureKind.network`
   and whose copy ("No connection. Check your internet and try again.") reads
   correctly on the sign-up screen. Showing an owner-side sentence there would be
   the wrong sentence, so the guard covers the owner side only. Cost of changing
   it: one `await _requireOnline()` plus one test.
3. **Phase 2 item 3 asserts a fact that is false.** It says no mockup exists for the
   login and sign-up screens; both do, and both say the shipped screen is a stub
   while the mockup is the design. Closed by **user ruling** (mockups win), so the
   screens were built to them. The task file should be corrected rather than the
   code.
4. **The offline sentence is rendered on a screen that is still a stub.** No mockup
   exists for Manage Associates, and the task file puts its UI in Task 20, so
   Phase 5 adds only the one line the rule needs. Task 20 replaces that body —
   nothing here should be read as the Manage Associates design.
5. **Role and subscription state are not in either mockup.** Closed by user ruling:
   they sit in a details sheet behind the existing Subscription Details row, so
   both mockup bodies are unchanged.
6. **Phase 4 item 2's branched-logout half is deferred.** Task 17 requires re-login
   without data loss and says the branched flow is "implemented fully in Task 19":
   today the re-login path removes nothing at all, which satisfies "never silently
   lost" trivially, and Task 19 owns sync-then-wipe / export / auto-export. The same
   boundary applies to sign-out: `clear()` drops the cached identity and the gate
   flag, but a device that already holds the user's own cases still opens its diary
   on the next launch — the deliberate "never locked out of your own diary" rule,
   not an oversight.
7. **Google sign-in is coded but unrunnable in this checkout.**
   `GOOGLE_WEB_CLIENT_ID` is empty, and `signInWithGoogle` fails closed with
   `AuthFailureKind.unavailable` when it is; the Google provider must also be
   enabled in the dashboard. **Owed by the user.**
8. **Three settings are not verifiable from Postgres** and so are neither confirmed
   nor refuted here: e-mail confirmation on/off (`auth.config` is not exposed),
   whether the Reset Password template carries `{{ .Token }}` (the in-app code flow
   needs it), and Task 16's Realtime Authorization toggle. All three are
   dashboard-side. **Owed by the user.**
9. ~~**The domain write path still stamps the Part A placeholder.**~~ **Closed**
   in `0.0.309`, ahead of the sync service rather than inside it, because every
   write this app makes is already stamped through one seam. `adopt` now ends by
   calling the new `LocalIdentityService.bindAccount(identity.userId)` — after the
   transaction commits, never on a refusal — so `getId()`, and with it
   `BaseLocalRepository.currentUserId`, `SyncWriteHelper.currentUserId`,
   `accountCacheUserIdProvider` and the two writers that reach for the service
   directly (`LocalSettingsRepository._userId`, the Add/Edit Case sheet's
   `case_notification_preferences` write) all return the account id from the
   moment an account is bound. Reads were already keyed correctly. `_rekeyPreferences`
   now also **merges** the two keys newest-first on every launch, whichever direction
   the newer row is on, so a preference row a stale-id write left behind is repaired
   rather than stranded.

## Ranked follow-ups

1. ~~**Addendum 3's protected cleanup**~~ — done: `20260929120000_abandon_provisional_account.sql`,
   applied and verified live (see *Deviations* 1).
2. ~~**The domain write path's identity sweep**~~ — done in `0.0.309`: binding the
   device id on adoption covers all ~10 repositories plus both direct writers, and
   `test/features/write_identity_test.dart` (12 tests) pins the invariant.
3. **Commit the three verification runs** (`ensure_firm`, the invite lifecycle and
   `abandon_provisional_account`) as rolling-back `supabase/tests/*.sql` scripts,
   so the owner-side and cleanup paths stay covered by the repository rather than by
   hand runs.
4. **The branched logout flow** (Task 19) — the one place unsynced work may be
   discarded, and only with the user.
5. **The user's dashboard work** — Google provider + Web client ID, the recovery
   template's `{{ .Token }}`, Realtime Authorization, and the two device passes
   (`part_a_manual_test_pass.md`, Phase 4's airplane-mode run).

*A process note worth keeping:* Task 17's `ensure_firm` shipped a defect
(`firms.created_at` is a `timestamptz` and the function wrote a bigint `v_now` into
it) that only its **first execution** revealed — the same lesson Task 16's first
apply taught. Reading a migration is not verifying it; where a new server function
has no committed test, running it once against the project is what closes the gap.

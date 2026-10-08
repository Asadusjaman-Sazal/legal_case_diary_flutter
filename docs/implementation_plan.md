# Legal Case Diary — Flutter App Implementation Plan

> **App Name:** Legal Case Diary (লিগ্যাল কেস ডায়েরি)
> **Target Users:** Individual lawyers & Law Firms in Bangladesh
> **Core Purpose & Target Audience:** The app serves as a digital clerk and ledger for individual lawyers and multi-user law firms (Chambers) in Bangladesh. Its primary goal is to digitize the traditional "cause list" diary, ensuring lawyers never miss a hearing date while maintaining all case details, notes, and precedents securely in their pockets.
> **Platform:** Flutter (Mobile-first, Android & iOS)
> **Backend:** Supabase (PostgreSQL + Auth + Realtime)
> **Offline DB:** Drift (SQLite wrapper for Flutter)
> **Last Updated:** July 17, 2026 (Revision 2.3 — lossless pull cursors, idempotency receipts, timestamp boundaries, admin authorization, encrypted local storage/backups, and deletion-review hardening applied)

---

## Document Map (for splitting into task files)

This plan is organized into six parts so it can be divided into small, bite-sized task files during the build phase:

| Part | Contents |
|---|---|
| **Part I — Product Decisions** | Resolved Design Clarifications; Screen Analysis & Theming Summary |
| **Part II — UI Specifications** | Detailed Cases and Settings Related Screens Specifications (§1–§10) |
| **Part III — Architecture** | Proposed Architecture; Folder & File Structure |
| **Part IV — Data Layer** | Database Schema; Row-Level Security (RLS) Strategy |
| **Part V — Sync, Subscription & Platform Systems** | Detailed Sync Plan & Multi-User Workflow (§1–§12.4) |
| **Part VI — Process** | Development Workflow & Coding Standards; Verification Plan |

## Revision 2.3 Change Summary (Correctness, Security & Implementation Clarity)

- Replaced timestamp-only pull checkpoints with per-table composite `(server_updated_at, id)` cursors committed after each local page, preventing equal-timestamp and crash-boundary data loss.
- Defined deterministic per-mutation savepoint behavior and the server-internal `mutation_receipts` ledger, including request-hash validation and retention.
- Clarified local epoch-ms versus PostgreSQL `TIMESTAMPTZ` boundaries and Bangladesh civil-date handling; aligned subscription expiry and payment arithmetic.
- Added a concrete immutable `app_admins` registry and safe `SECURITY DEFINER` authorization contract for payment approval.
- Required SQLCipher-compatible local database encryption, OS-backed key storage, encrypted authenticated backups/diagnostics, and failure-safe key-loss behavior.
- Hardened delete-request approvals against stale target snapshots, clarified server-side cascade tombstones, increased invite-code entropy, and made failed-attempt recording transactionally durable.

## Revision 2.2 Change Summary (Concurrency & Operational Hardening)

- Replaced client-authoritative LWW versions with server-assigned optimistic concurrency (`base_version`/`expected_version`, structured conflicts, server increments only).
- Added queue conflict reconciliation and three-way merge metadata (`mutation_id`, `base_payload`, changed fields); later edits are preserved/rebased or marked `conflict_pending`, never silently discarded.
- Made extended-offline recovery a persistent mutation lock before export; added stale-permission rollback, idempotent already-deleted request handling, and a user-facing Sync Status/Diagnostics recovery screen.
- Clarified that accepted case mutations create immutable `case_history` atomically in `push_changes`; rejected attempts go only to `conflict_log`.
- Added server-controlled payment timestamps and an admin-only atomic `approve_payment` RPC; added the invite-attempt lookup index.
- Required delta pulls after uncertain Realtime continuity, versioned/idempotent pre-seed migrations, bounded page-by-page PDF raster fallback, and stable court-category IDs. Appellate Division and High Court Division are themselves court categories for scoping courts, steps, case types, and representation roles.

## Revision 2.1 (of the Implementation Plan) Change Summary (Follow-up Hardening Fixes)

- **`join_firm` rate-limit storage specified:** a new server-internal `invite_attempts` table (no direct client access) is checked and maintained inside the `join_firm` RPC — 5 failed attempts per 15 minutes per user, with lazy cleanup in the RPC itself.
- **`firms.subscription_expiry` mirroring mechanism named:** a dedicated `mirror_owner_subscription_to_firm` trigger (`AFTER UPDATE OF subscription_expiry ON profiles`, owner rows only) is now the only write path for the column, created in the same migration as the payment-approval trigger.
- **Payment rate limit enforcement moved to a `BEFORE INSERT` trigger** on `payment_submissions` (RLS can't count rows per 24h window); the client-side check is retained as UX only.
- **Pull cursors are per-table and composite:** each synced table keeps a crash-safe `(server_updated_at, id)` cursor in the local database; timestamp-only/shared cursors can skip equal-timestamp or inter-table commits.

## Revision 2 (of the Implementation Plan) Change Summary (Historical; concurrency wording superseded by Revision 2.2)

> **Audit note:** Revision 2.2 supersedes the LWW comparator and winner/loser language formerly used in this historical summary. The current and only implementable contract is server-authoritative optimistic concurrency with exact `base_version` checks, structured conflict responses, and explicit three-way reconciliation. No client timestamp, submitted version, or editor UUID may decide write acceptance.

- **Delta-pull correctness:** pulls filter on server-assigned `server_updated_at` (trigger-maintained), never client `updated_at`; pull cursors set from server timestamps (and maintained **per-table** as of Revision 2.1).
- **Clock-skew-proof conflicts (superseded implementation):** per-row monotonic `version` remains the revision identifier, but the server alone assigns it. Updates require an exact `base_version` match; `updated_at` and editor UUID are audit/display metadata only.
- **Atomic push pipeline:** all sync writes go through a single `push_changes` Postgres RPC (optimistic-concurrency enforcement, structured conflict responses, FK-safe ordering, premium gate, idempotent mutations, serialized FIFO worker, retry policy, compaction matrix).
- **Per-device offline reset (firm mode only):** extended-offline check is device-local, threshold raised to 150 days (buffer under 180-day tombstone retention), with an automatic authenticated encrypted safety archive containing the versioned JSON backup before any wipe. An **individual** account is never locked or asked to rebuild — see Resolved Design Clarifications, "Extended-Offline Recovery Lock Applies to Firm Mode Only".
- **Firm-shared config:** `court_categories`, `case_categories`, `courts`, `steps`, `case_types`, `on_behalfs` gain `firm_id` + firm-wide SELECT; `case_history` gains denormalized `user_id`/`firm_id`; `case_types` additionally link to `case_categories` when a court category defines them.
- **Realtime:** "Broadcast from Database" (tiny `{table, id}` pings on private firm/user topics) replaces `postgres_changes` subscriptions.
- **Logout flow branches** for premium-online / premium-offline / free users (no sync deadlock); the safety copy is **offered, never mandatory**, in the Backup to Local Storage format.
- **Invite system hardened:** `firms.secret_key` and locally stored password hashes removed; new `firm_invites` table with hashed single-use revocable codes redeemed via a rate-limited `join_firm` RPC.
- **Subscription authority:** premium entitlement is always *derived* from `subscription_expiry` (+ 48h grace) — never a stored status flag; expiry always enters the 48h grace window first; lapsed-premium users keep all their cases.
- **Free tier clarified:** individual-only, never syncs; the old "Pre-Push Subscription Count Validation" section removed (its race is impossible); upgrade triggers an initial backlog push.
- **Removed `cases.status`:** disposal is derived from `last_step` against the disposed-step set (single source of truth).
- **`delete_requests`** added to `sync_queue` entity types (offline-capable) with "Deletion request sent to Admin/Owner" toast; firm administration declared online-only.
- **RLS realism:** delete-transition (`can_delete`) enforced via trigger/RPC (RLS cannot compare OLD vs NEW); firm members can read each other's profiles; unsynced local tombstones never purged.
- **Battery:** 2–3 s micro-batch write-through (radio tail energy), `connectivity_plus` stream instead of polling, 60 s resume-pull throttle, exact-alarm permission handling (Android 14) + `BOOT_COMPLETED` rescheduling, platform abstraction for the Windows port.

---

## Resolved Design Clarifications (User Approved)

The following design decisions have been resolved based on user feedback:
- **The Lawyer's Own Details Live on the Account (`profiles`).** The five fields edited at Settings > Accounts & Profile > Profile — full name, bar association, membership number, office address and mobile number — are the account holder's own record, not device state, so a re-install or a second phone must not ask for them again. `profiles` stays a **pull-only cache** for everything else, and the shape of the one exception is deliberate: the client writes the holder's **own row only** (`profiles_update_self`, Phase 4) and **only those columns** (column-wise grants, Phase 3 + `20260929130000_profiles_personal_details.sql`), through a plain PostgREST PATCH — no queue, no RPC, no generic sync behavior. `email` is a **server-owned mirror** of `auth.users.email` (sign-up and e-mail-change triggers) and is never client-writable. Two rules govern the two copies: the account's values **fill the device's blanks only** — a detail the user typed on this device is never overwritten by a pull — and a save that could not reach the server is **retried** on the next launch, resume or reconnect rather than silently left behind. Saving shows the truth about which copy it reached: the toast says *Profile saved* only when the account accepted the PATCH, and the offline variant only when it did not (nobody signed in, no backend, or no connection) — the fields themselves are always saved on the device first, with no country-code prefix box beyond the editor's fixed `+88`, so the user types the local number with its leading `0` (`01XXXXXXXXX`).
- **App Name:** Official names are **Legal Case Diary** in English and **লিগ্যাল কেস ডায়েরি** in Bengali.
- **Justice Ledger:** This is the main theme and instruction file from the Google Stitch front-end design, not a financial ledger. All theming and styles must align with it. Reference: legal_case_diary_flutter\mockup_html_screens\justiceLedger\DESIGN.md
- **English Typography:** **Manrope** for headlines, **Inter** for body text, and **IBM Plex Sans** for labels and data (like case numbers).
- **Bengali Typography:** **Tiro Bangla** must be used for Bengali text throughout the app.
- **Localization (l10n):** The app UI supports both **Bengali** and **English**. The user can switch language in Settings. Implemented using Flutter's `flutter_localizations` package + `intl` package with `.arb` files. Bengali is the default locale for Bangladeshi users.
- **Case Numbering:** `case_number` is a single text entity (e.g., "110/2021"). It will not be split into separate number and year fields.
- **Date Format:** Dates display as `DD/MM/YYYY` (customary in Bangladesh). Drift stores local values as Unix epoch milliseconds; Supabase uses the explicit `TIMESTAMPTZ`/`BIGINT` boundary defined in the Database Schema. Hearing/next dates are Bangladesh civil dates and must not shift with UTC conversion. **Next Date Format Rule:** Show "Today" or "Tomorrow" when the configured local civil date matches; otherwise show `DD/MM/YYYY`.
- **Login Flow:** A unified, world-class single login screen (Email + Password) for everyone. No confusing "Owner vs Associate" separate screens. The app determines the user's role and firm membership dynamically upon login by reading their `profiles` record.
- **Sign Up & Team Onboarding:** 
  - **Individuals & Firm Owners:** Use the standard Sign Up screen to create a new account (starts as an Individual, converts to Firm automatically when an associate is added).
  - **Associates (Joining a Firm):** The Firm Owner generates a short, **single-use Invite Code** from the app (OTP-style: usable exactly once, no expiry, revocable by the owner before use). The Associate downloads the app, goes to Sign Up, selects "Join Existing Firm", and enters the Invite Code along with their details. Redemption happens through a rate-limited, `SECURITY DEFINER` `join_firm(code)` RPC against the hashed code in the `firm_invites` table (see Database Schema) — single-use + server-side rate limiting makes brute-force guessing infeasible while keeping the code short and typeable. This securely links them to the firm.
- **The Legal Documents Are Readable Before Sign-Up (follow-up):** the Sign Up card links to the Terms of Service and the Privacy Policy before an account exists, so the router's sign-in gate exempts exactly those two routes (`/settings/about/terms`, `/settings/about/privacy`) from its "not signed in → Login" rule. They are the same routes and the same `LegalDocumentScreen` that Settings > About opens, so a visitor sees the one document screen rather than a second copy; both app stores also require the documents to be reachable before sign-up. Every other non-auth route still sends a not-signed-in visitor to Login. They are also **top-level routes rather than shell routes**: inside the shell a document opened from Sign Up sat on the shell's nested navigator with nothing beneath it, so its back button did nothing; as full-page routes on the root navigator its back button returns to Sign Up or to About, whichever opened it. Leaving the shell also left them the only screens that inset nothing: every shell screen is wrapped by `AppShellRoot`'s own `SafeArea(top: true)`, so a top-level route has to inset itself or its app bar paints its white surface up behind the status bar. The document screen therefore wraps its own `SettingsSubPageModal` in `SafeArea(top: true, bottom: false)` — the same inset, and the same reason, as the paywall's (0.0.402).
- **Firm Mode Detection:** The app determines mode at runtime from the user's `profiles` record. If `firm_id` is non-null, the user is in Firm mode. Firm Owners have `role = 'owner'`; Associates have `role = 'associate'` or `role = 'viewer'`. Individual lawyers have `firm_id = null`.
- **Firm/Associate Model & Syncing:** Multi-user chamber setups use a single main Supabase account (firm owner) with sub-accounts. If the internet connection is lost in Firm mode, the app continues to work as usual and saves changes in the local database. When back online, changes are pushed to Supabase and remote updates are pulled.
- **Bottom Navigation Bar:** Contains 4 default tabs: Overdue Dates, Daily Cause List, Active Cases, and Upcoming Cases. Users can customize this in settings.
- **Calendar & Pickers:** The calendar with case count badges (showing count of today's hearings over the date and monthly counts under the month name) is *only* shown on the Daily Cause List calendar picker. All other pickers are simple date selectors auto-defaulting to today's date.
- **Print vs Share:** Separate buttons. Print generates a formatted PDF of the current screen (Daily Cause List, Active Cases, Disposed Cases, etc.) in a user-selected layout. Share invokes the Android native sharing utility to share the app.
- **FAB (Add New Case):** Floating action button appears on all main case screens except the Disposed Cases screen.
- **Form changes:** Petitioner and Respondent input boxes include a line worth of extra space for a "Lead Counsel:" text field.
- **Client Representation & Role (`on_behalf_id`):** The `on_behalf_id` field in the database stores the representation role selected from the `on_behalfs` table (e.g., Plaintiff, Defendant, Accused, Appellant). The client's actual name is not stored in a separate column; it is extracted at runtime: if we represent the Plaintiff/Petitioner, the client name is the value of the `petitioner` field. If we represent the Defendant/Respondent/Accused, the client name is the value of the `respondent` field.
- **Party Phone — one column only, final (`cases.party_phone`):** A case stores exactly **one** nullable phone number, `party_phone`, and it is the **represented client's** number (resolved at runtime from `on_behalf_id`). Revision 2.4's separate nullable `petitioner_phone`/`respondent_phone` columns were never shipped and are **withdrawn**: they must not be added to Drift, Supabase, migrations, seed logic, sync payloads, backups or tests, and their absence must not be reported as a gap. Part A already implements the single column (the Drift v2→v3 migration added `party_phone`, carried the legacy values over and dropped the two old columns) and the server mirrors it in `supabase/migrations/20260929100000_phase1_core_schema.sql`. Every other mention of the two-column split — the `cases` schema table below, §12.1's search fields, the Case Detail party card and the Revision 2.4 "Schema corrections" bullet — is superseded by this one, as is the two-column wording in task files 03, 05, 10, 14 and 16's Alignment Addendum 3.
- **AD/HCD Fields Belong to the Case, Not the Hearing (`cases`):** `case_category_id`, `honorable_judges`, `tender_number`, `previous_court_case`, `district_of_origin` and `result` are **case** columns — captured once when the case is filed and edited with it, exactly as the shipped Drift `Cases` row stores them. Revision 2.4's earlier placement of the five AD/HCD fields on `case_history` is **withdrawn**: they must not be added to `case_history` in Drift, Supabase, migrations, sync payloads, backups or tests, and their absence from `case_history` must not be reported as a gap. `case_history` keeps its own `result` as a per-hearing snapshot of `cases.result`. The `cases` and `case_history` schema tables in this document, and the server schema in `supabase/migrations/20260929100000_phase1_core_schema.sql`, already carry the corrected placement.
- **Overdue Indicator:** The red left border strip is applied *only* on overdue case cards.
- **Backdrop Blur (No BackdropFilter):** Flutter's `BackdropFilter` is a GPU-heavy operation that causes severe frame drops (jank) and device heating on 2GB RAM Android devices, which are common in the target Bangladeshi market. **Do not use real-time `BackdropFilter` anywhere in the app.** Instead, simulate blur effects using performance-safe alternatives: use a semi-transparent dark overlay (`Colors.black54`), a frosted-glass appearance via a blurred pre-rendered static asset, or a `Container` with `BoxDecoration` using colors/gradients. The visual result should be indistinguishable to the user while being completely jank-free.
- **Subscription Model**: Freemium model. Free tier supports up to 50 **non-deleted** cases (`is_deleted = false` only). Soft-deleted cases do **not** count against this limit. Client Management (Detailed profiles & Case history) and Daily Cause List are core free features. Document storage and Automated SMS are removed from the app roadmap. Premium tier unlocks unlimited cases, secure cloud sync/backup to Supabase, and multi-device synchronization. **The free tier is strictly individual and strictly local:** cloud sync is never active on the free plan, free accounts are single-device, and Firm mode (adding any associate) requires an active premium subscription. The app is nonetheless architected so that the moment a user goes premium, it is 100% ready to sync (see Sync Plan §2 and §6).
- **Pricing**: Highly accessible pricing localized for Bangladeshi practitioners, in four durations: **৳100 for 1 Month**, **৳285 for 3 Months**, **৳540 for 6 Months** and **৳960 for 1 Year**. There is no lifetime subscription. The three longer plans are discounted against the ৳100 monthly rate — 5% off ৳300, 10% off ৳600 and 20% off ৳1,200 — and the paywall shows that full price struck through beside the discounted one. (The 3 Months and 6 Months plans are a later addition, and the discounts on 6 Months and 1 Year are a further one; the plan keys are `monthly`, `quarterly`, `half_yearly` and `annual`, and `approve_payment` validates each plan's exact amount and extends by its own duration.)
- **Payment Method**: Option A (Manual MFS Verification). Users send money to personal/merchant numbers (bKash/Nagad/Rocket) and submit their Transaction ID (TrxID) and sender details in-app. The admin verifies payments and manually/semi-automatically activates the premium subscription. (Task 23 adds the **Admin Panel** so that verification happens in the app rather than in the Supabase SQL editor: see Resolved Design Clarifications, "The Admin Panel Is In The App, And The Registry Stays Closed".)
- **Firm Subscription:** The premium subscription is owned by the **Firm Owner**. All associates under that firm inherit premium access (sync enabled) as long as the owner's subscription is active. When the firm owner's subscription expires, **sync is disabled for every member of the firm** (owner and all associates). Data is not deleted; the app falls back to local-only mode.
- **Free User Data Recovery:** Free-tier users (who have no cloud sync) can export all their case data as a **JSON file** to local device storage from Settings > Backup & Restore. This is the only backup mechanism for free users and prevents permanent data loss when changing devices. The export format is **versioned** (a `schema_version` field in the JSON envelope) and validated on import, so future schema changes never break old backups. Because this is a free user's only safety net, the app shows a gentle monthly "Back up your data" nudge to free users.
- **The Admin Panel Is In The App, And The Registry Stays Closed (Task 23):** the MFS approval step previously had no UI — `approve_payment` was admin-gated, but the only way to reach it was for the owner to read `payment_submissions` in the Supabase SQL editor and run the function by hand. A registered admin now approves or rejects from the phone. Three decisions hold it together. **(1) The app asks "am I an admin?", it does not read the registry:** `app_admins` keeps RLS with **no policy of any kind** and a trigger that refuses any UPDATE to the grant itself, so a new SECURITY DEFINER `is_app_admin()` is the only way a client learns its own status. The registry additionally carries hand-filled `full_name` and `email` so a revoked admin can still be identified; that UPDATE refusal was **narrowed**, not lifted — `reject_admin_grant_change()` refuses `user_id`/`granted_at`/`granted_by` and permits the two descriptive columns, because an untouched trigger would have made them unwritable. **(2) No RLS is widened for the panel.** `payment_submissions` stays `user_id = auth.uid()` and `profiles` stays self-or-firm; instead one admin-gated `admin_list_payment_submissions()` joins the two and returns the five profile fields (full name, e-mail, bar association, membership number, mobile) with the TrxID and amount, so an admin reads the payers through a function rather than holding blanket read of every profile row. Approval reuses the existing `approve_payment` unchanged; `admin_reject_payment()` is new, records `rejected_by`/`rejected_at` alongside the existing `approved_by`/`approved_at`, and refuses an already-resolved submission so a rejection can never undo an approval. **(3) The panel is a navigation entry, not a settings sub-page:** one entry in `bottomNavTabDefs` (and one in the drawer) carrying `adminOnly`, offered only in Settings → View Settings to an admin — the same list drives the bottom bar and the drawer, so one entry is what makes the screen appear wherever the admin selected. Admin status is `false` while loading, so nothing appears before the server has said yes. Adding or removing admins is **not** in the app: that stays a service-role operation, because the one decision that must not be reachable from a phone is who is allowed to decide. **The screen's design reference is `legal_case_diary_flutter\mockup_html_screens\admin_panel\code.html`**, written from the shipped screen after Task 23 (the task file records why the mockup came second).
- **The Header's Sync Button Shows Two Clouds (follow-up):** the shared header button (`lib/shared/widgets/sync_button.dart`, carried by every case screen and by the Admin Panel) no longer wears the `Icons.sync` arrows. **Idle and a completed sync both wear the success cloud** (`cloud_done_outlined`), and **offline or paused always wears the network-off cloud** (`cloud_off_outlined`) — including while work is queued, because the red count is a fact about the queue while the cloud is a claim about the connection, and one must not be read as the other. A genuine sync **error** keeps its own mark (`sync_problem_outlined`), because "something went wrong" is not the same claim as "you are offline", and a running sync keeps its spinner. **This is a change to the header only:** Settings' Online Sync row, the Online Sync screen's own Sync Now button and status icons, the Sync Status badges, the conflict banner and the Guidelines entry are deliberately untouched, and their existing icons stay as they are. The eight header-bearing mockups (`allCases`, `disposedCases`, `dailyCauseList`, `caseReference`, `notes`, `overdueDates`, `upcomingCases`, `admin_panel`) draw the same success cloud in their headers; their `screen.png` files still show the previous glyph and are regenerated separately. **(0.0.399 — user request)** A **free** account is a third case those two clouds did not name, and it was wrong in both reported ways. It saw the **success cloud**: the checkmark claims this device's work is safely in the account, which cannot be true when cloud sync is never active on the free plan. And it saw a red **count** over it: every write path populates `sync_queue` (deliberately, so an upgrade is 100% ready to sync), so a free account's queue really does fill — but a count on a sync button promises a sync that will never come and reports the work as *waiting* when for this account it is not. `_showsOffCloud` now includes `!isPremium` (and takes precedence over the error mark, because the engine never runs), the badge condition is premium-only, and the tooltip answers the **entitlement** first — a free account never reads a queue count or *No Connection*, because both describe a mechanism it does not have. This settles the free-account half of Task 06's "disabled with a localized entitlement explanation", which the control's colour, label and tap already did. The **seven free-variant mockup headers carried the same defect** — a greyed `cloud_done` — and now draw `cloud_off`; the Admin Panel's header keeps the enabled success cloud, because it is reached only by a signed-in admin with sync available. **Everything else about the header is unchanged**, and the eight `screen.png` files still lag by this one glyph.
- **Build Credentials Seam (No Credential In The Repository):** the app's Supabase settings — `SUPABASE_URL`, `SUPABASE_ANON_KEY` (the publishable/anon key, never the secret key) and `GOOGLE_WEB_CLIENT_ID` — are compile-time constants read in `lib/core/constants/supabase_config.dart`, supplied only through `--dart-define-from-file=env.json`; `env.json` is git-ignored, and `SupabaseConfig.isAllowedUrl` refuses any URL that does not name `lsthasywrdrhuuxnykau` (and always the off-limits `ykbwzodadijtiizobehk`), so a wrong value runs the offline app instead of reaching the wrong project. Builds inject it through **`tool/flutter_with_env.dart`**, the one wrapper that appends the flag for debug (`run`) and release (`build`) alike and fails loudly when `env.json` is absent, so a release can never silently ship offline; a plain `flutter run`/`build` without the flag remains the intended offline shape. Added by the build-wrapper follow-up; the seam itself was Task 17's.
- **A Google Failure Is Reported, Not Swallowed (follow-up):** Android's Credential Manager returns the same `GoogleSignInExceptionCode.canceled` for a user dismissing the account sheet **and** for a Google-side configuration failure — a signing certificate not registered for `com.legalcasediary.app`, a wrong package name, or a `serverClientId` naming a client from another project — so the earlier mapping folded a broken Google setup into `cancelled`, which the login and sign-up screens deliberately render as *no message at all* (the sheet closes and the screen looks unchanged). `mapAuthFailure` now tells the two apart by the GMS code a real failure carries (`[16] Account reauth failed.`, matched as `^\[\d+\]` on the exception's description) and by the `clientConfigurationError`/`providerConfigurationError` codes, all of which raise the new `AuthFailureKind.googleSignInFailed`, with copy in `app_en.arb` and `app_bn.arb` ("Google Sign-In Could Not Complete. Please Try Again."); a description-less `canceled` stays deliberately silent, exactly as a dismissal should. The screens needed no change, because they already show a banner for every kind except `cancelled`. The cause itself is still server-side, so **both** signing certificates (debug and release, plus the Google Play app-signing certificate, because Play re-signs uploads with its own key) must be registered as Android OAuth clients in the same Google Cloud project as the Web client, with every signing-in account allowlisted under *Audience* while the OAuth consent screen is in testing — documented in `README.md` (*Google Sign-In Setup and Troubleshooting*) and, as a novice-level walkthrough of every client type and the Supabase side, in `docs/google_oauth_setup.md`.
- **Auth E-mail Links Return To The App, And Google Sign-In Checks The Network First (follow-up):** Supabase falls back to the project's **Site URL** for any mail link whose call passed no redirect, and the dashboard default for that value is `http://localhost:3000` — a dead browser page the moment a link is opened on a phone. That is what a user saw on both the sign-up confirmation and the password-reset mails. The build now names its own destination: `SupabaseConfig.authRedirectUrl` is `com.legalcasediary.app://login-callback`, passed as `emailRedirectTo` by `signUpIndividual` and as `redirectTo` by `sendPasswordRecoveryCode`; `android/app/src/main/AndroidManifest.xml` claims that scheme with its own `<intent-filter>` and sets `flutter_deeplinking_enabled=false`, which is what stops the Flutter engine consuming the URI before `supabase_flutter`'s bundled `app_links` observer can exchange it for a session. **This supersedes the earlier "the recovery code, not a deep link, is what brings the user back" wording for the reset screen:** the primary path remains the code — the Reset Password e-mail template must still carry `{{ .Token }}`, and `resetPasswordForEmail` still sends no more than a redirect — and the link is simply a second way in. Because a verified recovery link signs the user in as a side effect of being verified, `AuthSessionEvent` gained `passwordRecovery` (mapped from `AuthChangeEvent.passwordRecovery`), `AuthState` gained the matching flag, exposed as `passwordRecoveryPendingProvider`, the router holds the user on the reset screen until the new password is set (an exception to its "signed in has no business on the auth screens" rule), and that screen asks for the password alone — no address, no code. Separately, the same investigation showed Google sign-in failing on a Wi-Fi network with **no uplink**, which `ConnectivityMonitor` deliberately cannot report, because it answers the *link* rather than the internet; `signInWithGoogle` now runs `probeSupabaseReachable` — a four-second request to the project URL — before opening the account sheet, and raises `AuthFailureKind.network` ("No Connection. Check Your Internet And Try Again.") when it cannot get through, so that cause is no longer indistinguishable from a certificate mismatch. Both dashboard values (**Redirect URLs** with the scheme, plus a real **Site URL**) and the `adb` deep-link test are documented in `docs/google_oauth_setup.md` §10.1 and `README.md`.
- **The Check Your Email Screen Finishes The Sign-Up (0.0.413, user request):** a project with e-mail confirmation on leaves the app on a card that used to offer one way out and no way forward. It now carries **Open Mail** — the bare `mailto:` route through the existing `ContactLauncher` seam, so Android raises its own chooser and the user picks the mailbox the confirmation went to, not a compose window — and three recoveries: **Resend Email**, **Change Email Address** and **Back To Login**. **The app checks on the way back, not on a tap.** A return from the mail app is a lifecycle event, so the screen observes it and asks the server whether the address is confirmed now, with the e-mail and password the user just typed; the answer **is not a sign-in**: the check is a `POST /auth/v1/token?grant_type=password` read for its status alone (`200` = confirmed, the very refusal Login shows for an unconfirmed address otherwise) whose reply is never stored, because a session would hand the app the account and adoption, the router's signed-in redirect and a profile pull are not what "Back To Login" means. **Confirmed** turns the card green — a green mark, a green title and one action, Back To Login — and spends the waiting record, because that address is done; **not confirmed** (and every failure, including an offline one) leaves the screen exactly as it was, which is the state the user is already reading. **The waiting state outlives the process.** `LocalAuthService` remembers the address a mail was sent to (never the password — it lives in memory for the life of that one screen and is written nowhere), and `appRouterProvider` opens **Sign Up** on a launch that has such a record, so a user who closes the app on the way to their mailbox returns to the screen rather than to an empty form; the record is ignored after seven days and cleared when the address is confirmed, corrected, or the user leaves for Login. The one honest limit: after a restart the typed password is gone, so the automatic check cannot run — the restored screen still offers Open Mail, Resend Email and Change Email Address or Back To Login, and logging in is itself the proof the address is confirmed. **A mistyped address is now correctable**, which it was not: an unconfirmed account cannot sign in, so no client call can reach it, and `abandon_provisional_account()` works from `auth.uid()` and can never have a session here. The new server function `public.discard_unconfirmed_signup(p_email, p_password)` (migration `20261008110000`, ledger version 0.0.413) verifies the password against the account's own bcrypt hash through pgcrypto's `crypt()`, refuses an address that is **already confirmed** and refuses an account that has **done anything** with exactly `abandon_provisional_account()`'s guards, then removes the `auth.users` row so the profile, preferences and sessions cascade with it — and the address is free to be registered again. It is granted to **`anon`**, because that caller has no session at all, and is therefore **rate-limited** (five refusals per address per fifteen minutes, in the new server-managed `signup_discard_attempts` ledger); a missing account and a wrong password answer identically, so it is not an address oracle. On success the screen brings the **form back with everything but the address still filled in**. **Resend Email** calls GoTrue's own `resend`, passes the app's redirect again so a resent link still opens the app, and shows the server's refusal verbatim (its rate limit has its own sentence). **(0.0.414) The green card's one action is Use The App, not Back To Login** — pressing it lands the user in the app rather than on Login, so the label now says what happens and the tap does what the label says: it signs in with the credentials the form is still holding (the same call Login makes, so a join-a-firm code the confirmation left pending is redeemed here too) and the card's sentence reads *You can use the app now.* in both languages. **The automatic check still signs nothing in** — the credentials are spent only by that deliberate tap — and a card restored after a restart holds no password, so Login remains the way in there.
- **A Server Error Is Not A Network Error:** the Supabase SDK raises one type, `AuthRetryableFetchException`, for both a request that never arrived (offline, DNS, timeout) **and** any HTTP 5xx, and the status code is the only thing that tells them apart — a transport failure carries none. `AuthFailureKind.network` therefore means "the request never reached the server" and nothing else; a 5xx classifies as `unknown`. Telling a user whose server *answered* to check their internet is how a recovery mail the server could not send (a mail relay rejecting its own credentials) was reported as *"No Connection. Check Your Internet And Try Again."* to a device that was online throughout.
- **The App Keeps Its Own Error Log (cross-cutting follow-up):** every failure path in this app was already a `try`/`catch` inside a feature — 167 of them, only two of which swallowed anything — and what none of them could see is the fault that arrives as a blank screen: a framework assertion, a build error, an `async` throw nobody awaited. Nor could any of them be read back afterwards, because **nothing was persisted**: logging was ad-hoc `debugPrint` and the exportable diagnostic bundle was queue-shaped, so a failure in sign-in, payments, the profile or the firm flow left no trace at all. Three pieces close that. **(1) One capture, at startup:** `installErrorCapture` wires `FlutterError.onError` and `PlatformDispatcher.instance.onError` and **delegates to whatever handler was already installed**, because a capture that swallowed would hide the very faults it exists to find. **(2) One log,** `ErrorLog`: the last 200 failures, in memory and in a file in the app's **private support directory** (never shared storage), each entry a time, an area and a redacted label — a `DiagnosableFailure` names its kind (`AuthFailure(network)`), and **no raw server message is ever written**, because `AuthFailure.serverMessage` and `PostgrestException.message` can carry fragments of a request or of the data in it. It is a `ChangeNotifier`, so the viewer reflects a failure the moment it is recorded and a Clear visibly empties the list. **(3) One place to read it:** a **Diagnostics** Settings sub-page over the log, and the log carried into the existing diagnostic bundle under a new `errors` section (bundle format version 2), so the file a user already knows how to export is the file that answers the question. **What the same follow-up then added, report first and the faults the capture cannot see.** **(4) A report a user can hand over, in plain text.** `buildDiagnosticsReport` renders the log as one `time | area | label` line per failure under a header carrying the app version, the moment it was generated, and how many of how many recorded failures are shown; the Diagnostics page gains a **Copy Diagnostics** action, and the Support screen's WhatsApp and e-mail message carries the same text, because a user who is stuck cannot be asked to open a screen and read a list out loud. The report is plaintext and the **encrypted** diagnostic bundle is untouched, so the passphrase gate is not weakened. **(5) Recording the failures that are caught.** Almost nothing escapes in this app — a wrong password, a rate limit, a refused payment and a list that will not load are all caught, turned into a typed failure and shown — so the log would be empty for exactly the faults a user reports. The view models and screens record them at the choke point through `recordFailure`, one entry per operation under its own area (`auth.signIn`, `cases.refresh`, `notes`, `settings.load`, `payments.submit`, `firm.action`); a failure the user caused on purpose, such as a dismissed Google sign-in sheet, is not a fault and is not recorded. **(6) The firm domain stopped borrowing `AuthFailure`.** A firm RPC fails for reasons a sign-in never can — the owner is off the network, the invite is spent, the account is not a member — so `FirmFailureKind`/`FirmFailure`/`mapFirmFailure` classify what a firm call threw (network, server, unauthorized, rate limit, unavailable, invalid invite, already a member, owner offline, premium), and `failureText` is the one place a screen asks for the sentence, so a third domain is one line rather than a migration. A firm failure is recorded as `FirmFailure(server)` and never under an auth failure's name. **Still owed:** the same treatment for the profile, admin and delete-request repositories, which still throw `AuthFailure` for non-auth failures and still leak a raw `PostgrestException`. **(0.0.403) The log never tells its listeners from inside the frame that failed.** `ErrorLog.record` and `ErrorLog.clear` hand their `notifyListeners` to a microtask instead of calling it where they stand, because the capture records an error *from inside the frame that hit it*: a synchronous notify therefore rebuilt the listening screen mid-failure (`setState() or markNeedsBuild() called during build`), which re-ran the layout that failed, which reported the error again, which notified again — a loop that never yielded a frame. On the device that ANR'd the app on **Settings > About > Support** (200 `framework` entries logged in three minutes, one thread pinned at ~100%), and Support and Diagnostics are the only two screens in the app that rebuild from this log. Nothing a user sees changed: the viewer still reflects a failure recorded while it is open, one microtask later. **(0.0.405) The Support screen no longer mirrors the message.** The *Either Channel Opens With The Message Below Already Written* hint and the *The Message That Opens* preview card are gone from it — the message still carries the diagnostics report into WhatsApp and the mail body, but the screen no longer draws it first — and the *We can help you with the app itself* scope paragraph moved from the card at the top to a note card titled **Before You Write To Us**, the first of the three above the channels' footer. **(0.0.406) The log keeps each failure's own message, because a label alone cannot be fixed from.** The old rule withheld the text — `serverMessage` may quote a request or the data in it — but a framework error records as the bare word `FlutterError` and `AuthFailure(unknown)` is only the start of the story, so the user asked for the message to be kept and shown. Each entry gains a **detail**: a typed failure answers through a new `DiagnosableFailure.diagnosticDetail` (the server reply and the cause; `FirmFailure` its cause, `SyncFailure` its classified message), the capture passes a framework error's text with its library and context, and anything else falls back to its `toString()` — flattened to one line and cut at 500 characters. The Diagnostics screen shows it under the label, and the plain-text report that Copy Diagnostics and the Support message carry appends it as an indented line, so a report names the error it is asking about. The text can therefore leave the phone — which is why it leaves only inside a report the user copies or sends and can read first, and why the encrypted bundle (which reads the same entries) is unchanged in posture: it was already the file the user exports deliberately. **(0.0.407) The first error that fed that loop is identified.** It was Flutter's own `ListTile` ink assert: the Settings list's section card was a white decorated `Container`, and every row reported "ListTile background color or ink splashes may be invisible" once per layout — the 179 bare `FlutterError` entries, in bursts of one per row. The card is now a shaped `Material`, so the rows' ink lands on it and the assert is gone (see Task 12).
- **A Typed Recovery Code Is Not An Opened Link:** gotrue raises the same `AuthChangeEvent.passwordRecovery` for a code typed into the reset screen as for a link opened from the mail — `verifyOTP` branches on `OtpType.recovery` and never on how the token arrived — so `AuthSessionEvent.passwordRecovery` proves only that a recovery session exists, not that the user opened anything. Reading it as a link was a real defect: `_beginPasswordRecovery` set the flag *after* `updatePassword` had already cleared it, and the router's "hold the user on the reset screen" rule then ran against a **non-auth** location, replacing Settings › Manage Account › Change Password with `/forgot-password` and unmounting the sub-page before its own success pop could run — which is how a reset from inside the app ended on a Reset Password screen instead of back at Manage Account, and why the flag was left set afterwards. `AuthViewModel` now **latches its own `verifyRecoveryCode` call** (`_typedRecoveryInFlight`, released when the call is refused so a link the user opens later is never swallowed as its echo) and spends the next `passwordRecovery` event on it, so only a link raises `passwordRecoveryPendingProvider`. The consequences are the intended ones: a Change Password from Settings pops back to Manage Account — the screen that holds the row, which it briefly did not while the Security sub-page held it (0.0.410) — and a reset begun at Login ends with the user signed in and the app opening on the Daily Cause List — the route sign-up uses — with `auth_passwordUpdated` raised through a messenger captured before the first await, so the confirmation survives the screen the router takes away.
- **Extended-Offline Recovery Lock Applies to Firm Mode Only (150 days, per-device):** The 150-day extended-offline recovery lock — the durable `extended_offline_recovery_required` flag, the automatic encrypted safety copy, the blocking warning and the wipe-and-rebuild that **Proceed** runs — applies **only in firm (multi-user) mode**, i.e. only when the account's `firm_id` is non-null (`firmModeProvider`). An account in **individual mode is never locked**: the flow is skipped entirely and **no recovery work or network work is performed for it**. The reason is the one the lock exists for — it protects a device from resurrecting rows that **another writer** deleted while the device was away, and a solo diary has no other writer, so nothing can have been deleted behind it; locking a single-author device out of its own edits would be pure harm. Consequences to hold to: the plan's earlier "premium/Firm mode" phrasing in §3 is **superseded** by this sharper rule (a premium individual is exempt too), and the lock is gated on **firm mode alone**, never on entitlement. Everything else in §3's Extended Offline Period Reset stands unchanged — the check is still the **device's own** `last_successful_sync_at` (never `profiles.last_successful_sync_at`), and a device that has never synced is not locked because there is no gap to measure. Implemented in `lib/sync/recovery_lock.dart` (`shouldRecover` requires `firmMode`) and `lib/sync/recovery_flow.dart`.

---

## Screen Analysis & Theming Summary (from `justiceLedger/DESIGN.md` & screens)

The application adheres to the custom **Justice Ledger** corporate design system, providing a high-density, flat, stationery-like aesthetic. Reference: legal_case_diary_flutter\mockup_html_screens\justiceLedger\DESIGN.md

### Color Palette (Justice Ledger Tokens)
- **Primary:** `#0F172A` (Ink dark - used for headers, titles, primary text)
- **Secondary:** `#2563EB` (Action blue - used for primary CTAs, active states, key highlights)
- **Tertiary:** `#64748B` (Muted gray - used for secondary text, icons, borders)
- **Neutral/Background:** `#F8FAFC` (Parchment white - screen background to reduce eye strain)
- **Surface Level 1 (Cards):** `#FFFFFF` with a subtle 1px border (`#E2E8F0`)
- **Semantic Colors:** `#DC2626` (Red - urgent court deadlines / overdue indicators) and `#059669` (Green - active/disposed status)

### Typography Hierarchy
- **English Font:** Manrope (Headlines), Inter (Body), IBM Plex Sans (Labels & Data/Case Numbers)
- **Bengali Font:** **Tiro Bangla** (Must be default for all Bengali text)
- **Line Heights:** Set to `1.5` for Bengali paragraphs to support script descenders.

### Court Hierarchy Flow (Settings > Edit Court/Steps > Court Category)
1. **Appellate Division** is itself a top-level court category (`appellate_division`) and lists its pre-seeded specific court names (e.g., Annex Building 2, Court No. 5).
2. **High Court Division** is itself a top-level court category (`high_court_division`) and lists its pre-seeded specific court names (e.g., Annex Building 1, Court No. 4).
3. **Lower Divisional Courts**
   - **Division** lists the 8 divisions of Bangladesh (Dhaka, Chattagram, Rangpur, etc.).
   - **District** lists districts within the selected division.
   - **Court Category** lists the pre-seeded lower-court categories within the selected district (e.g., `district_sessions_criminal`, `district_courts_civil`, `chief_judicial_magistrate`, `chief_metropolitan_magistrate`, `executive_magistrate`, `tribunals`).
   - **List of Courts** lists specific courts for the selected district + category. Users can add, edit, reorder, and soft-delete this list.

> **Canonical category rule:** Every court resolves to exactly one stable `court_category_id`. For Appellate and High Court selections, the category is assigned implicitly from field 1 even though the lower-court Court Category dropdown is hidden. For lower courts, it comes from field 4. Steps, lower-court Case Types, and on-behalf options are queried by this court-category ID. AD/HCD additionally use a separate `case_category_id` to scope their Case Types. Human-readable English/Bengali labels are presentation/localization only and must not be database keys. This hierarchy and its stable IDs must be maintained by versioned pre-seed migrations.
---

## Detailed Cases and Settings Related Screens Specifications

### 1. All Cases Screen
- **Design Reference:** Must use `legal_case_diary_flutter\mockup_html_screens\allCases\code.html` file to design the UI of the screen's body. For the App header and bottom nav bar, use the reusable `cases_screen_modal.dart` modal.
- **Main Data Source:** This screen acts as the primary data source for all case-related information in the app. Any case added by the user using the FAB "Add New Case" icon from any of the case-related pages is saved and added here.
- **Sorting Logic:** Cases are listed on a first-come, first-served basis. Meaning, the very first case is listed at serial no. 1, the next case added is serial 2, the next is serial 3.
- **KPI Summary:** Displays a total count of **Active** cases and **Disposed** cases at the top of the screen (as designed in the `legal_case_diary_flutter\mockup_html_screens\allCases\code.html` mockup).
- **Filters:** Users can filter cases by:
  - Court Name (displays cases belonging to a selected court category/specific court).
  - Chronology: Newest entry first / Oldest entry first.
- **Case Card UI Layout:** Case Card UI Layout must match exactly like the mockup html file's case card (`legal_case_diary_flutter\mockup_html_screens\allCases\code.html`).
  - **Line 1:** Top-Left: data taken from `case_type` & `case_number` columns | Top-Right: **On Behalf** (representing lawyer's client role, e.g., "Plaintiff")
  - **Line 2:** data taken from `petitioner` Vs `respondent` columns
  - **Line 3:** **Name of the Court** (e.g., "Magistrate Court, Dhaka")
  - **Line 4:** Left: **Next Date** (formatted as `DD/MM/YYYY`) | Right: **last_step** (current procedural stage)
  - **Line 5:** **Phone** icon/button, **Message** icon/button, and **Update** button (presents a quick date and step update pop-up window like the Update button pop-up window of 'mockup_html_screens\dailyCauseList\code.html` file).
  ### 1.1 Add/Edit Case Form (`AddEditCaseSheet`)
  - Create `lib/shared/widgets/add_edit_case_sheet.dart`
A full-screen modal sheet for adding a new case or editing an existing one.

**Task 07 AD/HCD extension:** When Appellate Division or High Court Division is selected, show and persist Name of Honorable Judges', Case Category, Tender Number, Previous Court Case, and District of Origin after Name of Court/Case Type and Case Number as specified below. Show Result after Day Offset, hide Step, and treat Result containing `Dismissed`, `খারিজ`, `Disposed`, `নিষ্পত্তি`, `Discharged`, or `অব্যহতি` as disposed without validating AD/HCD against seeded Steps.

**Reference-data labels:** Seeded District, Court, Case Type, and Step dropdown items resolve through the active locale (EN or BN); custom rows fall back to their stored English name. The current development default locale is EN.

**Design reference:** The Add New Case form mockup is embedded in `legal_case_diary_flutter\mockup_html_screens\dailyCauseList\code.html`.

**Form fields (in order):**

| # | Field | Widget Type | Data Source | Notes |
|---|-------|-------------|-------------|-------|
| 1 | **Higher or Lower Court** | `CustomDropdown` (single-select) | `PreSeededData.higherLowerCourtCategories` | 3 options: Appellate Division, High Court Division, Lower Divisional Courts |
| 2 | **Division** | `CustomDropdown` (single-select) | `PreSeededData.divisions` | Hidden when "Appellate Division" or "High Court Division" selected |
| 3 | **District** | `CustomDropdown` (single-select) | `PreSeededData.districtsByDivision[selectedDivision]` | Hidden when "Appellate Division" or "High Court Division" selected |
| 4 | **Court Category** | `CustomDropdown` (single-select) | `PreSeededData.lowerCourtCategories` | Hidden when "Appellate Division" or "High Court Division" selected |
| 5 | **Name of Court** | `CustomDropdown` (single-select, searchable) | Supreme: `PreSeededData.supremeCourtNames[category]` / Lower: `PreSeededData.lowerCourtNamesByDistrict[district][category]` | For lower divisional courts, filtered by selected district + category |
| 6 | **Name of Honorable Judges'** | `TextFormField` | — | AD/HCD only; after Name of Court |
| 7 | **Case Category** | `CustomDropdown` (single-select) | `CaseCategoriesDao` filtered by the resolved AD/HCD `court_category_id` | Shown only for Appellate/High Court; Case Type is filtered by the selected `case_category_id`. Lower courts do not show this field. |
| 8 | **Case Type** | `CustomDropdown` (single-select) | `CaseTypesDao` filtered by `court_category_id`; additionally by `case_category_id` for AD/HCD | Placed left of Case Number. |
| 9 | **Case Number** | `TextFormField` | — | Placed together with Case Type: Case Number on the right |
| 10 | **Tender Number** | Numeric `TextFormField` | — | AD/HCD only; after the Case Type/Case Number row |
| 11 | **Previous Court Case** | `TextFormField` | — | AD/HCD only |
| 12 | **District of Origin** | `TextFormField` | — | AD/HCD only |
| 13 | **Petitioner** | `TextFormField` | — | Includes a sub-field for Lead Counsel (`petitionerLeadCounsel`) |
| 14 | **Respondent** | `TextFormField` | — | Includes a sub-field for Lead Counsel (`respondentLeadCounsel`) |
| 15 | **On Behalf** | `CustomDropdown` (single-select) | `OnBehalfsDao` filtered by resolved `court_category_id` | Uses the same implicit/explicit court-category resolution as Step. |
| 16 | **Petitioner Phone No. / Respondent Phone No.** | Two `TextFormField`s (numeric keyboard) | — | Data types: `petitionerPhone`, `respondentPhone` |
| 17 | **Case Title & Remarks** | `TextFormField` (top half) + `TextFormField` (bottom half, multi-line) | — | Top: `caseTitleAndSection`. Bottom: `caseRemarks` |
| 18 | **Next Date** | Date picker | — | Data type: `nextDate` (epoch ms). Placed with 19 & 20 in a single row |
| 19 | **Notification** | `IconButton` (toggle) | — | When on, icon fills with black. Placed with 18 & 20 in a single row |
| 20 | **Day Offset** | `CustomDropdown` (multi-select, no search) | Fixed options: same day, 1, 3, 7, 15, and 30 days before the selected date; labels localized | Placed with 18 & 19 in a single row |
| 21 | **Result** | `TextFormField` (multi-line) | — | AD/HCD only; persisted separately as `result` and used for disposal matching |
| 22 | **Step** | `CustomDropdown` (multi-select) | `StepsDao` — filtered by selected court's category | Data type: `lastStep`; lower courts only; hidden for AD/HCD. |
| 23 | **Note** | `TextFormField` (multi-line) | — | Data type: `notesResults` |
| 24 | **Save** | `ElevatedButton` | — | Saves the form data via `CaseRepository.insertCase()` (add mode) or `CaseRepository.updateCase()` (edit mode) |

**Layout rules:**
- Fields 8–9 (Case Type + Case Number) are placed side-by-side: Case Type on the left, Case Number on the right.
- Fields 18–20 (Next Date → Notification → Day Offset) are placed in a **single row** in that exact order.
- Fields 5–15 (Court Name through On Behalf) are cascading: changing Higher/Lower Court resets and shows/hides Division/District/Court Category/Case Category, which in turn filters Name of Court and Case Type.
- All other fields are stacked vertically in the order listed above.

**Logic:**
- **Add mode:** Generates a new UUID, inserts via `CaseRepository.insertCase()`.
- **Edit mode:** Pre-fills all fields with existing data from the `Case` data class, calls `CaseRepository.updateCase()`.
- **50-case free limit:** Before inserting in add mode, call `CasesDao.getNonDeletedCaseCount()`. If count >= 50 AND `isPremium == false` (from `SettingsRepository`), block the save and navigate to `PaywallScreen`.
- **Case history:** On edit save, if `nextDate`, `lastStep`, or `notesResults` changed, save the previous values as a new `CaseHistoryData` entry via `CaseHistoryDao.insertHistoryEntry()`.

### 2. Daily Cause List Screen
- **Design Reference:** Must use `legal_case_diary_flutter\mockup_html_screens\dailyCauseList\code.html` file to design the UI of the screen's body. For the App header and bottom nav bar, use the reusable `cases_screen_modal.dart` modal.
- **Source of Truth:** Uses cases fetched from the "All Cases" dataset, filtering for cases scheduled for today.
- **Grouping & Court Hierarchy:** Grouped by **Court Name**, strictly maintaining the hierarchy of courts as listed in the pre-seeded file (Supreme Court Division → High Court Division → Lower Courts sessions, civil, magistrate, executive, tribunals).
- **KPI Summary:** Displays a total case count to the right side of each Court Name header.
- **Time/Date Filtering:**
  - Quick buttons: "Today" and "Tomorrow" display cases with `next_date` matching today's and tomorrow's date respectively.
  - Calendar Picker: To the right of the Today | Tomorrow buttons, show a calendar control displaying `DD/MM/YY | DDD` (three-letter localized weekday abbreviation). Selecting a date displays cases scheduled for that local civil date. Follow "### 2.1. Badge Calendar Picker (Daily Cause List Page Only)" for the expanded picker UI.
- **Case Card UI Layout:** Case Card UI Layout must match exactly like the mockup html file's case card (`legal_case_diary_flutter\mockup_html_screens\dailyCauseList\code.html`).
  - **Line 1:** Top-Left: data taken from `case_type` & `case_number` columns | Top-Right: **On Behalf**
  - **Line 2:** data taken from `petitioner` Vs `respondent` columns
  - **Line 3:** taken from `case_title_and_section` column (description of the case or specific legal sections, e.g., "Land Dispute" or "Section 302 IPC")
  - **Line 4:** Left: **last_step** | Right: **Note** (data taken from `notes_results` column. No Next Date field is present on this card).
  - **Line 5:** **Phone** icon/button, **Message** icon/button, and **Update** button.
  ### 2.1. Badge Calendar Picker (Daily Cause List Page Only)
UI Design: Follow mockup_html_screens\dailyCauseList\code.html for the design. The mockup html page hase the design of the calendar picker model we want to build.
- Displays hearing counts dynamically on the calendar:
  - Over date: Red/Gray badge showing count of hearings for that date.
  - Under month title: Monthly total hearing count.
- Keep the calendar at a fixed seven-row height: one weekday-header row plus six date rows. Fill leading/trailing cells as needed so the dialog does not shift vertically between months.
- All other date pickers in forms are simple native scroll/popup pickers defaulting to today's date.

### 3. Upcoming Cases Screen
- **Design Reference:** Must use `legal_case_diary_flutter\mockup_html_screens\upcomingCases\code.html` file to design the UI of the screen's body. For the App header and bottom nav bar, use the reusable `cases_screen_modal.dart` modal.
- **Source of Truth:** Sorted out subset of cases from the "All Cases" dataset.
- **Date Filter Offset:** Shows only cases with a `next_date` of **tomorrow + period** set in `Settings > View Settings > Upcoming Cases Period` (stored in SharedPreferences key `upcoming_cases_period`, default: 7 days).
- **Grouping & Sorting:** Cases are grouped according to Date, listing the newest first. Above each case cards' group the date is written in a format like Tuesday, October 24, 2023. See `upcomingCases\code.html` file for reference.
- **Case Card UI Layout:** Uses the exact same card design and fields as the **All Cases** screen card.

### 4. Overdue Dates Screen
- **Design Reference:** Must use `legal_case_diary_flutter\mockup_html_screens\overdueDates\code.html` file to design the UI of the screen's body. For the App header and bottom nav bar, use the reusable `cases_screen_modal.dart` modal.
- **Source of Truth:** Sorted out subset of cases from the "All Cases" dataset.
- **Date Filter:** Shows only cases with a `next_date` that is **in the past** (prior to today's date).
- **Status Indicator:** Displays a **Last Updated** status text showing when an associate last updated the page.
- **Grouping & Sorting:** Grouped and listed by Court Name maintaining the pre-seeded court hierarchy, identical to the **Daily Cause List** logic.
- **Case Card UI Layout:** Case Card UI Layout must match exactly like the mockup html file's case card (`legal_case_diary_flutter\mockup_html_screens\overdueDates\code.html`). Also, add a red line to the left side of the case card as a sign of urgency.
  - **Line 1:** Top-Left: data taken from `case_type` & `case_number` columns | Top-Right: **On Behalf**
  - **Line 2:** data taken from `petitioner` Vs `respondent` columns
  - **Line 3:** Show **Note** field (data taken from `notes_results` column).
  - **Line 4:** **Next Date** field's date, and directly under it, the **last_step**.
  - **Line 5:** **Phone** icon/button, **Message** icon/button, and **Update** button.

---

### 5. Case Detail Screen
- **UI Design Reference:** Must use `legal_case_diary_flutter\mockup_html_screens\caseDetails\code.html` file to design the UI.
- **UI Logic:** The screen is displayed when the user clicks/touches on a case card/row over all case-related pages.
- **Source of Truth:** Shows data from various data tables.
- **Layout Description:**
  - **Line 1:** `case_type` and `case_number` displayed in big font.
  - **Line 2:** A location icon and the name of the court (`court_name`). For AD/HCD cases only, a judges names line directly below.
  - **Line 3:** Action buttons — **Delete** (red, soft-deletes the case with confirmation dialog), **Edit Case** (opens `add_edit_case_sheet.dart` in edit mode), and **Close** (pops the screen).
  - **Line 4 — Parties KanBan Card:**
    - **On Behalf Of:** (from `on_behalf_id`)
    - **Petitioner** (title), Name of the Petitioner, Lead Counsel of Petitioner (from `petitioner_lead_counsel`)
    - **Respondent** (title), Name of the Respondent, Lead Counsel of Respondent (from `respondent_lead_counsel`)
    - **Phone & Message buttons** sit on the represented side only, using the case's single `party_phone` (see Resolved Design Clarifications); the opponent side is shown disabled with the reason
  - **Line 5 — Case Description KanBan Card:**
    - **Case Title & Remark** (title)
    - Two text boxes: `case_title_and_section` (Sections or Case Title) and `case_remarks` (Remarks or Case Summary)
  - **Other Information card (AD/HCD cases only):** Tender Number, Previous Court Case, and District of Origin boxes; sits between Line 5 and Line 6.
  - **Line 6 — Case History KanBan Card:**
    - Header: "Case History" with a time icon, a total history count ("x Entries Total"), and a Show/Hide button (only when more than 3 entries) that expands all entries or folds back to the newest 3; while expanded, the title row stays pinned at the top of the screen.
    - List of previous `next_date`, `last_step`, and `note_result` entries. Dates (DD/MM/YYYY + weekday) shown on the left; Steps on the right; Note directly below the Step. AD/HCD rows show the hearing's `result` snapshot in place of Step.
- **Case History Logic:**
  - Every time the user enters a new `next_date` (with or without `last_step` and `note_result`), the **previous** `next_date`, `last_step`, and `note_result` values — plus the previous `result` for AD/HCD — are saved as a new entry in the `case_history` table.
  - On the detail screen entries are ordered newest-first by each row's displayed date (`hearing_date`); the DAO query itself remains `next_date` **descending**.
  - **Long-press** on a history item shows 2 options: **Edit** (shows a form to change Next Date, Step, Note; Result too for AD/HCD) and **Delete** (shows a confirmation dialog before deleting).

---

### 6. Disposed Cases Screen
- **UI Design Reference:** Must use `legal_case_diary_flutter\mockup_html_screens\disposedCases\code.html` file to design the UI of the screen's body. For the App header and bottom nav bar, use the reusable `cases_screen_modal.dart` modal.
- **Source of Truth:** Sorted out subset of cases from the "All Cases" dataset.
- **Disposed Filter:** Shows only cases with steps defined as "disposed" in `pre_seeded_data.dart` or AD/HCD Results containing a configured disposal term.
- **Sorting:** Case cards are sorted by `next_date` **descending** — the latest disposed case sits at the top.
- **Case Card UI Layout:** Must match exactly like the mockup html file's case card (`legal_case_diary_flutter\mockup_html_screens\disposedCases\code.html`).
  - **Line 1:** `last_step` | Top-Right: "Disposed:"
  - **Line 2:** Left: `case_type` & `case_number` | Right (below "Disposed:"): `next_date` (the last date on which the case was disposed)
  - **Line 3:** `petitioner` vs `respondent`
  - **Line 4:** Note, displayed in a beautifully designed box matching the mock HTML.
  - **Line 5:** Case History — showing the last two case history entries from the `case_history` table.

---

### 7. Active Cases Screen
- Active Cases Screen shows the **exact same screen with the same logic as the All Cases Screen**, except:
  - It does **not** show the Active Cases / Disposed Cases count KPI summary.
  - It does **not** show the filter option by Court Name or Chronology.
  - It only shows cases with steps **not** defined as Disposed in `pre_seeded_data.dart`.

---

### 8. Settings — Main Page & Sub-Menu Pages

#### Main Settings Page
- **UI Design Reference:** The UI must be designed exactly like `legal_case_diary_flutter\mockup_html_screens\settings_main\code.html`. Only add a **Guidelines** sub-menu item before **About**.

#### Settings Page Structure

**("General" section)**
- **Account & Profile** — a **sectioned** sub-menu (**0.0.410**). Its body is grouped under three Title Case section labels — **Profile**, **Account** and **Firm** — drawn with the shared `SettingsSectionLabel` the other sectioned Settings screens use, and every entry renders through the shared `SettingsMenuCard`, so this screen stays the size reference for the whole Settings surface. It has **no mockup of its own**; `mockup_html_screens\settings_accountProfile\code.html` was written from the shipped screen, per rule 9's "mockups follow the app".
  - **Profile** section → **Profile** → `legal_case_diary_flutter\mockup_html_screens\settings_profile\code.html`
  - **Account** section → **Manage Account** (→ `settings_manageProfileAccount\code.html`) and **Subscription** (below).
  - **Firm** section → **Manage Associates** — shown only when the entry is offered (a premium individual or a firm owner); the label is drawn only with the row, so a hidden row never leaves a bare header.
- **Online Sync** → `legal_case_diary_flutter\mockup_html_screens\settings_onlineSync\code.html`
- **Subscription** → `/settings/subscription` (`subscription_screen.dart`), reached from the **Account** section of the Account & Profile menu (it was briefly a Settings list entry after moving off Manage Account). **Two rows, moved here from Manage Account unchanged** — **Subscription Details**, which opens a **sub-page of its own** (`/settings/subscription/details`, `subscription_details_screen.dart`) showing **Role** (and the firm, in firm mode), **Current Plan** and **Expiry**, followed by **Payment History** — this account's own submissions as **one card per purchase**, numbered from the newest, each card carrying the plan, the amount paid (under its own **Paid** caption), when it was submitted (under **Date & Time**), the reviewer's verdict as a pill, and the reviewer's note when there is one. Cards, not a grid: five columns on a phone either wrap their dates or push the verdict off the edge, and a card gives each purchase its own block to read. The summary card's values — **Role**, **Current Plan**, **Expiry** — sit at the card's right edge, which is what a value column is for; a `Flexible` right-aligns inside a box only as wide as the text, so the value lands beside its label and the card reads as one left-aligned column. **Purchase New Subscription** opens the paywall. Same icons and wording as the rows had in Manage Account. It is a sub-page rather than a bottom sheet because it is reference material a user reads — a plan, an expiry and a ledger they reconcile against a bank or MFS statement — not a choice they are making, and the ledger needs room the sheet never had. Two rules the page holds to: **an entitlement that has not landed reads a dash, never *Free*** (the entitlement bullet in §Payment Enforcement below, since a premium user whose profile pull is in flight must not read Free beside an expiry that names a date), and **every timestamp is Bangladesh civil time** — the date and the clock come from the same shifted instant, because a date formatted in UTC beside a clock formatted locally disagrees by six hours and the user reconciles the wrong moment. **No `settings_subscription` mockup exists**, so this is a recorded departure: the body is the two rows above moved verbatim, and it is shown to every account because the rows it replaces were unconditional and a premium user still needs to see what they paid for. It takes the icon **Go Premium** occupied, so the entry a free-plan user tapped keeps its look in its new home.
 **The card's number takes the active language's digits (0.0.391)**: each Payment History card's number was a raw `'$number'` interpolation, so বাংলা read `1` and `2` beside an amount and a date that were already localized; it now goes through `AppDateUtils.formatDigits(number, l.localeName, grouping: false)` — the same helper the amount beside it and every other count in the app uses — so বাংলা reads `১` and `২`. No ARB key: a number needs no translation, only the active language's digits.
- **Manage Account** → `/settings/manage-account` (`manage_account_screen.dart`), the account's own actions, and the one screen on this surface whose body is **not** a list of cards. **(0.0.411, user request.)** The profile summary keeps the avatar, name and e-mail only — the small inline **Logout** that sat under the address is gone — and the actions below it are, in order: a **full-size Logout** card, **Change Password** back from the Security sub-page (which is deleted: `/settings/security`, `security_screen.dart`, its ARB keys, its mockup and its test all go with it), then a red bold **Danger Zone** label and the **Delete Account** card. **Logout and Delete Account are the same card** (`SettingsActionCard`, two colour tones) rather than two layouts that happen to match, because the request was that the Logout button be the same size as the Delete Account button — the shared 16 px padding, 44 px content row and 40 px icon circle make that a property of the code. The mockup `settings_manageProfileAccount\code.html` was redrawn from the shipped body.
  - **Delete Account, warned and wired (0.0.411).** The card was the last Part A placeholder on the Settings surface: it warned nothing and did nothing. It now (1) opens **one warning** — Cancel and a red Delete Account, at the app's shared action size, and a dismissed window cancels — worded for this account's plan, because a **free** account's diary has never left the device while a **premium** account's is in the cloud as well, and it says the result is permanent and cannot be undone; (2) opens the **typed confirmation screen** (`/settings/manage-account/delete`, `DeleteAccountScreen`) — a page of its own, added on the user's request in **0.0.412**, which repeats the plan-specific sentence and holds a field that must contain the phrase **`delete my account`** before the red destructive button is enabled. Only the phrase in that sentence is **red and bold** (`AppColors.error`, `FontWeight.w700`) while the words around it stay ordinary body text, so the words to type are the ones the eye lands on. The sentence is still **one ARB string** with the phrase as its `{phrase}` placeholder and the screen splits it at its own placeholder for the styling, so no user-facing word lives outside the ARB. (A styling-only follow-up to the typed gate, recorded at the user's request **without a version bump**.) The phrase is **one ARB key, identical in English and Bengali** by the user's instruction (the same choice `drawer_version` makes for a version string), and the sentence above the field carries it as a `{phrase}` placeholder rather than repeating the words, so the instruction and the string the code compares can never drift. It is compared **trimmed and case-insensitively** — `  Delete My Account ` is the same intent, and the gate exists for deliberation rather than typing practice. **Nothing is destroyed until it matches**, and leaving the screen deletes nothing; (3) **refuses offline**, where the account row is unreachable, rather than half-deleting and touching nothing local either; (4) calls the server; and (5) on success returns the device to what an install starts from and ends the session — `LogoutFlow.wipeAndComplete()`, the logout's own wipe-and-sign-out, so the two ways off an account cannot diverge — then goes to Login.
  - **The server half is `delete_my_account()`** (`supabase/migrations/20261008100000_delete_my_account.sql`), a `SECURITY DEFINER` function that takes no arguments and can only ever act on `auth.uid()`, mirroring `abandon_provisional_account()` and differing exactly where it must: that one may only remove an account that never did anything, while this one removes an account that has done everything and leaves **no residue**. It answers `{"status":"removed"}`, `{"status":"refused","reason":…}` or `{"status":"unauthenticated"}`. It **refuses, changing nothing,** for a **firm account** (`profiles.firm_id`, or owning a `firms` row — a firm's domain rows are shared with colleagues, so the account must be removed from the firm first) and for an **app administrator** (their rows include other people's payment ledger). Otherwise it hard-deletes, children before parents: the caller's `delete_requests` (a request they merely reviewed is somebody else's, so only its `reviewed_by` link is cleared), `conflict_log`, `case_history`, `notes`, `case_references`, `case_notification_preferences`, `cases`, their custom rows in the six editable reference tables (seeded rows carry `user_id is null` and survive), their `payment_approval_events` and `payment_submissions`, `mutation_receipts`, `firm_invites` and `firm_members` — and finally the `auth.users` row, which cascades `profiles`, the preference rows, `invite_attempts`, `app_admins` and the Auth sessions. **One deliberate exception:** `payment_approval_events` is an immutable audit ledger whose trigger refuses deletes for every role, so the function disables that trigger for its own two statements and re-enables it inside the same transaction — it can never be left off. `authenticated` may execute it; `public` and `anon` may not. Verified against the project on a rolled-back transaction over an account holding a case, a payment, its approval event and three receipts: every residue count came back 0, the 1,016 seeded court rows survived, the ledger trigger was enabled again, and both refusals answered with their reason while changing nothing.
  - **Change Password** (on **Manage Account**, directly under Logout) → the Login screen's emailed-code reset flow (`forgot_password_screen.dart`), reached as its **own Settings sub-page** (`/settings/change-password`): the standard `SettingsSubPageModal` header with a back button, and **no "Back To Login" line**, because this user is signed in. It is a separate route from Login's `/forgot-password` on purpose — that is an **auth route**, and the router sends a signed-in user away from every auth route, so pushing it from the app only ever landed on the default landing page. A successful change from Settings returns to **Manage Account**, and one started from Login ends with the user signed in and the app opening on the Daily Cause List — because a typed code is not a link (see the recovery-event bullet above), and the reset creates a real session that the router will not let a Login screen coexist with.
- **Backup & Restore** → `legal_case_diary_flutter\mockup_html_screens\settings_backupRestore\code.html`
  - **Encryption On Backup** is a fourth collapsible section, placed **before Automatic Backup**, and is a recorded departure from the mockup (which draws three sections): it explains what a passphrase protects and the cost of forgetting it — there is no way back into a sealed backup without it — then offers **Enable** and **Disable** on one line in the screen's own primary-button style, with the current state named above them. Encryption is a per-user preference (**off by default**) and governs every backup export and the diagnostic bundle: while it is off the file is the readable versioned JSON envelope and nothing is asked for, and while it is on the file is sealed in the authenticated container with a passphrase that is asked fresh on every backup and restore and is never stored. The section's explanation copy is stored in **sentence case**, not Title Case — in this app Title Case is for titles, headings, subtitles and labels only, and a paragraph follows ordinary capitalization; the note under the action card and the recovery screen's two safety-copy bodies follow the same rule, which is also how the mockup's own note is written.

**("Preferences" section)**
- **Edit Court/Steps** → `EditCourtStepsMenuScreen` (`legal_case_diary_flutter\mockup_html_screens\settings_editCourtSteps\code.html`)
  - **Edit Court Names & Categories** → `legal_case_diary_flutter\mockup_html_screens\settings_editCourtSteps_editCourtNamesCategory\code.html`
    - **Supreme Court of Bangladesh**
      - Appellate Division → List of Court Names (drag & drop, FAB add, edit, delete)
      - High Court Division → List of Court Names (drag & drop, FAB add, edit, delete)
    - **Lower Courts**
      - Divisions → List of 8 Divisions (`legal_case_diary_flutter\mockup_html_screens\courtCategory_lowerCourts-Division\code.html`)
        - Each Division → List of Districts (`legal_case_diary_flutter\mockup_html_screens\courtCategory_lowerCourts-Districts\code.html`)
          - Each District → List of Court Categories under it:
            - District Sessions Courts (Criminal)
            - District Courts (Civil)
            - Chief Judicial Magistrate Courts
            - Chief Metropolitan Magistrate Courts (where applicable)
            - Executive Magistrate Courts
            - Tribunals
          - Each Category → List of Court Names (`legal_case_diary_flutter\mockup_html_screens\courtCategory_lowerCourts-Districts_listOfCourts\code.html`) with drag & drop, FAB add, edit, delete buttons.
  - **Edit Case Types, Steps etc.** → A sub-menu page where all court categories are shown as KanBan cards. Under each category name, **Case Types**, **Steps**, and **On Behalf** buttons are listed. Clicking any button shows a list with drag & drop, FAB add, edit, delete. UI Reference: `legal_case_diary_flutter\mockup_html_screens\settings_courtNamesSteps\code.html` — **remove the Court Names button**, as court names are managed separately above.
- **Notifications** → `legal_case_diary_flutter\mockup_html_screens\settings_notifications\code.html`
- **Language** → Inline toggle (Bengali / English)
- **View Settings** → View Settings screen

**("App Info" section)**
- **Guidelines** → `legal_case_diary_flutter\mockup_html_screens\guidelines\code.html`
- **About** → `legal_case_diary_flutter\mockup_html_screens\settings_about\code.html`

#### Settings — Critical Rules
- All sub-menu page bodies must be designed **exactly** like their referenced HTML mockup files. The App header with back button uses `settings_sub_page_modal.dart`. Use of the mentioned mockup HTML files is **mandatory, not optional**.
- All Divisions, Districts, Court Categories under all districts, list of court names under all categories, and court names for Appellate Division / High Court Division are to be **pre-seeded** in `pre_seeded_data.dart`. Users can add items later through the sub-menu pages.
- List of Court Categories and Court Names must be presented with drag & drop, FAB add, edit, delete buttons — matching the `courtCategory_lowerCourts-Districts_listOfCourts\code.html` mockup.
  - Implemented as the **Lower Court Categories** card in Edit Court/Steps (added during Task 12 Phase 3): Divisions → Districts → the categories present in that district (a pre-seeded category with no court in `pre_seeded_data.dart` is hidden; user-added ones are district-scoped). This list is the end of that walkthrough — court names stay in Edit Court Names & Categories. Categories owned by the user live in `court_categories` with `division`/`district` set (schema v7) and can be renamed, reordered and deleted; built-ins can be renamed and reordered but not deleted (`LocalCourtCategoriesRepository.delete` refuses them). The list is shared with the Add/Edit Case form through `lib/features/settings/data/district_court_categories.dart`, so both show the same categories in the same `order_index` serial.

---

### 9. Notes Screen
- **UI Design Reference:** Must use `legal_case_diary_flutter\mockup_html_screens\notes\code.html` file to design the UI of the screen and the Add/Edit Note form. Just add a search button to the right of the app header to search through note title and body text.
- **Sorting:** Note cards are sorted by `created_at` **descending** — the latest note sits at the top.
- **Note Card UI Layout:** Must match exactly like the mockup html file's note card (`legal_case_diary_flutter\mockup_html_screens\notes\code.html`).
  - **Part 1:** Modified date and time in `DD/MM/YY, HH:MM AM/PM` format. To the right: a **Delete** button (shows confirmation window before deleting) and a **Pin** button.
  - **Part 2:** Title of the note in bold, slightly bigger text.
  - **Part 3:** Note body text.
- **Note:** Keep the hovering/selection effects intact from the mockup HTML file.
- Notes screen access in firm mode: Notes are visible and editable like case entries to all members of the firm.

---

### 10. Case Reference Screen
- **UI Design Reference:** Must use `legal_case_diary_flutter\mockup_html_screens\caseReference\code.html` file to design the UI of the screen and the Add/Edit Case Reference form.
- **App Header:** Left side — the same navigation panel button from the cases screen; next to it the "Case Reference" title; far right — a search button.
- **Add Case Reference Form Fields:** `reference_and_page_no`, `statute`, `section_or_article`, `title_and_description`, `comments_notes`.
- **Sorting:** Case reference cards are sorted by `created_at` **descending** — the latest entry sits at the top. Pinned items always appear above non-pinned items.
- **Case Reference Card UI Layout:** Must match exactly like the mockup html file's card (`legal_case_diary_flutter\mockup_html_screens\caseReference\code.html`).
  - **Line 1:** `reference_and_page_no` and `statute` on the left | 3-dot button on the right. Clicking the 3-dot button shows 2 options: **Pin** (pins the reference to the top) and **Delete** (shows a confirmation window before deleting).
  - **Line 2:** `section_or_article`
  - **Line 3:** `title_and_description`
  - **Line 4:** `comments_notes`
- **Note:** Keep the hovering/selection effects intact from the mockup HTML file.
- Case Reference screen access in firm mode: Notes are visible and editable like case entries to all members of the firm.

---

## Proposed Architecture & Subscription Enforcement

### MVVM + Repository + Dual-Sync Mode + Subscription Enforcement
```
UI Layer (Widgets/Screens)
    │
    ▼
ViewModel Layer (Riverpod AsyncNotifiers)
    │
    ▼
Repository Layer (Abstracts Local vs Remote)
    │
    ├──► Local Data: Drift (SQLite)   [Used for immediate UI feedback & offline]
    └──► Remote Data: Supabase        [Realtime sync if Premium; Disabled if Free]
```

---

## Folder & File Structure

```
lib/
├── main.dart                          # Entry point (ProviderScope)
├── app.dart                           # MaterialApp, theme, GoRouter setup
│
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # Justice Ledger colors
│   │   ├── app_typography.dart        # Manrope, Inter, IBM Plex, Tiro Bangla
│   │   ├── app_spacing.dart           # Fluid spacing rules
│   │   ├── app_version.dart           # Bundled app version shown on About (guarded against pubspec + version history)
│   │   ├── app_strings.dart           # l10n key references (not raw strings)
│   │   └── pre_seeded_data.dart       # Pre‑seeded data: courts (nested by district via lowerCourtNamesByDistrict), steps (per category), case types (per category), on behalfs (per category)
│   ├── theme/
│   │   └── app_theme.dart             # ThemeData configurations
│   ├── router/
│   │   └── app_router.dart            # GoRouter route declarations
│   ├── l10n/
│   │   ├── app_translations.dart      # Custom translation file organized by screens/sub-menus
│   │   ├── app_en.arb                 # English strings
│   │   └── app_bn.arb                 # Bengali strings
│   └── utils/
│       └── date_utils.dart            # Epoch ms ↔ DD/MM/YYYY display converter
│       └── pdf_generator.dart         # PDF rendering for Print feature
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── local_auth_service.dart # Cached login credentials store
│   │   └── presentation/
│   │       ├── login_screen.dart       # Unified single login screen (Email + Password)
│   │       ├── signup_screen.dart      # Registration & Join Firm via Invite Code
│   │       └── auth_viewmodel.dart
│   │
│   ├── cases/
│   │   ├── data/
│   │   │   ├── case_repository.dart
│   │   │   └── local/cases_dao.dart
│   │   └── presentation/
│   │       ├── cases_screen_modal.dart # Reusable modal layout with side navigation panel button and panel itself, page header, search button, view toggles, manual sync, and customizable bottom nav bar
│   │       ├── daily_cause_list/
│   │       │   ├── daily_cause_list_screen.dart
│   │       │   └── daily_cause_list_viewmodel.dart
│   │       ├── all_cases/
│   │       │   └── all_cases_screen.dart
│   │       ├── active_cases/
│   │       │   └── active_cases_screen.dart   # Same as All Cases but filters to non-disposed steps only
│   │       ├── upcoming_cases/
│   │       │   └── upcoming_cases_screen.dart
│   │       ├── overdue_dates/
│   │       │   └── overdue_dates_screen.dart
│   │       ├── disposed_cases/
│   │       │   └── disposed_cases_screen.dart
│   │       └── case_detail/
│   │           └── case_detail_screen.dart # Pushed from case lists; shows KanBan cards for Parties, Description, Case History
│   │
│   ├── case_reference/
│   │   ├── data/
│   │   │   └── reference_repository.dart
│   │   └── presentation/
│   │       └── case_reference_screen.dart  # Precedents and citations library (with side navigation panel button and search button)
│   │
│   ├── notes/
│   │   ├── data/
│   │   │   └── notes_repository.dart
│   │   └── presentation/
│   │       └── notes_screen.dart           # Notes screen (with side navigation panel button and search button)
│   │
│   ├── payments/
│   │   ├── data/
│   │   │   └── payment_repository.dart     # Handles in-app MFS payment submissions
│   │   └── presentation/
│   │       ├── paywall_screen.dart         # Premium benefits display & plan selection [Design-deferred]
│   │       ├── checkout_screen.dart        # Manual MFS transfer instructions & TrxID form [Design-deferred]
│   │       └── payment_viewmodel.dart      # Controls checkout submission state + local draft
│   │
│   ├── settings/
│   │   ├── data/
│   │   │   ├── settings_repository.dart
│   │   │   ├── district_court_categories.dart    # Shared lower-court category derivation + order helpers
│   │   │   └── notification_day_offsets.dart     # One day-offset list shared by Settings and the case form
│   │   └── presentation/
│   │       ├── settings_main_screen.dart          # Main settings screen (UI: settings_main/code.html)
│   │       ├── settings_sub_page_modal.dart       # Reusable modal layout with back button for all sub-pages
│   │       ├── settings_menu_card.dart            # Shared sub-menu card/button size contract (76 px card, 56 px CTA)
│   │       ├── edit_court_steps/
│   │       │   ├── edit_court_steps_menu.dart         # (UI: settings_editCourtSteps/code.html)
│   │       │   ├── edit_court_names_category_screen.dart  # (UI: settings_editCourtSteps_editCourtNamesCategory)
│   │       │   ├── court_names_steps_screen.dart      # Case Types, Steps, On Behalfs (UI: settings_courtNamesSteps)
│   │       │   ├── court_category_screen.dart         # Division picker (UI: courtCategory_lowerCourts-Division)
│   │       │   ├── district_list_screen.dart          # District list (UI: courtCategory_lowerCourts-Districts)
│   │       │   ├── district_court_category_screen.dart  # A district's court categories (Edit Court Names walkthrough)
│   │       │   ├── lower_court_category_list_screen.dart  # Lower Court Categories of one district (sub-menu "Lower Court Categories")
│   │       │   ├── court_category_label.dart          # Shared court-category label resolution (seed key or typed name)
│   │       │   └── court_list_screen.dart             # Court names of one category (UI: courtCategory_lowerCourts-Districts_listOfCourts)
│   │       ├── settings_notifications/
│   │       │   └── notification_settings_screen.dart  # (UI: settings_notifications/code.html)
│   │       ├── settings_view/
│   │       │   └── view_settings_screen.dart          # Upcoming Cases Period, tab order, etc.
│   │       ├── settings_controls.dart             # Shared sub-page controls (section card, 48 px picker row, option row)
│   │       ├── settings_about/
│   │       │   ├── more_about_app_screen.dart         # About (UI: settings_about/code.html)
│   │       │   ├── more_about_the_app_screen.dart     # More About the App (UI: settings_moreAboutTheApp/code.html)
│   │       │   └── guidelines_screen.dart             # (UI: guidelines/code.html)
│   │       └── backup_restore_screen.dart         # (UI: settings_backupRestore/code.html)
│   │
│   └── accounts_and_profile/
│       ├── data/
│       │   ├── profile_repository.dart
│       │   └── firm_repository.dart
│       └── presentation/
│           ├── accounts_profile_menu_screen.dart # Settings > Accounts & Profile main sub-menu
│           ├── profile_screen.dart               # Profile details (name, role)
│           ├── manage_account_screen.dart       # Account details & Subscription state
│           └── manage_associates_screen.dart     # Add/Manage associates & toggle deletion perms [Design-deferred]
│
├── shared/
│   ├── widgets/
│   │   ├── app_navigation_drawer.dart   # Left navigation panel (Daily Cause List drawer template)
│   │   ├── bottom_nav_bar.dart          # 4 Configurable Tabs
│   │   ├── case_card.dart               # Overdue has red left border strip
│   │   ├── add_edit_case_sheet.dart     # Modal with Lead Counsel inputs
│   │   ├── calendar_picker_dialog.dart  # Badge count calendar (Daily Cause List only)
│   │   └── custom_dropdown.dart         # Single & multi-select searchable dropdown
│   └── providers/
│       └── database_provider.dart
│
├── database/
│   ├── app_database.dart                # Drift DB definition
│   └── tables/
│       ├── cases_table.dart
│       ├── case_history_table.dart
│       ├── court_categories_table.dart
│       ├── case_categories_table.dart
│       ├── courts_table.dart
│       ├── steps_table.dart
│       ├── case_types_table.dart        # Custom/preseeded case types
│       ├── on_behalfs_table.dart        # Custom/preseeded representational options
│       ├── notes_table.dart
│       ├── references_table.dart
│       ├── firms_table.dart
│       ├── firm_members_table.dart      # Local cache of firm membership & permission flags (can_add/can_edit/can_delete). No passwords or secrets are ever stored locally — Supabase Auth owns all credentials.
│       ├── delete_requests_table.dart   # Local delete-request queue (offline create/approve — see Sync Plan §1 & schema note)
│       ├── conflict_log_table.dart      # Rejected mutation + authoritative-row conflict log (mirrored to Supabase)
│       └── sync_queue_table.dart
│
├── sync/
│   ├── sync_service.dart                # Orchestrates delta pull, cursor management, resume throttle, clock-skew check
│   ├── push_worker.dart                 # Single serialized FIFO: compaction matrix, FK-safe ordering, 2–3 s micro-batching, retry/backoff policy → push_changes RPC
│   ├── realtime_listener.dart           # One Broadcast channel per session (private firm/user topic); micro delta pull on {table, id} ping
│   └── connectivity_monitor.dart        # connectivity_plus stream subscription (no polling) + WebSocket reconnect backoff
│
├── assets/
│   └── fonts/
│       ├── TiroBangla-Regular.ttf       # Tiro Bangla Bengali font file
│       ├── Manrope-VariableFont_wght.ttf
│       ├── Inter-VariableFont_slnt,wght.ttf
│       └── IBMPlexSans-Regular.ttf
│
└── docs/
    ├── systemRequirements.md
    ├── version_history.md               # See Development Workflow §4 (Version History Tracking)
    └── currentlyWorking.md              # See Development Workflow §7 (Progress Tracker)
```

---

## Database Schema

> **Naming Convention Mapping:** To ensure seamless DB-to-Dart translation without custom mapping boilerplates, the industry standard is used:
> - **Database Columns (SQLite & PostgreSQL):** `snake_case` (e.g., `court_id`, `case_number`, `is_deleted`).
> - **Dart Model Fields / JSON:** `camelCase` (e.g., `courtId`, `caseNumber`, `isDeleted`).
> - **Drift Auto-mapping:** Drift maps these automatically so that database files use native `snake_case` columns and generated Dart classes use native `camelCase` fields, preventing naming mismatches.

> **Timestamp Convention (explicit storage boundary):** Drift stores timestamps as `INTEGER` Unix epoch milliseconds because SQLite has no native timestamp type. Supabase/PostgreSQL stores server-authoritative instants (`server_updated_at`, submission/approval times, subscription expiry, audit times, invite attempts) as `TIMESTAMPTZ`; client-origin display metadata such as local `updated_at` may remain `BIGINT` epoch milliseconds because it is untrusted and never used for authorization, ordering cursors, or conflict acceptance. Repository serializers convert `TIMESTAMPTZ` ISO-8601 UTC values to/from local epoch milliseconds at the boundary. Calendar-only legal dates such as `next_date` and `hearing_date` are normalized to a local civil date (start-of-day in the configured Bangladesh timezone) and compared by calendar date, never as an arbitrary UTC instant. The display layer (`date_utils.dart`) renders the configured locale and timezone consistently.

> **Sync Columns:** Every synced data table (`cases`, `case_history`, `notes`, `case_references`, `court_categories`, `case_categories`, `courts`, `steps`, `case_types`, `on_behalfs`, `delete_requests`) includes:
> - `updated_at` (INTEGER) — Epoch ms of the last local modification, retained for display/audit only. It never decides write acceptance because device clocks are untrusted.
> - `version` (INTEGER) — Monotonic per-row revision assigned **only by the server**. Inserts receive version 1; accepted updates receive `current_server_version + 1`. Clients never choose or increment the authoritative value.
> - `server_updated_at` (TIMESTAMPTZ, **Supabase only**) — Maintained by a Postgres `BEFORE INSERT OR UPDATE` trigger (`server_updated_at = now()`). This is the only column delta pulls filter on. It does not exist in the local Drift schema.
> - `synced_at` (INTEGER) — Epoch ms of last successful Supabase push. `null` means unsynced.
> - `is_deleted` (BOOLEAN) — Soft delete flag. Never hard-delete rows.
> - `last_modified_by` (TEXT/UUID) — User ID of the last accepted editor, assigned/validated by the server from `auth.uid()`.
>
> **Optimistic concurrency contract (server-authoritative):** Every queued update/delete carries the row's last known `base_version` (also called `expected_version`). `push_changes` accepts it only when `base_version = current server version`, applies the mutation, and assigns the next version. A mismatch never falls back to timestamps or UUID ordering; it returns a structured `conflict` result containing the current server row/version and the submitted mutation metadata. This prevents two offline clients that both edited version 1 from independently claiming version 2, and prevents a tampered client from winning with an artificially large version. Inserts are idempotent by stable row ID + `mutation_id`. (The `version` and `server_updated_at` columns are not repeated in each table definition below — they apply globally per this note.)

---

### `profiles` (One per Supabase user — controls subscription & firm membership)
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | References `auth.users` |
| `full_name` | TEXT | The account holder's display name — the one self-service column since Phase 3 |
| `email` | TEXT | The account's login e-mail, mirrored from `auth.users.email` by the sign-up and e-mail-change triggers. **Server-owned:** never client-writable |
| `bar_association` | TEXT | The bar association the holder is enrolled in. Self-service on the holder's own row (see Resolved Design Clarifications, "The Lawyer's Own Details") |
| `membership_no` | TEXT | The holder's bar membership/registration number. Self-service on the holder's own row |
| `office_address` | TEXT | The holder's chamber/office address. Self-service on the holder's own row |
| `mobile_no` | TEXT | The holder's mobile number as the editor captured it — the local form with its leading `0`, no country code (the editor's fixed `+88` prefix box carries that). Self-service on the holder's own row |
| `firm_id` | UUID FK → `firms` | null for individual lawyers |
| `role` | TEXT | `owner`, `associate`, `viewer`, `individual` |
| `subscription_status` | TEXT | `free` or `premium` — **display/analytics only.** Premium entitlement is always *derived* as `subscription_expiry (+ 48h grace) > now()` on the client, in RLS, and in the `push_changes` RPC. A stored status can go stale — nothing fires at the expiry instant to flip it. |
| `subscription_expiry` | TIMESTAMPTZ | null if free. **The single source of truth for premium entitlement; evaluated against database `now()`.** Converted to epoch ms only in the local repository model. |
| `last_successful_sync_at` | TIMESTAMPTZ | **Admin analytics only.** The extended-offline reset check is per-*device*: each device stores its own epoch-ms `last_successful_sync_at` locally and checks that value on reconnect (see Sync Plan §3). |
| `created_at` | TIMESTAMPTZ | `NOT NULL DEFAULT now()`; server-assigned |

---

### `firms`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `name` | TEXT | Chamber/firm name |
| `owner_id` | UUID FK → `auth.users` | The principal lawyer |
| `subscription_status` | TEXT | `free` or `premium` — mirrors owner's subscription. **Display only** — firm entitlement is derived from `subscription_expiry` (see `profiles`). |
| `subscription_expiry` | TIMESTAMPTZ | Mirrored from the owner's profile by **`mirror_owner_subscription_to_firm`**, an `AFTER UPDATE OF subscription_expiry ON profiles` trigger that fires for the linked owner and copies expiry plus display-only status onto that owner's firm. This is the only write path; deploy it in the same migration as `approve_payment`. Source of truth for firm-wide sync entitlement. |
| `created_at` | TIMESTAMPTZ | `NOT NULL DEFAULT now()`; server-assigned |

---

### `firm_members`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `firm_id` | UUID FK → `firms` | Chamber reference |
| `user_id` | UUID FK → `auth.users` | Each associate has their own Supabase auth account |
| `role` | TEXT | `associate`, `viewer` |
| `can_add` | BOOLEAN | Permission flags |
| `can_edit` | BOOLEAN | |
| `can_delete` | BOOLEAN | |
| `synced_at` | INTEGER | Epoch ms |
| `permissions_synced_at` | INTEGER | Device-local epoch ms of the last successful permission refresh; used to label provisional offline actions and trigger refresh on launch, resume, and reconnect. |

> **Permission freshness and rollback:** The local permission cache is advisory; `push_changes` is always authoritative. Before every online permission-sensitive action, and on launch/resume/reconnect, refresh `firm_members`. When offline, authorized-looking case operations may proceed **provisionally** so the diary remains useful, but the queue entry must retain a pre-mutation snapshot. If the server rejects it because permissions changed, restore the authoritative server row (or the pre-mutation snapshot until the pull completes), resolve/remove the rejected queue entry, refresh permissions, and show *"Your firm permissions changed; this pending action was not applied."* Destructive provisional actions must be visibly marked pending. Firm-administration operations remain online-only.

> **Note on Associate Auth & Invite System:** Associates are full Supabase `auth.users` (created with their email + password). Onboarding uses a **single-use Invite Code** generated by the firm owner (see `firm_invites` below). The associate uses it **once** during Sign Up — like an OTP — to link their new account to the firm. From then on, they simply log in with Email + Password like any modern SaaS app (e.g., Slack, Notion). No secret keys or associate password hashes are ever stored anywhere (locally or on the owner's device) — Supabase Auth owns all credentials. This is highly secure, leverages Supabase RLS, and provides a frictionless, professional user experience.

---

### `firm_invites` (Single-use onboarding codes — replaces the former `firms.secret_key`)
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `firm_id` | UUID FK → `firms` | |
| `code_hash` | TEXT UNIQUE | SHA-256 hash of a cryptographically random, normalized invite code with at least 50 bits of entropy (for example 10 Crockford Base32 characters). Plaintext is shown once, never stored or logged. |
| `created_by` | UUID FK → `auth.users` | The owner who generated the code |
| `used_by` | UUID FK → `auth.users` | null until redeemed. **Single-use:** once set, the code can never be used again. |
| `used_at` | INTEGER | Epoch ms — null until redeemed |
| `revoked` | BOOLEAN | The owner can revoke an **unused** code at any time. Default `false`. |
| `created_at` | INTEGER | Epoch ms |

> **Redemption flow (online-only):** Codes have **no expiry** but are strictly **single-use** (OTP-style) and revocable before use. Joining goes through a `SECURITY DEFINER` RPC `join_firm(code)` — required anyway, since an associate cannot SELECT the firm pre-membership under RLS. The RPC: hashes the input, matches an unused & unrevoked row, creates the `firm_members` row, updates the associate's `profiles.firm_id`/`role`, and marks the invite used — all in one transaction. **Rate limiting (concrete mechanism):** max 5 failed attempts per 15 minutes per user, tracked server-side in a small **`invite_attempts`** table (see below). At the start of `join_firm`, the RPC counts rows in `invite_attempts` where `user_id = auth.uid() AND attempted_at > now() - interval '15 minutes'`; if the count is ≥ 5, it raises a "Too many attempts — try again later" exception before touching `firm_invites`. Every **failed** match records an attempt through a non-exception return path (for example `{status: 'invalid_code'}`), so the insert commits; do not insert and then `RAISE`, because PostgreSQL would roll the attempt back with the statement/transaction. A successful redemption deletes the caller's attempt rows. Rows older than 15 minutes are ignored by the check and lazily cleaned up by the RPC itself (a `DELETE ... WHERE attempted_at < now() - interval '1 day'` on each call) — no cron job needed. Single-use + rate limiting makes brute-force guessing infeasible even with a short, typeable code.

---

### `invite_attempts` (Server-side rate-limit ledger for `join_firm`)
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `user_id` | UUID FK → `auth.users` | The caller who attempted a code redemption |
| `attempted_at` | TIMESTAMPTZ | Server time (`now()`), assigned inside the RPC — never client-supplied |

> **Access:** This table is written and read **exclusively** by the `SECURITY DEFINER` `join_firm(code)` RPC. RLS denies all direct client access (no SELECT/INSERT/UPDATE/DELETE policies for `authenticated`). It is a server-internal ledger, never synced to the device. Create `CREATE INDEX invite_attempts_user_attempted_at_idx ON invite_attempts (user_id, attempted_at DESC);` so the rolling-window count remains an indexed lookup. Lazy one-day cleanup is sufficient at launch scale; a scheduled cleanup job may be added later if table volume warrants it—Redis is not required.

---

### `cases`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `user_id` | UUID FK → `auth.users` | The lawyer who created the case |
| `firm_id` | UUID FK → `firms` | null for individuals |
| `court_id` | UUID FK → `courts` | |
| `case_type` | TEXT | |
| `case_category_id` | TEXT NULL FK → `case_categories` | AD/HCD Case Category scope; null for lower courts |
| `case_number` | TEXT | Single text entity (e.g., "110/2021") |
| `honorable_judges` | TEXT NULL | AD/HCD judge or bench names |
| `tender_number` | TEXT NULL | AD/HCD tender number; text storage preserves leading zeroes |
| `previous_court_case` | TEXT NULL | AD/HCD previous court case |
| `district_of_origin` | TEXT NULL | AD/HCD originating district |
| `petitioner` | TEXT | Legal party label |
| `petitioner_lead_counsel` | TEXT | Lawyer name for Petitioner |
| `respondent` | TEXT | Legal party label |
| `respondent_lead_counsel` | TEXT | Lawyer name for Respondent |
| `on_behalf_id` | UUID FK → `on_behalfs` | Client's representation role (e.g. Plaintiff, Defendant, Accused). The client's actual name is extracted at runtime from `petitioner` or `respondent` based on this role. |
| `party_phone` | TEXT | Nullable mobile number of the represented client — the **only** phone column (`petitioner_phone`/`respondent_phone` are withdrawn; see Resolved Design Clarifications) |
| `case_title_and_section` | TEXT | Case description or specific legal sections |
| `case_remarks` | TEXT | Case summary/remarks |
| `next_date` | INTEGER | Epoch ms — next hearing date |
| `last_step` | TEXT | Most recent court step (denormalized for fast list display) |
| `notes_results` | TEXT | Any particular notes or result of the last date |
| `result` | TEXT NULL | AD/HCD result; a configured disposal term marks the case disposed. `case_history.result` snapshots this value per hearing. |
| `created_at` | INTEGER | Epoch ms |
| `updated_at` | INTEGER | Epoch ms |
| `is_deleted` | BOOLEAN | Soft delete flag |
| `synced_at` | INTEGER | Epoch ms — null if unsynced |
| `last_modified_by` | TEXT | UUID of last editing user |

> **The five AD/HCD fields live on the case, not on the hearing.** `case_category_id`, `honorable_judges`, `tender_number`, `previous_court_case`, `district_of_origin` and `result` describe the case itself — they are captured once when the case is filed and edited with it, exactly as the shipped Drift `Cases` row stores them. `case_history` keeps its own `result` as a per-hearing snapshot (see that table below).

---

### `case_history` (Full hearing timeline for a case)
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `case_id` | UUID FK → `cases` | |
| `user_id` | UUID FK → `auth.users` | Denormalized owner — required for Realtime topic scoping and RLS filtering directly on this table (no join available in channel filters). |
| `firm_id` | UUID FK → `firms` | Denormalized — null for individuals. Required so firm-wide sync and change notifications can filter this table directly. |
| `hearing_date` | INTEGER | Epoch ms — date of the hearing |
| `last_step` | TEXT | Court procedure step at this hearing |
| `next_date` | INTEGER | Epoch ms — the next date set at this hearing |
| `note_result` | TEXT | What happened at the hearing (UI: "Note/Result") |
| `result` | TEXT NULL | Snapshot of the case's AD/HCD `result` at the moment this hearing was frozen; null for lower courts, which use steps |
| `created_by` | TEXT | UUID of the user who logged this entry |
| `source_mutation_id` | UUID | Unique ID of the accepted case mutation that created this immutable history event; UNIQUE on the server for idempotency. |
| `base_case_version` | INTEGER | Case version the accepted mutation was based on. |
| `result_case_version` | INTEGER | Server-assigned case version produced by the accepted mutation. |
| `updated_at` | INTEGER | Epoch ms |
| `is_deleted` | BOOLEAN | |
| `synced_at` | INTEGER | Epoch ms |
| `last_modified_by` | TEXT | UUID |

> **Authoritative history rule:** A local edit may stage a provisional history preview, but authoritative `case_history` is created **inside the same `push_changes` transaction** only after the parent case mutation passes `base_version` validation. The RPC writes one immutable history event keyed by `source_mutation_id`, with `base_case_version` and `result_case_version`; retries cannot duplicate it. A rejected/conflicting case mutation creates no normal history row—its attempted payload belongs in `conflict_log`. Clients pull history normally and do not infer validity from numeric ordering alone.

---

### `court_categories` (Canonical scope shared by courts, steps, case types, and representation roles)
| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | Stable machine key such as `appellate_division`, `high_court_division`, `district_sessions_criminal`, `district_courts_civil`, `chief_judicial_magistrate`, `chief_metropolitan_magistrate`, `executive_magistrate`, `tribunals`; never a localized label. |
| `name_key` | TEXT | Localization key resolved through `app_translations.dart`. |
| `court_level` | TEXT | `appellate`, `high_court`, or `lower`. |
| `order_index` | INTEGER | Canonical display order. |
| `is_custom` | BOOLEAN | Built-in vs user-created category. |
| `user_id` | TEXT | Creator for custom individual categories; null for built-ins. |
| `firm_id` | TEXT | Firm scope for custom firm categories; null for built-ins/individuals. |
| `is_deleted` | BOOLEAN | Soft delete flag. |

> Appellate Division and High Court Division are complete categories in this table, not merely hierarchy headings. UI labels such as "Appellate Division" are mapped to these stable IDs; changing language or wording cannot break foreign-key-style scoping.

### `case_categories` (Case categories nested under a court category)
| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | Stable deterministic machine key; never a localized label. |
| `court_category_id` | TEXT FK → `court_categories.id` | Owning canonical court category. |
| `name` | TEXT | English seed/custom name; Bengali is resolved through `app_translations.dart`. |
| `order_index` | INTEGER | Canonical display order within the court category. |
| `is_custom` | BOOLEAN | Built-in vs user-created category. |
| `is_user_modified` | BOOLEAN | Preserves customized built-ins during seed migrations. |
| `user_id` | TEXT | Creator for custom individual categories; null for built-ins. |
| `firm_id` | TEXT | Firm scope for custom firm categories; null for built-ins/individuals. |
| `is_deleted` | BOOLEAN | Soft delete flag. |
| `updated_at` | INTEGER | Epoch ms. |
| `version` | INTEGER | Global sync column. |
| `synced_at` | INTEGER | Epoch ms; null until synced. |
| `last_modified_by` | TEXT | UUID. |

> Only AD/HCD Case Types are nested beneath these rows and reference them through `case_category_id`. The current authoritative source is `docs/AD_and_HCD.txt`; lower-court Case Types remain directly scoped by `court_category_id`.

### `courts`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `court_name` | TEXT | Court name (can be in Bengali or English) |
| `higher_lower_courts` | TEXT | `higher_courts` (Supreme Court) or `lower_courts` |
| `division` | TEXT | Bangladesh division (e.g., "Dhaka"). Populated only when higher_lower_courts is 'lower_courts'. |
| `district` | TEXT | Bangladesh district. Populated only when higher_lower_courts is 'lower_courts'. |
| `court_category_id` | TEXT FK → `court_categories.id` | Required for every court. Implicitly `appellate_division`/`high_court_division` for those top-level selections; selected explicitly for lower courts. |
| `order_index` | INTEGER | Canonical seed display order within the district/category list. |
| `is_custom` | BOOLEAN | `true` if added by the user; `false` if pre-seeded |
| `user_id` | TEXT | UUID — creator of custom court. null for pre-seeded. |
| `firm_id` | TEXT | UUID — null for individuals & pre-seeded rows. **Required for firm sharing:** when an associate creates a custom court and a firm case references it, every firm member must be able to resolve that court. Firm-wide SELECT is granted via RLS on this column, and this table is included in firm sync & change notifications. |
| `is_deleted` | BOOLEAN | |
| `updated_at` | INTEGER | Epoch ms |
| `synced_at` | INTEGER | Epoch ms |
| `last_modified_by` | TEXT | UUID |

---

### `steps` (Court procedure steps linked to a court category)
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `court_category_id` | TEXT FK → `court_categories.id` | Stable category scope, including Appellate and High Court divisions. |
| `step_name` | TEXT | Name of the procedural step |
| `order_index` | INTEGER | Display order |
| `is_custom` | BOOLEAN | User-added or pre-seeded |
| `user_id` | TEXT | UUID — creator. null for pre-seeded. |
| `firm_id` | TEXT | UUID — null for individuals & pre-seeded rows. Firm-wide SELECT via RLS; included in firm sync (see `courts` note). |
| `is_deleted` | BOOLEAN | |
| `updated_at` | INTEGER | Epoch ms |
| `synced_at` | INTEGER | Epoch ms |
| `last_modified_by` | TEXT | UUID |

---

### `case_types` (Case types scoped by court category; AD/HCD additionally by Case Category)
// Note: Every case type is scoped by `court_category_id`; only AD/HCD case types additionally require `case_category_id`.
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `court_category_id` | TEXT FK → `court_categories.id` | Stable category scope shared with courts and steps; drives Add/Edit Case filtering. |
| `case_category_id` | TEXT NULL FK → `case_categories.id` | Case Category scope for AD/HCD only; null for lower-court case types. |
| `name` | TEXT | Name of the case type (e.g., "Writ Petition", "Civil Suit") |
| `order_index` | INTEGER | Canonical display order within its court/category scope. |
| `is_custom` | BOOLEAN | User-added or pre-seeded |
| `user_id` | TEXT | UUID — creator. null for pre-seeded. |
| `firm_id` | TEXT | UUID    null for individuals & pre-seeded rows. Firm-wide SELECT via RLS; included in firm sync (see `courts` note). |
| `is_deleted` | BOOLEAN | |
| `updated_at` | INTEGER | Epoch ms |
| `synced_at` | INTEGER | Epoch ms |
| `last_modified_by` | TEXT | UUID |

---

### `on_behalfs` (Who we represent)
// Note: On-behalf options are scoped across ALL canonical categories—including Appellate Division and High Court Division—by `court_category_id`. This is mandatory in pre-seeded data and custom configuration.
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `court_category_id` | TEXT FK → `court_categories.id` | Stable category scope shared with courts, steps, and case types; drives Add/Edit Case filtering. |
| `name` | TEXT | Representational label (e.g., "Plaintiff", "Defendant", "Accused", "Appellant") |
| `is_custom` | BOOLEAN | User-added or pre-seeded |
| `user_id` | TEXT | UUID — creator. null for pre-seeded. |
| `firm_id` | TEXT | UUID — null for individuals & pre-seeded rows. Firm-wide SELECT via RLS; included in firm sync (see `courts` note). |
| `is_deleted` | BOOLEAN | |
| `updated_at` | INTEGER | Epoch ms |
| `synced_at` | INTEGER | Epoch ms |
| `last_modified_by` | TEXT | UUID |

---

### `notes`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `user_id` | TEXT | UUID — note owner |
| `firm_id` | TEXT | UUID — null for individuals |
| `title` | TEXT | |
| `body` | TEXT | |
| `is_pinned` | BOOLEAN | `true` if pinned to top. Default `false`. |
| `created_at` | INTEGER | Epoch ms |
| `updated_at` | INTEGER | Epoch ms |
| `is_deleted` | BOOLEAN | |
| `synced_at` | INTEGER | Epoch ms |
| `last_modified_by` | TEXT | UUID |

---

### `case_references` (Precedents & citations library)
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `user_id` | TEXT | UUID — entry owner |
| `firm_id` | TEXT | UUID — null for individuals |
| `reference_and_page_no` | TEXT | Reference name and page number (e.g., "12 BLD (AD) 2024, Page 45") |
| `statute` | TEXT | Name of the Act, Ordinance, or Statute |
| `section_or_article` | TEXT | Specific section or article of the statute |
| `title_and_description` | TEXT | Case title or description of the precedent |
| `comments_notes` | TEXT | Lawyer's personal comments or notes on this reference |
| `is_pinned` | BOOLEAN | `true` if pinned to top. Default `false`. |
| `created_at` | INTEGER | Epoch ms |
| `updated_at` | INTEGER | Epoch ms |
| `is_deleted` | BOOLEAN | |
| `synced_at` | INTEGER | Epoch ms |
| `last_modified_by` | TEXT | UUID |

---

### `delete_requests` (Deletion request queue for associates without delete permission)
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `firm_id` | UUID FK → `firms` | The firm this request belongs to |
| `entity_type` | TEXT | `case`, `case_history`, `note`, `reference` |
| `entity_id` | TEXT | UUID of the record to be deleted |
| `entity_snapshot` | TEXT/JSONB | Snapshot of the target at request time (local TEXT, server JSONB) |
| `target_base_version` | INTEGER | Target version observed when the request was created; required for approval review |
| `requested_by` | UUID FK → `auth.users` | The associate who requested deletion |
| `status` | TEXT | `pending`, `approved`, `rejected`, or `stale_review_required` |
| `reviewed_by` | UUID FK → `auth.users` | The user with `can_delete` who acted on it |
| `review_note` | TEXT | Optional note from the reviewer (e.g., rejection reason) |
| `created_at` | INTEGER | Epoch ms |
| `updated_at` | INTEGER | Epoch ms |
| `is_deleted` | BOOLEAN | Soft delete flag (consistency with all synced tables) |
| `synced_at` | INTEGER | Epoch ms |
| `last_modified_by` | TEXT | UUID |

> **Offline-capable and idempotent workflow:** Delete requests flow through `sync_queue` (`entity_type = 'delete_request'`). Associates may create requests offline, and reviewers may stage approve/reject decisions offline; the server remains authoritative. Approval submits both the request `base_version` and `target_base_version`, locks request and target, and proceeds only when the request is still pending and the target is unchanged. If the target changed, return `target_conflict` with the current snapshot/version, set/show `stale_review_required`, and require the reviewer to inspect and reconfirm—an old snapshot never authorizes deletion of materially changed data. If already soft-deleted, return `already_resolved` with tombstone metadata and retain the request as audit history. Successful approval atomically tombstones the target, resolves the request, records reviewer/server time, and produces idempotent receipts. The client never resolves later queue entries merely because this review completed.

---

### `conflict_log` (Local rejected-mutation record — mirrored to Supabase for device portability)
| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID shared with the Supabase mirror |
| `mutation_id` | TEXT | Stable ID of the rejected logical mutation |
| `entity_type` | TEXT | `case`, `case_history`, `note`, `reference` |
| `entity_id` | TEXT | UUID of the conflicted record |
| `base_version` | INTEGER | Server version the attempted mutation was based on |
| `base_payload` | TEXT | JSON snapshot used as the common three-way base |
| `submitted_payload` | TEXT | JSON payload/patch the client attempted to apply |
| `changed_fields` | TEXT | JSON array of intentionally changed fields |
| `server_version` | INTEGER | Authoritative server version returned by `push_changes` |
| `server_payload` | TEXT | Authoritative row returned by `push_changes` |
| `resolution_state` | TEXT | `unresolved`, `rebased`, `user_resolved`, or `discarded` |
| `conflict_at` | INTEGER | Epoch ms — when the conflict was detected |
| `resolved_at` | INTEGER | Epoch ms; null while unresolved |
| `is_dismissed` | BOOLEAN | UI acknowledgement only; never resolves the conflict |

> **Sync flow:** Every local `conflict_log` entry is queued with `entity_type = 'conflict_log'` and mirrored to Supabase. It records an attempted mutation and the authoritative row, not a simplistic winner/loser. On a new device, conflict history is pulled and merged by `id`; resolution remains driven by successful rebase/push, explicit user selection, or confirmed discard.

---

### `conflict_log` (Supabase mirror — synced for cross-device portability)
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | Same stable ID as the local record |
| `user_id` | UUID FK → `auth.users` | User who submitted the conflicting mutation |
| `firm_id` | UUID FK → `firms` | null for individual lawyers |
| `mutation_id` | UUID | Stable ID of the rejected logical mutation |
| `entity_type` | TEXT | `case`, `case_history`, `note`, `reference` |
| `entity_id` | TEXT | UUID of the conflicted record |
| `base_version` | INTEGER | Version the mutation expected |
| `base_payload` | JSONB | Common base snapshot |
| `submitted_payload` | JSONB | Rejected attempted payload/patch |
| `changed_fields` | JSONB | Fields intentionally changed by the mutation |
| `server_version` | INTEGER | Authoritative version returned by the server |
| `server_payload` | JSONB | Authoritative row returned by the server |
| `resolution_state` | TEXT | `unresolved`, `rebased`, `user_resolved`, or `discarded` |
| `conflict_at` | TIMESTAMPTZ | Server-recorded conflict time |
| `resolved_at` | TIMESTAMPTZ | null while unresolved |
| `is_dismissed` | BOOLEAN | UI acknowledgement only |
| `created_at` | TIMESTAMPTZ | Server time |
| `synced_at` | INTEGER | Device mirror metadata only |

---

### `sync_queue` (Offline change log for background sync)
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK | Auto-increment |
| `entity_type` | TEXT | `case`, `case_history`, `note`, `reference`, `court`, `step`, `case_type`, `on_behalf`, `conflict_log`, `delete_request` |
| `entity_id` | TEXT | UUID of the modified record |
| `operation` | TEXT | `insert`, `update`, `delete` |
| `mutation_id` | UUID | Stable client-generated idempotency key, unique per logical mutation and retained across retries. |
| `base_version` | INTEGER | Last server version observed when this mutation began; null only for a new insert. |
| `base_payload` | TEXT | JSON snapshot of the common base used for three-way comparison/rebase. |
| `changed_fields` | TEXT | JSON array of fields intentionally changed by this mutation. |
| `payload` | TEXT | JSON-serialized intended record state/patch at time of change. |
| `pre_mutation_payload` | TEXT | Snapshot used to roll back a server-rejected permission-sensitive action. |
| `created_at` | INTEGER | Epoch ms — used to order sync operations |
| `retry_count` | INTEGER | Number of failed push attempts (default 0) |
| `state` | TEXT | `pending`, `pushing`, `conflict_pending`, `blocked`, or `resolved`. Replaces a single-purpose blocked flag. |
| `last_error` | TEXT | Last error message (for diagnostics and user recovery) |

> **Retry Policy and recovery:** Each queue entry retries with **exponential backoff** (e.g., 30s → 1m → 2m → 4m … capped at 30m). Network/HTTP 5xx errors are retryable; RLS denial, validation failure, optimistic-concurrency mismatch, and permanent server rejection stop automatic retries immediately and set `state` to `blocked` or `conflict_pending`. After 10 transient failures, mark the entry `blocked` for manual review instead of looping. The push worker is a **single serialized FIFO**—never parallel fire-and-forget pushes.
>
> **Sync Status / Diagnostics screen:** Every user (not just firm admins) can open a Sync Status screen showing entity, operation, state, retry count, last error, and last attempt. Actions: **Retry**, **Discard** (with confirmation and authoritative-row rollback/pull), **Review Conflict**, and **Export Diagnostic Bundle** (redacted metadata + queue payloads suitable for support). A blocked/conflicted badge in the app header links here; no queue row may become permanently invisible.
>
> **FK-Safe Ordering:** Queue entries are ordered by **entity dependency first** (config tables `courts`/`steps`/`case_types`/`on_behalfs` → `cases` → `case_history`/`delete_requests`/`conflict_log`), then by `created_at` within each group. Combined with the atomic `push_changes` RPC (which applies a whole batch in one transaction with correct internal ordering), this makes FK violations from queue reordering impossible.
>
> **Offline Compaction Matrix (per `entity_id`):**
> | Offline operations on the same record | Compacted to |
> |---|---|
> | `insert` + one or more `update`s | single `insert` with the latest snapshot |
> | `insert` + `delete` | **both dropped** — never pushed (the server never needs to know) |
> | `update`(s) + `delete` | single soft-`delete` update with the latest snapshot |
> | multiple `update`s | single `update` with the latest snapshot |
>
> Compaction must preserve the earliest `base_version`/`base_payload`, union the intentional `changed_fields`, retain the latest intended payload, and keep the stable logical `mutation_id` rules required for idempotency. **Never compact across an entity in `conflict_pending`:** freeze that entity's compaction, preserve all later queue entries in order, apply the returned server row as the new authoritative base, and three-way rebase later mutations when their changed fields do not overlap remote changes. If overlap or semantic ambiguity exists, leave the entity `conflict_pending` for user review; banner dismissal or a timeout never determines data correctness.

---

### `payment_submissions`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `user_id` | UUID FK → `auth.users` | |
| `plan_type` | TEXT | `monthly`, `quarterly`, `half_yearly` or `annual` — the machine key, not a label |
| `plan_name` | TEXT | Readable name beside the key — `1 Month`, `3 Months`, `6 Months` or `1 Year` — **generated** from `plan_type` (`0.0.385`). Read-only and never written, so it cannot drift from the key; it exists so the raw table reads plainly in Studio. |
| `amount` | INTEGER | Exact BDT amount paid |
| `mfs_provider` | TEXT | `bkash`, `nagad`, or `rocket` |
| `sender_number` | TEXT | Mobile number payment was sent from |
| `transaction_id` | TEXT UNIQUE | Unique TrxID |
| `status` | TEXT | `pending`, `approved`, `rejected` |
| `admin_notes` | TEXT | For rejection reasons or notes |
| `created_at` | INTEGER | Client/device creation time for display metadata only; never used for security decisions. |
| `submitted_at` | TIMESTAMPTZ | Authoritative server submission time: `NOT NULL DEFAULT now()`. A `BEFORE INSERT` trigger overwrites/rejects any client-supplied value. The 3-per-24h limit counts this column. |
| `approved_at` | TIMESTAMPTZ | Server time set only by `approve_payment`; null until approved. |
| `approved_by` | UUID FK → `auth.users` | Admin actor set from the authenticated admin context. |
| `updated_at` | INTEGER | Epoch ms |

> Create `CREATE INDEX payment_submissions_user_submitted_at_idx ON payment_submissions (user_id, submitted_at DESC);`. Revoke ordinary client UPDATE access to `status`, `approved_at`, `approved_by`, `profiles.subscription_expiry`, and `firms.subscription_expiry`; approval is available only through the RPC below.
>
> **Admin authorization registry:** Create server-internal `app_admins(user_id UUID PRIMARY KEY REFERENCES auth.users, granted_at TIMESTAMPTZ NOT NULL DEFAULT now(), granted_by UUID REFERENCES auth.users)`. No authenticated client receives INSERT/UPDATE/DELETE policies; bootstrap and membership changes occur only through controlled migrations/service-role operations and are audited. Do not trust user-editable profile fields or raw client metadata as admin claims.
>
> **Admin-only atomic `approve_payment(payment_submission_id UUID)` RPC contract:** Implement as `SECURITY DEFINER` with `SET search_path = pg_catalog, public`, schema-qualified object references, owner not used by ordinary clients, `REVOKE ALL ... FROM PUBLIC`, and `GRANT EXECUTE ... TO authenticated`. Because Supabase callers share the `authenticated` database role, the RPC itself must reject unless `EXISTS (SELECT 1 FROM public.app_admins WHERE user_id = auth.uid())`; a database-role grant alone is not authorization. The RPC executes in one transaction and:
> 1. Locks the submission with `SELECT ... FOR UPDATE`; missing rows return `not_found` without revealing unrelated user data.
> 2. Validates `status = 'pending'`, `plan_type IN ('monthly', 'quarterly', 'half_yearly', 'annual')`, and the exact configured BDT amount for that plan (৳100/৳285/৳540/৳960). A rejected submission cannot be approved without a separately audited reset flow.
> 3. Handles retries idempotently: if already approved, return the existing approval result when the stored approval event matches this submission; otherwise return `already_resolved`. Concurrent/duplicate approvals can never extend expiry twice.
> 4. Locks the target `profiles` row, computes the authoritative base as `GREATEST(COALESCE(subscription_expiry, now()), now())`, and adds exactly 1, 3, 6 or 12 calendar months according to `plan_type` (`monthly`/`quarterly`/`half_yearly`/`annual`). All calculation uses server time; no client-supplied approval or expiry time is accepted.
> 5. Updates `profiles.subscription_expiry` and display-only `subscription_status`, then updates the submission to `approved` with `approved_at = now()` and `approved_by = auth.uid()`.
> 6. For a firm owner, mirrors the resulting expiry/status to the matching `firms` row in the same transaction through `mirror_owner_subscription_to_firm`; the trigger and RPC migration are deployed together. Non-owner submissions do not mutate unrelated firms.
> 7. Inserts one immutable `payment_approval_events` row keyed by unique `payment_submission_id`, recording actor, prior/new expiry, plan, amount, and server timestamp. Failure of any validation, profile/firm update, or audit insert rolls back the entire transaction.
>
> ### `payment_approval_events` (Immutable admin audit ledger)
> | Column | Type | Notes |
> |---|---|---|
> | `id` | UUID PK | Server-generated |
> | `payment_submission_id` | UUID UNIQUE FK → `payment_submissions` | One approval event maximum per submission |
> | `user_id` | UUID FK → `auth.users` | Subscription owner |
> | `approved_by` | UUID FK → `auth.users` | Authorized admin actor |
> | `plan_type` | TEXT | Validated `monthly`, `quarterly`, `half_yearly` or `annual` |
> | `plan_name` | TEXT | The same **generated** readable name of `plan_type` (`0.0.385`), so the immutable ledger reads plainly in Studio without its key becoming a label. |
> | `amount` | INTEGER | Validated BDT amount at approval |
> | `previous_expiry` | TIMESTAMPTZ | Value locked before extension |
> | `new_expiry` | TIMESTAMPTZ | Authoritative result |
> | `created_at` | TIMESTAMPTZ | `NOT NULL DEFAULT now()` |
>
> RLS denies every direct client INSERT/UPDATE/DELETE on this ledger; authenticated owners may read only their own events if the product exposes receipts, while admins may read all. No update/delete policy or mutable audit RPC is provided.

> ### `payment_configuration` (MFS receiving numbers — server-managed configuration)
> | Column | Type | Notes |
> |---|---|---|
> | `provider` | TEXT PK | `bkash`, `nagad`, or `rocket` (checked) |
> | `receiving_number` | TEXT | The number users send money to; `<> ''`. Display-only, never an authorization input |
> | `is_active` | BOOLEAN | Only active rows are served to clients |
> | `updated_at` | TIMESTAMPTZ | Server set; `NOT NULL DEFAULT now()` |
>
> RLS: authenticated SELECT only, and **no client INSERT/UPDATE/DELETE policy** — a receiving number is server-managed configuration. It is not seeded: the client falls back to validated build defaults (`--dart-define`) until an admin inserts a row, so a number rotates centrally without a release (Rev 2.4 §5). Added by Task 21 Phase 1.

---

## Row-Level Security (RLS) Strategy

All Supabase tables have RLS **enabled**. Core policies:

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `cases` | `user_id = auth.uid()` OR `firm_id = user's firm_id` | `user_id = auth.uid()` | `user_id = auth.uid()` OR firm member with `can_edit` (coarse rule — the `can_delete` transition is enforced by trigger, see note below) | Soft delete only |
| `case_history` | `user_id = auth.uid()` OR `firm_id = user's firm_id` (denormalized columns — no join needed) | Same as `cases` | Same as `cases` | Soft delete only |
| `courts` | All authenticated (pre-seeded); `user_id = auth.uid()` OR `firm_id = user's firm_id` for custom | `user_id = auth.uid()` | Creator OR firm member with `can_edit` | Soft delete only |
| `steps` | All authenticated (pre-seeded); `user_id = auth.uid()` OR `firm_id = user's firm_id` for custom | `user_id = auth.uid()` | Creator OR firm member with `can_edit` | Soft delete only |
| `case_types` | All authenticated (pre-seeded); `user_id = auth.uid()` OR `firm_id = user's firm_id` for custom | `user_id = auth.uid()` | Creator OR firm member with `can_edit` | Soft delete only |
| `on_behalfs` | All authenticated (pre-seeded); `user_id = auth.uid()` OR `firm_id = user's firm_id` for custom | `user_id = auth.uid()` | Creator OR firm member with `can_edit` | Soft delete only |
| `notes` | `user_id = auth.uid()` OR firm member | Same | Same | Soft delete only |
| `case_references` | `user_id = auth.uid()` OR firm member | Same | Same | Soft delete only |
| `profiles` | `id = auth.uid()` OR **same-firm members** (`firm_id` matches — required so the owner can list associates in Manage Associates, and so "edited by [Name]" / the conflict banner's "[User]" can render) | Supabase trigger on sign-up | `id = auth.uid()` — column-wise only for the holder's own display and detail fields (`full_name`, `bar_association`, `membership_no`, `office_address`, `mobile_no`). `role`, `firm_id`, the entitlement pair and `email` are server-owned and refuse a client UPDATE | Not allowed |
| `firms` | `owner_id = auth.uid()` OR firm member | `owner_id = auth.uid()` | `owner_id = auth.uid()` | Not allowed |
| `firm_members` | Firm members only | Firm owner only | Firm owner only | Firm owner only |
| `firm_invites` | Firm owner only | Firm owner only | Firm owner only (revoke). Redemption happens exclusively via the `SECURITY DEFINER` `join_firm(code)` RPC — associates never touch this table directly. | Not allowed |
| `invite_attempts` | No direct client access | No direct client access | No direct client access | No direct client access — read/written only inside the `SECURITY DEFINER` `join_firm(code)` RPC (rate-limit ledger) |
| `delete_requests` | Firm members of the same `firm_id` | Firm members (any role) | Requester (edit own pending request) OR firm member with `can_delete` (approve/reject) | Not allowed (audit trail) |
| `conflict_log` | `user_id = auth.uid()` | `user_id = auth.uid()` | `user_id = auth.uid()` | Not allowed |
| `payment_submissions` | `user_id = auth.uid()` | `user_id = auth.uid()` + `BEFORE INSERT` trigger enforcing the 3-per-24h rate limit (see §7 — RLS can't count rows per time window) | No ordinary client update; approval only through authorized `approve_payment` RPC | Not allowed |
| `payment_approval_events` | Owner may read own receipt events; admins read all | RPC only | Not allowed | Not allowed (immutable audit ledger) |

> **Delete-transition enforcement (trigger, not RLS):** Postgres RLS `WITH CHECK` sees only the *new* row — it **cannot compare OLD vs NEW**, so a policy like "`can_edit` for standard fields but `can_delete` when setting `is_deleted = true`" is unimplementable in pure RLS. Instead, a `BEFORE UPDATE` trigger on each soft-deletable table detects the delete transition (`OLD.is_deleted = false AND NEW.is_deleted = true`) and verifies the editor has `can_delete` in `firm_members`, raising an exception otherwise. RLS keeps the coarse row-access rules; triggers (and the `push_changes` RPC) handle field-level transitions.
>
> **Premium gate in RLS/RPC:** Wherever a policy or trigger needs to check premium entitlement, it derives it as `subscription_expiry (+ 48h grace) > now()` — never by reading `subscription_status` (see `profiles` schema note).

---

## Detailed Sync Plan & Multi-User Workflow

The synchronization architecture dynamically adapts depending on whether the user is operating individually or within a law firm (Chamber).

### 1. Multi-User/Firm Setup (Offline-First with Realtime Sync)
In multi-user chamber setups, multiple users interact with the same dataset. While real-time updates are preferred when online, the app is fully offline-capable.
- **Account Mode Detection (Individual vs Firm):** Every account starts as an **Individual Account** (`firm_id = null`, `role = 'individual'` in the user profile). The moment the main user adds any associate via `Settings > Accounts & Profile > Manage Associates`, the system creates a `firms` record, sets the main user's `role` to `'owner'`, links both profiles to the new `firm_id`, and transitions the account to a **Firm Account**.
- **Associate Deletion Policy (Delete Request Workflow):** Associates without `can_delete` permission **cannot directly delete records** from the app. Instead, when they attempt to delete a case, note, or reference, the action creates a **Delete Request** entry stored in the `delete_requests` table. This request appears as a notification/badge in the `Settings` dashboard (and optionally `Manage Associates` screen) of all firm members who have `can_delete = true`. A reviewer can tap the notification, view a snapshot of the item to be deleted, and choose to **Approve** (which triggers the soft-delete and sync) or **Reject** (which keeps the record and notifies the requester). Deletion permissions themselves can be granted or revoked at any time by the firm owner via `Settings > Accounts & Profile > Manage Associates`.
- **Offline Continuity:** If the internet connection is lost in Firm mode, the app continues to work as usual. All additions, edits, and deletions (if authorized) are saved to the local Drift database and queued in `sync_queue`.
- **Hybrid Lifecycle-Aware Foreground Sync:** The sync strategy is a battery-efficient hybrid that combines a smart delta pull on resume with Supabase Realtime WebSocket notifications while active, and micro-batched write-through (2–3 s coalescing window) on every local change. This gives near-real-time collaboration with zero background resource consumption:
  - **Smart Delta Pull on App Launch/Resume:** When the user opens or foregrounds the app:
    1. First check the local `sync_queue` for any pending unsynced items. If found, push them to Supabase immediately via the `push_changes` RPC (see §1.1).
    2. Then perform a targeted **delta pull** per synced table using a stable composite cursor **`(server_updated_at, id)`**, ordered ascending by both columns. Query rows satisfying `server_updated_at > cursor.time OR (server_updated_at = cursor.time AND id > cursor.id)` and page with a fixed limit until the page is short. `server_updated_at` is trigger-assigned—never client `updated_at`. The UUID tie-breaker prevents rows sharing the same timestamp from being skipped at page/cursor boundaries.
    3. **Cursor update (per-table, crash-safe):** Maintain an independent composite cursor for every table. After each page is fully committed to Drift in one transaction, persist that page's final `(server_updated_at, id)` in the same durable checkpoint flow; a crash may replay rows but cannot skip them. Do not advance before local commit. An empty page completes that table without inventing a device-clock cursor. For initial/full pulls, start at the minimum sentinel. Store the cursor map per device in the local database (preferred, transactionally adjacent to imported rows), not only in `SharedPreferences`; schema migration/reset must preserve or intentionally reset it. A single shared cursor is forbidden because pulls occur at different times.
    4. **Continuity-aware resume throttle:** Skip a resume pull within 60 seconds **only if the client can prove the same Realtime connection generation remained continuously subscribed since the last successful pull**. Any disconnect, channel error, authentication refresh/reconnect, process suspension with unknown continuity, connectivity restoration, or WebSocket reconnection forces an immediate per-table delta pull before the throttle may apply again. Broadcast is an ephemeral notification—not a durable event log—so uncertain continuity is always repaired through REST delta pull.
    5. **Clock-Skew Detection:** On each successful sync, compare device time against server time. If skew exceeds ~2 minutes, record the offset locally and show a non-intrusive warning: *"Your device clock appears incorrect. Please fix it to ensure reliable syncing."*
  - **Supabase Realtime — "Broadcast from Database" (Foreground Only, Notification Only):**
    The app does **not** use `postgres_changes` subscriptions. `postgres_changes` delivers the **full changed record** (not lightweight pings) and Supabase evaluates RLS *for every subscriber on every change* — this scales poorly and is why Supabase recommends **Broadcast** for production. Instead:
    
    - A Postgres `AFTER INSERT/UPDATE` trigger on each synced table calls **`realtime.send()`** with a tiny payload — just `{table, id}` — to a **private topic**: `firm:{firm_id}` for firm members, or `user:{user_id}` for individuals. Topic access is protected by Realtime authorization (RLS on `realtime.messages`).
    - The client keeps exactly **one** channel open, subscribed to its private topic. On receiving a `{table, id}` ping, the app performs a **micro delta pull** via REST for just the changed row(s).
    - This gives exactly the notification-only behavior the design calls for, at a fraction of the server cost: tiny frames over the socket, no per-subscriber RLS churn, and effectively unlimited firm-member scalability.
    
  - **WebSocket Reconnection Strategy (Exponential Backoff):**
    1. **Immediate attempt** on foreground resume (`didChangeAppLifecycleState == resumed`).
    2. **On failure:** Retry with exponential backoff: 1s → 2s → 4s → 8s → 16s → 32s (max interval).
    3. **After 6 failed retries** (~63 seconds), stop active retrying and rely on the **`connectivity_plus` stream**: the OS broadcasts connectivity changes, so the app reacts instantly when a network appears — **no periodic polling** (the old 30-second connectivity poll is removed; it wasted battery and reacted slower). The built-in `supabase_flutter` auto-reconnect handles transient socket drops; this backoff applies when foreground reconnect fails.
    4. **User-visible indicator:** After 3 consecutive failures, a subtle "Sync paused" status icon appears in the app header. Tapping it forces an immediate retry and resets the backoff counter.
    5. **Graceful degradation and gap repair:** During WebSocket absence, sync continues via REST push/pull on user actions and resume. Track a monotonically increasing local connection generation; after every reconnection or connectivity restoration, push pending changes and then force a per-table delta pull before declaring sync healthy. WebSocket loss therefore causes delayed notification, never an unexamined gap.
    
  - **Micro-Batched Write-Through on Local Action (2–3 s coalescing window):** When the active user performs any action (add/edit/delete a case, note, or reference), the change is saved to the local Drift DB first (for instant UI feedback) and enqueued. A **2–3 second micro-batch window** then coalesces all writes made in that window into **one** `push_changes` RPC call. Rationale: each HTTP request keeps the cellular radio in a high-power state for ~10–20 s afterward (tail energy) — a lawyer updating 25 cases after a court day would otherwise cause 25 radio wake-ups. The window is imperceptible to users, cuts radio usage by an order of magnitude, and *shrinks* the data-loss window because the batch is queued atomically in `sync_queue` on failure. If the push fails (no internet), the batch remains in `sync_queue` for retry on reconnection.
  - **Lifecycle Bounds:** The Realtime WebSocket channel is opened when the app enters the foreground (`WidgetsBindingObserver.didChangeAppLifecycleState == resumed`) and **immediately closed** when the app is backgrounded or the screen is locked. This ensures zero radio usage when the app is idle.
- **Automatic Re-sync:** Once a connection is re-established, the background `SyncService` pushes queued operations to Supabase in dependency-then-`created_at` order (see `sync_queue` FK-Safe Ordering note), then pulls remote changes.
- **Firm Mode Conflict Resolution (Optimistic Concurrency + Three-Way Reconciliation):** Each mutation submits `base_version`, `base_payload`, `changed_fields`, and `mutation_id`. `push_changes` accepts only an exact version match and assigns the next version. On mismatch it returns `conflict` with the authoritative row/version; device timestamps and editor UUIDs never choose a winner.
  - **On push conflict:** Mark the entity `conflict_pending`, freeze compaction for it, preserve every later queue entry, and log the rejected attempted payload in `conflict_log`. Apply the server row as the authoritative base, then three-way compare base/server/local changes. Disjoint field changes may be rebased into a new mutation against the latest server version; overlapping or semantically coupled fields require review.
  - **On pull conflict:** If a pulled row intersects pending local mutations, run the same three-way path rather than deleting pending edits. A pull never silently overwrites a queued mutation.
  - The conflict log is queued to its Supabase mirror for portability. A non-dismissible banner links to **Review Conflict**, showing server values, attempted values, and later preserved edits. The initial release may require manual field selection/copying for ambiguous conflicts, but the wire protocol and queue metadata must support `mergeable_conflict` from day one.
  - Banner dismissal or elapsed time never resolves data. Resolution occurs only through successful rebase/push, explicit user choice, or confirmed discard with authoritative rollback.
- **Online-Only Firm Administration (explicit rule):** Creating a `firms` record, generating/revoking invite codes, adding or removing associates, and changing associate permissions are **online-only operations**. These involve RLS-privileged multi-row server mutations (and the `join_firm` RPC), and supporting them offline invites nasty edge cases for near-zero benefit. The relevant screens (`Manage Associates`, invite generation) show a "Connect to the internet to manage your firm" state when offline. All *case data* operations remain fully offline-capable.

### 1.1 The `push_changes` RPC (Single Atomic Push Pipeline)
All sync writes go through **one Postgres RPC**—`push_changes(rows jsonb)`—instead of direct table upserts. For each logical mutation, the RPC:
1. **Optimistic concurrency:** Locks the target row and accepts an update/delete only when incoming `base_version` equals the current server `version`; inserts require no existing row. On acceptance the server assigns `version = current + 1` (or 1 for insert), `last_modified_by = auth.uid()`, and server time. Clients cannot submit the authoritative resulting version.
2. **Structured conflict response:** A mismatch returns `status = conflict`, the authoritative row/version, `mutation_id`, and enough metadata for three-way reconciliation. It never uses client timestamps or UUID ordering as a fallback.
3. **Atomic history:** When an accepted case mutation changes `next_date`, `last_step`, or `notes_results`, create the immutable `case_history` event in this same transaction using `source_mutation_id`, `base_case_version`, and `result_case_version`. Rejected mutations create no normal history.
4. **Deterministic per-mutation results:** Use one outer transaction and one savepoint per logical mutation, processed in dependency order. A permanent conflict/validation/permission failure rolls back only that mutation to its savepoint and returns a stable result; independent valid mutations may commit. A database/infrastructure error or violated batch invariant aborts the entire RPC. The response contains exactly one result for every submitted `mutation_id`, in input order, so the client never faces a partially unknown batch. Mutations explicitly linked as one domain operation (for example case update + generated history) remain atomic inside one savepoint.
5. **Permission and premium gates:** Re-check current `firm_members` permissions and derived premium entitlement before every applicable mutation. Return stable machine-readable rejection codes so clients can roll back provisional actions correctly.
6. **Idempotency:** Persist a receipt for every terminal mutation result. Retrying a known `mutation_id` with the same canonical request hash returns the original result and cannot increment version or duplicate history; reuse with a different hash returns `mutation_id_reused` and applies nothing.
7. **Tombstone and delete-request semantics:** Writes against soft-deleted rows return the tombstone. Delete requests targeting an existing tombstone return `already_resolved`, not a generic error.

One RPC round trip per micro-batch also delivers the D1 battery win (single radio wake-up per batch).

> **`mutation_receipts` (server-internal idempotency ledger):** Define `mutation_id UUID PRIMARY KEY`, `actor_id UUID NOT NULL`, `entity_type TEXT NOT NULL`, `entity_id UUID NOT NULL`, `request_hash TEXT NOT NULL`, `terminal_status TEXT NOT NULL`, `result_payload JSONB NOT NULL`, and `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`. `push_changes` inserts/reads this table in the same savepoint as the domain mutation. RLS exposes no direct client policies; only the RPC owner can read/write it. Retain receipts for at least the maximum supported offline window plus retry buffer (minimum 210 days), and never purge a receipt still referenced by history/conflict/audit records.

### 2. Upgrade Readiness & Initial Backlog Push (Free → Premium Transition)
> The former "Pre-Push Subscription Count Validation" section has been **removed**. Its premise was a multi-device race (two offline devices at count 49 each adding a case → 51). That race is **impossible**: free accounts never sync and are strictly single-device, and Firm mode requires premium. The only moments case counts and sync interact are the ones below.
- **Always Sync-Ready Architecture:** Even though the free tier never syncs, every local write on a free account still populates `sync_queue` and maintains all sync columns (`version`, `updated_at`, `is_deleted`, `last_modified_by`). The moment the user upgrades, the app is 100% ready to sync with zero migration.
- **Initial Backlog Push on Upgrade:** When a subscription becomes active, the `SyncService` reviews the accumulated `sync_queue`, compacts only eligible `pending` rows, preserves `conflict_pending` rows for review, and exposes `blocked` rows in Sync Status rather than silently clearing them. After user-confirmed retry/repair, it pushes FK-ordered micro-batches through `push_changes`, then performs a full pull. Permanent validation/permission failures remain visible and are never force-retried as ordinary backlog.
- **Free-Tier Case Limit (local enforcement):** The 50 non-deleted case limit is enforced **locally** at the "Add Case" flow with a paywall screen (see §6). Since free accounts never push, no pre-push validation is needed.
- **Server-Side Trigger Guard (defense in depth):** A Postgres trigger on `cases` still rejects INSERTs when the owner's derived entitlement is free and their non-deleted case count is ≥ 50 — catching stale or tampered clients. Because two concurrent inserts under READ COMMITTED could both read 49 and land at 51, the trigger takes `pg_advisory_xact_lock(hashtext(NEW.user_id::text))` before counting, serializing the count-and-insert. (This scenario is nearly impossible given single-device free accounts, but the lock is one line and makes the guard airtight.)
- **Downgrade Behavior:** After premium expiry (past the 48h grace window, §6/§7), sync stops but **no data is deleted** and the 50-case limit is **not** re-imposed on existing cases — a lapsed-premium user keeps everything (see §6).

### 3. Preventing Deleted Data Resurrection (Zombie Data Mitigation)
To prevent older, offline/inactive devices from restoring cases that have been deleted by other users:
- **Soft Deletes (Tombstones):** Hard deletes are avoided. Deletion marks `is_deleted = true` and updates the `updated_at` timestamp. Soft-deleted rows persist on Supabase for **180 days** as tombstones, then are purged by a scheduled DB function.
- **Server-authoritative resurrection guard:** Normal clients cannot write synced tables directly; `push_changes` is the sole mutation path and locks the current row. If the authoritative row is already soft-deleted, the RPC returns `status = 'tombstone'`, the current row/version, and the submitted `mutation_id` without applying or incrementing anything. A narrow `BEFORE UPDATE` defense-in-depth trigger rejects `OLD.is_deleted = true AND NEW.is_deleted = false` unless a separately audited administrator recovery RPC sets a transaction-local authorization flag. The trigger never compares client timestamps, client versions, or editor UUIDs.
- **Client Pull Phase:** If pulled data contains `is_deleted = true`, the client applies the authoritative tombstone locally and hides the record from normal UI queries. If no local mutation is pending, related completed queue entries may be resolved. If pending/later edits exist, preserve them, mark the entity `conflict_pending`, attach the tombstone as `server_payload`, and require explicit rebase/copy-to-new-record or confirmed discard; never silently delete queued work.
- **Client Push Phase:** If a client pushes a modification to a row the server has marked deleted, the server returns the tombstone. The client applies it locally and follows the same reconciliation path: resolve only the rejected mutation after recording the conflict, while preserving later queue entries until explicit resolution.
- **Cascade Soft-Deletes:** An accepted case delete soft-deletes related server `case_history` rows inside the same `push_changes` transaction, assigning each changed child a new server version and `server_updated_at`; server code never writes a device-local `sync_queue`. The originating device applies the returned parent/child rows locally, while other devices receive them through delta pull/Realtime pings. If the local delete was created offline, the client may stage child tombstones for immediate UI consistency, but they are marked derived and reconciled to the server-returned versions rather than pushed as independent mutations. This prevents orphaned history and double version increments.
- **UI & Cleanup:** All UI queries add `WHERE is_deleted = 0` filter. Local soft-deleted records are purged from the device's Drift DB after **90 days** — but **only if their deletion has actually reached the server**: purge requires `synced_at IS NOT NULL AND synced_at >= updated_at`. Without this guard, a tombstone created during a long offline stretch could be purged before it ever synced, losing the deletion — the record would then resurrect from the server on the next pull.
- **Extended Offline Period Reset (per-device, 150 days, firm mode only):** The offline-gap check is **per-device**, not per-user. Comparing against `profiles.last_successful_sync_at` would be defeated by any *other* device keeping the column fresh — e.g., the owner's phone syncs daily while their old tablet sits offline 200 days; the tablet's gap would never be detected, and it is exactly the device the check exists for. Instead, each device keeps its own `last_successful_sync_at`, written by the delta pull into the durable local `sync_metadata` table (the Revision 2.4 Addendum's placement, superseding the earlier `SharedPreferences` note), and checks it on reconnect. The threshold is **150 days** — safely under the 180-day server tombstone retention (a device offline less than that can still sync correctly, since all tombstones it needs are still on the server), with a 30-day buffer before purge. **The lock applies in firm mode only** — an individual account is never locked, because a solo diary has no other writer whose deletions could be resurrected (see Resolved Design Clarifications, "Extended-Offline Recovery Lock Applies to Firm Mode Only"). When a device in **Firm mode** reconnects after ≥ 150 days offline:
  1. In one durable local transaction, set persistent `extended_offline_recovery_required = true` **before** export or network work, pause push/pull workers, and wait for any already-started local write transaction to finish. While this flag is set, repositories reject every mutation and the UI disables editing/FAB actions with a recovery-required message. The lock survives process termination.
  2. **Automatic safety export under the lock:** Export the complete local Drift DB plus all pending/blocked/conflicted `sync_queue` rows and metadata to the versioned Backup & Restore JSON format. Record archive path, checksum, and completion state. No post-export mutation is possible.
  3. Show a blocking warning: *"You have been offline for [X] days. Your local changes have been saved to [path]. Fresh data must be loaded from the server before editing can continue."*
  4. If the user selects:
    (a) **Proceed:** verify the export checksum, clear firm-shared local tables and queue, perform a full authenticated pull, commit the fresh database, then clear `extended_offline_recovery_required` and re-enable mutations. If any step fails, keep the lock and retry safely.
    (b) **Close:** terminate/leave the app locked without cloud writes. On every next launch, restore the blocking recovery flow; do not permit read-write use until recovery succeeds.

### 4. Individual Setup (Offline-First, Queue-Based Sync)
For solo practitioners, the application operates fully offline.
- **Drift First:** All inserts, updates, and soft deletes occur in the local Drift SQLite database.
- **Sync Queue:** Each action generates a row in `sync_queue`.
- **Background Worker:** When an internet connection is established, the `SyncService` processes the queue (compacted, FK-ordered, serialized FIFO) and pushes micro-batches through the `push_changes` RPC.
- **Conflict Resolution (Optimistic Concurrency):** If a premium individual logs in on multiple devices, conflicts use the same exact `base_version` validation, structured server-row response, queue preservation, and three-way reconciliation as Firm mode. Client timestamps and editor UUIDs never decide acceptance.
### 5. Local Database Security & Account Switching
To ensure data security and prevent cross-contamination when users switch accounts on the same device, the local Drift SQLite database and `sync_queue` are completely wiped whenever a user actively logs out. **The logout flow branches by plan and connectivity — a single "mandatory sync before wipe" rule would deadlock free users (who have no sync at all) and offline premium users (who cannot sync), leaving them permanently unable to log out:**
- **(a) Premium + online:** If `sync_queue` has pending rows, a mandatory sync with Supabase is performed. Only after the sync completes successfully does the app wipe the local data and complete the logout.
- **(b) Premium + offline:** Logout is blocked with *"Connect to the internet to sync your changes first."*, alongside an explicit **"Log out anyway"** option. Tapping it shows a warning: *"Some data haven't finished syncing to cloud yet. Logging out now will result in those unsynced data being discarded."* with **Proceed** and **Close** buttons. **Proceed** → the app then **offers** the safety copy (below), and on **Yes** writes it before the wipe — in exactly the same manner and format as `Settings > Backup & Restore > Backup to Local Storage` — with clear messaging: *"Your data has been backed up to [path]. You can restore it after logging back in."* **Close** → the logout flow is cancelled.
- **(c) Free users:** The app **offers** the safety copy (below), and on **Yes** backs the data up in the same manner and format as `Settings > Backup & Restore > Backup to Local Storage`, with the same *"Your data has been backed up to [path]. You can restore it after logging back in."* message. Then the wipe proceeds.
- **The safety copy is offered, never mandatory (0.0.398 — user request).** Every branch that would otherwise auto-export first opens one window — titled **Backup Data to Local Storage**, with **Yes** and **No** centred and sized like the Exit App? window (112x48 at 16 pt). **Yes** writes the copy (asking for the passphrase only when Encryption On Backup is enabled; a dismissed passphrase window still cancels the logout and deletes nothing), and **No** wipes with no copy. A dismissed window (barrier or system back) cancels the logout, as the app's other confirmations do. The window is **not shown at all** when the wipe trades away nothing: a **premium account whose work is already on the server** (its queue empty, or its mandatory sync completed), or a **free account holding nothing the user authored** — no case, note or case reference, and no added/edited court category, case category, court, on-behalf, step or case type (`is_custom` or `is_user_modified`). A row the user added or edited in those six reference tables counts as their work even with no case on the device.
- **A completed logout lands on the Login screen (follow-up).** Whichever branch runs, once the session has actually ended the user is shown the app's single sign-in screen. It is an **explicit** navigation, not the router's sign-in gate: that gate is decided once per launch, so a device already signed in is never re-gated mid-session, and without this a signed-out user would be left on the now-empty Settings surface. A cancelled branch (a declined offline block, a closed warning, a dismissed passphrase) changes nothing and navigates nowhere.

This guarantees that local data is tightly bound to the current Supabase `auth.uid()`. When a new user logs in, they start with a fresh database and perform an initial pull from Supabase (premium) or a fresh local database (free).
- **A wipe leaves a fresh install's database, and an account switch wipes too (0.0.400 — two reported device defects).** (a) The complete wipe takes the seeded reference data and its `seed_migrations` ledger with everything else, and `SeedMigrationRunner` runs only when the database is **opened**, so a logout in the middle of an app run left the next account on that device with no court categories at all — an Add Case form whose Court Category, court names, case categories, case types, steps and on-behalfs were empty while the static Higher/Lower Court, Division and District dropdowns still showed. The wipe is therefore one named operation, `BackupRepository.wipeToFreshInstall` (the complete scope, then the baseline seed migrations), so no caller can wipe without restoring what an install starts from; extended-offline recovery keeps its own order because it re-seeds between its wipe and its authoritative pull. (b) The wipe was reachable **only** through the Logout button. A session the server revoked, one that expired, or one that could not be parsed back at all runs no logout flow and clears nothing — which is deliberate for a rejected session, but a later sign-in **as a different account** then opened the diary onto the previous holder's cases, notes, reference rows **and** their `sync_queue`, so the header counted work with no owner on that device while `IdentityAdoptionService` refused to hand the rows over. The account switch — plan §5's own rule above — now runs that same wipe before the arriving account is adopted, from the moment `AuthViewModel._completeSignIn` sees a different account id arrive. **(0.0.401)** The wipe's deletes go through Drift's table API (`db.delete(table).go()`), never `customStatement`: raw SQL removes the rows from the file but tells no query stream, so a device whose database was already clean still showed the previous account's pending count on its header and its queued mutation on Sync Status for the rest of the app run. Each table's streams are invalidated as every other writer in the app does; only `restoreSnapshot` keeps raw deletes, and it has its own reload lever (the restore screen re-opens the database).
- **Offline Session Expiry (never gates local data):** Supabase access tokens expire in ~1 hour and refreshing requires network. The app **never blocks local DB access on JWT validity** — an offline lawyer must always reach their diary. If a token refresh ultimately fails while online (e.g., revoked session or changed password), the app requires re-login, but **never wipes local data while `sync_queue` has pending rows** — the re-login path routes through the branched logout flow above so unsynced work is synced, exported, or explicitly discarded by the user, never silently lost. **A third way a session ends needs the same treatment.** A persisted session that cannot be parsed back into one at all (`SignOutReason.sessionMissing` — corruption rather than rejection, and raised before any request is made) requires a sign-in exactly as a rejected refresh token does. Reading only the rejection left such a device falling through to *offline, token stale*, which by design shows nothing: the diary opened as usual, the sync was dead for good, and the user had no prompt and no reason to ever sign in again. Both reasons are now decided in one place, `authSessionNeedsSignIn`, and a deliberate sign-out is deliberately not one of them.
### 6. Subscription Enforcement (Free vs Premium Sync)
- **Free Plan:** 50-case limit applies to `is_deleted = false` records only. Soft-deleted cases are excluded from the count. If a user hits 50 live cases, the "Add Case" flow is blocked with a paywall screen. Online Sync is only available in the premium plan; it is disabled from the very beginning for the free plan, meaning all data remains strictly local. The free plan is strictly individual and single-device (Firm mode requires premium).
- **Premium Entitlement Is Derived, Never Stored:** There is no trigger that can fire *at the expiry instant* — expiry is a moment in time, and triggers need a write. A stored `subscription_status` flag therefore inevitably goes stale. Instead, premium entitlement is **always computed** — on the client, in RLS policies, and in the `push_changes` RPC / server triggers — as: `subscription_expiry + 48h grace > now()`. No cron job, no stale-status bugs. The `subscription_status` columns on `profiles` and `firms` are retained for display/analytics only and are never consulted for authorization.
- **Premium Plan:** On app init or reconnection, the app computes entitlement from `profiles.subscription_expiry` (or the firm's, below). If valid, sync is authorized.
- **Entitlement Is Settled Before The Gates Read It.** Entitlement is derived from the **cached** `profiles` row, so any gate that reads it before that row exists answers *free* — which is how a premium account was shown `Subscription: Free` beside `Plan: 1 Month` (the plan comes straight from `payment_submissions`), refused in Online Sync with *"Premium is required to sync across devices"*, and left saying *Last Sync: Never* because the engine's own `_isEntitled` check made `syncNow` return **silently** with no retry scheduled. Three consequences to hold to. **(a)** The account refresh also runs **as soon as a session appears**, not only on launch/resume/reconnect: `AccountRefreshScope` mounts once above the router, so a sign-in on a running app is its own moment and is triggered by a change of account id. **(b)** A gate must distinguish *unknown* from *free*: `entitlementKnownProvider` is false until the cached row lands, and both the Subscription row and Online Sync say nothing (a dash / *Checking Your Subscription…*) rather than claiming Free. **(c)** The engine never re-tries a run it refused, so the **false → true entitlement transition** is what re-issues the delta pull (`SyncTriggerScope`), which is the only automatic repair that does not wait for a resume, a reconnect or a local write.
- **A Free Plan's Sentence Is Also The Way To Buy One (0.0.395):** Online Sync's status card stated *"Premium is required to sync across devices"* and the line under its **Sync Now** button repeated the same news in Title Case, because the two lines read the same sentence from two keys. The card's own body now reads **"A subscription plan is required to sync across devices. Purchase a plan from here."** — sentence case, being a prose body (rule 11) — with **here** bold, underlined and tappable into the bare `AppRoutes.paywall` (**Subscription Plans**); the bare route is the right target because this entry is not the 50-case gate, so the gate-only *Free Plan Limit Reached* card stays hidden. The line under the button is gone: the free plan is the one blocker with no second line, its body already naming the plan and linking to it. The sentence is three ARB pieces — prefix, link, closing punctuation — because only those words are styled and tappable, and the closing punctuation is the language's own ("." / "।"). The *Free Plan* pill, the *Last Sync* line and every other blocker are unchanged. **(0.0.396)** That sentence is now set like the info line above the card — `bodyMd`, muted — instead of a size smaller than it, and it is drawn **outside** the card's header row. Inside it, the 48px icon column and its 16px gap narrowed every line beneath the icon too, so the sentence wrapped early with the space to its right left empty; the same move gives every other blocker's body line the card's full width. The *Free Plan* pill and the *Last Sync* line remain unchanged.
- **Firm Subscription:** Sync eligibility for the entire firm is derived from `firms.subscription_expiry` (mirrored from the owner's profile) using the same formula. When the owner's subscription lapses past the grace window, the derived check fails for all associates on their next sync attempt — no trigger or status flip needed.
- **Expiry Fallback:** If a subscription expires, the app first enters the **48-Hour Grace Period (Expiry Buffer)** defined in §7 — sync remains fully active with a renewal warning banner. Only after the 48-hour grace period ends is sync disabled (immediately), and the app falls back to local-only mode. Existing data is not deleted. The app shows an appropriate sync banner:
  - **For the Firm Owner:** *"Your premium subscription has ended. Renew your subscription to restore sync."*
  - **For an Associate:** *"Your firm's premium subscription has ended. Contact your firm owner to renew."*
- **A Premium Entry Is Not Advertised To A Free Account (0.0.384):** the **Manage Associates** row in Settings > Accounts & Profile is offered to a **premium individual** — adding the first associate is what creates the firm, and `ensure_firm` refuses a non-premium caller server-side — and to a firm owner **whatever their plan**, because a lapsed owner keeps the firm and its roster and only *creating* a firm is gated. An associate or viewer is not offered it either, since the roster, the invites and the permission toggles are owner-only server-side. The screen itself is unchanged: it still offers a free account the Paywall route, so a deep link resolves to something honest rather than an owner-only message.
- **Lapsed-Premium Users Keep Everything:** If a premium user never repurchases after their plan expires, the **50-case limit does not apply** to their existing data — they keep all of their previous cases. The 50-case paywall gates only *adding new cases beyond 50* on a free entitlement; it never hides, blocks, or deletes existing cases.

### 7. Manual MFS Payment Flow
- **User Checkout Flow:**
  1. User hits the 50-case limit, or reaches the paywall from **Settings > Subscription > Purchase New Subscription**. The old standalone **Go Premium** entry in the Settings list is **removed**: it was an approved departure from the Settings main mockup, so removing it puts that screen back on its mockup, and one entry now does what two did. The Manage Associates screen's own *Go Premium* button and Online Sync's *Free Plan* pill are untouched.
  2. `PaywallScreen` shows benefits and 4 plans: 1 Month (৳100), 3 Months (৳285), 6 Months (৳540) or 1 Year (৳960), each discounted plan showing its full per-month price struck through and its saving. A later pass (0.0.392) retitled the screen **Subscription Plans** and replaced its *Premium Includes* section with **Subscription Plans Offer** — four Title Case headings over sentence-case bodies: **Disaster Recovery**, **Real-time Backup**, **Multi-device Support** and **Collaboration** — and made the **"Free Plan Limit Reached"** card show **only** when the 50-case gate opened the screen: that gate opens `?reason=limit` (`AppRoutes.paywallFromCaseLimit`), while every other entry (Settings > Subscription > Purchase New Subscription, Manage Associates' Go Premium) opens the bare route and hides it. The plans section is unchanged. **(0.0.393)** Its two group headings — **Subscription Plans Offer** and **Plans** — are now set in bold title typography, a step larger than the label style they previously borrowed, so each reads as a title.
  3. Clicking a plan opens `CheckoutScreen` with:
     - Transfer instructions (amount, MFS number with copy-to-clipboard).
     - Input form: Payment Method (dropdown), Sender Phone Number, Transaction ID (TrxID).
     - **Local Draft:** The form input is saved to SharedPreferences on every keystroke. If submission fails or the user closes and reopens, the form is pre-filled with their saved draft.
  4. App submits to `payment_submissions` on Supabase. Status starts as `pending`. If the network call fails, the user sees: *"Submission failed. Tap Retry."* The draft remains saved.
- **Rate Limiting (Abuse Prevention):** Each user is restricted to a maximum of **3 payment submissions per 24-hour period**. **Enforcement is a `BEFORE INSERT` trigger on `payment_submissions`** — RLS policies cannot reliably count rows per time window, so the trigger is the authoritative gate: it overwrites/rejects client `submitted_at`, counts the caller's rows where `user_id = auth.uid() AND submitted_at > now() - interval '24 hours'`, and raises an exception (surfaced to the app as a friendly *"You've reached today's submission limit. Please try again tomorrow."* message) if the count is already 3. The client performs a best-effort local check purely as UX; it is never the security boundary. This prevents spam abuse while still allowing legitimate retries.
- **48-Hour Grace Period (Expiry Buffer):** When a subscription expires, sync is **not** cut off immediately. A **48-hour grace period** is applied during which sync remains fully active but a persistent, non-intrusive warning banner is displayed (e.g., *"Your subscription expired. Renew to avoid losing sync access."*). If the admin approves a payment submission within this window, the expiry is extended seamlessly and the banner disappears. This prevents legitimate users from losing access during normal admin verification delays.
- **Receiving Numbers (configuration, not code):** the numbers a user sends money to come from `payment_configuration` (authenticated read-only) through the client's payments configuration service, with validated `--dart-define` build defaults as a bootstrap; a row can be inserted or updated by an admin so a number rotates without a release, and a missing/malformed/unsupported entry is rejected rather than shown. The table is seeded (`20261001020000`) with the firm's one MFS account — 01835252721 in the local 11-digit form the validator accepts — for `bkash`, `nagad` and `rocket`. Values are display-only — the server's `approve_payment` and the RLS policies remain the boundary.
- **Readable Plan Names On The Server (0.0.385):** `plan_type` stays the machine key — `approve_payment` validates it against the accepted set and its `CASE` selects the amount and the interval — and both `payment_submissions` and `payment_approval_events` now carry a **generated** `plan_name` (`1 Month` / `3 Months` / `6 Months` / `1 Year`, `20261005120000`) derived from it, so the raw tables and any SQL output read plainly in Studio. Generated, not written: it cannot drift from the key, needed no data migration (existing rows compute on the spot) and neither the approval path nor either table's write privileges changed. The names are English; the app localizes its own display text (Bengali included) from the key, and an unknown future key falls back to its raw value rather than a blank.
- **Admin Verification:** Admin checks the incoming MFS payment and invokes the admin-only `approve_payment(payment_submission_id)` RPC from the protected admin surface; neither Supabase Studio row edits nor direct client updates are an approval path. The RPC performs the lock, validation, idempotent expiry extension, owner-firm mirror, submission metadata update, and immutable audit insertion atomically as defined in the schema section. `subscription_expiry` remains the only entitlement authority; `subscription_status` is display-only. The app detects the committed change via a Broadcast ping or profile refresh on next launch.

### 8. Print (PDF Export)
- Utilizes the `pdf` package to format the current screen's data:
  - Daily Cause List: Grouped by court, shows Case Number, Parties, Lead Counsel, and Steps.
  - Active Cases: Clean list of all current litigation.
  - Case History: Export timeline of a specific case.
- Integrates with `printing` package to present the standard OS print dialog.
- **Bengali Script Rendering — native-text-first strategy:** The custom PDF generator (`pdf_generator.dart`) loads the `Tiro Bangla` font asset and registers it with the `pdf` package. The default path uses native paginated PDF text (searchable/selectable, small output) and must pass automated golden/text-extraction checks for Bengali vowels, diacritics, ligatures, mixed Bengali/English lines, and conjunct-heavy fixtures before release. Pagination uses the PDF layout engine's measured rendered height and natural page breaking—not a fixed row count.
- **Bengali Script Rendering — bounded widget-to-image fallback:** Use raster output only for content/fixtures proven to shape incorrectly in the native path; never capture an entire long scroll view as one bitmap. Instead:
  1. Lay out a print-only widget into bounded page-height chunks based on measured rendered height (not a fixed row count).
  2. Wrap and capture **one PDF-sized page/chunk at a time** with `RepaintBoundary.toImage()`.
  3. Cap pixel ratio and output dimensions to a tested memory budget (do not blindly use the device pixel ratio); encode/embed that page, then dispose image/byte buffers before rendering the next page.
  4. Run encoding/PDF assembly in an isolate or equivalent off-main-thread worker where Flutter/plugin constraints permit; keep only the current page buffer alive. Stream/build incrementally where supported, show progress/cancellation for large exports, and fail with a recoverable message rather than crashing.
  5. Define and test explicit maximum page width, height, pixel ratio, and estimated RGBA byte budget before allocation. QA large cause lists, mixed scripts, Bengali conjuncts, cancellation, and representative low-memory Android devices; add automated upper-bound tests for dimensions, peak live buffers, and successful multi-page completion.
  This preserves screen-accurate Bengali while preventing a single unbounded bitmap allocation.

### 9 Action Buttons (Phone & Message)
- **Phone Button:** When clicked, shows a popup/bottom sheet with two options:
  1. **Standard Phone Call:** Launches the device's native dialer via the `url_launcher` package using the `tel:` URI scheme with the client's phone number.
  2. **WhatsApp Call:** Launches WhatsApp call using direct API link / app URL scheme.
- **Message Button:** When clicked, shows a popup/bottom sheet with two options:
  1. **Standard SMS:** Launches the device's native SMS application via the `url_launcher` package using the `sms:` URI scheme, pre-populating it with a standard template.
  2. **WhatsApp Message:** Launches WhatsApp via the `url_launcher` package using `https://wa.me/<number>?text=<urlencoded_message>` pre-populating the message.
- **Translation Template:** The pre-filled message text (e.g., *"Dear Client, your case [No] is scheduled for [Date] at [Court]. - [Lawyer Name]"*) must be stored in `app_translations.dart` to support translation to Bengali.

### 10. Bullet-proof Notification System (Upcoming Case Alerts)
- **Core Mechanism:** Combines `flutter_local_notifications` (for high-importance UI banners) and `android_alarm_manager_plus` (using `setExactAndAllowWhileIdle`) for precise background alarm firing. No persistent Foreground Service notification is used, as it disturbs users.
- **Settings Configuration:** Alerts are configured via `Settings > Notifications` with two key parameters stored in `SharedPreferences`:
  - `notification_time` (String/TimeOfDay, e.g., "08:00"): The daily time the notification is triggered.
  - `notification_day_offset` (Integer, e.g., 0 = same day of hearing, 1 = 1 day before hearing, 2 = 2 days before hearing).
- **Scheduling Logic & Interactivity:** A daily background job queries the local Drift SQLite database for any case having `next_date` that matches the configured offset. If found, it schedules a high-priority system notification containing the case number, parties, and court name. **When the user taps the notification, the app navigates directly to the Detail View of that case.**
- **OEM Battery Killer Mitigation (Critical for Bangladesh Market):** The Bangladeshi smartphone market is dominated by Xiaomi (MIUI), Oppo (ColorOS), Vivo (Funtouch OS), and Realme (Realme UI). These OEMs have aggressive battery management systems that completely ignore standard `AlarmManager` calls and kill background isolates — meaning standard notifications will silently fail on the majority of target devices. To counter this:
  - **OEM Detection on First Launch:** On the first launch (and accessible via `Settings > Notifications`), the app reads `Platform.localeName` and `device_info_plus` to detect the device manufacturer.
  - **Localized Setup Guide UI:** A localized, step-by-step "Battery Optimization & Auto-Start Guide" screen is shown to the user, instructing them to manually:
    1. Enable **"Auto-start"** for the app (required on Xiaomi/MIUI, Oppo/ColorOS, Vivo).
    2. Set Battery Optimization to **"Unrestricted"** / **"No restrictions"** for the app.
  - **Deep Links to OEM Settings:** Where possible (using platform `Intent` calls via `android_intent_plus`), the guide includes a "Take Me There" button that uses deep link Intent URLs to jump the user directly to the specific OEM battery or auto-start settings page, eliminating guesswork.
  - **Reminder:** If the user skips the guide, a persistent non-intrusive banner is shown in `Settings > Notifications`: *"Notifications may not work reliably on your device. Tap to complete setup."*
- **Exact Alarm Permission (Android 12–14+):** `setExactAndAllowWhileIdle` requires the `SCHEDULE_EXACT_ALARM` permission, and **Android 14 denies it by default for new installs**. The app must:
  1. Detect at runtime whether exact alarms are permitted (`canScheduleExactAlarms`).
  2. If denied, deep-link the user to the system "Alarms & reminders" grant screen — this integrates naturally into the existing OEM Setup Guide UI above.
  3. If the user refuses, **fall back to inexact windowed alarms** (`setWindow`/`setAndAllowWhileIdle`) so notifications still fire, just with minute-level rather than second-level precision.
- **Boot-Time Rescheduling:** `AlarmManager` schedules **do not survive a device reboot**. The app registers a `BOOT_COMPLETED` broadcast receiver that re-schedules the daily notification alarm after every reboot (and after app updates via `MY_PACKAGE_REPLACED`).
- **Platform Abstraction (Windows Port Prep):** All notification scheduling, alarm management, and OEM battery-guide logic is accessed through a **platform-abstraction interface** (e.g., `NotificationScheduler` with `AndroidNotificationScheduler` / future `WindowsNotificationScheduler` implementations). `android_alarm_manager_plus`, `android_intent_plus`, and the OEM guide are Android-only — isolating them behind an interface now means the Windows port swaps implementations instead of rewriting call sites.

### 10.1 View Settings Configuration
Alerts and display parameters are configured via `Settings > View Settings` and stored in `SharedPreferences`:
- `upcoming_cases_period` (Integer, default: 7): Days offset range to display in the Upcoming Cases screen.
- `case_list_display_mode` (String, default: `'compact'`): Controls density of case list items.
- `bottom_nav_tabs` (List<String>, default: `['overdue', 'daily_cause_list', 'active', 'upcoming']`): Custom selection and ordering of the 4 bottom tabs.
- `side_nav_options` (Map<String, Boolean>, default: all true): Toggles visibility of side navigation panel options (Case screens, Notes, References, Share, Print, etc.). **(0.0.408)** The panel's own last line shows the bundled app version (e.g. `V0.0.408`), read from `appVersion` in `lib/core/constants/app_version.dart` so it cannot drift from the build; the string is a Latin `V{version}` token in both languages, added to the ARBs as `drawer_version`. **(0.0.409)** Per the user's follow-up the line is pinned to the very bottom of the panel's available space — a footer below the scrolling list, not a row inside it — and is left aligned rather than centred.
- `default_landing_page` (String, default: `'daily_cause_list'`): Selected default landing page on app launch.
- `font_size_step` (Integer, default: 0, clamped to −2..+6): the in-app Font Size step added to every text size in the app by `FontSizeScope` at the app root. The app **ignores the phone's own font-size setting**: its base is a fixed standard size, so only this step can change the app's text. This keeps a device set to an extreme scale from breaking the layout.

### 11. Screen-Organized App Translations (Language & Labels)
- **Central Translation File:** Instead of scattering text strings, all UI labels are stored in `lib/core/l10n/app_translations.dart`. Along with the UI labels, this file will store translations for pre-seeded items including court related items, steps, case types, on behalfs etc.
- **Organized Structure:** Translations are structured hierarchically as nested maps, grouped by screen (e.g., `allCasesScreen`, `caseDetailsScreen`), settings submenu (e.g., `settingsProfile`, `settingsOnlineSync`), and shared dialogs/drawers.
- **Language Selection:** The language selection is stored in `SharedPreferences` (Bengali vs English).
- **Customizable Label Hooks:** Because labels are loaded dynamically from `app_translations.dart`, a future Settings > Language translation manager screen can easily override these key-value pairs locally.

### 12. App-Wide Systems & Configuration

### 12.1. Unified Search Strategy (Global & Contextual)
- **Case, Notes & References Search:** Every case listing (Active, Upcoming, Disposed, Overdue), Notes listing, and Case Reference page includes a prominent search bar.
  - Search runs Drift database queries using case-insensitive `LIKE` patterns or Full-Text Search (FTS) indices.
  - Cases are searchable by: Case Number (e.g., "110/2021"), Petitioner, Respondent, Lead Counsel (Petitioner/Respondent), represented Client Name (resolved from Petitioner/Respondent through `on_behalf_id`), `party_phone`, Remarks, and Case Title. Each case screen applies its own dataset filter before text search.
  - Notes are searchable by: Title and Body.
  - Case References are searchable by: `reference_and_page_no`, `statute`, `section_or_article`, `title_and_description`, and `comments_notes` (matching the `case_references` schema — there is no separate citation-title/body or URL field).
- **Settings Search:** The main Settings screen (`settings_main_screen.dart`) features a search input that dynamically filters settings submenu items (e.g., typing "profile" hides unrelated submenus and only displays "Profile Settings" and "Manage Account").

### 12.2. Unified Courts, Case Types, Steps & On Behalf of Configuration
  - **Seeded Configuration File:** All initial options are stored in `lib/core/constants/pre_seeded_data.dart`. This includes comprehensive standard values for Bangladesh:
  - Court Categories: Categorized by `Supreme Court Division`, `High Court Division`, `District Sessions Courts`, `District Civil Courts`, `Magistrate Courts`, `Executive Courts`, `Tribunals`, or other custom categories.
  - Court Names (categorized by these higher/lower court categories, and for lower courts, division and district options are only shown/entered when category is selected as Lower Courts).
  - AD/HCD Case Categories, with their Case Types nested under the selected Case Category. The current source is `docs/AD_and_HCD.txt`; it defines 4 Appellate categories/11 types and 5 High Court categories/98 types.
  - Case Types (e.g., Criminal Appeal, Civil Suit, Writ Petition, Revision), persisted with `court_category_id`; AD/HCD types additionally persist `case_category_id`.
  - Court Steps (standard steps for lower-court procedures, strictly linked to court categories. AD/HCD intentionally have no seeded Steps until authoritative lists are supplied).
  - On Behalf options (e.g., Petitioner, Respondent, Plaintiff, Defendant)
- **Category-scoped representation seed:** Use stable category IDs. The current AD/HCD source defines:
  - `appellate_division` → Petitioner, Respondent
  - `high_court_division` → Petitioner, Respondent
  Lower-court defaults remain:
  - `district_sessions_criminal` → Accused, Complainant, State, Victim
  - `district_courts_civil` → Plaintiff, Defendant, Petitioner, Respondent, Applicant
  - `chief_judicial_magistrate` → Accused, Complainant, State, Informant
  - `chief_metropolitan_magistrate` → Accused, Complainant, State, Informant
  - `executive_magistrate` → Defendant, Complainant, Applicant
  - `tribunals` → Applicant, Respondent, Claimant, Objector
  Apply the same stable-ID scoping pattern to `case_categories`, `case_types`, and `steps`. Dart may expose typed maps for court categories, case categories, and nested case types, but persisted relationships must use IDs rather than English labels.
- **Versioned, idempotent seed migrations:** Pre-seeded data includes `court_categories`, `case_categories`, `courts`, `steps`, `case_types`, and `on_behalfs`. Every built-in row has a stable deterministic ID shared across Drift, Supabase, backups, and releases. Ship ordered migrations (`seed_v1`, `seed_v2`, …) and record each successful application in a database-backed Drift `seed_migrations` ledger with `migration_id` PK, `checksum`, and `applied_at`; a lone `SharedPreferences` integer is not migration state. On every app/database upgrade, apply only missing migrations in order and transactionally. Each migration must be rerunnable: insert absent IDs with conflict-safe semantics, perform only explicitly listed corrections, and record the ledger row in the same transaction. Track `is_user_modified` (and soft-delete state) for editable built-ins; generic corrections must skip customized/deleted rows, while any exceptional forced correction must name its IDs, reason, and preservation behavior. Never resurrect user-deleted rows implicitly. A database reset is a development tool, never the production update mechanism.
- **Customization Screen:** The `Settings > Edit Court/Steps > Court Names & Steps` screen provides a tabbed UI allowing users to view, add, edit, and soft-delete entries for all 5 lists (Court Names, Case Categories, Case Types, Steps, and On Behalfs).

### 12.3 Power & Sync Efficiency (Battery Conservation)
- **Foreground WebSocket Sync (Broadcast Ping Channel):** The Supabase Realtime WebSocket connection is active only when the app is in the foreground, carrying **only tiny "Broadcast from Database" `{table, id}` pings** on the private firm/user topic (see Sync Plan §1) — smaller frames over the socket and zero per-subscriber RLS churn, which itself is a battery win. When the app is backgrounded or the screen is locked, the channel is immediately disconnected. On returning to the foreground, the connection is re-established.
- **Micro-Batched Write-Through (2–3 s Coalescing Window):** Every local write (add/edit/delete) is saved to the local Drift DB first for instant UI feedback, then coalesced with any other writes made within a **2–3 second micro-batch window** into **one** `push_changes` RPC call (see Sync Plan §1). Rationale: each HTTP request keeps the cellular radio in a high-power state for ~10–20 s afterward (tail energy), which dwarfs the payload cost — a lawyer updating 25 cases after a court day would otherwise cause 25 radio wake-ups. The window is imperceptible to users, cuts radio usage by an order of magnitude, and *shrinks* the data-loss window because the whole batch is queued atomically in `sync_queue` on failure. This is the single biggest battery win in the design.
- **Sync Queue Compaction:** If multiple unsynced local edits occur on the same database record offline, the sync queue processor collapses them per the **Offline Compaction Matrix** (see `sync_queue` schema note), pushing only the latest snapshot state and reducing network requests.
- **Event-Driven Connectivity (No Polling):** The app never polls for connectivity. It subscribes to the **`connectivity_plus` stream** — the OS already broadcasts connectivity changes, so the app reacts instantly when a network appears, at zero polling cost (see Sync Plan §1 WebSocket Reconnection Strategy).
- **Continuity-Aware Resume-Pull Throttle (60 s):** Rapid app switching may skip a delta pull within 60 seconds only when the client proves the same Realtime connection generation remained continuously subscribed since the last successful pull. Any disconnect, reconnect, auth refresh, connectivity restoration, process suspension, or unknown continuity forces an immediate per-table delta pull before sync is declared healthy (see Sync Plan §1).
- **Purely Local Background Operations (Enforced Rule):** All background services — including alarm manager triggers for notifications and any scheduled tasks — must run **completely locally** against the Drift SQLite database. **No background network calls, no GPS operations, and no Supabase requests are permitted from background isolates or background tasks.**
- **Rendering Optimization:** Using Riverpod's `.select()` modifier to listen only to the specific properties needed, avoiding unnecessary rebuilds. Listings use pagination (`limit` and `offset`) to avoid loading large datasets into RAM.

### 12.3.1 Security, Local Database Encryption & Sensitive Exports
- **Database-at-rest encryption required:** Legal case data must not ship in plaintext SQLite. Use a maintained SQLCipher-compatible Drift backend for full-database encryption so ordinary `LIKE`/FTS queries continue to work after the database is opened; do not implement deterministic per-field encryption for searchable legal text. Validate Android and planned Windows support with an integration test before locking the package choice.
- **Key management:** Generate a random per-installation database key, store it only in Android Keystore-backed secure storage (and the OS credential vault on future desktop platforms), never in SharedPreferences, source code, logs, analytics, or synced tables. Redact keys and sensitive payloads from crash reports. Define explicit behavior for secure-storage/key loss: never silently create a new empty database over an unreadable encrypted file; offer authenticated cloud restore or user-selected encrypted backup recovery.
- **Lifecycle hardening:** Clear sensitive in-memory state on logout/account switch, require the account-switch wipe described in §5, disable Android auto-backup for raw database/secure-key files unless an encrypted restore design is verified, and prevent sensitive screen contents from appearing in app-switcher snapshots where platform support allows. **The in-memory state is not only what a wipe can reach (0.0.394):** an account-scoped **live read** — this account's payment history, the admin panel's status and its queue, and a firm owner's roster and invite codes — is a server read held by a Riverpod provider, so it outlived both the branched logout's database wipe and `signOut`, and the next account on the device read the previous holder's rows: a non-admin was shown the Admin Panel, and *Payment History* was somebody else's ledger. `AuthViewModel._forgetAccount()` now drops all four, together with the SharedPreferences profile record, as one *the account is leaving* operation, and it runs on the Logout button **and** whenever a sign-in arrives as a different account id — the path a revoked or expired session takes, which clears nothing on its own. A cold start, or the same account arriving again, drops nothing.
- **Backups and diagnostics — encryption is opt-in, off by default (revised):** Safety exports and user backups containing case data **can** be sealed with an authenticated format (versioned header, KDF parameters, nonce, ciphertext, authentication tag, checksum) using a user recovery secret. **Encryption is off until the user turns it on** in Settings > Backup & Restore > Encryption On Backup, so a fresh install writes the readable versioned JSON envelope, asks no passphrase, and restores it back without one; the restore path opens either kind and prompts for a passphrase only for an encrypted container. A sealed export is still never placed in shared storage without that explicit choice. Diagnostic bundles default to metadata only, and including queue/case payloads still requires explicit consent; the bundle follows the same preference (sealed when encryption is on, readable JSON when off) with a visible expiry/deletion reminder.

### 12.4 Industry-Standard Responsive Design
- **Fluid Layouts:** The app uses responsive layouts instead of fixed widths or heights. Sizing relies on relative widgets like `Flex`, `Flexible`, `Expanded`, `Spacer`, `ListView`, and `GridView`.
- **Dynamic Adaptability:** Padding, margins, and grid columns are scaled dynamically using `MediaQuery` and `LayoutBuilder` based on the device width.
- **Mobile-First Rule:** Focus strictly on developing the mobile view for now. Layout optimization for tablet and desktop screens will be handled specifically after the mobile version is fully complete.

---

## Development Workflow & Coding Standards

To maintain code quality and strict project control, all development must adhere to the following rules:

### 1. Naming Conventions
- **Database (SQLite & PostgreSQL):** `snake_case` (e.g., `court_id`, `case_number`, `is_deleted`).
- **Dart & JSON Serialization:** `camelCase` (e.g., `courtId`, `caseNumber`, `isDeleted`).
- **Drift Mappings:** Built-in column renaming is used in Drift tables to map DB `snake_case` to generated Dart `camelCase` class fields automatically.

### 2. Comment Preservation Rule
- Every file and every major code section inside that file must include short, precise comments explaining intent and architectural logic.
- During subsequent edits, **existing comments must not be removed or deleted** unless they directly conflict with new logic. Modify them to reflect changes, but preserve comments for unchanged code.

### 3. File Modification Scope
- Only modify or edit files/sections of code as explicitly instructed.
- Do not make changes to files or features that are outside the scope of the current task.

### 4. Version History Tracking (`docs/version_history.md`)
- A file named `docs/version_history.md` must be maintained at the project root.
- **Every code modification, even a single-line fix, must be logged in `docs/version_history.md`** before finishing a turn.
- The log entry must strictly follow this format:
  `Version: X.Y.Z - [brief summary of changes]`
- Version numbers must start at `0.0.1` and bump sequentially (e.g., `0.0.2`, `0.0.3`) up to `0.0.999` and then 0.1.0. After that bump sequentially (e.g., `0.1.1`, `0.1.2`) up to `0.1.999` and then 0.2.0.
- Above the ## Version History section, there is "## Current Version" section. After each update, log the latest version here. Make it so the app uses this Current Version as the app's versioning.
- Example `docs/version_history.md` contents. Maintain this format:
"# Legal Case Diary — Version History
This file tracks all modifications made to the **Legal Case Diary** codebase during development. Every edit (even a single-line change) must be logged here immediately with a bumped version number. Update Current Version section with the latest version and summary after each edit.

### Version Range
- Range: `0.0.1` to `0.0.1000`

### Formatting Rule
- Each change must be logged in the following format:
  `Version: X.Y.Z - [ Brief summary of changes]`
---

## Current Version
0.0.4 - Task 01 Phase 1 complete: Flutter project initialized with Android configuration and minimal entry points.

## Version History
Version: 0.0.1 - Finalized implementation plan.
Version: 0.0.2 - Formatted README.md file and initiated the Git.
Version: 0.0.3 - Updated 8 task files with gap fixes found during IP cross-reference.
Version: 0.0.4 - Task 01 Phase 1 complete: Flutter project initialized with Android configuration and minimal entry points."

### 5. Workload Division & Incremental Iteration
- To prevent hallucination and minimize errors due to large context limits, divide all coding tasks during the building phase into small, manageable, bite-sized workloads and incremental steps. Focus on building, validating, and testing one specific module/feature at a time before proceeding to the next.

### 6. Navigation Pop & App Exit Confirmation
- Implement proper back button/back gesture behavior throughout the app to prevent black screens or accidental pops.
- Intercept the system back gesture on the app's root screen (e.g., Daily Cause List) and show a confirmation dialog/modal before allowing the user to exit the app.
- **Extended in 0.0.383:** the same exit confirmation answers the back gesture on every bottom-nav screen — the six case lists, Notes and Case Reference — whatever screen they were opened from. Those routes are pushed by the navigation drawer and by the All Cases summary cards, so a pop would return to a screen unrelated to the tab; an open drawer still closes on the first back.

### 7. Progress Tracker Location (`docs/currentlyWorking.md`)
- The `currentlyWorking.md` file is maintained in the `docs/` folder. Every development session starts by reading it to resume where work left off, and it is updated incrementally as tasks begin and complete.
- Format: `### [Date Time] — Current Task: [brief description]`

### 8. Shell Script Note (Windows Development)
Some `.agents/skills/` directories contain `.sh` reference scripts intended for Linux/macOS environments. On Windows, use equivalent PowerShell commands or WSL/Git Bash instead. These scripts are skill-library reference assets and should not be modified. For local development tasks (build_runner, drift_dev, flutter), use the standard `flutter` and `dart` CLI commands directly via PowerShell.

---

## Verification Plan

### Automated Tests
- `flutter test` checks the associate login and the single-use invite-code onboarding flow (redemption via the `join_firm` RPC: valid code joins the firm; used or revoked codes are rejected).
- DAOs tested for: soft-delete behavior, offline queue ordering (dependency-then-`created_at`), compaction matrix outcomes (insert+delete → both dropped, etc.), 50-case free-tier block at `count(is_deleted=false) >= 50`.
- Optimistic-concurrency tests: verify exact `base_version` matches are accepted with one server increment; stale/future/tampered versions return structured conflicts; same-hash `mutation_id` retries return the stored receipt, different-hash reuse returns `mutation_id_reused`; tombstones cannot be resurrected; and later queued edits survive reconciliation.
- Delta-pull tests: paginate multiple rows with identical `server_updated_at`, crash between fetch and local commit/checkpoint, replay safely, and prove no row is skipped across page, table, reconnect, or empty-result boundaries.
- Delete-review tests: changed targets return `target_conflict`/`stale_review_required`; reconfirmed current versions delete atomically; duplicate approvals return the same terminal receipt.
- Timestamp tests: verify `date_utils.dart` converts server UTC instants to local epoch milliseconds, renders Bangladesh civil dates without day drift, and handles DST-independent configured-zone boundaries deterministically.
- Security tests: open/search the SQLCipher database with the correct key, reject an incorrect/missing key without replacing data, verify raw files do not contain known plaintext fixtures, and round-trip an authenticated encrypted backup while detecting tampering.
- Schema verification for all Drift and server-internal tables, constraints, indexes, RLS grants, fixed RPC `search_path`, global sync columns, composite cursor storage, `mutation_receipts`, and immutable audit ledgers.

### Manual Verification
- **Low-end Device Test:** Verify backdrop blur filters do not trigger frame drops.
- **PDF Print Test:** Export native-text PDFs with mixed English/Bengali and conjunct-heavy Tiro Bangla fixtures, then force the bounded raster fallback on a large cause list. Verify page-height pagination, configured bitmap caps, progress/cancellation, buffer disposal, and completion without OOM on a representative low-memory device.
- **Multi-User Concurrency Test:** Open the app on an emulator and a physical device. Update a case on the emulator and ensure the change reflects on the physical device via Supabase Realtime.
- **Offline Auth Test:** Login while connected, enable airplane mode, close the app, reopen, verify login works, add cases, toggle airplane mode, verify sync.
- **Extended-Offline Reset Test (150-day, per-device):** Set the device-local `last_successful_sync_at` to 151 days ago, reconnect, and verify: (1) the persistent mutation lock commits before export/network work, (2) the authenticated encrypted safety archive contains the versioned JSON payload for local data plus pending/blocked/conflicted queue metadata, decrypts with the recovery secret, and fails closed on checksum/tag tampering, (3) Close leaves the app locked across restart, and (4) wipe + full pull happens only after Proceed and clears the lock only on success. Also verify another device syncing daily does not mask the stale device's gap.
- **Clock-Skew Test:** Set a device clock 1 year ahead, edit a case, and verify device time cannot influence server acceptance; only an exact `base_version` succeeds, and the skew warning appears after sync.
- **Structured Conflict Test:** Edit the same case offline on two devices from the same base. Sync one mutation first, then the stale one. Verify the stale device receives `status = conflict` with the authoritative row/version, records base/submitted/server payloads, preserves later edits, and offers automatic rebase only for disjoint fields.
- **Zombie Data Test:** Delete a case on Device A while Device B is offline. Bring Device B online. Verify the deleted case does not reappear on Device A or Supabase.
- **Logout Flow Test:** Verify all three logout branches — premium+online (sync then wipe), premium+offline ("Log out anyway" warning with Proceed/Close), free (Backup Data to Local Storage? Yes/No, then wipe) — and that the popup is skipped for a premium account already synced and for a free account with nothing authored.
- **Firm Subscription Expiry Test:** Expire a firm owner's subscription in Supabase Studio. Verify all associates lose sync access on next connection.
- **Payment Submission & Approval Test:** Submit a Monthly payment and verify server `submitted_at` and pending status. Approve only through the protected `approve_payment` RPC; verify row locking, exact amount/plan validation, server-calculated expiry, owner-firm mirroring, approval metadata, and one immutable audit event. Retry and concurrently invoke approval to prove expiry is extended exactly once; verify ordinary clients and direct row updates cannot approve or alter audit records.

---

## Revision 2.4 — Alignment Decisions and Complete Data Contracts

The following decisions are authoritative wherever an earlier section is ambiguous. Task files 00–22 must implement these rules without inventing alternatives.

### 1. Table classification and scope

- **Push/pull domain tables:** `cases`, `case_history`, `notes`, `case_references`, `court_categories`, `case_categories`, `courts`, `steps`, `case_types`, `on_behalfs`, `delete_requests`, and `conflict_log`. These receive the complete global sync contract, `(server_updated_at, id)` server indexes, Broadcast triggers, conflict handling, and tombstone behavior.
- **Firm-shared editable reference data:** `court_categories`, `case_categories`, `courts`, `steps`, `case_types`, and `on_behalfs`. Built-ins use deterministic IDs. Every editable built-in has `is_user_modified BOOLEAN NOT NULL DEFAULT false`; custom rows have `is_custom = true`. Firm members share firm-scoped customizations; individuals use user-scoped customizations.
- **Pull-only local caches:** authenticated `profiles`, `firms`, and `firm_members`. They are refreshed from the server and are never uploaded by the generic domain queue.
- **Per-user preferences:** language, theme/view configuration, navigation configuration, notification enabled/time/default offsets, backup-nudge metadata, and related settings. They are never firm-shared. They persist in a local `user_preferences` table keyed by user identity; premium accounts may sync them through a dedicated user-scoped server preference row protected by self-only RLS.
- **Local operational state:** `sync_queue`, per-table pull cursors, `seed_migrations`, and `sync_metadata`. `sync_metadata` stores device `last_successful_sync_at`, clock offset, recovery-required flag, archive path/checksum/completion state, and atomic recovery checkpoints. These are not generic domain-synced tables.
- **Server-managed/account/payment tables:** auth users, `profiles`, `firms`, `firm_members`, `firm_invites`, `payment_submissions`, `payment_approval_events`, `mutation_receipts`, `invite_attempts`, and `app_admins`. Global domain sync columns do not automatically apply to them, and they are never queued. **One documented exception:** a `profiles` row's own display and detail columns are writable by their holder (see Resolved Design Clarifications, "The Lawyer's Own Details Live on the Account") — the server still owns `email`, `role`, `firm_id` and the entitlement pair.

### 2. Schema corrections

- ~~Replace the single `client_phone` field everywhere with nullable `petitioner_phone` and `respondent_phone`. The represented client's phone is selected at runtime from `on_behalf_id`; detail views may display both explicitly stored party phones.~~ **Withdrawn (see Resolved Design Clarifications, "Party Phone"):** the shipped model is a single nullable `cases.party_phone` holding the represented client's number. There is no two-column split, and none is pending.
- Add `is_user_modified` to `court_categories`, `case_categories`, `courts`, `steps`, `case_types`, and `on_behalfs` in Drift and Supabase, migrations, seed-preservation logic, sync payloads, backups, and tests.
- Add `last_attempt_at INTEGER NULL` to local `sync_queue`; write it immediately before each attempt and expose it in diagnostics.
- The local profile cache stores `full_name`, `role`, `firm_id`, and `subscription_expiry`; server `TIMESTAMPTZ` values convert to local epoch milliseconds and invalidate on logout/account switch.
- Notification and view settings are durable per-user preferences, not transient form-only state. A case's notification toggle and selected offsets are stored in a dedicated local per-user `case_notification_preferences` relation keyed by `(user_id, case_id)`; premium cross-device synchronization remains user-scoped.

### 3. Domain behavior corrections

- `getNonDeletedCaseCount()` counts every non-deleted case and exclusively enforces the 50-case free limit. `getActiveCaseCount()` counts non-deleted cases whose step is not disposed and is used only for Active Cases/KPIs.
- Ordinary Add/Edit Case saves do not create history merely because step or note changed. Only the repository transaction handling the Update Case popup creates one provisional history row when `next_date` changes, preserving the previous date/step/note. The server creates/reconciles the authoritative history event for an accepted date-changing mutation. UI code never calls the history DAO directly for this operation.
- In Part A, Overdue “Last Updated” displays a clear local/offline state. In Part B it displays the latest successful server update for firm data and explicit pending/error states; it never invents a local associate-sync timestamp.
- The real manual Sync button lives at the top-right of shared `cases_screen_modal.dart`, is accessible from every case screen, and exposes idle/syncing/success/paused/error states. It is disabled with a localized entitlement explanation when unavailable; no placeholder behavior remains.
- Phone actions use the case's single nullable `party_phone` (the represented client's number, resolved from `on_behalf_id`) and are offered on the represented side only. Support dialer, SMS, and WhatsApp message through validated launch capabilities. Offer WhatsApp call only if the installed platform exposes a documented supported capability; otherwise safely fall back to WhatsApp contact/chat or the standard phone dialer. Never use an undocumented URL scheme.
- Search remains contextual: each case screen searches only its current filtered dataset; Notes only notes; Case Reference only references; Settings only settings/sub-settings. DAOs own query primitives, feature tasks own UI wiring, and the shared search task owns consistent UX and integration verification.

### 4. Backup, identity, recovery, and membership

- A backup is a versioned authenticated-encrypted **full-app restorable snapshot**: all domain rows/history/tombstones, custom and user-modified seed rows, queue entries, per-user preferences and case-notification settings, pull-only caches, cursors, seed ledger, sync/recovery metadata, and required local configuration. Exclude database keys, auth tokens, passwords, recovery secrets, and other nonportable secure credentials; recreate or reauthenticate them after restore.
- Restore validates authentication tag/checksum/schema compatibility before a single transaction. A non-empty target offers Replace or Cancel only. Replace is atomic and rolls back on any failure.
- Before repositories adopt authenticated ownership, atomically rewrite placeholder-owned offline rows, queue payloads/base snapshots, notification settings, and attribution to the authenticated identity/firm. Preserve audit provenance separately and never expose one account's data to another.
- If `join_firm` fails after sign-up, onboarding remains retryable. If abandoned before successful redemption, a protected cleanup operation removes the provisional profile/account so it is treated as never created.
- Extended-offline fresh start explicitly clears all domain tables, queue, pull-only caches, per-user preferences/settings, notification configuration, cursors, custom/seed data, seed ledger, and recovery metadata after the verified archive. Preserve only minimum secure session material required for authenticated pull; require reauthentication if preservation is unsafe.
- Removing an associate immediately revokes server/app access. The server rejects removed-member mutations; the client discards/rolls back their pending mutations, retains immutable server audit attribution, receives a membership-revocation broadcast, then forces logout and securely erases all app data on next connectivity.

### 5. Server contracts and configuration

- Base sync RPC ownership belongs to Task 18 and uses `push_changes(rows jsonb)`, where `rows` is a validated JSON array. Task 20 extends the RPC through a later migration with delete-review mutation types and matching idempotency/concurrency tests.
- `court_categories` receives explicit individual/firm RLS, soft-delete guards, Broadcast triggers, delta indexes, and creator/firm `can_edit` rules matching the other editable reference tables.
- MFS receiving numbers come from validated build environment or authenticated remote configuration owned by the payments configuration service. They are display-only, never hardcoded, safely rotatable without code changes when remote config is used, and covered by missing/invalid/rotation tests.
- Spacing values derive from mandatory mockups and semantic tokens; do not impose an invented fixed scale when a mockup differs.
- Android app sharing has an explicit platform-service owner using a maintained share package, content/file-provider URIs, correct MIME types, scoped permissions, graceful failure messaging, and Android integration tests.

### 6. Complete verification traceability

Final verification must trace every implementation-plan section to a task and test. In addition to sync/security/payment scenarios, verify all five case lists, all 19 form fields and cascade resets, date-only history creation, both party-phone actions, Daily Cause List badge calendar, Notes/References CRUD/pinning/contextual search, every Settings submenu and court hierarchy reorder, Bengali rendering/language switching, mobile responsive layouts, full-state backup collisions/restore, back/exit navigation, notification persistence, identity adoption, membership revocation, and every local/server scope boundary above.

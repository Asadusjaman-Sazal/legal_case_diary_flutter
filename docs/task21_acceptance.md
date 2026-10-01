# Task 21 — Payments & Subscription: Acceptance Run

Run against `0.0.336`. Every item below is the task file's own wording, checked
against the code and tests that shipped.

## Phase 1 — Paywall & Checkout Screens

| # | Item | Result | Evidence |
|---|---|---|---|
| 1 | `PaywallScreen` replaces the Task 15 stub; premium benefits; Monthly ৳100 / Annual ৳1,000; no lifetime plan | **PASS** | `paywall_screen.dart` keeps the mockup layout (user ruling) with the plan actions enabled and `paywall_subscribe`; prices are aliases of `payment_plans.dart` (`paymentMonthlyPrice` 100, `paymentAnnualPrice` 1000, no lifetime); the mockup HTML was updated to the enabled design so AGENTS rule 9 still holds. |
| 2 | Entry points: the 50-case limit and a "Go Premium" action in Settings | **PASS** | The 50-case gate already opens `AppRoutes.paywall`; Manage Account → *Purchase New Subscription* (mockup row) and a new Settings → General *Go Premium* row (hidden once premium) open it too. |
| 3 | `CheckoutScreen`: transfer instructions with copy-to-clipboard; `PaymentsConfigurationService` (validated build defaults bootstrap, authenticated remote authoritative, rotatable, display-only, reject missing/malformed/unsupported, retain last validated on transient failure, no hardcoding); form with method dropdown, sender phone, TrxID | **PASS** | `checkout_screen.dart` + `payments_configuration_service.dart`; remote is the new read-only `payment_configuration` table; 7 service tests cover missing/invalid/unsupported/rotation/empty/retention. |
| 4 | All strings localized (Bengali default) | **PASS** | New keys in `app_en.arb` + `app_bn.arb`, key-for-key, `flutter gen-l10n`; `test/l10n/arb_keys_test.dart` green. |

**Task-vs-project note:** the task names `app_translations.dart`; this project's
localization is the ARB + generated `AppLocalizations` system, which is what was
used.

## Phase 2 — Submission, Local Draft & Rate Limiting

| # | Item | Result | Evidence |
|---|---|---|---|
| 1 | Local draft saved on every keystroke, pre-filled on reopen, cleared only after a confirmed successful submission | **PASS** | `payment_local_store.dart` (`PaymentDraftNotifier`, per-user key), controller listeners in `checkout_screen.dart`, cleared in `PaymentViewModel.submit` only after the repository returns. |
| 2 | Submit to `payment_submissions` (pending; `submitted_at` server-assigned — client never supplies it); network failure shows *"Submission failed. Tap Retry."* and keeps the draft | **PASS** | `payment_repository.dart` omits `submitted_at`; `payments_submitFailed` wording; view-model test keeps the draft on a network failure. |
| 3 | Rate-limiting UX: best-effort 3-per-24h local check; authoritative server `BEFORE INSERT` trigger; trigger rejection surfaced as *"You've reached today's submission limit. Please try again tomorrow."* | **PASS** | `paymentSubmissionLogProvider` + pure `isLocallyRateLimited`; `limitReached` mapped from the trigger's `payment_submission_limit_reached` to `payments_limitReached`. |
| 4 | Submission history/status (pending/approved/rejected + `admin_notes`), own rows only under RLS; placement confirmed | **PASS** | `_PaymentHistory` in Manage Account behind Subscription Details (user ruling); reads `payment_submissions` under the existing own-row SELECT policy. |
| 5 | `payment_viewmodel.dart` controlling submission state + draft | **PASS** | `PaymentViewModel` (idle/submitting/success/failure), draft + log writes on success. |

## Phase 3 — Derived Premium Entitlement (Client)

| # | Item | Result | Evidence |
|---|---|---|---|
| 1 | Real derivation `subscription_expiry + 48h grace > now()`; never `subscription_status` | **PASS** | `premium_access.dart`; the display-only status cannot grant access (test). |
| 2 | Firm inheritance from `firms.subscription_expiry` | **PASS** | `resolvePremiumAccess` reads the firm expiry for a member; firm-inherited test. |
| 3 | One derivation feeds the sync worker gate, Firm-mode gating and the 50-case gate with call sites unchanged | **PASS** | `SyncService._isEntitled → premiumAccessProvider`, `ensure_firm`'s premium gate, `add_edit_case_sheet` — all already on this provider. |
| 4 | Clock caution: device time is UX-only; apply the recorded clock-skew offset | **PASS** | Skew applied inside the one derivation; the skew-flip test. Server RLS/`push_changes` remain the boundary. |
| 5 | Lapsed-premium users keep everything; only adding beyond 50 is gated | **PASS** | Unchanged existing behaviour; lapsed is not premium but nothing is hidden or deleted. |

## Phase 4 — Grace Period, Expiry Banners & Activation Detection

| # | Item | Result | Evidence |
|---|---|---|---|
| 1 | 48h grace with a persistent, non-intrusive banner; a within-window approval extends seamlessly | **PASS** | `subscription_banner.dart` grace state; a newer expiry simply resolves to `none`. |
| 2 | After grace, sync disabled immediately, local-only, no deletion; owner and associate banners | **PASS** | The sync gate already refuses below entitlement; `expiredOwner` / `expiredAssociate` messages. |
| 3 | Activation detection via Broadcast ping or profile refresh; trigger the Initial Backlog Push | **PASS** | `subscription_activation.dart` runs `runBacklogPush()` on a durable false → true transition (launch/resume refresh); `profiles`/`payment_submissions` have no Broadcast trigger, so the refresh path is the only one and is implemented. |
| 4 | Reflect plan, expiry (`DD/MM/YYYY`) and status in `manage_account_screen.dart` | **PASS** | Plan / Expiry / Subscription rows behind Subscription Details. |

## Alignment Addendum (Revision 2.4)

| Item | Result | Evidence |
|---|---|---|
| A payments configuration service owns MFS numbers; build env or authenticated remote; never hardcoded; rotatable without a release; display-only; missing/invalid/rotation tests | **PASS** | `payment_configuration` server table (authenticated SELECT only, no client write) + `PaymentsConfigurationService`; 7 tests. |
| Checkout drafts and payment UI preferences are per-user local state, never firm-shared | **PASS** | `payment_draft_<userId>` / `payment_submission_log_<userId>` in `SharedPreferences`; no firm scope. |
| Premium preference synchronization stays self-scoped even when entitlement is inherited | **PASS** | No new firm-shared state; entitlement is derived, never stored. |

## Completion criteria

| Item | Result |
|---|---|
| Phase 1 / 2 / 3 / 4 `flutter analyze` clean | **PASS** |
| Version history updated each phase | **PASS** (`0.0.333`–`0.0.336`) |
| Entitlement derivation unit tests (active, in-grace, lapsed, firm-inherited) | **PASS** (`premium_access_test.dart`) |
| Payment submission & approval end-to-end per the Verification Plan | **PASS (server contract) / see limitation** |

**Limitation, recorded honestly.** The Verification Plan's approval half is
server-side and was built and proven in Task 16: `approve_payment` is exercised
by `supabase/tests/rpc_smoke_test.sql` (lock, amount/plan validation, server
expiry, owner-firm mirror, one immutable audit event, idempotent retry). A fully
live two-account submission-then-approval run still faces the same constraint
Task 20 recorded — the project holds one live account — so the client half is
covered by the unit/widget suite (`payment_submission_test.dart`,
`checkout_screen_test.dart`, `subscription_activation_test.dart`) and the server
half by the rolled-back smoke test rather than a second live login.

## Deliberate deviations (recorded)

1. The paywall keeps its mockup layout with the actions enabled; the mockup HTML
   was updated to the enabled design (no mockup existed for the final screen).
2. `CheckoutScreen` has no mockup; its layout was proposed and approved in the
   plan (Justice Ledger tokens).
3. The Settings main list gained a *Go Premium* entry (mockup-bound body had no
   slot), the same kind of recorded departure Task 20 made for Delete Requests.
4. Submission history lives behind Subscription Details rather than as a new
   mockup-bound row.

# Task 21 — Payments & Subscription (Manual MFS Flow)

> **Plan references:** Sync Plan §7 "Manual MFS Payment Flow", §6 "Subscription Enforcement", Database Schema (`payment_submissions`, `payment_approval_events`, `approve_payment` contract — server side built in Task 16), "Resolved Design Clarifications" (Pricing, Payment Method, Firm Subscription) in `docs/implementation_plan.md`.
> **Goal:** The complete client-side payments experience: Paywall and Checkout screens, submission with local draft, derived premium entitlement everywhere on the client, grace-period and expiry banners, and activation detection.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess. Approval happens **only** via the admin `approve_payment` RPC (Task 16) — the app never approves anything.

---

## Phase 1 — Paywall & Checkout Screens

1. **`PaywallScreen`** (`features/payments/presentation/paywall_screen.dart` — replaces the Task 15 stub). Marked **[Design-deferred]**: no mockup exists, so propose a Justice Ledger-styled layout and **confirm with the user before building**. Contents: premium benefits (unlimited cases, secure cloud sync/backup, multi-device/firm sync) and the two plans — **Monthly ৳100** and **Annual ৳1,000**. No lifetime plan.
2. Entry points: hitting the 50-case limit (Task 15 Phase 5 navigation) and a "Go Premium" action in Settings.
3. **`CheckoutScreen`** (also [Design-deferred] — confirm layout) opened by selecting a plan:
   - Transfer instructions: exact amount and MFS number(s) with **copy-to-clipboard**. Load receiving numbers through a `PaymentsConfigurationService`: validated build-time defaults may bootstrap the app, but authenticated remote configuration is authoritative so numbers can rotate without a release. Treat values as display-only, reject missing/malformed/unsupported-method entries, retain the last validated configuration during a transient refresh failure, and never hardcode numbers in widgets or logs.
   - Input form: Payment Method dropdown (`bkash`, `nagad`, `rocket`), Sender Phone Number, Transaction ID (TrxID).
4. All strings localized (Bengali default) via `app_translations.dart`.

**Phase 1 completion:** Run `flutter analyze`, fix all errors. Update `docs/version_history.md` (new version entry + `## Current Version`).

## Phase 2 — Submission, Local Draft & Rate Limiting

1. **Local draft:** save the checkout form input to `SharedPreferences` on every keystroke. If submission fails or the user closes and reopens, pre-fill the form from the saved draft. Clear the draft only after a confirmed successful submission.
2. Submit to `payment_submissions` (status starts `pending`; `submitted_at` is server-assigned — the client never supplies it). On network failure show *"Submission failed. Tap Retry."* — the draft remains saved.
3. **Rate limiting UX:** perform a best-effort local check (3 submissions per 24h) purely as UX; the authoritative gate is the server `BEFORE INSERT` trigger (Task 16). Surface the trigger's rejection as *"You've reached today's submission limit. Please try again tomorrow."*
4. Show the user's submission history/status (pending/approved/rejected with `admin_notes`) — own rows only under RLS. Confirm placement (Checkout screen vs Manage Account) with the user.
5. Implement `payment_viewmodel.dart` controlling submission state + draft, per the folder structure.

**Phase 2 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Derived Premium Entitlement (Client)

1. Replace the Task 15 `SettingsRepository` entitlement stub with the real derivation: **`subscription_expiry + 48h grace > now()`** — computed, never read from `subscription_status` (display/analytics only).
2. **Firm inheritance:** for firm members, entitlement derives from `firms.subscription_expiry` (mirrored from the owner by the Task 16 trigger). When the owner lapses past grace, the derived check fails for every member on their next sync attempt.
3. Feed this single derivation to: the sync worker gate (Task 18), Firm-mode gating (Task 20 Phase 1), and the 50-case Add Case gate (Task 15 Phase 5 — call sites must not change).
4. **Clock caution:** the local check uses device time and is UX-only; RLS/RPC checks with database `now()` remain the security boundary. Apply the recorded clock-skew offset (Task 18 Phase 3) to reduce false banners.
5. **Lapsed-premium users keep everything:** expired premium never hides, blocks, or deletes existing cases; only *adding beyond 50* is gated on a free entitlement.

**Phase 3 completion:** `flutter analyze` clean; entitlement derivation unit tests pass (active, in-grace, lapsed, firm-inherited). Update `docs/version_history.md`.

## Phase 4 — Grace Period, Expiry Banners & Activation Detection

1. **48-hour grace period:** when `subscription_expiry` passes, sync stays fully active for 48h with a persistent, non-intrusive banner: *"Your subscription expired. Renew to avoid losing sync access."* If an admin approves a payment within the window, expiry extends seamlessly and the banner disappears.
2. **After grace ends:** sync is disabled immediately; the app falls back to local-only mode; no data is deleted. Banners:
   - Firm Owner: *"Your premium subscription has ended. Renew your subscription to restore sync."*
   - Associate: *"Your firm's premium subscription has ended. Contact your firm owner to renew."*
3. **Activation detection:** the app detects an approved payment via a Broadcast ping or a profile refresh on next launch/resume; on activation, trigger the **Initial Backlog Push** (Task 18 Phase 4) for first-time upgrades.
4. Reflect subscription state (plan, expiry date in `DD/MM/YYYY`, status) in `manage_account_screen.dart`.

**Phase 4 completion:** `flutter analyze` clean; payment submission & approval test per the Verification Plan passes end-to-end. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- A payments configuration service owns MFS receiving numbers. Load and validate them from build environment or authenticated remote configuration; never hardcode them. Remote values must be safely rotatable without a release, display-only, and covered by missing/invalid/rotation tests.
- Checkout drafts and payment UI preferences are per-user local state, never firm-shared.
- Premium preference synchronization remains self-scoped even when entitlement is inherited from a firm owner.

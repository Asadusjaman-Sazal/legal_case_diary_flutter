# Task 16 — Supabase Schema, RLS & Triggers (PART B begins)

> **Plan references:** "Database Schema" (all Supabase tables + notes), "Row-Level Security (RLS) Strategy", Sync Plan §1.1 (`push_changes` contract — implemented in Task 18, but its server tables are created here), §2 (server-side trigger guard), §3 (tombstones), §7 (payment triggers/RPC) in `docs/implementation_plan.md`.
> **Goal:** The complete Supabase backend schema: tables, server-internal tables, triggers, RLS policies, indexes, and scheduled cleanup — deployed as ordered SQL migrations. No Flutter code changes in this task beyond keeping the project compiling.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess. Keep all SQL in versioned migration files (e.g., `supabase/migrations/`) so the schema is reproducible.

---

## Phase 1 — Project Setup & Core Synced Tables

1. Create/link the Supabase project (ask the user for the project if not already provisioned). Set up the local `supabase/` migrations workflow.
2. Create core tables exactly per the Database Schema section: `profiles`, `firms`, `firm_members`, `firm_invites`, `cases`, `case_history`, `court_categories`, `courts`, `steps`, `case_types`, `on_behalfs`, `notes`, `case_references`, `delete_requests`, `conflict_log` (Supabase mirror), `payment_submissions`.
3. Apply the **global sync columns** only to the push/pull domain class: `cases`, `case_history`, `notes`, `case_references`, `court_categories`, `courts`, `steps`, `case_types`, `on_behalfs`, `delete_requests`, and `conflict_log`. Each gets `version INTEGER`, `server_updated_at TIMESTAMPTZ`, plus the per-table `updated_at`/`synced_at`/`is_deleted`/`last_modified_by` columns listed in its definition. Do not apply this contract to profiles, firms, memberships, invites, preferences, payments, or internal ledgers. Timestamp convention: server-authoritative instants are `TIMESTAMPTZ`; client display metadata stays `BIGINT` epoch ms exactly as each table specifies.
4. `case_history` gets a UNIQUE constraint on `source_mutation_id`; `payment_submissions.transaction_id` is UNIQUE.
5. Add the sign-up trigger that creates a `profiles` row for each new `auth.users` record (`role = 'individual'`, `firm_id = null`).
6. Seed `court_categories`, pre-seeded `courts`, `steps`, `case_types`, and `on_behalfs` with the **same stable deterministic IDs** used by the Drift seed migrations (Task 04) — IDs must match across Drift, Supabase, and backups.

**Phase 1 completion:** Migrations apply cleanly to a fresh project. Run `flutter analyze` (project must remain clean). Update `docs/version_history.md`.

## Phase 2 — Server-Internal Tables (No Client Access)

1. **`invite_attempts`** — rate-limit ledger for `join_firm`: `id UUID PK`, `user_id FK → auth.users`, `attempted_at TIMESTAMPTZ` (server `now()` only). RLS denies ALL direct client access. Create `invite_attempts_user_attempted_at_idx ON (user_id, attempted_at DESC)`.
2. **`mutation_receipts`** — idempotency ledger for `push_changes`: `mutation_id UUID PK`, `actor_id UUID NOT NULL`, `entity_type TEXT NOT NULL`, `entity_id UUID NOT NULL`, `request_hash TEXT NOT NULL`, `terminal_status TEXT NOT NULL`, `result_payload JSONB NOT NULL`, `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`. No client RLS policies; only the RPC owner reads/writes. Retention: ≥ 210 days, and never purge a receipt still referenced by history/conflict/audit records.
3. **`app_admins`** — immutable admin registry: `user_id UUID PRIMARY KEY REFERENCES auth.users`, `granted_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `granted_by UUID REFERENCES auth.users`. No authenticated INSERT/UPDATE/DELETE policies; membership changes only via audited migrations/service-role operations.
4. **`payment_approval_events`** — immutable audit ledger per the schema table: one event max per submission (`payment_submission_id UUID UNIQUE`), recording actor, plan, amount, previous/new expiry, server time. RLS: owners read own events, admins read all; no client writes, no update/delete path at all.

**Phase 2 completion:** Migrations apply cleanly. `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Triggers & Server Functions

1. **`server_updated_at` maintenance:** `BEFORE INSERT OR UPDATE` trigger on every synced table setting `server_updated_at = now()`. This is the only column delta pulls filter on.
2. **Delete-transition enforcement (trigger, not RLS):** `BEFORE UPDATE` trigger on each soft-deletable table detecting `OLD.is_deleted = false AND NEW.is_deleted = true` and verifying the editor has `can_delete` in `firm_members` (owner/individual creator always allowed), raising an exception otherwise.
3. **Resurrection guard:** narrow `BEFORE UPDATE` trigger rejecting `OLD.is_deleted = true AND NEW.is_deleted = false` unless a separately audited administrator recovery RPC sets a transaction-local authorization flag. Never compares client timestamps/versions/UUIDs.
4. **Free-tier case-limit guard (defense in depth):** trigger on `cases` INSERT that, when the owner's **derived** entitlement is free (`subscription_expiry + 48h grace > now()` is false) and their non-deleted case count is ≥ 50, rejects the insert. Take `pg_advisory_xact_lock(hashtext(NEW.user_id::text))` before counting to serialize count-and-insert.
5. **Payment rate limit:** `BEFORE INSERT` trigger on `payment_submissions` that overwrites/rejects client `submitted_at`, counts the caller's rows in the last 24h by `submitted_at`, and raises if already 3.
6. **`mirror_owner_subscription_to_firm`:** `AFTER UPDATE OF subscription_expiry ON profiles` trigger (owner rows only) copying expiry + display-only status to the owner's firm — the **only** write path for `firms.subscription_expiry`. Deploy in the same migration as `approve_payment`.
7. **`approve_payment(payment_submission_id UUID)` RPC:** implement exactly per the schema-section contract — `SECURITY DEFINER`, `SET search_path = pg_catalog, public`, `REVOKE ALL FROM PUBLIC`, `GRANT EXECUTE TO authenticated`, internal `app_admins` check, `SELECT ... FOR UPDATE` lock, pending/plan/amount validation, idempotent retries (`already_resolved`), expiry = `GREATEST(COALESCE(subscription_expiry, now()), now()) + 1 month/year`, submission update, firm mirror, and one immutable `payment_approval_events` insert — all in one transaction.
8. **`join_firm(code)` RPC:** `SECURITY DEFINER`; rate-limit check against `invite_attempts` (≥ 5 failures in 15 min → "Too many attempts"), hash the input, match an unused & unrevoked `firm_invites` row, create `firm_members`, update the associate's `profiles.firm_id`/`role`, mark the invite used — one transaction. Failed matches record an attempt via a **non-exception return path** (e.g., `{status: 'invalid_code'}`) so the insert commits; success deletes the caller's attempt rows; each call lazily deletes attempts older than 1 day.
9. **Realtime broadcast triggers:** `AFTER INSERT/UPDATE` trigger on each synced table calling `realtime.send()` with a tiny `{table, id}` payload to the private topic `firm:{firm_id}` (firm rows) or `user:{user_id}` (individual rows). Protect topic access with Realtime authorization (RLS on `realtime.messages`).
10. Revoke ordinary client UPDATE access to `payment_submissions.status/approved_at/approved_by`, `profiles.subscription_expiry`, and `firms.subscription_expiry`.

**Phase 3 completion:** Migrations apply cleanly; RPC smoke tests via SQL pass. `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 4 — Row-Level Security Policies

1. Enable RLS on **all** tables.
2. Implement the full policy matrix from the "Row-Level Security (RLS) Strategy" table verbatim, including:
   - `cases`/`case_history`: SELECT own or same-firm; INSERT own; UPDATE own or firm `can_edit` (coarse — delete transition handled by trigger); DELETE = soft delete only (no hard-delete policy).
   - Config tables (`court_categories`, `courts`, `steps`, `case_types`, `on_behalfs`): all-authenticated SELECT for pre-seeded rows; own/firm SELECT for custom rows; creator-or-same-firm-`can_edit` UPDATE; guarded soft delete. Custom and modified reference rows are firm-shared in firm mode and user-scoped in individual mode.
   - `profiles`: readable by self **and same-firm members** (needed for Manage Associates and "edited by [Name]" rendering); UPDATE self only; no DELETE.
   - `firm_invites`: owner-only everything; redemption exclusively via `join_firm`.
   - `delete_requests`: firm-member SELECT/INSERT; UPDATE by requester (own pending) or `can_delete` reviewer; never DELETE (audit trail).
   - `conflict_log`: own-rows only; no DELETE.
   - `payment_submissions`: own SELECT/INSERT (+ trigger limit); no ordinary UPDATE; no DELETE.
   - Server-internal tables (`invite_attempts`, `mutation_receipts`, `app_admins`): no client policies at all.
3. Wherever a policy/trigger checks premium entitlement, derive it as `subscription_expiry + 48h grace > now()` — never read `subscription_status`.

**Phase 4 completion:** Policy tests (e.g., `supabase test`/pgTAP or scripted anon/authenticated queries) prove the matrix. `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 5 — Indexes & Scheduled Cleanup

1. Create `payment_submissions_user_submitted_at_idx ON (user_id, submitted_at DESC)` and the `invite_attempts` index (if not created in Phase 2).
2. Add delta-pull support indexes on every synced table: composite `(server_updated_at, id)` (plus `user_id`/`firm_id` filters as appropriate) so cursor pagination is index-backed.
3. **Tombstone purge:** scheduled DB function (pg_cron or Supabase scheduled function) purging rows where `is_deleted = true` and the tombstone is older than **180 days**.
4. Document every migration file's purpose in a short header comment (Comment Preservation Rule).

**Phase 5 completion:** Full clean-slate migration run succeeds end-to-end. `flutter analyze` clean. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

1. Domain-synced tables are cases, case_history, notes, case_references, court_categories, courts, steps, case_types, on_behalfs, delete_requests, and conflict_log. Apply global sync columns/triggers/indexes only to this class.
2. profiles/firms/firm_members are server-managed pull-only caches on clients; auth/invite/payment/internal tables do not inherit the domain sync contract.
3. Add `is_user_modified` to all editable reference tables. The `cases` table has separate nullable `petitioner_phone` and `respondent_phone` columns.
4. Add a dedicated self-only server preference table for premium cross-device user preferences and case-notification settings. Never firm-share preferences.
5. Add explicit court_categories RLS: authenticated reads for built-ins, own/firm reads for custom rows, creator or same-firm can_edit updates, soft-delete guards, Broadcast trigger, and delta index.
6. Seed/custom reference data is firm-shared in firm mode and user-scoped in individual mode.
7. Keep `push_changes(rows jsonb)` implementation in Task 18; this task creates prerequisites only.

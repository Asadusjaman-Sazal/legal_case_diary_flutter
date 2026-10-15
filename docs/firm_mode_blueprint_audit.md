# Firm Mode Blueprint — Audit

> **What this is.** A loophole-and-missing-piece audit of `docs/firm_mode_blueprint.md`, checked
> against the **shipped** server SQL (`supabase/migrations/`) and client code, not against the plan
> or the task files. Each finding says what the blueprint rules, what the code actually does, the
> consequence, and a recommended resolution. Findings marked **decision** required a user ruling before the blueprint could be
> finalized — all six were ruled on and are recorded in *Rulings taken* below — and the rest are
> corrections that can be applied as-is.
>
> The known, already-admitted gap — that the reversals in the blueprint had not yet been
> propagated into `docs/implementation_plan.md` and tasks 15–21 — is **not** repeated here. That
> pass has since **run** (version 0.0.519), so no document now contradicts the blueprint.

---

## Severity summary

| # | Finding | Sections | Kind |
|---|---|---|---|
| 1 | Dissolution inverts ownership: the owner loses every member-authored row, the ex-members keep them | §4.4, §4.3, §2.1, §8 | decision |
| 2 | No tier, no seats and no `payment_plans`: the ladder §5.2/§5.3/§5.4 depends on is unmodelled | §5.2, §5.3, §5.4 | decision |
| 3 | A member's own live plan defeats the chamber-lapse ceilings; §5.1's "the firm's expiry is what applies" is not what the server does | §5.1, §5.2, §2.4 | decision |
| 4 | `can_add` is enforced nowhere — the blueprint says it already is | §3.3, §9.5, §10.1 | correction |
| 5 | Restore: the pull-only caches are restored, no rule for a restored row's `firm_id`, and a stale firm backup can trigger the removal wipe | §6, §4.1 | decision |
| 6 | The removal wipe is a tapped notice, not the automatic erase §4.1/§8 describe; detection also needs a cached membership row | §4.1, §8 | decision |
| 7 | Pricing arithmetic contradicts itself and its own 5/10/20 policy | §5.3, §10.9 | decision |
| 8 | "Every device computes the same set" is false during a lapse | §5.2, §5.4 | correction |
| 9 | The 365/335 numbers live in more places than §11 names, including a generated file a test polices | §5.5, §11 | correction |
| 10 | Smaller gaps: table-class list, `device_tokens` after removal, dissolved request/conflict rows, updater verification, the 400-day receipts invariant, and the status note's "nothing is written yet" | §7, §4.2, §4.4, §5.6, §5.5, header | mixed |

---

## 1. Dissolution inverts ownership (decision — the most serious)

**The ruling.** §4.4 step 3 unscope the chamber's rows by nulling `firm_id`, keeping attribution
(`user_id`, `created_by`, `last_modified_by`) untouched, so that "the owner keeps a complete,
ordinary, offline diary"; §8 repeats that "nothing is deleted".

**What the code does.** Every read policy on those tables is
`user_id = auth.uid() or firm_id = current_firm_id()`
(`20260929103000_phase4_rls_core_tables.sql`, `20260929103100_phase4_rls_reference_tables.sql`), and
§4.3's owed fix narrows the first half to `user_id = auth.uid() and firm_id is null`. After a
dissolve the rows carry `firm_id = null` and each row's original author in `user_id`. So:

- **the owner cannot read a row a member authored** — `user_id` is not his, and the second disjunct
  is null; and
- **the removed member can** — the first disjunct is exactly "my authored rows, no firm".

The owner therefore keeps only the rows *he* personally authored. That is not a corner case under
the blueprint's own reasoning in §3.2 ("most owners do not touch cases themselves — their associates
do"): dissolving a working chamber leaves the owner with a nearly empty diary, and the chamber's
ledger is readable only by the associates who were just removed and wiped. Any full pull (a fresh
device, a reinstall, or the wipe's fresh database) reproduces that: those rows never arrive, while
they would arrive in an ex-member's new ledger.

Three further consequences ride on the same root cause:

- **§2.1's join refusal misfires.** "Its own diary" is defined as non-deleted rows the account
  authored while `firm_id IS NULL`. After a dissolve, that is precisely what the ex-members' old
  chamber rows look like, so the account that §2.2 promises "may join another chamber with the same
  account" is refused — with the "N cases" wording — for rows it wrote inside a chamber.
- **§4.1's reassurance becomes untrue.** The rows "stay the firm's" only until the firm is dissolved;
  after that they are the authors' in every sense the read policy understands.
- **The owner's own delete becomes destructive.** Once dissolved, the rows sit in his account's
  scope, and `delete_my_account()` hard-deletes domain rows rather than soft-deleting them
  (`20261008100000_delete_my_account.sql`), so members' work can be destroyed without their
  knowledge.

Two more tables make the picture worse rather than better: unscoped `delete_requests` have
**no author clause at all** (`delete_requests_select_firm` is `firm_id = current_firm_id()`), so the
dissolved chamber's request history becomes unreadable by everyone including its requester; and
unscoped `conflict_log` rows are readable by their authors only, exactly as above.

**Recommended resolution.** Make the scope key distinct from the attribution key. The cheapest
coherent shape: give the domain rows a nullable scope owner and have the dissolve write it —
`firm_id` nulled, `scope_owner_id = <owner>` — with the read policy
`(user_id = auth.uid() and firm_id is null and scope_owner_id is null) or firm_id = current_firm_id()
or scope_owner_id = auth.uid()`, and §2.1's "its own diary" test the same three conditions. Attribution
(`user_id`, `last_modified_by`) then stays intact and the display keeps working. The alternatives are
to re-point `user_id` to the owner (one assignment, no new column, but `cases`, `notes` and
`case_references` have **no `created_by`** — `user_id` is their only author record — so "added by"
is lost) or to accept the behaviour and say so (the owner exports before dissolving, and the
confirmation states that member-authored rows become their authors' again). This is a product
decision, not a bug fix.

---

## 2. No tier, no seats, no `payment_plans` (decision)

**The ruling.** §5.2 scales a lapsed account's write allowance by "the tier it last held" (Pro 100 /
Firm 500 / Firm Plus 1,000); §5.3 prices five tiers with case ceilings and seat counts (5 and 20
associates), says "each plan is one row in `payment_plans`", and §5.4 caps seats at join time.

**What the code has.** `firms` is `(id, name, owner_id, subscription_status, subscription_expiry,
created_at)` and `profiles` is `(id, full_name, firm_id, role, subscription_status,
subscription_expiry, created_at)` (`20260929100000_phase1_core_schema.sql`; mirrored by
`firms_table.dart` / `profiles_table.dart`). There is **no `payment_plans` table anywhere in the
schema**: the ladder lives as four constants inside `approve_payment`
(`20261002100000_payment_prices_discounted.sql` — `c_monthly_bdt 100`, `c_quarterly_bdt 285`,
`c_half_yearly_bdt 540`, `c_annual_bdt 960`), keyed by `plan_type` ∈
{`monthly`, `quarterly`, `half_yearly`, `annual`}, with the readable name a **generated** column
derived from those four keys (`20261005120000_payment_plan_name.sql`). And `join_firm` inserts a
membership with no seat check of any kind (`20260929102300_phase3_join_firm.sql`).

So three of the blueprint's load-bearing quantities have nowhere to live: **which tier an account
holds**, **how many seats it bought**, and **what the last tier held was** at the moment a lapse
begins. A two-tier ladder cannot even be expressed in the current `plan_type` keys: Pro quarterly
and Firm quarterly would collide. §5.3's "one row in `payment_plans`… ten plans, not sixteen" also
misdescribes the real cost, which is four (soon seven-plus) `plan_type` keys × the `approve_payment`
CASE × the generated `plan_name` CASE × the client's plan labels and checkout.

**Recommended resolution.** Model the tier explicitly — the plan keys carry it (e.g.
`firm_quarterly`, `firm_plus_annual`) and a `tier` value is written to `profiles`/`firms` at
approval, so "the tier last held" survives a lapse and the seat cap has a source — then correct
§5.3's account of the implementation cost, name the four places a new plan touches, and define the
seat check `join_firm` must run (and what it answers when the cap is reached).

---

## 3. A member's own live plan defeats the lapse ceilings (decision)

**The ruling.** §5.1: "A member who *also* holds their own plan keeps it for the day they leave; it
changes nothing while they are in a chamber, because the firm's expiry is what applies." §5.2: while
lapsed "the engine cannot push anything anyway, so the cap is enforced on the device… the server's own
gate (entitlement on `push_changes`) remains the security boundary".

**What the code does.** `has_sync_entitlement(p_user_id)`
(`20260930140000_push_changes.sql`) is an **OR**: the caller's own `profiles.subscription_expiry + 48h
> now()` **or** the firm's mirrored expiry. `push_changes` gates every mutation on it. So a member of
a lapsed chamber who holds their own live plan **keeps pushing**, and the entitlement gate that §5.2
calls the security boundary is open for exactly that member. §2.4's "the new member works local-only
with everybody else until the owner renews" is likewise untrue for them, and §5.2's ceilings become
the only limit on their writes — a modified client can write past the allowance.

**Recommended resolution.** Pick one: make a member's entitlement the firm's alone (a small change to
`has_sync_entitlement`: when `profiles.firm_id` is not null, only the firm's expiry counts), which
makes §5.1 real; or keep the OR and record the consequence plainly — a member with their own plan
keeps syncing while the chamber has lapsed, so §5.2's allowance bites only members without one, and
the local cap is not backed by a server gate for the rest.

---

## 4. `can_add` is enforced nowhere (correction)

**The ruling.** §3.3: "`can_add` is already enforced where it matters (`push_changes` INSERT); the
UPDATE half is the new work." §9.5 and §10.1 repeat it.

**What the code does.** `sync_can_write`'s INSERT branch checks authorship and firm scope only — for
ordinary rows `user_id = v_actor and (firm_id is null or firm_id = current_firm_id())`, for reference
rows the same plus `is_custom` — and never reads a permission flag
(`20260930140000_push_changes.sql`; unchanged by
`20260930210000_sync_can_write_firm_membership.sql`). The phase-4 INSERT policies are the same shape.
There is **no `can_add_firm` helper anywhere**: the only flag readers in the schema are
`can_edit_firm` and `can_delete_firm` (`20260929102000_phase3_access_helpers.sql`). So a member with
`can_add = false` can insert firm rows today through the RPC *and* through PostgREST, and both halves
of §3.3's boundary are owed rather than just the UPDATE half.

**Fix.** Correct §3.3, §9.5 and §10.1 to say both halves are new work (a `can_add_firm`-style helper
plus one `BEFORE` trigger per table, the shape `enforce_delete_transition()` already uses, which is
verified present), and note the new helper beside the two existing ones.

---

## 5. Restore in firm mode: caches, firm scope, and a false removal (decision)

**The ruling.** §6 bars restore whenever firm mode is on, the owner included, with one exception — a
completely empty device — where "the full pull a fresh install performs brings the chamber's rows,
and every tombstone the server still holds, over the restored ones".

**What the code does.** The snapshot covers **every** portable table, including the pull-only caches
`profiles`, `firms` and `firm_members` (`backup_repository.dart` → `backupTableOrder`), and the
import replays that list forwards. Ownership is decided from the rows: a row whose `user_id` is this
device's identity counts as **mine whatever its `firm_id` is**, and `firm_id` is stamped only into
rows that name *no* owner (`backup_ownership.dart` → `classifyBackupOwnership` /
`stampRowOwnership`). Restore-onto-empty-device is already allowed by the shipped guard, which blocks
only when the account is premium, has synced *and* still holds user-authored data
(`backup_restore_screen.dart`).

Three consequences the blueprint does not rule on:

- **The mixed ledger §1 forbids.** An owner restoring his own pre-chamber (or pre-dissolve) file into
  a live chamber writes rows with `firm_id is null` beside the chamber's: not the chamber's, invisible
  to every member, and — once §4.3's fix lands — not readable as "his" either.
- **Rows scoped to a firm he is not in.** A file row carrying another firm's `firm_id` passes the
  ownership gate (the owner matches), then can never be pushed (`sync_can_write` refuses a foreign
  firm) and, after §4.3, cannot even be read back from the server: permanent local-only data.
- **A stale firm backup can trigger the removal wipe.** A restored `profiles` row with a dead
  `firm_id` plus a restored `firm_members` row is exactly `membershipRevokedProvider`'s condition
  (`account_mode.dart`) once the server's own profile lands with `firm_id = null`; the user then meets
  the blocked "access ended" screen and the wipe erases the diary they just restored.

**Recommended resolution.** Exclude the pull-only caches from **restore** (rule 4 already says they are
the server's, not the device's) and rule what a restored row's `firm_id` becomes in firm mode: stamped
to the current chamber, or the file refused. Keep the empty-device exception.

---

## 6. The removal wipe is not what §4.1/§8 describe (decision)

**The ruling.** §4.1: the app "runs its **complete wipe scope**"; §8: the device "wipes on its next
launch or connectivity **before any sync, pull or write runs**"; §4.1 also says the revocation ends
"the member's sessions and Realtime topic access".

**What the code does.** The shipped client shows a latched, blocking notice with one button and
erases nothing until the person taps it — "**Nothing is erased until the user acts**"
(`membership_revoked_scope.dart`). The wipe it runs is the right one
(`LogoutFlow.wipeAndComplete` → `BackupRepository.wipeAllTables`, then sign-out), but it is
user-initiated, not automatic, and it is a UI gate rather than a pre-sync barrier. Two smaller
discrepancies sit beside it:

- Detection needs the profile pull to have landed **and** a cached `firm_members` row to exist
  (`account_mode.dart` → `membershipRevokedProvider`); a member whose device never cached its own
  membership row is never told it was removed.
- The server does not end the session: `remove_firm_member` says so explicitly and deliberately
  (`20260930190000_remove_firm_member.sql`), because there is no service-role key. What actually ends
  is the RLS and Realtime access. The baseline is right; the sentence overstates it.

**Recommended resolution.** Rule which behaviour is intended. If the tapped notice stays, reword §4.1
and §8 to match it (the member is told, blocks the app, and confirms; nothing is erased silently) and
name the cached-membership-absent case; also note that until the tap, that device's scheduled case
notifications for the chamber keep firing. If the wipe is to be automatic, say what replaces the
"nothing is erased until the user acts" reasoning, and keep the notice as information only.

---

## 7. Pricing arithmetic (decision)

**What the blueprint says.** §5.3's table gives Pro "৳100/month · **৳1,000/year**", while the
*Durations* paragraph two lines below says "Pro keeps the four plans the app already sells (1, 3, 6 and
12 months at ৳100/৳285/৳540/**৳960**)", and §10.9 repeats ৳1,000. The shipped constants are
৳100 / ৳285 / ৳540 / ৳960 (`20261002100000_payment_prices_discounted.sql`), i.e. the paragraph is the
accurate one and the table and §10.9 are stale. Separately, the new chamber annuals do not follow the
policy the paragraph states: at the same 5 %/10 %/20 %, Firm 12 months is
**৳2,880** (not ৳3,000) and Firm Plus 12 months is **৳5,760** (not ৳6,000) — the quoted figures are
~16.7 % off, while the three- and six-month figures (৳855/৳1,620 and ৳1,710/৳3,240) are exactly right.

**Recommended resolution.** One ruling fixes both: either Pro annual is ৳960 and the chamber annuals
are ৳2,880/৳5,760 (policy stated stays true, table and §10.9 corrected), or Pro annual is ৳1,000 and
the chamber annuals are ৳3,000/৳6,000 (the discount policy paragraph is restated as ~17 % for the
chamber tiers and ৳960 → ৳1,000 becomes a deliberate price rise, which is a `plan_type` constant
change with a migration). Whichever is chosen, the numbers in the table, the paragraph, §10.9 and
`approve_payment` must be one set.

---

## 8. "Every device computes the same set" is false during a lapse (correction)

§5.2 derives the writable set from the local ledger and claims "every device computes the same set".
While lapsed **nothing syncs**, so each device's ledger is its own: two devices of one chamber can
compute different writable sets, the same case can be editable on one and read-only on another, and
on renewal the merged backlog can exceed the tier ceiling in one go. The claim holds only for a
chamber whose devices were in sync at the instant the lapse began. **Fix:** soften the sentence and
add one line saying what renewal does with an over-allowance backlog (accept it, or drain
most-recently-updated first).

---

## 9. The 365/335 numbers live in more places than §11 names (correction)

Besides `purge_tombstones()`'s default and `recoveryOfflineThreshold`, both figures appear as prose:

- the migration's own header comment and the function's `comment on function` still say 180
  (`20260929104000_phase5_indexes_and_tombstone_purge.sql`);
- `recovery_lock.dart`'s doc block states 180/150 twice above
  `const Duration recoveryOfflineThreshold = Duration(days: 150)`;
- the **generated** ledger carries the number in its section label —
  `'purge_tombstones(180 days) scheduled daily through pg_cron'` in
  `tool/generate_all_supabase_sql.dart` — and `dart run tool/generate_all_supabase_sql.dart --check`
  plus `test/supabase/all_supabase_sql_test.dart` fail on drift.

**Fix.** Add the generator's label and the in-code comments to §5.5's list of edits, so a 365-day
migration plus a regenerated ledger is one pass rather than a failing check.

---

## 10. Smaller gaps (mostly corrections)

1. **§7's table-class list is incomplete.** It names the shared domain set and the per-user settings,
   but not `delete_requests` (firm-scoped domain), `conflict_log` (per-device domain, the reason its
   policies have no `can_edit_firm` disjunct), `case_notification_preferences`, `user_preferences`,
   `profiles`/`firms`/`firm_members` (pull-only caches) or `device_tokens` (server-managed). Rule 4
   wants every touched table classified in one place.
2. **§4.2 leaves `device_tokens` behind on removal.** The sign-out row removes its own token; a
   *removal* touches no token (`remove_firm_member`), so a removed member's device keeps its push
   registration. Harmless today — the only server push is the admin payment alert, which needs
   `app_admins` — but it should be either deleted on removal or explicitly ruled out of scope.
3. **§4.4 step 3's unscope needs `delete_requests`/`conflict_log` to keep an author clause** or their
   history becomes unreadable by everyone, including the member who raised the request (see finding 1).
4. **§5.6 has no verification story.** With the self-updater as the only update path and no store to
   fall back on, the blueprint should say who proves a release is ours (signed releases, or a checksum
   pinned in the app). Release naming and the `FileProvider` grant are named; authenticity is not.
5. **§5.5's 400-day `mutation_receipts` invariant is unenforced.** Correct that nothing purges them —
   it is a documented invariant only, so a later cleanup job could break it silently. One line saying
   where the invariant is (re)checked would close it.
6. **The status note is too pessimistic.** "No migration, screen or test for these rulings has been
   written yet" is true for §4.3, §3.3, §3.2's in-use guard and §5.5 — but §6's restore guard and the
   ownership rules, §4.2's `delete_my_account()` firm refusal and the §2.4 premium gate on
   `ensure_firm` are already built. The note should separate *built* from *owed* so nobody re-plans
   existing work.

---

## Claims checked and confirmed (no finding)

- §4.3's leak is real and quoted correctly: `cases_select_scoped`, `case_history_select_scoped`,
  `notes_select_scoped`, `case_references_select_scoped` are `user_id = auth.uid() or firm_id =
  current_firm_id()`; the six reference tables add `is_custom = false`;
  `conflict_log_select_own` is still `user_id = auth.uid()` only — the 0.0.330 migration fixed its
  insert/update policies and left the select alone.
- `join_firm` consumes the code as `used_by` when the redeemer is already a member — the fumble §2.5
  fixes — and inserts `('associate', can_add => true, can_edit => false, can_delete => false)`.
- `remove_firm_member` relinks `profiles.firm_id`/`role` to null/individual, deletes the
  `firm_members` row, broadcasts to both topics, and touches no domain row.
- `ensure_firm` refuses a non-premium caller (the premium-gated transition) and refuses a member of
  another firm; it relinks the profile and upserts the owner's `firm_members` row (all permissions
  true) but does **not** stamp the owner's existing rows — consistent with §1/§9.1 being owed.
- `delete_my_account()` refuses a firm account and an administrator, and hard-deletes the account's
  own domain rows; after a dissolve (firm_id null, no owned firm) it is no longer refused.
- `purge_tombstones(p_retention_days integer default 180)` is scheduled daily as
  `select public.purge_tombstones()` with no argument, and its delete order is children-first.
- The reference-row FK really is what makes the purge fail as a whole: `cases.on_behalf_id` (and its
  siblings) reference the reference tables with no cascade, so deleting a tombstoned row a live case
  still names raises and aborts the whole function — §3.2's reasoning is exact.
- `recovery_lock` is firm-mode only and never reads entitlement (`shouldRecover`), and its threshold
  is 150 days today.
- `has_sync_entitlement` uses expiry + 48h grace and never `subscription_status`; `is_premium` backs
  the `ensure_firm` gate on the same rule.
- The free wall is 50 live cases (`freeTierCaseLimit`, enforced in the Add Case save path) with no
  ceiling on notes, references or seed customisation — §5.2's "the wall it has today" is accurate, and
  there is no premium case ceiling anywhere yet.
- `enforce_delete_transition()` exists as a per-table `BEFORE` trigger; it is the shape §3.3 proposes
  for the permission triggers.

---

## Rulings taken (all six)

1. **Dissolution ownership** — a **scope owner**: the dissolve nulls `firm_id` *and* writes the owner
   as the rows' scope owner, so he keeps the ledger and the authors lose the read they would
   otherwise have regained, with `user_id` / `created_by` / `last_modified_by` untouched. Recorded in
   the blueprint's §4.4, §4.3 and §2.1.
2. **Where the tier lives** — an explicit **`profiles.tier` / `firms.tier`** column plus the seat cap
   read from it, written at approval and never cleared by expiry, with `join_firm` refusing a join
   past the cap. §5.3 and §5.4.
3. **A member's own plan** — **a member may not buy one** (the app does not offer it and the server
   refuses the submission) and **their own expiry does not count while they hold a firm**; paid time
   is preserved for the day they are individual again. §5.1.
4. **Restore in the blank-diary exception** — the account rows (`profiles`, `firms`, `firm_members`)
   are **never restored**, a restored row is **stamped with the current chamber**, and a file naming
   another firm is refused. §6.
5. **Removal wipe timing** — **the device erases itself**, with no confirmation step, on its next
   launch or connection and before any pull or write; the notice only says what has been removed.
   §4.1 and §8.
6. **The pricing numbers** — **the blueprint's ten prices stand as written** (Pro
   ৳100/৳285/৳540/৳1,000; Firm ৳855/৳1,620/৳3,000; Firm Plus ৳1,710/৳3,240/৳6,000), with the
   percentage-discount story withdrawn; Pro's annual consequently moves from the shipped ৳960
   constant to ৳1,000 by migration. §5.3.

**Findings 4, 8, 9 and 10** needed no ruling and are applied: both halves of the permission boundary
are now owed (§3.3), the "every device computes the same set" claim is narrowed (§5.2), the 365/335
numbers are listed with the generated ledger label and the in-code comments (§5.5), and the
table-class list, the `device_tokens` note, the updater's authenticity requirement and the 400-day
receipts invariant are recorded (§4.2, §5.6, §7).

**Propagated (version 0.0.519).** `docs/implementation_plan.md` and tasks 15, 16, 17, 18, 19, 20 and
21 no longer carry the superseded wording: this revision's rulings and corrections travelled in one
pass, so no file was edited twice for the same ruling. **What remains owed is work, not records** —
every migration the blueprint's §10 open list names. **The user asked to be reminded of exactly
this.**

---

## Second pass — re-audit of the finalized blueprint

Re-checked against the shipped SQL and Dart after the rulings were applied. The ten first-pass
findings still hold as stated (the policy text, the invite consume, the entitlement OR, the 50-case
gate, the two-constant mirror, the FK that aborts the purge, the `delete_my_account()` refusals).
This pass found **six new holes**, **five misjudgements in this audit's own first-pass text**, and
left **two product questions** for the user.

### New holes

1. **The scope columns are client-writable, and a member can currently detach a row from the
   chamber.** `push_changes` is `SECURITY DEFINER`, so the column privileges that guard direct
   PostgREST writes do not apply to it, and it strips only `server_updated_at`, `version` and
   `last_modified_by` (plus `created_at` for `conflict_log`) from a payload — **any column added
   later arrives client-writable**. `sync_can_write`'s update branch then evaluates the *final* row,
   where `user_id = v_actor and firm_id is null` is true for an author, so nulling `firm_id` is
   accepted; the insert branch likewise accepts `firm_id is null` from a caller who holds a firm. So
   §1's "a chamber holds chamber rows and nothing else" is unenforced today, and the new
   `scope_owner_id` would have arrived writable — one accepted update would let an author take a case
   out of the chamber's ledger and carry it into their next one as their own. **Fixed** in §3.3 (the
   scope columns are server-owned; `firm_id` is assigned from the caller's firm at insert and never
   changed by a client). This was a hole in *this audit's own* pass-1 recommendation.
2. **`firms.tier` had no write path.** `approve_payment` writes the **profile**, and the firm's copy
   moves only through `mirror_owner_subscription_to_firm()`, which fires *on `subscription_expiry`
   changes only* and copies two columns — so a tier-only change would never reach the firm and the
   seat cap would read a stale value. **Fixed** in §5.3 (the mirror's `of` list and `when` widen to
   cover `tier`). Confirmed alongside it: client writes to `tier` are closed *by construction* —
   `20260929102500_phase3_column_privileges.sql` grants only `update (full_name)` on `profiles` and
   `update (name)` on `firms`, and its own comment states that a column a later migration adds is
   denied by default.
3. **The allowance had no enforcement site.** The shipped gate is `freeTierCaseLimit` (50) in the Add
   Case save path, applied whenever the account is not premium — so a lapsed Pro or Firm account
   would be stopped at **50** rather than at its allowance, and notes and case references have no gate
   anywhere today, so their ceilings are two new checks. **Fixed** in §5.2 (the sites are named).
4. **A sequencing hazard between two rulings.** The self-erasing removal is only safe once the join
   refusal guarantees the seat is empty; until `join_firm` refuses a caller with individual rows, an
   account that kept a diary and joined anyway would have it erased, with no backup (§6 gives a member
   none) and no confirmation step to warn them. **Fixed** in §9 (step 3 ships no earlier than step 2).
5. **The erase trigger's evidence was unnamed.** Detection no longer leans on a cached `firm_members`
   row, so the comparison needs durable local evidence — the cached **firm row**, or an explicit
   *had a firm* marker — and the blueprint asserted the behaviour without naming it. **Fixed** in §4.1.
6. **The member's purchase refusal needs its sites.** `payment_submissions_insert_own` is
   `with check (user_id = auth.uid())`, so "the server refuses the submission" is a policy change, and
   the hidden plans entry is not only on the Subscription screen — the side menu's **Current Plan** row
   expands into Subscription Plans. **Fixed** in §5.1 and §11.

### Misjudgements in this audit's first-pass text (corrected)

1. **§4.3's fix misdescribed its two exception tables.** `conflict_log` is a device's own merge
   diagnostics, not a ledger: it needs the membership condition on its select and **no** scope owner;
   and `delete_requests` names its author `requested_by`, not `user_id`, so the condition cannot be
   copied verbatim. §4.4's step 3 had also listed conflict entries among the rows to hand the owner.
   That would have donated colleagues' merge diagnostics to the owner. **Corrected** in §4.3 and §4.4.
2. **§6's restored-row rule would have rewritten `user_id`.** "Stamped with the current chamber's
   `firm_id` and the restoring account" contradicts §4.4's own rule that attribution is never
   rewritten, and would have made a colleague's restored row the restorer's. **Corrected**: stamp
   `firm_id`, clear `scope_owner_id`, leave `user_id` / `created_by` / `last_modified_by` alone (the
   existing ownership rule still fills an owner column that names nobody).
3. **§4.2 contradicted the new §4.1** — "membership, sessions and topic access revoked" against the
   audit's own finding and the migration's deliberate decision that the auth session is not revoked.
   **Corrected** in §4.2.
4. **§10.9 carried a duplicated word** — "(৳6,000 a / a year)" — left by this audit's pass-1 script,
   whose first anchor failed and whose fix landed in the wrong half of the edit. **Corrected.**
5. **The erase notice still read "about to be erased"** after the ruling changed the wipe to
   self-erasing. **Corrected** in §4.1.

### Verified this pass (previously asserted without checking)

- §5.5's device-local purge claim is accurate: `AppDatabase.purgeSoftDeletedRecords()` uses a
  **90-day** retention and purges only rows that were **successfully synced**
  (`synced_at IS NOT NULL AND synced_at >= updated_at`), so a never-synced tombstone is never purged
  and the server remains the record of a deletion for the recovery window.

### Questions left to the user (both ruled)

1. **Ruled: a chamber may not be created on Pro.** Creation needs the Firm tier or above, so
   `ensure_firm`'s gate reads the tier rather than `is_premium`, and a Pro owner is refused with the
   reason instead of building a chamber whose seat cap of 0 fails every invitation. Recorded in the
   blueprint's §2.4, §5.3 and §10 (item 16).
2. **Ruled: a downgrade waits for the period it was bought for.** A Firm Plus owner who buys Firm
   mid-term keeps Firm Plus until the paid period ends and is on Firm from the day after. Because
   nothing runs when a period turns over, the rule needs two values beside the tier in force — a
   **pending tier and the instant it starts** — and every gate derives the effective one. Recorded in
   the blueprint's §5.3, §5.4 and §10 (item 17).

**Both rulings are applied in the blueprint** (§2.4, §5.3, §5.4 and §10 items 16 and 17), so §10's open
list is now work only, not questions. **The propagation pass across `docs/implementation_plan.md` and
tasks 15, 16, 17, 18, 19, 20 and 21 has since run (version 0.0.519)**, carrying this pass's
corrections with it, so no document now contradicts the blueprint; the owed SQL is untouched.

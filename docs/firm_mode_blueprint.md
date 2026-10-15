# Firm Mode Blueprint — The Chamber Ledger

> **Status: plan record, not as-built documentation.** This file carries the detail behind the
> firm-mode rulings that are summarised in `docs/implementation_plan.md` →
> *Resolved Design Clarifications* (the bullets headed *A Chamber Holds One Ledger* through
> *The Order Of Work For Firm Mode*). The plan remains the source of truth; if this file and the
> plan disagree, the plan wins and this file is corrected. Every statement below is a **decision
> about what to build**, not a description of what exists, and part of it is already built: §6's
> firm-mode restore bar with its ownership rules, §4.2's `delete_my_account()` firm refusal and
> §2.4's premium gate on `ensure_firm` exist today; the rest is owed, and where the shipped server
> or client contradicts a ruling this file says so (§4.1, §4.3, §5.5, §10).
> `docs/firm_mode_blueprint_audit.md` is the finding-by-finding record of what was checked against
> the shipped SQL and Dart; this revision answers it.
>
> **Revision note (the previous pass).** Nine rulings changed or arrived here: the chamber's shared config
> became **member-editable** (§3.2, reversing the earlier owner-only reading), the permission flags
> became a **real server boundary** (§3.3, closing the old open item), removal gained an **owner
> warning** about the device that never returns (§4.1), the invite code **survives** with its
> fumble fixed (§2.5), a lapsed account gained **write ceilings scaled to the tier it last held**
> (§5.2), tombstone retention went to **365 days / 335-day recovery** (§5.5), the **tier ladder was
> repriced and settled** (§5.3), **dissolution** was designed (§4.4), and the app sells through
> **direct distribution** rather than Google Play for now (§5.6).
>
> **Audit pass (this revision).** `docs/firm_mode_blueprint_audit.md` checked every ruling against
> the shipped SQL and Dart, found ten loopholes or gaps, and raised six decisions — all six are now
> ruled on and recorded here: a **scope owner** so a dissolve cannot hand member-authored rows back
> to their authors (§4.4), a stored **tier and seat cap** so the lapse allowance and the join-time
> seat check have a source (§5.3), **no personal plan for a member** and their own expiry ignored
> while they hold a firm (§5.1), restore that **skips the account rows** and stamps the chamber
> (§6), a **self-erasing** removal with no confirmation step (§4.1), and the plan prices kept
> exactly as written with the percentage-discount story withdrawn (§5.3). Its smaller corrections
> are recorded in §3.3, §4.2, §5.2, §5.5, §5.6 and §7.

---

## 1. The shape of an account

**Two account shapes, and only two.** An account is either **individual** (`profiles.firm_id` is
null) or **chamber** (`firm_id` non-null). There is no third, mixed shape, and that is the whole
foundation of the model.

**A chamber account holds chamber rows and nothing else.** There is no per-row "mine" marker, no
ownership chip, no scope filter, and no such thing as a private case inside a firm account. Every
case, note, reference and custom seed row the chamber holds is visible to every member of it.

**Creating a chamber shares the creator's existing diary, and asks nothing.** A lawyer creates a
chamber in order to collaborate, so the moment the firm is created, the cases, notes, case
references and customised seed data the owner already has **become the chamber's**, stamped with
the new `firm_id` exactly as every row written afterwards is. An earlier draft had creation ask one
explicit question — *"Share your N existing cases with this chamber? Everything you share becomes
visible to every member you invite."* — and that question is **withdrawn**: sharing at creation is
the default, not a choice.

**Why single-ledger rather than personal-and-chamber rows.** Every list, count, badge, export, PDF,
search and reminder in the app would have to become scope-aware for a mixed account, and one
forgotten path leaks one member's work to another silently. With a single ledger the app's existing
reads are correct as they stand: a case or note query filters on `is_deleted` and screen scope
only, and that is enough.

**Authorship is answered by attribution, not by visibility.** `user_id`, `created_by` and
`last_modified_by` say who added a row and who last changed it — which is what "edited by [Name]"
and the conflict banner already read.

---

## 2. Joining a chamber

### 2.1 A seat starts empty

Joining an existing chamber is refused when the account already holds its own diary, where *its own
diary* means non-deleted rows that account authored **as an individual** — `firm_id IS NULL` *and*
its scope owner null (§4.4's dissolve writes one, which is what stops a dissolved chamber's rows
ever counting as anybody's own diary) — cases, notes, case references, or a court category, case
category, court, step, case type or on-behalf it added or edited.

The refusal is worded:

> **This account already has its own diary (N cases). An associate's diary must be empty — sign up
> again using a different account with Join Existing Firm, or export your diary, delete this
> account and then Join Existing Firm.**

(English source string; localized in both ARBs like every other refusal.) A refused join changes
nothing and says why; it is never silent.

### 2.2 Two consequences that are deliberate

**Rows authored inside a chamber are the chamber's.** They keep their author's `user_id`, but they
are not that account's "own diary", so they never block a later join. This is what makes the
removed-member case work: an account removed from one chamber is left with an empty diary and may
join another chamber with the same account.

**An invitation never merges.** An existing individual with a diary either stays personal or
becomes the chamber it owns. No product checked for this decision merges a solo account into a firm
workspace on invitation; the documented pattern is explicit import or grant.

### 2.3 The `firm_id IS NULL` definition depends on §4.3

The definition above is only sound because a member cannot read the rows they authored in a chamber
they have left. That is not true on the server today — see §4.3. Until the read policies are
scoped, a removed member's old chamber rows come back on their next full pull, and they would not
even be counted as "its own diary" by this definition, so one chamber's ledger could reappear
inside the next one.

### 2.4 Joining a lapsed chamber is allowed, on purpose

If the owner's subscription has lapsed past the 48-hour grace window when a new associate redeems a
code, the join still succeeds, and nothing bad follows from it.

- There is **nothing to merge**: the seat is empty by §2.1, so the newcomer brings no second diary
  and the chamber's ledger is not touched.
- The only effect is that the new member works **local-only** with everybody else until the owner
  renews: the app behaves exactly as it always does without a connection, every write is saved
  locally and queued in `sync_queue` with its sync columns, and the member sees the plan's existing
  *"Your firm's premium subscription has ended. Contact your firm owner to renew."* banner.
  §5.2's write ceilings apply to the whole chamber from that moment, the newcomer included.
- When the owner renews, the false→true entitlement transition re-issues the delta pull and all of
  it catches up by itself.

Refusing the join would strand the owner's new colleague for no benefit to anyone. Lapsing does not
weaken the other gate either: a chamber that does not exist yet still cannot be **created** without
**the Firm tier or above** (user ruling). The chamber tiers are what sell seats, so `ensure_firm`'s
gate reads the tier rather than the derived premium answer it reads today: a Pro caller is refused
with the reason, instead of being allowed to build a chamber whose seat cap of 0 makes every
invitation fail.

### 2.5 The invite code stays, and its fumble is fixed

**Codes survive.** The email-bound alternative (the owner types an associate's address and the seat
claims itself) was considered and **rejected**, because its only credential would be control of a
mailbox: a mistyped address would hand a seat to a stranger with nothing that could ever be
unsent, the invited person would have to register with exactly that address, and the firm would
hold the address of somebody who never consented. A code is a deliberate out-of-band secret, its
plaintext exists only in the owner's hands and the invite row, and it is single-use.

**What is fixed is the fumble.** Today `join_firm` consumes the code when the redeemer is *already
a member* of that firm, so a member who re-enters their own code burns the owner's invite and must
ask for another. The rule becomes:

- the redemption still returns `already_member`, so the member is told the truth rather than an
  error;
- the code is **retired as revoked** (never as `used_by`), so it is dead for a stranger — which was
  the reason the migration consumed it — while the owner's list reads *retired*, not *used by
  [member]*, and the owner is not misled into thinking a new colleague joined;
- the **client never offers the invite field to an account that already has a firm**: the Join
  Existing Firm path is not shown to a signed-in member, which is the cheap half of the fix and
  the one that stops most of these fumbles before they happen.

---

## 3. What a member may do

### 3.1 The defaults

A newly joined associate starts with `can_add = true` and `can_edit = true`, so the chamber's cases,
notes and case references are theirs to work on from the first day, with no per-member setup step
for the owner to remember.

**`can_delete` stays false.** Deletion inside a chamber runs through the delete-request flow, which
this ruling keeps: any member may raise a request for a case, note or reference, and the owner
approves or rejects it (Task 20 Phases 3–4, unchanged). The owner may still narrow add or edit per
member — the toggles remain his.

This **supersedes** the shipped `join_firm` default of `can_edit = false`
(`supabase/migrations/20260929102300_phase3_join_firm.sql`), which inserts
`('associate', can_add => true, can_edit => false, can_delete => false)`.

### 3.2 The chamber's shared config belongs to every member (user ruling — reversed)

The shared reference data — court categories, case categories, courts, steps, case types and
on-behalfs — stays **firm-shared** under `AGENTS.md` rule 10, and **every member may add, edit and
reorder it**. Edit Court/Steps, case types and on-behalfs offer Add, Edit and Reorder to a member
exactly as they do to the owner. The earlier owner-only reading is **withdrawn**, and the reason it
defeats the purpose is the one the user gave: most owners do not touch cases themselves — their
associates do — so a chamber in which one person is the only one allowed to add a new court name or
a new step is a chamber that queues its work behind its busiest person.

Three limits hold it together, and each one already exists or is owed:

- **The built-in baseline is immutable for everyone.** A row with `is_custom = false` is the
  seeded, globally shared list, so no member and no owner may edit, reorder or delete it; a chamber
  that wants a different wording *adds* its own row. Every install reads the same baseline.
- **A reference row a live case still names cannot be deleted** — neither on the device (the
  repositories already refuse it, and the Manage Account tick list relies on the same rule) nor on
  the server, where the guard is **owed**: a tombstoned reference row that a non-deleted case still
  points at cannot be removed at all, because the foreign key refuses it, and the nightly
  `purge_tombstones()` would fail as a whole rather than skip one row. See §10.6.
- **A member's permission still governs it.** `can_edit = false` on a member switches their
  reference edits off with everything else (§3.3), so the owner's control is not lost by this
  reversal — it is only no longer the *only* control.

Member edits to shared config are attributed (`last_modified_by`), sync like any other domain row,
and are visible to the whole chamber. Two members changing the same court at once is an ordinary
conflict, handled by the same banner and rebase flow as a case; nothing about reference rows gets a
private path.

### 3.3 The permission is a boundary, not an intention (user ruling)

The flags are enforced **on the server**, so a modified client, or a direct PostgREST call carrying
a member's own token, cannot name its own permissions. This closes what was open item 1.

- **INSERT** is gated on `can_add`, **UPDATE** on `can_edit`, read from `firm_members` for the
  caller and the row's `firm_id`. **Both halves are new work** (audit correction: an earlier draft
  called the INSERT half already enforced). There is no `can_add_firm` helper beside
  `can_edit_firm` / `can_delete_firm`, and `sync_can_write`'s INSERT branch reads no permission
  flag at all, so a member with `can_add = false` can insert a firm row through the RPC *and*
  straight through PostgREST today. The work is a third helper plus one `BEFORE` trigger per table.
- The shape is the one the delete transition already uses — a **`BEFORE` trigger per table**, not a
  policy rewrite: `cases`, `case_history`, `notes`, `case_references` and the six reference tables,
  one trigger each, reading the caller's `firm_members` row. `can_delete` keeps its existing gate
  (the delete-transition trigger plus the pending delete-request flow) and is not duplicated.
- **A member may not change their own flags.** The `firm_members` write path is owner-only already
  (`20260930210000_sync_can_write_firm_membership.sql`), and the read guard is §4.3's fix.
- **The scope columns belong to the server (audit).** `firm_id` is written **from the caller's
  own firm when the row is created** and never read from a payload, **no client may change it on
  an existing row**, and a caller who holds a firm may not create a firm-less row at all — §1 says
  a chamber holds chamber rows and nothing else, and the shipped guard allows both of the
  opposite. `scope_owner_id` is written by the dissolve (§4.4) and by nothing else. This has to be
  stated because `push_changes` is `SECURITY DEFINER` and so bypasses the column privileges that
  guard direct PostgREST writes: it strips only `server_updated_at`, `version` and
  `last_modified_by` from a payload, which means **any column added later is client-writable
  through the RPC unless it is named there**. Without the rule, one accepted update lets an author
  null their own row's `firm_id` (and set `scope_owner_id` to themselves), which removes the case
  from the chamber's ledger and carries it into their next chamber as their own.
- **Per-member toggles are the only control** — one concept, not two. There is no firm-wide
  read-only switch: the owner who wants a frozen chamber sets every member's `can_add` and
  `can_edit` off, and the owner's own seat is not a special case to design around.

This is why the interface and the server can now agree: `can_edit = false` means the same thing in
the screen and in the database, and the owner's decision survives a client that ignores it.

### 3.4 Authoring versus answering

Attribution does not grant reach either: a member's authored rows are the chamber's on the server,
not a permanent claim. `20260930210000_sync_can_write_firm_membership.sql` already applies that
principle to **writes** (a firm-scoped row may be written by its author only while that firm is
still theirs), and §4.3 applies it to **reads**.

---

## 4. Leaving, removal and dissolution

### 4.1 What removal is

Removal is one act with two halves.

**Owner's side (server).** Membership is revoked, and the member's Realtime topic access and every
firm-scoped read and write end with it, while the revocation is broadcast on both topics so
connected devices act on it at once. (The **auth session itself is not revoked**: this project has
no service-role key, so the device is what ends the session — at the same moment it erases.) The
member's authored rows are **untouched** and stay the firm's, with attribution preserved and never
reassigned. `remove_firm_member` relinks `profiles.firm_id` to null and removes the
`firm_members` row; it does not touch a single domain row.

**Member's side (device).** The device erases itself, **without asking and without waiting** (user
ruling): the next time that phone is opened or gets a connection it runs its **complete wipe
scope** — the same one a logout uses, `BackupRepository.wipeToFreshInstall`, which leaves behind a
fresh install's database including the baseline seed — discards every queued mutation instead of
pushing it, cancels that device's scheduled case notifications, and force-signs out. There is **no
confirmation step**: the earlier design blocked the app behind a notice with an *Erase & sign out*
button, and that is withdrawn, because the erase is the chamber's decision rather than the
phone-holder's, and a copy that waits for a tap is a copy the person holding the phone can keep.
What they see instead is an informational *your access ended* screen saying what has been removed.

**The order is the point:** the erase runs before the device can reach the firm again — before any
pull, any write and any sync — so nothing of the chamber is left on it: no case, no note, no
reference, no roster, no invite, no pending request. The account keeps no link to the firm
whatsoever afterwards, and because its diary is then empty it may join another chamber with the
same account (§2.2).

**How the device knows, with no button to press.** The trigger is the profile: `profiles.firm_id`
becomes null server-side while this account still held a firm — the one direction the two can
disagree, and the reason the check reads the profile rather than the membership row. Detection
therefore does **not** depend on a `firm_members` row having been cached: a member whose device
never pulled its own membership row is erased just the same. It is durable, so a phone removed
while offline erases at its next launch once the profile pull lands; until that pull lands the app
cannot know, and the block is what covers the window. The comparison needs durable local evidence
rather than a memory: the **cached firm row** — pulled while the account was a member and removed
only by the wipe that has not run yet — or an explicit *had a firm* marker written the first time
a profile arrives with a `firm_id`. The `firm_members` row is a useful second signal and not the
trigger, because a device may never have pulled one and the wipe clears it first.

**The honest limit, and the warning the owner now gets (user ruling).** A device that never comes
back online is the one case the server cannot reach: the removal is immediate server-side and the
chamber's rows are unreachable from that device, but its **local copy can only be erased the first
time it is opened**, because nothing can reach a phone that is off. The removal confirmation
therefore states that limit in plain words and tells the owner what to do about it:

- it says that the associate's phone keeps a copy of the chamber until that phone next opens the
  app, and that the copy is erased then, on its own;
- it advises the owner to have the associate **open the app once, while they are still together
  and connected**, before or just after the removal, so the wipe runs while someone can see it;
- it says plainly that for a phone that will never be opened again the only way to clear it is the
  device's own means — a factory reset, or the platform's remote-wipe/locate feature — because no
  app can erase a device that is off;
- and it reassures the owner about the part that is safe: the chamber's rows on the server are
  untouched and are attributed, so nothing of the firm is lost or hidden by the removal either way.

The same limit is shown to the removed member on the screen that tells them their access ended, so
the person holding the phone is told **what has been erased** and why — the notice reports the
erase rather than announcing one, which is what the no-confirmation ruling above means.

**Offline work still pending there is discarded rather than synced**, deliberately: it belongs to a
chamber the member has already left.

### 4.2 Removal is not the only way a member leaves

| Way out | Server | Device |
|---|---|---|
| Owner removes the member | membership and topic access revoked (**the auth session itself is not revoked** — §4.1 — the device ends it when it erases); revocation broadcast | complete wipe, queued work discarded, notifications cancelled, forced sign-out, with the §4.1 warning to the owner |
| Member signs out | session ends (`device_tokens` row removed while the session still exists) | complete wipe; the member gets **no** safety copy (§6) |
| Member switches account on the device | the arriving account is adopted | complete wipe before adoption (`backup_restore_and_free_tier_gating` territory: §6's account-switch rule) |
| Member's account is deleted | `delete_my_account()` **refuses a firm account** — the account must be removed from the firm first | — |
| The owner dissolves the chamber | every remaining member is removed first, then the firm's rows are unscoped **and given the owner as their scope owner** (§4.4) | each member's device wipes exactly as in row 1 |

**One row this table leaves behind (audit).** A removal deletes no `device_tokens` row —
`remove_firm_member` touches none — so a removed member's device keeps its push registration, while
the sign-out row above is the only path that clears it. Nothing reaches such a device today (the
only server push is the admin payment alert, which needs `app_admins`), but the rule is stated
rather than implied: a removal takes that token with it as soon as the device is reachable again,
and no firm notification may be routed to it in the meantime.

### 4.3 The wipe is only half, and the server still hands those rows back

**What is true today.** The read policies still treat a firm-scoped row as its author's:

- `cases_select_scoped`, `case_history_select_scoped`, `notes_select_scoped` and
  `case_references_select_scoped` read
  `user_id = auth.uid() or firm_id = current_firm_id()` (`20260929103000_phase4_rls_core_tables.sql`);
- the six reference tables' `*_select_scoped` read
  `is_custom = false or user_id = auth.uid() or firm_id = current_firm_id()`
  (`20260929103100_phase4_rls_reference_tables.sql`);
- `conflict_log_select_own` reads `user_id = auth.uid()` with no membership condition at all.

Attribution is immutable, so `user_id = auth.uid()` **alone** still selects every row that member
ever wrote in the chamber they left. `current_firm_id()` going null only falsifies the *second*
disjunct.

**Why it was missed.** `20260930210000_sync_can_write_firm_membership.sql` and
`20260930220000_rls_firm_membership.sql` closed exactly this hole for **writes** and left **reads**
alone, on the stated belief that *"a caller with no firm already reads nothing from a firm row"*.
That is true of the `firm_id = current_firm_id()` half and **false of the `user_id = auth.uid()`
half standing beside it under `or`**.

**The leak chain, step by step.**

1. A member is removed; their device wipes and the account is now an individual with an empty diary.
2. That account signs in again on the same device, and at some later point it is premium once more —
   on a plan of its own, or on a seat in another chamber.
3. The engine runs. Because the removal wipe left a **fresh local database**, the per-table cursors
   sit at the initial sentinel, so that pull is a **full** one, table by table.
4. The sync layer carries no firm filter of its own — `firm_id` appears in it only in the push
   payload (`push_worker.dart`) and the Realtime topic — so RLS decides, and it returns every row
   that account authored in the chamber it left.
5. Those rows land in the local ledger, where local reads do not filter by firm: the old chamber's
   cases, notes and references appear inside the new diary or the new chamber. Under §2.1's
   `firm_id IS NULL` definition they do not even block a later join.
6. Any attempt to edit one is then refused by the write guard (`sync_can_write` requires the row's
   firm to be the caller's), which surfaces as conflict noise rather than a clear message.

**The fix.** Scope the read policies the way the write path already is, and give an unscoped row a
scope owner while you are there — the audit's second half, ruled in §4.4:

```
(user_id = auth.uid() and firm_id is null and scope_owner_id is null)
  or firm_id = current_firm_id()
  or scope_owner_id = auth.uid()
```

on the **eleven ledger tables** (`cases`, `case_history`, `notes`, `case_references`, the six
reference tables and `delete_requests`), keeping `is_custom = false` for the reference tables'
seeded rows; in `delete_requests` the author column is `requested_by`, not `user_id`, so the
condition is copied with that name. Two tables need something narrower, and the first pass got
this wrong: `conflict_log` is **not** a ledger table — its rows are a device's own merge
diagnostics — so its select needs only the membership condition
(`user_id = auth.uid() and (firm_id is null or firm_id is not distinct from current_firm_id())`)
and it takes **no** scope owner; and `delete_requests` needs the clause precisely because its
select is firm-only with no author at all, so without it a dissolved chamber's request history
becomes unreadable to everyone, the member who raised it included. The
equivalent SQL for the write path uses `is not distinct from`; on the read side plain equality is
equivalent, because a null on either side is already not true.

**One consequence to hold elsewhere.** A chamber's rows are readable only while that chamber is
still the caller's, so **dissolving** a chamber must null its rows' `firm_id` *and* write the owner
as their scope owner. A bare null is not enough, as the audit showed: the owner would then keep
only the rows he authored himself while the members kept the rest. Clearing
`profiles.firm_id` alone, the third option, would lose the ledger from every side. That is §4.4.

### 4.4 How a chamber is dissolved (user ruling)

**The owner empties the roster first, then dissolves.** The order is deliberate: every leaving
member goes through the one removal path that already exists (§4.1), so each of their devices wipes
on its own, each revocation is broadcast, and nothing about the chamber is left on a phone that
nobody has agreed to abandon. A dissolve that auto-removed the roster would create a second,
untested removal path — and the one thing a removal must never do is surprise a member.

The rules, in the order the server does them:

1. **The owner must remove every member**, associates and viewers alike, until only the owner's own
   seat is left. The dissolve action is unavailable while the roster holds anyone else, and it says
   how many are left rather than only refusing.
2. **Open invites are retired** (`revoked = true`), so a code issued before the dissolve can never
   create a seat in a chamber that no longer exists. The invite rows themselves leave with the
   `firms` row in step 4 — the foreign key cascades — so no retired orphan is left pointing at a
   chamber that is gone.
3. **The chamber's rows are unscoped, and given a scope owner**: every row carrying that `firm_id`
   — cases, case histories, notes, case references, delete requests and the customised seed rows —
   has `firm_id` set to null **and `scope_owner_id` set to the owner's id**, so the owner keeps a
   complete, ordinary, offline diary. (`conflict_log` is the one exception, and deliberately: a
   colleague's merge diagnostics are not the owner's ledger, so the dissolve neither hands them to
   him nor takes them from their author — §4.3 gives that table the membership condition only.) This is the consequence §4.3 records,
   and it is why the ledger is not deleted: the owner built it.
   The scope owner is what makes that true rather than aspirational, and the audit is why it is
   there: with `firm_id` merely nulled, the read policy's first condition (`user_id = auth.uid()`
   on a firm-less row) would hand every member-authored row back to its author and hide it from the
   owner — the opposite of what a dissolve is for, since under §3.2 the associates write most of a
   chamber's cases. `scope_owner_id` is a **scope** key, not an attribution one: `user_id`,
   `created_by` and `last_modified_by` are **not** rewritten, so the rows still say who wrote them
   and the *edited by [Name]* rendering is unaffected. It also settles §2.1 — a dissolved chamber's
   rows never count as their authors' own diary — so a former member may still join another chamber
   with the same account (§2.2).
4. **The `firms` row and the owner's `firm_members` row are removed**, the owner's `profiles.role`
   returns to `individual`, and `firm_id` on the owner's profile is nulled — so the account is
   individual again and `delete_my_account()` is no longer refused. Its rows are already its own.
5. **The owner's plan is untouched.** Dissolving is not a cancellation: the subscription runs to its
   own expiry and now covers the individual diary. Nothing about the lapse rules changes.

Two limits worth stating. First, the unscoped rows stay subject to the ordinary free/premium rules,
so a dissolved chamber whose owner lapses is treated exactly like any other lapsed individual —
§5.2's ceilings, and no re-imposition of anything the plan already promises. Second, **dissolution
is not reversible by the app**: re-creating a chamber is a new chamber with a new `firm_id`, and the
rows must be shared into it the way any existing diary is at creation (§1), because the old
chamber's membership, invites and roster are gone.

---

## 5. Plan, entitlement and gating

### 5.1 Entitlement is derived, and a member's entitlement is the firm's

- **Firm mode is premium.** A free account has no online sync at all — sync is a premium feature
  from the first day — so it can never be in a chamber: creating one is refused server-side, and
  joining one is the only other way in.
- **Entitlement is one derivation, never a stored flag:** `subscription_expiry + 48h grace > now`,
  computed in `lib/features/settings/data/premium_access.dart`, in RLS and in `push_changes`.
- **An associate's entitlement is the firm's, and a member may not buy their own** (user ruling,
  closing the audit's finding here): a member needs no plan of their own, and while the owner's
  subscription is live the member syncs on it — the same mirrored `firms.subscription_expiry` every
  gate already reads. **A member cannot buy a personal plan**: the app does not offer Subscription
  Plans to an account that holds a firm, and the server refuses the submission itself, because a
  screen was never the boundary. Both halves are work with a named site (audit): the side menu's
  **Current Plan** row expands into Subscription Plans, so that row — not only the Subscription
  screen — has to drop the entry for a member, and `payment_submissions_insert_own` is
  `with check (user_id = auth.uid())` today, so refusing the submission is a policy change and not
  a client check. That matters because the state is reachable today —
  `profiles.subscription_expiry` is not cleared when someone joins, so an account that bought Pro
  and then joined with an empty diary keeps a live expiry, and the server's gate is currently *my
  own expiry **or** the firm's*: while the owner was lapsed, that member kept pushing and §5.2's
  ceilings had no server gate behind them for that one account. **While the account holds a firm,
  only the firm's expiry counts.** Paid time is preserved rather than destroyed: it is ignored in a
  chamber and applies again the day they are individual. When the firm lapses, the member lapses
  with it — §5.2's ceilings apply to the whole chamber.

### 5.2 What a lapsed account may still write (user ruling)

Lapsing never deletes, hides or re-reads a row — but it does **cap what can be written**, and this is
new. The rule:

- **A free account that has never been premium** keeps the wall it has today: 50 live cases, and no
  ceiling on notes, case references or seed customisation. Nothing here changes for it.
- **A lapsed account — individual or chamber — may keep writing locally** while it holds fewer
  than the **lapse allowance of the tier it last held**: **Pro 100, Firm 500, Firm Plus 1,000**
  cases, and the same number of notes and case references. *The tier it last held* is read from
  the account's stored tier — `profiles.tier`, or a chamber's `firms.tier` — which is why that
  column exists (§5.3); nothing else records it, and approaching it from the plan the account
  bought would misread a chamber that was downgraded before it lapsed. Seed customisation is unlimited: a court
  name, step or case type is not the product, and a chamber that cannot add a new court cannot work
  at all — which is exactly the §3.2 ruling, applied to a lapse. Scaling the allowance with the tier
  is deliberate: a flat 100 would reduce a 20-lawyer chamber holding 6,000 cases to 100 editable
  cases overnight, which buys churn rather than renewal, and would punish exactly the customer the
  lapse was meant to win back.
- **Beyond the allowance, the excess is read-only.** An account that lapsed holding 2,500 cases
  loses none of them: it can open, search, print and export every one, and it can **edit** the
  allowance's worth — the most recently updated rows — while the rest waits for renewal. The remainder is read-only until renewal, and **deleting a writable row
  frees a slot**, so the ceiling is a reason to renew rather than a trap. The writable set is the
  **most recently updated** rows of that kind — the allowance taken in the user's own working order,
  `updated_at` descending with `id` as the tie-break — so the cases a lawyer is actually on stay
  editable and the archive is what goes read-only. It is derived from the ledger on the device, so it
  needs no server call, nothing is stored, and each device computes the set from its own ledger —
  while lapsed nothing syncs, so two devices of one chamber can disagree about which rows are
  inside the allowance until they next meet; on renewal the read-only set evaporates for all of
  them, over-allowance backlog and all (§5.4).
- **Children follow their parent.** A note or a case reference attached to a read-only case is
  read-only too, and no new note can be added to a case that is over the allowance; the allowance's
  own note and reference ceilings then apply in their own right to everything else.
- **Nothing is ever deleted, hidden or unreadable**, and **renewal returns the whole ledger at
  once**: the read-only set evaporates on the false→true entitlement transition, which is also the
  moment the delta pull and the queued backlog run.
- **This is a local rule and it says so.** While lapsed the engine cannot push anything anyway, so
  the cap is enforced on the device; it is UX, like the rest of the derived-entitlement checks, and
  the server's own gate (entitlement on `push_changes`) remains the security boundary. **That is
  now exactly true, and §5.1 is why**: a member's own expiry is ignored while they hold a firm and
  a member cannot buy one, so nobody in a lapsed chamber has an entitlement of their own to push
  on. The audit found the gate was *own expiry **or** the firm's*, which left precisely that hole.
- **Where the allowance has to be enforced, so it is not a rule without a site (audit).** The
  shipped gate is `freeTierCaseLimit` (50) in the Add Case save path, applied whenever the account
  is not premium — so a lapsed Pro or Firm account would be stopped at **50** cases, not its
  allowance, until that check is replaced by the allowance itself; and notes and case references
  have **no** gate anywhere today, so their ceilings are two new checks rather than a tightened
  existing one. A member's allowance is the chamber's, so the same site must read `firms.tier`
  rather than the member's own (absent) plan.

**The allowance is a ceiling on writing, never on reading, and it is per item rather than a hidden
row.** Searching, opening, printing and exporting ignore it entirely: a lapsed chamber can still
hand a client a printed cause list of all 2,500 of its cases, every row is still found by a search,
and the only thing the lapse changes is which of them can be edited.

### 5.3 The tier ladder (user ruling)

| Tier | Price | Case ceiling | Seats | What it adds |
|---|---|---|---|---|
| **Free** | ৳0 | 50 | — (strictly individual) | the offline diary: cases, notes, references, seed customisation, offline backup & restore |
| **Pro** | ৳100/month · ৳1,000/year | 1,000 | — (one account) | disaster recovery, real-time cloud backup, multi-device |
| **Firm** | ৳300/month · ৳3,000/year | 2,500 | up to 5 associates | everything in Pro, plus collaboration |
| **Firm Plus** | ৳600/month · ৳6,000/year | 6,000 | up to 20 associates | everything in Firm, plus the larger roster |
| **Unlimited** | by quotation (indicative ৳1,200/month) | above 6,000 | unlimited | Firm Plus, with agreed support and terms |

**Durations, as flat prices (user ruling).** Ten plans in all, and **no percentage-discount story**:
Pro sells **1, 3, 6 and 12 months at ৳100 / ৳285 / ৳540 / ৳1,000**, and Firm and Firm Plus sell
**3, 6 and 12 months** — a chamber does not buy a month — at **৳855 / ৳1,620 / ৳3,000** and
**৳1,710 / ৳3,240 / ৳6,000**. Each is simply its price. Pro's annual therefore **changes** from the
৳960 the app ships today to **৳1,000**, a `plan_type` constant change and a migration rather than a
code change, and the plans screen is being rebuilt to this set. Annual is the plan to lead with,
because at this price point prepayment is the economics: cash in hand today, eleven fewer renewal
failures a year, and one payment-gateway fee instead of twelve.

**What a plan actually costs to add (audit correction).** An earlier draft said "each plan is one
row in `payment_plans`"; **there is no `payment_plans` table**. The ladder lives as constants
inside `approve_payment`, keyed by `plan_type`, with the readable name a **generated** column
derived from those keys. One new plan therefore touches four server places and is a migration, not
a code change: the accepted `plan_type` keys, the amount its `approve_payment` CASE validates, the
interval it extends by, and the generated name's CASE — plus the client's paywall labels and
checkout, which read the same keys. Ten plans is the ceiling that keeps that list short.

**The tier and its seats are stored, not implied (user ruling).** Two quantities the ladder depends
on have nowhere to live today: *which tier* the account holds — so §5.2's allowance of the tier
last held can still be derived after a lapse — and *how many seats* it bought, so §5.4's join-time
cap has a source. Both become columns: **`profiles.tier`** for an individual and **`firms.tier`**
for a chamber, written at approval and **never cleared by expiry** (it is the record of the last
tier held), with the seat cap read from the same value — Pro 0, Firm 5, Firm Plus 20, Unlimited by
agreement. **The write path is two steps, and the second is easy to miss** (audit):
`approve_payment` writes the **profile**, and the firm's copy moves only because
`mirror_owner_subscription_to_firm()` copies it — a trigger that fires *on `subscription_expiry`
changes only* and copies two columns. `tier` therefore needs the same mirror, with the trigger's
`of` list and its `when` widened to cover it, or a chamber's tier would never move and the seat
cap would keep reading the tier before it. Client writes are closed on both tables by
construction rather than by luck: the column privileges **deny by default any column a later
migration adds** (`20260929102500_phase3_column_privileges.sql` grants `update (full_name)` on
`profiles` and `update (name)` on `firms`), so `tier` is unwritable until someone deliberately
grants it — which nobody will. **A downgrade adds two more values beside it** (§5.4): the tier in
force cannot be overwritten mid-term, so a lower-tier purchase writes `tier_pending` and
`tier_pending_from`, and every reader — the seat cap in `join_firm`, the lapse allowance, the
Subscription screen — takes the **effective** tier rather than the column as stored. `join_firm` reads it and refuses a join that would exceed the
cap, which is new: the shipped `join_firm` inserts a membership with no seat check of any kind.
**Creating a chamber needs Firm or above** (user ruling): Pro's cap is 0, so the creation gate
belongs with the cap rather than with a bare premium check, and a Pro owner is told to upgrade
before the chamber exists rather than after a colleague cannot be invited.

**Why the chamber tiers cost ৳300 and ৳600 rather than ৳200 and ৳300.** The value a chamber buys is
the **seats**, not the cases: a case is text and stores for almost nothing, while a seat costs
Realtime fan-out, egress, support and risk. The nearest Bangladesh competitor charges about
৳125–149 **per user per month** (Court Diary BD, promo rate), so pricing 20 associates at ৳200 for
the chamber is ৳10 a seat — an order of magnitude below the market, at precisely the tier where
willingness to pay is highest, and a price a later raise can never recover from. At ৳300 for five
associates (৳60 a seat) and ৳600 for twenty (৳30 a seat) the chamber is still the cheapest
collaboration offer in the market while the product is paid what it is worth. The case ceilings stay
as the **cloud-storage guard** they always were — an anti-abuse number, not the headline — and the
headline is collaboration, real-time backup, disaster recovery and multi-device.

**Free stays exactly as it is.** 50 live cases, offline only, free backup and full seed
customisation. It costs nothing server-side (a free account never syncs) and it is the funnel: the
50-case wall is what opens the paywall, and its generosity is what makes the app the default
recommendation between colleagues.

### 5.4 Upgrade, downgrade and lapse, as one rule set

- **Upgrading is immediate** on approval, and the new ceiling applies at once; rows already stored
  are never touched by a ceiling that grows.
- **A downgrade never removes data.** Only the *new additions* are capped at the lower tier; every
  row already stored stays readable, searchable, printable and exportable, and the excess becomes
  read-only exactly as §5.2 describes (the industry pattern: keep the items, block new ones —
  Airtable, Google Drive and monday.com all behave this way).
- **A downgrade takes effect at the next renewal**, never mid-term, so a user who has paid for
  6,000 cases keeps 6,000 until the period they paid for ends. **User ruling, with the mechanism
  it needs:** a Firm Plus owner who buys Firm mid-term keeps Firm Plus until the paid period ends
  and is on Firm from the day the next period begins. Nothing runs at the moment a period turns
  over, so one stored value cannot express it — the purchase writes a **pending tier and the
  instant it starts** beside the tier in force, and every gate derives which applies now
  (`pending once its instant has passed, else the tier in force`). The purchase still extends
  `subscription_expiry` by `greatest(now, expiry) + duration`, so paid time is never lost.
- **A lapse falls back to the allowance of the tier last held, never to Free** (§5.2): a lapsed Pro
  keeps writing 100 cases, notes and references, a lapsed Firm 500, a lapsed Firm Plus 1,000. Renewal
  restores the tier's own ceiling at once, and a *higher* tier bought later restores it immediately.
- **A seat cap binds new joins only.** If a Firm Plus chamber holding 30 members drops to Firm
  (20), **nobody is auto-removed** — a removal is a destructive, broadcast act that must never be a
  billing side effect — the owner is told to trim the roster, and the extra members keep working
  read-write until the owner acts. (Seat caps are checked at join time from `firms.tier` — §5.3 —
  and a refusal names the cap and how many seats are in use.)
- **Types never change silently.** A plan's `subscription_expiry` is extended by
  `greatest(now, expiry) + duration`, so buying while entitled stacks rather than restarting, and the
  tier that applies is the one **in force** — a higher tier the moment it is bought, a lower one
  only when the period it was bought for begins (the pending pair above, and §5.3).

### 5.5 Retention and the recovery window (user ruling)

**Tombstones are kept 365 days, and the recovery window is 335.** The pair moves together so the
30-day buffer the plan chose is preserved: a device that comes back inside 335 days still finds
every tombstone it needs, and one that has been away longer is rebuilt rather than trusted. The
consequences:

- `purge_tombstones()`'s default retention becomes **365** (the scheduled job keeps calling it with
  no argument, so the number lives in one place);
- `recoveryOfflineThreshold` in `lib/sync/recovery_lock.dart` becomes **335 days** — the lock stays
  **firm-mode only** and never reads entitlement, exactly as the plan's own ruling says;
- the plan's rule for `mutation_receipts` — *"at least the maximum supported offline window plus a
  retry buffer"*, 210 days today — must read **at least 400 days** to stay true. No job purges
  receipts (they are only removed with the account), so this is a documented invariant to correct
  rather than a schedule to change — and nothing enforces it, so the corrected number belongs where
  a later cleanup job will meet it rather than in one plan sentence;
- **a longer offline window means a longer pull, not a bigger one**: the delta pull is cursor-paged
  per table, so a device away for 300 days makes a long succession of small pages;
- the **privacy policy's** retention row is still a `[TO CONFIRM]` placeholder
  (`docs/legal/privacy_policy_EN.md`), and it now needs the real numbers — a tombstone holds no case
  content (an id, a flag and two timestamps), but the row should say so rather than leave a reader
  guessing;
- the device-local purge (a tombstone is dropped locally only once the server has acknowledged it
  and it is 90 days old) is **unchanged and still safe**: the server, not the device, is what
  remembers a deletion for the recovery window.
- **The restore exception in §6 moves with it**: a stale restored row can be corrected by a server
  tombstone for **365** days instead of 180;
- **the number lives in four places, not one** (audit): the migration's header comment and the
  function's `comment on function` still say 180, `recovery_lock.dart`'s doc block states 180/150
  twice above its constant, and the **generated** ledger carries it in a section label
  (`tool/generate_all_supabase_sql.dart`, *purge_tombstones(180 days) …*) that
  `dart run tool/generate_all_supabase_sql.dart --check` and
  `test/supabase/all_supabase_sql_test.dart` police. A 365-day change is therefore four edits plus
  a regeneration, and a migration alone fails the check.

### 5.6 How a subscription is sold — direct distribution, for now (user ruling)

**The app is distributed directly and not through Google Play for now.** The project's own APK,
delivered by the in-app updater that already reads its own GitHub releases, stays the only channel
until the user has tested the product and gathered feedback; Play is a later decision, not a
rejected one.

Three facts make this more than a distribution preference, and they are why the decision is
recorded here rather than left to Task 21:

- **Play requires Play Billing for an in-app digital subscription**, and it forbids steering an
  in-app user to another payment method through buttons, links or messaging. Bangladesh is in **no**
  alternative-billing or user-choice-billing programme, so there is no local exemption to enrol in.
- **A Play-distributed app may not update itself by any method other than Google Play's update
  mechanism** (`Device and Network Abuse` policy). "The user tapped Android's installer" does not
  create an exception.
- Therefore the two mechanisms this app is built around — the manual MFS flow
  (bKash/Nagad/Rocket → TrxID → `payment_submissions` → Admin Panel approval) and the GitHub-APK
  self-updater — are **compliant only while the app is not on Play**, and direct distribution makes
  both correct and keeps 100 % of the revenue instead of 85 %.

**What direct distribution makes load-bearing.** (1) The in-app updater is now the **only** way an
update reaches a user: its release naming, size verification, `FileProvider` grant and per-resolver
URI permission are critical infrastructure, and a broken update path strands the whole user base
with no store to fall back on. **Authenticity is part of that infrastructure** (audit): with no
store review in the path, the app is what installs the file, so it has to be able to tell a release
of ours from anything else — a signed release, or a checksum pinned in the app — because the
release feed is otherwise a direct route into every installed diary. (2) Installs become the marketing problem: the APK needs a reachable
download page, a stated owner, and install instructions that survive Android's unknown-sources
prompt, so the readme and the site are part of the product. (3) The manual MFS flow stays exactly as
built — `approve_payment`'s per-plan amount validation, the rate limit, the Admin Panel — and its
zero-commission economics should be named in the pitch, because it is a real advantage over any
competitor shipping through Play. (4) If Play is adopted later, the Play build must switch to Play
Billing **and** drop the self-updater, so it becomes a **build flavour**, not a code change, and the
15 % comes off margin rather than being added to the customer's price.

---

## 6. Backup and restore inside a chamber

**Restore is barred whenever firm mode is on, the owner included.** A backup file is a photograph of
the ledger taken at one moment, and putting it back over a chamber re-introduces rows other members
may have changed or deleted since, silently undoing their work.

**The single exception is a completely empty device** — a fresh install, or the state a wipe leaves
— where there is nothing to overwrite. Even there it is not a merge: the full pull a fresh install
performs brings the chamber's rows, and every tombstone the server still holds, over the restored
ones, so a deletion from within the last **365** days corrects a stale restored row (§5.5). A server
row already purged past that window cannot correct one, **which is the accepted ceiling of this
exception**.

**What restore may write in that exception (user ruling).** `profiles`, `firms` and `firm_members`
are **never restored**: they are pull-only caches (rule 4), they belong to the server, and a stale
`firm_id` in them is precisely what trips the removal path — a restored profile naming a dead firm
beside a restored membership row is the removal check's own condition, so a restore could erase the
diary it had just written. The account's rows come from the pull instead. A restored **row's** scope
is settled rather than inherited: each restored row is stamped with the current chamber's `firm_id`
and has its `scope_owner_id` cleared, so it belongs to the chamber like every other row of it, and a
file whose rows name **another firm** is refused outright, because
such a row can neither be pushed (`sync_can_write` refuses a firm that is not the caller's) nor
read back from the server, which would make it permanent local-only data. `user_id`, `created_by`
and `last_modified_by` are **not** stamped either: attribution is not the restorer's to rewrite
(§4.4). The one case where the restoring account is written in is the existing ownership rule's own
— an owner column that names nobody at all, which is a hand-filled workbook (the first pass said
"and the restoring account" without that limit, which would have rewritten attribution). The full
pull then runs over the restored rows exactly as described above.

**A member is offered no backup at all (user ruling)** — neither **Back Up** nor **Restore**, in
Settings > Backup & Restore or on the way out. When removed, when signing out, and when switching
account, there is no *Backup Data to Local Storage* window and no passphrase prompt; instead a plain
warning names what is being discarded and, when there is a connection, that the sync should be
allowed to finish first. A blocking *Syncing to Cloud* screen shows that the sync is in progress.
The reason the export goes too is the one that decides it: a member who can export holds the
chamber's whole ledger — its clients, its cases, its history — in a file they can keep, which is
the firm's asset rather than theirs, and the member's own work is theirs to see for as long as they
are in the chamber. Only the owner keeps both actions.

This **supersedes the safety-copy offer in Sync Plan §5 for firm accounts only**: an individual
account's logout flow keeps the offer it has.

---

## 7. What is shared and what is personal

**Shared with every member of the chamber:** cases and their case histories, notes, case
references, and seed data including the customised seed data — court categories, case categories,
court names, steps, case types and on-behalfs.

**Never shared, always personal to the account that set it:** the Settings entries for
**notifications, language and view** — notification time and day offset, the master notification
toggles, the app language, the bottom-navigation tabs, the side-menu rows, the default landing page
and the case-list display mode — together with every other per-user setting such as the backup nudge
and the app lock.

This is `AGENTS.md` rule 10 said plainly, with the shared half named, and it is held by the table
classes rather than by discipline: the first group are push/pull domain tables, the second are
per-user preference rows that are never written to a firm topic.

**The whole list, so rule 4 is answerable from this file (audit).** *Push/pull domain* — `cases`,
`case_history`, `notes`, `case_references`, the six reference tables, `delete_requests`
(firm-scoped: its select policy has no author clause, which is why §4.3 has to add the scope
condition) and `conflict_log` (the one domain table whose rows are per-device rather than per-firm,
which is why its policies carry no `can_edit_firm` disjunct). *Per-user preference* —
`user_preferences`, `case_notification_preferences`. *Pull-only cache*, never the device's to own
and never restored (§6) — `profiles`, `firms`, `firm_members`. *Server-managed* — `firm_invites`,
`payment_submissions`, `payment_approval_events`, `device_tokens`, `app_admins`, `invite_attempts`,
`mutation_receipts`. *Local operational, never synced* — `sync_queue`, `sync_metadata`,
`seed_migrations`.

---

## 8. Edge cases, and what each one resolves to

| Case | Resolution |
|---|---|
| An individual with 30 cases redeems an invite | Refused, with the §2.1 wording. The account stays personal; a second, empty account joins. |
| A member fumbles their own code after already joining | `already_member`, the code is retired as revoked rather than consumed as used, and the Join Existing Firm path is not offered to an account that already has a firm (§2.5). |
| A member's authorised device was wiped but the server removal has not been seen yet | The revocation is broadcast, and the device wipes on its next launch or connectivity before any sync, pull or write runs. |
| Removed member's device never comes back online | Server side is immediate; the local copy is erased the first time that device is opened, and the owner is warned of exactly this in the removal confirmation, told to have the associate open the app while they can, and told that only a factory reset or a platform remote wipe clears a phone that is never opened again (§4.1). |
| Removed member rejoins a different chamber | Allowed, same account, because their diary is empty and their old chamber rows are not theirs (§2.2, §4.3). |
| Member's work was still queued at removal | Discarded, never pushed, deliberately (§4.1). |
| Member's scheduled case notifications | Cancelled on the device as part of the wipe (§4.1). |
| A member adds, edits or reorders a shared court, step or case type | Allowed and attributed, visible to the whole chamber; the built-in baseline (`is_custom = false`) is immutable for members and owner alike (§3.2). |
| Two members edit the same shared reference row at once | An ordinary conflict: the same banner and rebase flow as a case, because reference rows have no private path (§3.2). |
| A member deletes a custom reference row a live case still names | Refused on the device (already) and on the server (owed, §10.6) — a tombstoned row a live case points at would make `purge_tombstones()` fail as a whole. |
| A member whose `can_edit` is false edits anything | Refused by the server, not merely hidden in the interface (§3.3). |
| The owner wants to dissolve a chamber while it has members | Refused until the roster is empty; the owner removes each member first, then dissolves (§4.4). |
| Dissolving a chamber that still holds cases | `firm_id` is nulled and the owner becomes the rows' **scope owner**, so they become his personal diary and stay readable to him; attribution is untouched and nothing is deleted (§4.3, §4.4). |
| Owner wants to delete their account while the chamber has members | `delete_my_account()` refuses a firm account; the owner must finish with the chamber first. |
| Owner wants to delete their account after dissolving | Allowed once `profiles.firm_id` is null and no `firms` row is owned. |
| Owner's plan lapses while a member is joining | Join succeeds; local-only until renewal (§2.4), with §5.2's ceilings applying to the chamber. |
| Owner's plan lapses while a member is working | Local-only until renewal; writes continue up to the allowance of the tier last held (Pro 100, Firm 500, Firm Plus 1,000); beyond it the most recently updated rows stay writable and the rest are read-only; nothing deleted; the plan's own banner (§5.2). |
| A chamber that last held Firm lapses holding 2,500 cases | Its 500 most recently updated cases stay writable; the other 2,000 stay readable, searchable, printable and exportable but read-only until renewal, and deleting a writable row frees a slot (§5.2). |
| A lapsed chamber is asked for a printed cause list of everything | Never capped: the read path ignores the allowance entirely, and only add and edit are limited (§5.2). |
| A chamber buys Firm after holding Firm Plus and lapses later | The last tier held decides the allowance, so its 20 seats and 6,000-case ceiling were what it lost, not the Firm one it never held (§5.4). |
| A firm owner lapses and renews a week later | Everything the members wrote meanwhile is queued; the false→true transition pulls the delta and pushes the backlog, and the read-only set disappears at once (§5.2). |
| A device has been offline 335+ days in a chamber | The extended-offline recovery lock applies (firm mode only), now at 335 days under the 365-day tombstone retention (§5.5). |
| A Firm Plus chamber with 30 members downgrades to Firm | Nobody is auto-removed; the 20-seat cap binds new joins and the owner is told to trim the roster (§5.4). |
| A member tries to buy a plan of their own | Refused: Subscription Plans is not offered to an account that holds a firm, and the server refuses the submission itself. A plan bought before joining is ignored while they hold the firm and applies again once they are individual (§5.1). |
| A dissolved chamber's rows | The owner keeps the whole ledger: the rows lose their `firm_id` and gain the owner as their **scope owner**, so they stay readable to him and stop being readable to their authors, whose attribution is untouched (§4.4). |
| An owner restores an old file onto the blank phone | The file's rows are stamped into the current chamber and the file's account rows are ignored; a file naming another firm is refused (§6). |
| Two chambers at once | Impossible: one `profiles.firm_id` is the only membership that scopes anything. |

---

## 9. Order of work

1. **Chamber creation shares the owner's existing diary** and stamps it with the new `firm_id`, and
   the write path carries that scope. Without this, firm mode is inert: a chamber account's rows
   would not carry the scope the reads and the Realtime topic need.
2. **The join refusal**, with the `firm_id IS NULL` **and no scope owner** definition of *its own
   diary* its companion, and the §2.5 invite fix beside it (the retire-as-revoked path and the
   client never offering the field to an existing member).
3. **The removal wipe, its no-backup rule and the §4.1 owner warning** — without the wipe a removed
   member keeps the ledger; without the warning the owner cannot know which phone still holds it.
   **It ships no earlier than step 2** (audit): a self-erasing device is only safe once the join
   refusal guarantees the seat was empty. Until `join_firm` refuses a caller who holds individual
   rows, an account that kept a diary and joined anyway would have that diary erased, with no
   backup (§6 gives a member none) and no confirmation step left to warn the person.
4. **The read-side scoping** of §4.3, which is what makes step 3 stick.
5. **The permission boundary** of §3.3 (`can_add` on INSERT, `can_edit` on UPDATE, per table) — the
   user's decision that members write by default makes this load-bearing: a revocation that is not
   enforced is worse than no toggle at all. **Both halves are new work, not one** (audit): no
   `can_add_firm` helper exists and no INSERT path reads the flag today, so nothing enforces
   `can_add` on the server at all.
6. **The server-side in-use guard** for reference rows (§10.6), so a member's edit or delete of the
   shared config can never break the nightly purge.
7. **The lapse ceilings and the read-only-over-the-allowance rule** (§5.2), which read the settled
   tier ladder (§5.3) because both the allowance and its scaling come from it. **The stored tier
   column comes first** — `profiles.tier` / `firms.tier` written at approval — because the allowance
   is derived from it and from nothing else.
8. **Dissolution** (§4.4), including the roster-empty precondition and the unscoping step **with
   its scope owner**: without the scope owner, the dissolve hands the chamber's rows to their
   authors and hides them from the owner.
9. **Attribution in the UI** — who added a row, who last changed it — and the owner's roster, which
   are readability rather than correctness.

A per-row "only me" scope is **not** on this list and is not planned: under the single-ledger model
of §1 it would have nothing to mark, and building it is exactly what would turn every read path
into a leak surface.

---

## 10. Decisions taken, and what is still open

**Taken (these were the open items):**

1. **Permissions are a real boundary.** `can_add` on INSERT and `can_edit` on UPDATE are enforced by
   one `BEFORE` trigger per table (the delete-transition trigger's own shape), and per-member toggles
   are the only control — no firm-wide switch. Members write by default; the owner narrows them.
   *(Was: "accept it, or tighten it?" — §3.3.)* **Audit correction: both halves are new work** —
   there is no `can_add_firm` helper and no INSERT path reads the flag today.
2. **The invite code stays; its fumble is fixed.** An already-member redemption returns
   `already_member` and retires the code as revoked instead of consuming it as used, and the client
   never offers the invite field to an account that already has a firm. The email-bound alternative
   is rejected for the reasons in §2.5. *(Was: "consume it or leave it redeemable?")*
3. **A member's Settings > Backup & Restore keeps neither action** — no Back Up, no Restore. Only
   the owner keeps the export (§6).
4. **Dissolution: the owner empties the roster first, then dissolves**, and dissolving nulls the
   rows' `firm_id` so the owner keeps his ledger rather than deleting it (§4.4).
5. **The chamber's shared config is member-editable** — the owner-only reading is withdrawn, with
   the built-in baseline immutable and the in-use guard protecting a case's own references (§3.2).
6. **The in-use guard is added on the server**, so a soft-deleted reference row that a live case
   still names can neither be written nor break `purge_tombstones()` (§3.2, §9.6).
7. **Retention is 365 days and the recovery window is 335** (§5.5), with the `mutation_receipts`
   invariant corrected to 400 days and the privacy policy's placeholder row to be filled in.
8. **A lapsed account keeps writing up to the allowance of the tier it last held** — Pro 100, Firm
   500, Firm Plus 1,000 cases, notes and case references — with the **most recently updated** rows
   the writable set, the excess read-only, seed customisation unlimited, and nothing deleted or
   hidden; renewal restores everything at once (§5.2, §5.4). The one-month-then-never-renew gap the
   user asked about is closed by this rule rather than by hiding any case.
9. **The tier ladder is settled and repriced** (§5.3): Free ৳0/50 cases, Pro ৳100 a month or ৳1,000 a
   year/1,000 cases, Firm ৳300 (৳3,000 a year)/2,500 cases/5 associates, Firm Plus ৳600 (৳6,000 a
   year)/6,000 cases/20 associates, and Unlimited by quotation. The chamber tiers were raised from
   the draft's ৳200 and ৳300 because the value is seats, not cases, and ৳200 for 20 lawyers priced
   collaboration at a tenth of the market's per-seat rate. **The prices are flat and final**: the
   earlier "same 5 % / 10 % / 20 % discount policy" wording is withdrawn (the chamber annuals were
   never that), and Pro's annual moves from the shipped ৳960 to ৳1,000 as part of the new set.
10. **Distribution is direct, not Google Play, for now** (§5.6): the app's own APK and in-app updater
    stay the only channel, which is what makes the manual MFS payment flow and the self-updater
    correct rather than a policy exposure, and keeps the full price instead of 85 % of it. Play is a
    later decision after testing and feedback, and adopting it means a build flavour that switches to
    Play Billing and drops the self-updater.

**Taken in the audit pass (this revision):**

11. **A dissolved chamber's rows get a scope owner** (§4.4): `firm_id` is nulled *and* the owner is
    written as the rows' scope owner, so he keeps the ledger and the authors lose the read they
    would otherwise have regained, with attribution untouched. The audit found a bare null would do
    the opposite: the owner could not read the rows his members wrote, and they could.
12. **The tier and its seat cap are stored** (§5.3): `profiles.tier` / `firms.tier`, written at
    approval and never cleared by expiry, so §5.2's allowance of the tier last held is derivable and
    §5.4's join-time seat check has a source. There is no `payment_plans` table; the ladder is
    `plan_type` keys plus the `approve_payment` constants.
13. **A member may not buy a personal plan, and their own expiry does not count while they hold a
    firm** (§5.1). The app does not offer it and the server refuses the submission; a plan bought
    before joining is ignored in the chamber and applies again once they are individual. The audit
    found the gate was *own expiry OR firm's*, so a member with a leftover plan kept syncing through
    the chamber's lapse.
14. **Restore never writes the account rows and stamps the chamber** (§6): `profiles`, `firms` and
    `firm_members` are skipped, restored rows take the current chamber's `firm_id`, and a file naming
    another firm is refused.
15. **A removal erases the device by itself** (§4.1): no confirmation step and no waiting for a tap;
    the erase runs on the phone's next launch or connection, before any pull or write, and the notice
    tells the person what has already been removed.
16. **A chamber is created on the Firm tier or above** (§2.4, §5.3): Pro's seat cap is 0, so the
    creation gate reads the tier instead of `is_premium`, and a Pro caller is refused with the reason
    rather than allowed to build a chamber nobody can join.
17. **A downgrade waits for the period it was bought for** (§5.4, §5.3): a Firm Plus owner who buys
    Firm mid-term keeps Firm Plus to the end of the paid period and is on Firm from the day after.
    Because nothing runs when a period turns over, the rule is carried by a **pending tier and the
    instant it starts** beside the tier in force, and every gate derives the effective one.

**Still open, and all of it work rather than questions:**

1. **The read-side migration of §4.3** — written nowhere yet, and the hole is live on the project.
2. **The reference-table write scope in `push_changes`**: with member edits now allowed, the push
   path must accept a member's reference insert/update under `can_edit` and refuse only the
   immutable baseline — to be checked against the RPC as built (§3.2, §3.3).
3. **Everything this revision adds**, none of it written yet: the `scope_owner_id` column with its
   read-policy rewrite (§4.3, §4.4), `profiles.tier` / `firms.tier` with the `join_firm` seat check
   and the ten-plan ladder (§5.3), the `can_add` / `can_edit` triggers (§3.3), the write-path scope
   rules (§3.3), `ensure_firm`'s creation gate re-pointed from `is_premium()` at the tier
   (shipped as `is_premium` in `20260930180000_ensure_firm_premium_gate.sql`, so the replacement
   is owed), the self-erasing removal's client rework (§4.1) and the plans screen rebuilt to
   the new set.

---

## 11. Where each ruling is recorded

| Where | What it holds |
|---|---|
| `docs/implementation_plan.md` → Resolved Design Clarifications | The rulings themselves, and the corrected RLS strategy table (`cases`, `case_history`, `notes`, `case_references`, the four reference rows, `conflict_log`). **Propagated (version 0.0.519)** — the previous pass's reversals and this revision's rulings are all recorded there now, together with the scope owner, the stored tier and its pending pair, the ruled permission boundary, the 365/335 pair and the ten flat plans (see the note below). |
| `docs/tasks/17_auth_profiles_and_firm_onboarding.md` | The join refusal and its wording; the empty-seat rule; the lapsed-chamber join; the invite-code fix. |
| `docs/tasks/18_sync_engine_push_pull.md` | The four `push_changes` rules: only the firm's expiry counts for a member, `can_add` / `can_edit` enforcement, the server-owned scope columns, and a member's reference writes under `can_edit`. |
| `docs/tasks/20_firm_management_and_delete_requests.md` | The permission defaults and the enforced permission boundary; member-editable config; the removal wipe, its ordering and its owner warning; the roster; dissolution. |
| `docs/tasks/15_backup_restore_and_free_tier_gating.md` | The restore bar in firm mode with its empty-device exception and its 365-day correction ceiling; no backup or restore for a member; the 50-case free wall and the §5.2 lapse ceilings. |
| `docs/tasks/16_supabase_schema_rls_and_triggers.md` | The read-policy scoping of §4.3, the §3.3 permission triggers, the 365-day purge and the in-use guard. |
| `docs/tasks/19_realtime_conflicts_and_recovery.md` | The 335-day recovery window and the 400-day `mutation_receipts` invariant. |
| `docs/tasks/21_payments_and_subscription.md` | The settled tier ladder and its plan rows, the downgrade and lapse rules, and the direct-distribution decision (§5.3, §5.4, §5.6). |
| `supabase/migrations/` + `supabase/AllSupabaseSql.md` | Nothing yet: §4.3's scoping, §3.3's permission triggers and its **write-path scope rules** (`firm_id` server-assigned, `scope_owner_id` server-only, no firm-less row for a member), §3.2's in-use guard, §5.5's 365-day retention, §5.3's tier column **with the widened subscription mirror**, and the `payment_submissions` insert policy that refuses a submission from an account holding a firm (§5.1). The 365-day change also moves the **generated** ledger's own section label, so it is a migration plus a regeneration (§5.5). |
| `docs/firm_mode_blueprint_audit.md` | The audit this revision answers: ten findings checked against the shipped SQL and Dart, and the six decisions they raised — now ruled on in §3.3, §4.1, §4.2, §4.4, §5.1, §5.3, §5.5, §5.6, §6 and §7. |

> **Propagation note — done (version 0.0.519).** This file is revised first because the user asked
> for it first, and every ruling it records is now settled — including the tier ladder and the
> distribution decision. The **one pass** across `docs/implementation_plan.md` and tasks 15, 16, 17,
> 18, 19, 20 and 21 has since **run**, so no file was edited twice for the same ruling: each piece of
> superseded wording was replaced in place — owner-only config became member-editable, "the server
> still cannot tell" became the ruled permission boundary, the 180/150 pair became 365/335, the
> four-plan pricing became the ten flat plans, and the Play-billing assumption became direct
> distribution — and this revision's rulings and corrections travelled with it (the scope owner of
> §4.4, the stored tier and seat cap of §5.3, no personal plan for a member of §5.1, the restore
> mechanics of §6, the self-erasing removal of §4.1, the flat plan prices of §5.3 and the audit
> corrections in §3.3, §4.2, §5.2, §5.5, §5.6 and §7). **What remains owed is work, not records:**
> every migration §10's open list names, none of which is written yet.

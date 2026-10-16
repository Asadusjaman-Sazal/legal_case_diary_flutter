# Firm Mode Blueprint — The Chamber Ledger

> **Status: plan record, not as-built documentation.** This file carries the detail behind the
> firm-mode rulings that are summarised in `docs/implementation_plan.md` →
> *Resolved Design Clarifications* (the bullets headed *A Chamber Holds One Ledger* through
> *The Order Of Work For Firm Mode*). The plan remains the source of truth; if this file and the
> plan disagree, the plan wins and this file is corrected. Every statement below is a **decision
> about what to build**, not a description of what exists, and much of it is already built: §6's
> firm-mode restore bar with its ownership rules, §4.2's `delete_my_account()` firm refusal and
> §2.4's premium gate on `ensure_firm` predate the phase list, and §4.3's read-side scoping
> (0.0.520), §3.3's write-path scope rules with §1's creation stamping (0.0.522), §2.1's empty-seat
> refusal (0.0.523) and §4.1's self-erasing removal (0.0.525) have landed since. **Where the shipped
> server or client still contradicts a ruling, the phase list at the end of this file says so**: an
> `Owed` phase is the contradiction, and its `Hazards` field is what the contradiction costs.
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

1. **The read-side migration of §4.3** — **built** (Phase 1, 0.0.520, `20261015100000_firm_mode_read_scope.sql`), so the hole is closed on the project; items 2 and 3 below are where the remaining work is.
2. **The reference-table write scope in `push_changes`**: with member edits now allowed, the push
   path must accept a member's reference insert/update under `can_edit` and refuse only the
   immutable baseline — to be checked against the RPC as built (§3.2, §3.3).
3. **Everything this revision adds** — **built and still owed, so this list is not read as
   untouched.** *Built:* the `scope_owner_id` column with its read-policy rewrite (§4.3, 0.0.520),
   the write-path scope rules (§3.3, 0.0.522), the `join_firm` **seat check and refusal** (§5.3's
   mechanism, 0.0.523 — `firm_seat_cap` still reads `is_premium` as a placeholder, so only the source
   it reads is owed), the self-erasing removal's client rework (§4.1, 0.0.525), the `can_add` / `can_edit` triggers (§3.3, 0.0.529) and the in-use guard with the purge's per-row skip (§3.2, 0.0.530). *Still owed:*
   `profiles.tier` / `firms.tier` with the pending pair and the ten-plan ladder (§5.3),
   `ensure_firm`'s creation gate re-pointed from
   `is_premium()` at the tier (shipped as `is_premium` in
   `20260930180000_ensure_firm_premium_gate.sql`, so the replacement is owed), and the plans screen
   rebuilt to the new set.

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
| `supabase/migrations/` + `supabase/AllSupabaseSql.md` | **Six of these are shipped:** §4.3's scoping (`20261015100000_firm_mode_read_scope.sql`, 0.0.520), §3.3's **write-path scope rules** (`firm_id` server-assigned, `scope_owner_id` server-only, no firm-less row for a member) with §1's creation stamping (`20261015110000_firm_mode_creation_and_scope.sql`, 0.0.522), §2.1's empty-seat refusal (`20261015120000_firm_mode_join_gate.sql`, 0.0.523) and §4.1's removal clearing the member's `device_tokens` (`20261015160000_firm_removal_clears_device_tokens.sql`, 0.0.525), §3.3's **permission triggers** (`20261016100000_firm_mode_permission_boundary.sql`, 0.0.529) and §3.2's **in-use guard** (`20261016110000_firm_mode_reference_in_use_guard.sql`, 0.0.530). **Still owed:** §5.5's 365-day retention, §5.3's tier column **with the widened subscription mirror**, and the `payment_submissions` insert policy that refuses a submission from an account holding a firm (§5.1). The 365-day change also moves the **generated** ledger's own section label, so it is a migration plus a regeneration (§5.5). |
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
> four of the migrations §10's open list names are **built** (§4.3's scoping, the write-path scope rules, the empty-seat refusal and the self-erasing removal, 0.0.520–0.0.525); the work that remains is listed per phase at the end of this file.

## Phases to Implement:

> **How to read this section.** §1–§10 above are the **rulings** — what to build, and why. This
> section is only the **execution spec**: the order the work runs in, what each phase touches by
> name, how each phase is proved, and what is already done. Where the two disagree, §1–§10 win and
> this section is corrected.
>
> **Every phase carries the same ten fields** — `Status`, `Discharges`, `Depends On`, `Why Here`, `Server`, `Objects`, `Client`, `Proof`, `Acceptance` and `Hazards` — plus any phase-specific extra (`Records`, `Note`, `Open Input`, `The Rule`, `Already Built`). `**Objects.**` answers *which functions, tables and files*, `**Hazards.**` answers *what breaks if this is done carelessly*, and `**Status.**` is the one place a phase’s condition is stated. Every phase is one migration or one client change, carries its own
> proof, and is **applied to the live project** (`lsthasywrdrhuuxnykau`) before it is called done.

### Status at a Glance

| # | Phase | Discharges | Status | Artifact |
|---|---|---|---|---|
| 1 | Read-Side Scoping | §4.3 | **Built** 0.0.520 | `20261015100000_firm_mode_read_scope.sql` |
| 2 | Creation Shares The Diary, And The Scope Columns Become The Server's | §1, §9.1, §3.3 | **Built** 0.0.522 | `20261015110000_firm_mode_creation_and_scope.sql` |
| 3 | The Join Gate | §2.1–§2.5, §3.1 | **Built** 0.0.523 | `20261015120000_firm_mode_join_gate.sql` |
| 4 | Removal Erases Itself | §4.1, §4.2, §6 | **Built** 0.0.525 | `20261015160000_firm_removal_clears_device_tokens.sql` |
| 5 | The Permission Boundary | §3.3 | **Built** 0.0.529 | `20261016100000_firm_mode_permission_boundary.sql` |
| 6 | The In-Use Guard | §3.2, §10.6 | **Built** 0.0.530 | `20261016110000_firm_mode_reference_in_use_guard.sql` |
| 7 | Stored Tier And The Creation Gate | §5.3, §5.4, §10.12, §10.16 | Owed | new migration |
| 8 | The Ten-Plan Ladder | §5.3, §10.9 | Owed | migration + client |
| 9 | A Member Has No Plan Of Their Own | §5.1, §10.13 | Owed | migration + client |
| 10 | The Lapse Allowance | §5.2, §5.4, §10.8 | Owed | client (+ server gate) |
| 11 | Dissolution | §4.4, §10.4, §10.11 | Owed | new migration + client |
| 12 | Retention And The Recovery Window | §5.5, §10.7 | Owed | migration + regeneration |
| 13 | Restore Inside A Chamber | §6, §10.14 | Owed | client |
| 14 | Attribution And The Roster | §9.9 | Owed (verify) | client, verify only |
| 15 | Distribution | §5.6, §10.4, §10.10 | Owed | client + docs |

**The § → phase map, so rule 4 and the ruling index stay answerable:** §1→P2, §2→P3/P7,
§3.1→P3, §3.2→P6, §3.3→P2/P5, §4.1–§4.2→P4, §4.3→P1, §4.4→P11, §5.1→P9, §5.2→P10, §5.3→P7/P8,
§5.4→P7/P8/P10, §5.5→P12, §5.6→P15, §6→P4/P13, §7→no code change, §9.9→P14.

### The Contract Every Phase Follows

1. **Order.** Phases 1–4 are built and are recorded below with their evidence. Phase 5–15 run in
   the numbered order unless an ordering hazard below says otherwise. The order is deliberate: the
   firm-mode **correctness** set (5–6) precedes the **plans and tiers** revamp (7–10), because firm
   mode is not safe to hand to an associate until its permission boundary and in-use guard exist,
   and because a pricing change is not a prerequisite for a permission fix.
2. **One migration, one phase.** A server phase adds exactly one file under
   `supabase/migrations/`. The name is the phase's concern, not a sequence number — the timestamp is
   the day it is applied, matching the four built firm-mode migrations
   (`20261015100000_firm_mode_*.sql`).
3. **The phase is not done until it is applied and proved.** Run `flutter analyze`, run the proof
   against the live project, run the suite, regenerate the ledger, and record the version. The
   exact commands are in *Applying A Phase To The Live Project* below.
4. **A new migration is registered in two more places, or the build breaks.** The generator keeps a
   **hand-maintained manifest** in `tool/generate_all_supabase_sql.dart` and throws without a
   `_groupTitles` entry for the new version; and the literal migration counts and `versions.last` in
   `test/supabase/migration_applier_test.dart` and `test/supabase/all_supabase_sql_test.dart` must
   move with the ledger. Missing either is a red suite, not a warning.
5. **A proof file is run wrapped.** Several `supabase/tests/*.sql` files open a PL/pgSQL block
   rather than a SQL transaction, so a bare `psql -f` **commits its fixtures to the live project**.
   Always wrap the stream — see the command list below.
6. **Table classes (rule 4) are named per phase** from §7's list rather than re-derived: push/pull
   domain, pull-only cache, per-user preference, local operational, server-managed.

---

### Phase 1 — Read-Side Scoping — **Built** (0.0.520)


- **Status.** **Built** — 0.0.520, applied to `lsthasywrdrhuuxnykau`; migration `supabase/migrations/20261015100000_firm_mode_read_scope.sql`; proof `supabase/tests/firm_mode_read_scope_test.sql` → `SCOPE OK`.
- **Discharges.** §4.3, §10 open item 1. Plan: *What Firm Mode Still Owes* items (1) and (3)'s
  read-policy half. The hole was live on the project when this landed.
- **Depends On.** Nothing — it was the first phase, and it is what makes Phase 4 stick: a removed member’s own authored rows must stop being readable *before* their device is erased and their next full pull runs.
- **Why Here.** §9’s design order put the read scoping fourth; it was **hoisted to Phase 1** because the hole was live on the project and every later phase rests on the scope rule being true.
- **Server.** Shipped: `supabase/migrations/20261015100000_firm_mode_read_scope.sql`.
- **Objects.** `scope_owner_id uuid` added to the **eleven ledger tables** — `cases`,
  `case_history`, `notes`, `case_references`, `delete_requests`, `court_categories`,
  `case_categories`, `courts`, `steps`, `case_types`, `on_behalfs` — and deliberately **not** on
  `conflict_log`. The SELECT policies rewritten to
  `(user_id = auth.uid() and firm_id is null and scope_owner_id is null) or firm_id = current_firm_id() or scope_owner_id = auth.uid()`;
  the six reference tables keep `is_custom = false`; `delete_requests_select_firm` renamed
  `delete_requests_select_scoped` and carrying the same rule on `requested_by`; `conflict_log_select_own`
  narrowed to the membership condition with **no** scope owner. The column is **server-only to
  write** from the moment it exists: the table-level INSERT/UPDATE grant is dropped and every other
  column granted back, because a table-level GRANT is not undone by a column-level REVOKE (the fact
  `20260929102500_phase3_column_privileges.sql` proved).
- **Client.** None — the pull is scoped by RLS.
- **Proof.** `supabase/tests/firm_mode_read_scope_test.sql` prints `SCOPE OK`. Guards:
  `test/supabase/schema_contract_test.dart` (the scoped rule, the eleven-table list,
  `conflict_log`'s exclusion, the grant-back loop), plus the counts in `all_supabase_sql_test.dart`
  and `migration_applier_test.dart`.
- **Acceptance.** A removed member reads **0** of their authored chamber rows on all four case-data
  tables while the owner and an associate read them; an individual's own firm-less row is untouched
  and invisible to others; a dissolved row is readable by its scope owner and not by its author; the
  built-in baseline stays readable to everyone; `delete_requests` keeps the chamber's queue to the
  chamber; a client INSERT/UPDATE naming `scope_owner_id` is refused while `case_remarks` still
  updates as that role.
- **Hazards.** The column-privilege trap it had to work around: Supabase grants table-level INSERT/UPDATE and **a table-level GRANT is not undone by a column-level REVOKE** (the fact `20260929102500` proved), so `scope_owner_id` is protected by dropping the table-level grant and granting every other column back — which is also what leaves any column a later migration adds closed by default.
- **Note.** The assertion was proved to bite by restoring the superseded policy on a scratch copy:
  `with the shipped policy: 0, with the old rule: 1`.

### Phase 2 — Creation Shares The Diary, And The Scope Columns Become The Server's — **Built** (0.0.522)


- **Status.** **Built** — 0.0.522; migration `supabase/migrations/20261015110000_firm_mode_creation_and_scope.sql`; proof `supabase/tests/firm_mode_creation_scope_test.sql` → `CREATION OK`.
- **Discharges.** §1, §9.1, §3.3's scope-column half. Plan: *What Firm Mode Still Owes* — the write-path scope half.
- **Depends On.** Phase 1 — the read rule and `scope_owner_id` had to exist before creation could stamp a diary into a chamber.
- **Why Here.** Without it firm mode is inert: every repository writes `firmId: null`, so a member’s row landed as a personal row inside a chamber and the server refused it (`42501`).
- **Server.** Shipped: `supabase/migrations/20261015110000_firm_mode_creation_and_scope.sql`.
- **Objects.** `ensure_firm` now stamps, in the transaction that creates the firm, every firm-less
  ledger row its creator authored — all four case-data tables, the six reference tables' **custom**
  rows, and the owner's **pending** `delete_requests`, **tombstones included** — each with
  `version = coalesce(version, 1) + 1` beside a refreshed `updated_at`, so devices converge on the
  `server_updated_at` cursor. A re-call (rename, repair) stamps nothing again; a row already in
  another firm is left alone; the built-in baseline is untouched. `push_changes` derives an insert's
  `firm_id` from `current_firm_id()` read once per call, never names `firm_id` on an update, and
  **subtracts `scope_owner_id`** from every payload before any branch reads it.
- **Client.** None.
- **Hazards.** The trap it closes is also the one it must not reopen: `push_changes` is `SECURITY DEFINER`, so it strips only a fixed list of columns and **any column a later migration adds is client-writable through the RPC unless the RPC names it**. Adding a column to a ledger table later means adding it to that strip list.
- **Ruling taken while building (recorded in the plan, rule 14).** The scope columns are
  **stripped and derived, not rejected**: the client sends the whole local row, so `firm_id` is
  present and usually null, and refusing a payload that merely names the column would refuse
  legitimate writes for no gain, because a column the UPDATE never names cannot change.
- **Proof.** `supabase/tests/firm_mode_creation_scope_test.sql` prints `CREATION OK`. Bite checked
  on scratch copies of the superseded bodies: with the old `ensure_firm` the run fails at
  `cases scope2-case did not follow the creator into the chamber`.
- **Acceptance.** Creation stamps all twelve row kinds and leaves the four it must alone; a second
  call stamps nothing; a member's insert whose payload says `firm_id` null lands in the chamber; a
  payload naming another firm is corrected; a payload naming a scope owner is ignored; an update
  cannot move a row out of its chamber; an individual's row stays personal.
- **Why it had to precede Phase 3.** Until this landed, every repository wrote `firmId: null`, so a
  member's case was rejected on the server (`42501`) and firm mode was inert.

### Phase 3 — The Join Gate — **Built** (0.0.523, audited 0.0.524)


- **Status.** **Built** — 0.0.523, adversarially re-probed at 0.0.524; migration `supabase/migrations/20261015120000_firm_mode_join_gate.sql`; proofs `supabase/tests/firm_mode_join_gate_test.sql` → `JOIN OK` and `supabase/tests/firm_mode_audit_probe.sql`.
- **Discharges.** §2.1–§2.5, §3.1. Tasks 17 and 20.
- **Depends On.** Phase 2 — the seat has to be guaranteed empty before Phase 4 may erase a device on the strength of it.
- **Why Here.** Parity needed the other half of the seat rule: a seat an associate can actually join, and one an account holding its own diary cannot take.
- **Server.** Shipped: `supabase/migrations/20261015120000_firm_mode_join_gate.sql`.
- **Objects.** `join_firm(code text)` decides `has_own_diary` and `seats_full` **before its first
  write**, so a refusal writes no `firm_members` row, relinks no profile and does not consume the
  invite. `holds_own_diary(p_user_id)` and `individual_diary_cases(p_user_id)` are new and granted
  to **`authenticated` alone**, so a signed-out caller cannot use the gate's refusal as an oracle
  for another account's diary count. `firm_seat_cap(p_firm_id)` is new and is a **placeholder** —
  see Phase 7. An `already_member` redemption now **retires the code as `revoked`** rather than
  consuming it as `used_by`. A join lands with `role = 'associate'`, `can_add` and `can_edit`
  **true**, `can_delete` **false**, and both `synced_at` and `permissions_synced_at` written.
- **Client.** `parseInviteRedemption` maps the two new **statuses** (not errors) to a typed
  `InviteRefusal` carrying the count the sentence quotes; four new ARB keys in both locales
  (`auth_errorOwnDiary(cases)`, `auth_errorSeatsFull(seats)` and their no-count fallbacks);
  `login_screen` and `signup_screen` catch `InviteRefusal` beside their firm branches.
- **Proof.** `supabase/tests/firm_mode_join_gate_test.sql` prints `JOIN OK`;
  `supabase/tests/firm_mode_audit_probe.sql` re-ran it adversarially and the guarantee held.
- **Acceptance.** An account holding one individual case is refused with `cases = 1` and **writes
  nothing**; a chamber-authored row does not make a diary, so a removed member joins cleanly; a
  scope-owned firm-less row is nobody's own diary; an already-member redemption answers
  `already_member` with `revoked` true and `used_by` null; a join lands §3.1's defaults; a live
  Premium chamber sells 5 seats and the sixth join is refused with `seats = 5`; a chamber lapsed past
  the grace window has no cap and stays joinable (§2.4).
- **Hazards.** The trap this phase hit, still live for 5, 6, 7 and 11: The migration revoked
  EXECUTE on its new helpers from `public, anon, authenticated` and **granted it back to nobody**, so
  on the project `has_function_privilege` was false for every role while `join_firm` — SECURITY
  DEFINER, granted in the same file — kept working, which is why the RPC test passed. **A revoke that
  names `authenticated` is a lock-out unless a grant follows it, and a passing RPC test does not
  cover the helpers it calls.** Every later phase must re-read the grants it writes.

### Phase 4 — Removal Erases Itself — **Built** (0.0.525)


- **Status.** **Built** — 0.0.525; migration `supabase/migrations/20261015160000_firm_removal_clears_device_tokens.sql`; proofs `supabase/tests/firm_removal_test.sql` → `REMOVAL OK` and `test/features/membership_revocation_test.dart`.
- **Discharges.** §4.1, §4.2, §6's no-backup half, §10.15. Task 20.
- **Depends On.** Phase 3 — a self-erasing device is only safe once a refused join guarantees the seat was empty, which is why this ships **no earlier than** Phase 3.
- **Why Here.** Without the wipe a removed member keeps the ledger; without the warning the owner cannot know which phone still holds it.
- **Server.** Shipped: `supabase/migrations/20261015160000_firm_removal_clears_device_tokens.sql`:
  `remove_firm_member` deletes the removed member's `device_tokens` rows **in the same transaction
  as the revocation**, so no firm notification can be routed to a removed device even before its own
  erase runs; the rows they authored and their attribution are untouched.
- **Objects.** `remove_firm_member` (deletes the removed member’s `device_tokens` rows in the revocation’s own transaction); client `MembershipRevokedScope`, `membershipRevokedProvider` (`lib/features/accounts_and_profile/data/account_mode.dart`), `BackupRepository.wipeToFreshInstall`, the informational *Your Access Ended* screen, and the owner’s removal confirmation.
- **Client.** `MembershipRevokedScope` (mounted above the app shell) watches
  `membershipRevokedProvider` and **erases without asking and without waiting**, cancelling that
  device's scheduled case notifications, discarding its queued mutations,
  running `wipeToFreshInstall` before any pull or write, ending the session, and showing an
  informational *Your Access Ended* screen that reports what was erased. The withdrawn *Erase &
  sign out* button is gone. A member's Settings > Backup & Restore keeps **neither** action. The
  owner's removal confirmation carries §4.1's warning about a device that never comes back.
- **Proof.** `supabase/tests/firm_removal_test.sql` prints
  `REMOVAL OK: access revoked, authored rows kept, push registrations cleared, both topics announced.`;
  `test/features/membership_revocation_test.dart` (8 tests).
- **Acceptance.** Access revoked, authored rows kept with attribution, push registrations cleared
  for the removed member alone while the owner's are kept, the profile relinked, both topics
  announced, the three refusal cases still refused, and a device that detects removal erases itself
  before its first pull.
- **Hazards.** How this proof must be run: The file opens with a PL/pgSQL `begin`, not a SQL
  transaction. Running it bare leaked three fixture auth users, their profiles, a case and a firm
  into the project. Use the wrapped invocation in the command list below, and check every other
  `supabase/tests/*.sql` probe for the same shape before running it.
- **Hazards.** A bug worth not repeating: The first erasure was started with
  `Future<void>(_erase)`, which runs synchronously up to its first `await` **during the build**, so
  `ref.read` threw inside `build` and the erasure silently never ran; the symptom was a hang, not an
  exception. It is `Future.microtask(...)`.

---

### Phase 5 — The Permission Boundary — **Built** (0.0.529)


- **Status.** **Built (0.0.529)** — `can_add_firm` exists beside its two siblings, twenty `BEFORE` triggers gate INSERT on `can_add` and UPDATE on `can_edit` across the ten named tables, and `sync_can_write`'s INSERT branch reads the flag in both of its branches; `supabase/tests/firm_mode_permission_boundary_test.sql` prints `PERMISSION OK` on the live project.
- **Discharges.** §3.3 (both halves), §9.5, §10.1. Plan: *What Firm Mode Still Owes*, and §10's open item 2 (the reference-table write scope in `push_changes` is this phase's second acceptance case). Task 20's *Permissions are a real
  boundary now* entry.
- **Depends On.** Phase 2 (built) — the write-path scope half already exists, so **do not re-write
  it** — and Phase 3 (built) for the flags themselves, which now default `can_add = true` and
  `can_edit = true`.
- **Why Here.** A revocation that is not enforced is worse than no toggle at all, and this is the
  last correctness item standing between firm mode and handing a chamber to a real associate.
- **Server.** One new migration (`<timestamp>_firm_mode_permission_boundary.sql`):
  - a **`can_add_firm`** helper beside `can_edit_firm` and `can_delete_firm` in
    `20260929102000_phase3_access_helpers.sql`. **It does not exist today** — confirmed by reading
    the schema — so both halves are new work, not just the UPDATE half.
  - **One `BEFORE INSERT` trigger per table reading `can_add`, and one `BEFORE UPDATE` trigger per
    table reading `can_edit`**, across the **ten tables**: `cases`, `case_history`, `notes`,
    `case_references`, `court_categories`, `case_categories`, `courts`, `steps`, `case_types`,
    `on_behalfs`. Use the shape `enforce_delete_transition()` already has
    (`20260929102100_phase3_sync_and_guard_triggers.sql`) — a `BEFORE` trigger per table, **not** a
    policy rewrite.
  - **`sync_can_write`**'s INSERT branch (`20260930140000_push_changes.sql`, last replaced by
    `20260930210000_sync_can_write_firm_membership.sql`) must read the flag. Today it checks
    authorship and firm scope only and reads no permission flag, so a member with `can_add = false`
    can insert firm rows through the RPC **and** straight through PostgREST.
  - **`can_delete` is not duplicated.** It keeps its existing gate — the delete-transition trigger
    plus the pending delete-request flow (Task 20 Phases 3–4).
  - **A member may not change their own flags.** The `firm_members` write path is already
    owner-only (`20260930210000_sync_can_write_firm_membership.sql`).
- **Objects.** The ten tables named in the Server bullet; `firm_members` as the flag’s source, read for the caller and the row’s firm; `sync_can_write`’s INSERT branch (`20260930140000_push_changes.sql`, last replaced by `20260930210000_sync_can_write_firm_membership.sql`); the helper’s siblings `can_edit_firm` / `can_delete_firm` and the shape `enforce_delete_transition()` already uses.
- **Client.** None. `can_edit = false` must mean the same thing in the screen and in the database,
  and §3.2's reversal means no owner-only guard over the six reference tables is expected.
- **Proof.** A new `supabase/tests/firm_mode_permission_boundary_test.sql`, rolled back, run
  wrapped, impersonating the `authenticated` role so `sync_can_write`'s own guards run.
- **Acceptance.** A member with `can_add = false` is refused an INSERT **through `push_changes` and
  through direct PostgREST**; with `can_edit = false` refused an UPDATE; the owner's own insert is
  unaffected; a member's reference insert/update under `can_edit = true` is accepted while the
  `is_custom = false` baseline is refused; `can_delete` behaviour is unchanged.
- **Records.** The ruling and both halves are already in the plan (*The Permission Is A Boundary,
  Not An Intention*) and in Task 20, so **nothing new is recorded** (rule 14). Only the as-built
  facts go into the ledger, the generator's group title and the guards.
- **Hazards.** (a) Phase 3's revoke-without-grant trap — re-read every grant this migration writes.
  (b) `push_changes` is `SECURITY DEFINER`, so it bypasses the column privileges and the policies: the
  **trigger** is the enforcement, and the policy is not. (c) Two triggers across ten tables means a
  single missed table silently keeps the hole — the proof must **enumerate all ten by name** rather
  than spot-check.

### Phase 6 — The In-Use Guard — **Built** (0.0.530)


- **Status.** **Built (0.0.530)** — `enforce_reference_not_in_use()` refuses the tombstone with `reference_in_use` (23503) off the nine-pair map, four `trg_<table>_in_use_guard` triggers attach it to the four guardable parents, `purge_tombstones` skips a blocked row instead of aborting as a whole, and the three Edit Court/Steps screens withhold Delete for a row a live dependent still names; `supabase/tests/firm_mode_reference_in_use_guard_test.sql` prints `INUSE OK` on the live project.
- **Discharges.** §3.2, §10.6. Plan: *What Firm Mode Still Owes*. Task 16.
- **Depends On.** Phase 5 — the reference tables' member-editable write scope is what makes this
  load-bearing; and Phase 1's `scope_owner_id` (built) for the table list.
- **Why Here.** §3.2's reversal lets every member reorder and delete shared config, so a member's
  edit can now reach the reference rows a live case depends on. §5.5's retention purge must not be
  the thing that discovers the collision.
- **Server.** One new migration (`<timestamp>_firm_mode_reference_in_use_guard.sql`):
  - refuse **tombstoning a reference row a live dependent row still names**. The dependency graph is
    **nine foreign keys, all declared in `20260929100000_phase1_core_schema.sql`**, and it is not
    what the older one-line summary implied:
    - `court_categories` ← `case_categories.court_category_id`, `courts.court_category_id`,
      `steps.court_category_id`, `case_types.court_category_id`, `on_behalfs.court_category_id`
    - `case_categories` ← `case_types.case_category_id`, `cases.case_category_id`
    - `courts` ← `cases.court_id`
    - `on_behalfs` ← `cases.on_behalf_id`
    - `steps` ← **nothing**, and `case_types` ← **nothing**: `cases.case_type` is free text, not a
      foreign key.
  - make **`purge_tombstones`** (`20260929104000_phase5_indexes_and_tombstone_purge.sql`) **skip a
    blocked row rather than fail as a whole** — today the blocked foreign key raises and aborts the
    entire function, so one member's stale reference edit can stop every tombstone on the project
    from being purged.
- **Objects.** `purge_tombstones` (`20260929104000_phase5_indexes_and_tombstone_purge.sql`) and its daily `pg_cron` schedule; the nine foreign keys listed above; the device-side refusal in the reference repositories, which is the only protection `steps` and `case_types` can have.
- **Client.** **Built (0.0.530).** Edit Court/Steps, case types and on-behalfs still offer **Add, Edit
  and Reorder** to a member exactly as to the owner — an assertion, not a change, and it is now
  **pinned** by a widget test over all three screens rather than left to a reading. **Past its own
  *verify only* wording, on the user's instruction and recorded per rule 14:** the Delete action is
  now **withheld** for a row a live dependent still names — the device-side refusal this phase's
  `Objects` names — so an offline delete is never queued only to be refused. The rule has one home,
  `lib/features/settings/data/reference_in_use_checker.dart` (`referenceInUseProvider`, a Drift
  `watch()` over live `cases` and the five editable tables), which `data_deletion_service.dart` reads
  as well, so the Manage Account tick list and those screens cannot disagree about what is in use.
- **Proof.** A new `supabase/tests/firm_mode_reference_in_use_guard_test.sql`, rolled back, run
  wrapped.
- **Acceptance.** A tombstoned reference row that a live case still names **cannot be written**; a
  purge run over such a row **completes and skips it** instead of raising; a tombstoned row naming no
  live dependent is still purged; the built-in baseline (`is_custom = false`) remains undeletable for
  members and owner alike.
- **Hazards.** (a) `steps` and `case_types` have **no referencing column**, so a foreign-key-based
  guard cannot protect them — the device-side refusal in the repositories is the only protection
  there, and the proof must not claim a server guard where none can exist. (b) `purge_tombstones` is
  scheduled daily through `pg_cron`, so a failure is silent until someone reads the log — the "skip
  rather than fail" half is not optional.

### Phase 7 — Stored Tier And The Creation Gate — **Owed**


- **Status.** **Owed** — `profiles.tier` / `firms.tier` do not exist, and `firm_seat_cap` reads `is_premium` as a placeholder.
- **Discharges.** §5.3's storage half, §5.4's mechanism, §10.12, §10.16. Plan: *What Firm Mode Still Owes* — the tier's storage half
  and the creation gate. Task 21.
- **Depends On.** Phase 8 — **see the hazard below; this is the one ordering defect in the list.**
- **Why Here.** The lapse allowance (§5.2) and the join-time seat check (§5.4) both need a source
  for *which tier* an account holds; today the tier is derived from `is_premium()` and from nothing
  else, so neither rule is expressible.
- **Server.** One new migration (`<timestamp>_firm_mode_stored_tier.sql`):
  - `profiles.tier`, `profiles.tier_pending`, `profiles.tier_pending_from` and the matching
    `firms.tier` pair, written at approval and **never cleared by expiry**, so "the tier it last
    held" is derivable and the seat cap has a source. The pending pair carries §10.17: a downgrade
    waits for the period it was bought for, and because nothing runs when a period turns over the
    rule is a pending tier plus the instant it starts, with every gate deriving the effective one.
  - **`approve_payment`** (`20261002100000_payment_prices_discounted.sql`) writes the tier.
  - **`mirror_owner_subscription_to_firm`** widened in **both** its `of` list and its `when`: today
    it fires on `subscription_expiry` changes only and copies two columns, so a tier-only change
    would never reach the firm and the seat cap would read a stale value.
  - **`firm_seat_cap`** re-pointed at `firms.tier` — Pro 0, Firm 5, Firm Plus 20. **This function
    already exists** (`20261015120000_firm_mode_join_gate.sql:128`) and is a placeholder that reads
    `is_premium(f.owner_id) → 5`, with its own comment saying *"Firm 5 until `firms.tier` lands"*.
    So this phase **widens** it rather than adding it, and Phase 3's seat check and refusal wording
    need no rework.
  - **`ensure_firm`**'s gate re-pointed from `is_premium()` at **effective tier ≥ Firm**
    (`20260930180000_ensure_firm_premium_gate.sql`).
  - Client writes to `tier` are closed **by construction**:
    `20260929102500_phase3_column_privileges.sql` grants only `update (full_name)` on `profiles` and
    `update (name)` on `firms`, and denies by default any column a later migration adds.
- **Objects.** `profiles.tier` / `firms.tier` and the pending pair; `approve_payment`; `mirror_owner_subscription_to_firm` (both its `of` list and its `when`); `firm_seat_cap` (`20261015120000_firm_mode_join_gate.sql`); `ensure_firm`’s gate (`20260930180000_ensure_firm_premium_gate.sql`); `20260929102500_phase3_column_privileges.sql`, which already closes client writes to a new column by default.
- **Client.** None for the gate itself.
- **Proof.** A new `supabase/tests/firm_mode_stored_tier_test.sql`, rolled back, run wrapped.
- **Acceptance.** A Firm approval writes `firms.tier` through the widened mirror, not only the
  profile; the tier survives expiry; `firm_seat_cap` answers 0/5/20 by tier; a Pro caller creating a
  chamber is refused with the reason; a client cannot write `tier` directly or through the RPC.
- **Hazards.** The ordering defect this pass found — and why the plan carries it as a warning
  rather than a reorder: Phase 7's two behavioural changes — the seat cap reading a tier, and the
  creation gate requiring Firm or above — are **only safe once Phase 8 exists**. `approve_payment`
  accepts exactly four `plan_type` keys today (`monthly`, `quarterly`, `half_yearly`, `annual`) and
  **all four are Pro** (`20261002100000_payment_prices_discounted.sql:87`), so there is currently
  **no way for anyone to buy a Firm tier**. Landing Phase 7 alone therefore (a) makes a Pro owner's
  chamber sell **0 seats**, breaking invitations in chambers that exist and work today, and (b)
  refuses a Pro owner the creation of a chamber, with nothing purchasable that fixes either.
  **Ship Phase 7 and Phase 8 in the same pass, or hold the two behavioural changes to the end of
  Phase 8 and let Phase 7 land as storage only.** The tier columns themselves are inert and safe
  alone; the gate and the cap are not.
- **Open input.** Whether the gate switch-on stays inside Phase 7 or moves into Phase 8 is a
  sequencing decision to take when the phase is built, not a question about the ruling.

### Phase 8 — The Ten-Plan Ladder — **Owed**


- **Status.** **Owed** — `approve_payment` still accepts only the four Pro keys.
- **Discharges.** §5.3's ladder, §10.9. Plan: *What Firm Mode Still Owes* — the ladder and the rebuilt plans screen. Task 21.
- **Depends On.** Phase 7's columns (the tier is written at approval), and it is the phase that makes
  Phase 7's gate safe — see the hazard above.
- **Why Here.** It is the phase that makes Phase 7’s gate safe: until a Firm plan key exists, nobody can buy the tier that Phase 7’s seat cap and creation gate require.
- **Server.** `approve_payment` rebuilt to the ten keys with the settled prices: Pro
  ৳100/৳285/৳540/৳1,000 monthly/quarterly/half-yearly/annual; Firm ৳855/৳1,620/৳3,000; Firm Plus
  ৳1,710/৳3,240/৳6,000, each written into the amount-validation `CASE`, the duration `CASE` and the
  `plan_type` allow-list. Pro's annual moves from the shipped ৳960 to ৳1,000 as a deliberate price
  rise.
- **Objects.** `approve_payment` (`20261002100000_payment_prices_discounted.sql`) — the `plan_type` allow-list, the amount-validation `CASE` and the duration `CASE`; the **generated** `plan_name` `CASE` (`20261005120000_payment_plan_name.sql`); client `lib/features/payments/data/payment_plans.dart`, `presentation/payment_plan_labels.dart`, `paywall_screen.dart`, `checkout_screen.dart`, `current_plan.dart`, `lib/features/settings/presentation/subscription_details_screen.dart`. There is **no `payment_plans` table**.
- **Client.** The plans screen, the paywall and checkout rebuilt to the same set:
  `lib/features/payments/data/payment_plans.dart`, `payment_plan_labels.dart`,
  `presentation/paywall_screen.dart`, `checkout_screen.dart`, `current_plan.dart`,
  `lib/features/settings/presentation/subscription_details_screen.dart`.
- **Proof.** A rolled-back SQL run over all ten keys — each approves at its own amount and refuses a wrong amount — plus the paywall and checkout widget tests updated to the new set in **both** locales.
- **Acceptance.** Each of the ten keys approves at its own amount and refuses a wrong amount; the
  paywall lists exactly the new set in **both locales**; `payment_plans.dart` and the server's
  constants agree; a new key cannot be added in one place only.
- **Hazards.** The audit's correction stands: a new plan touches **four** places — the `plan_type`
  allow-list, `approve_payment`'s amount `CASE`, the **generated** `plan_name` `CASE`
  (`20261005120000_payment_plan_name.sql`), and the client's labels — not "one row in
  `payment_plans`", because **there is no `payment_plans` table**; the ladder lives as keys plus the
  `approve_payment` constants.

### Phase 9 — A Member Has No Plan Of Their Own — **Owed**


- **Status.** **Owed** — the entitlement gate is still *own expiry OR firm’s*, and a member may still submit a payment.
- **Discharges.** §5.1, §10.13. Task 21.
- **Depends On.** Phase 3 (a member exists to test against) and Phase 7/8 for the tier story, but its
  own two changes are independent of the ladder.
- **Why Here.** The audit found the entitlement gate was *own expiry OR firm's*, so a member holding
  a leftover plan kept syncing straight through the chamber's lapse — which defeats §5.2's ceilings
  and makes §2.4's "local-only until renewal" untrue for exactly that member.
- **Server.** `payment_submissions`'s insert policy
  (`20260929103200_phase4_rls_account_payment_tables.sql`; rate limit
  `20261013120000_payment_rate_limit_five.sql`) refuses a submission from an account holding a firm;
  and `has_sync_entitlement` (`20260930140000_push_changes.sql`) counts **only the firm's expiry**
  while `profiles.firm_id` is not null, instead of OR-ing the caller's own.
- **Objects.** `payment_submissions`’s insert policy (`20260929103200_phase4_rls_account_payment_tables.sql`, rate-limited by `20261013120000_payment_rate_limit_five.sql`); `has_sync_entitlement` (`20260930140000_push_changes.sql`); client `lib/features/payments/presentation/current_plan.dart`, `lib/features/settings/presentation/subscription_details_screen.dart`, and the side menu’s Current Plan row.
- **Client.** Subscription Plans is not offered to a member — on the **Subscription screen** and on
  the side menu's **Current Plan** row, not only the paywall. A plan bought before joining is ignored
  while the account holds the firm and applies again once it is individual.
- **Proof.** A rolled-back SQL run proving a member’s `payment_submissions` insert is refused, and that a member holding a live plan of their own still cannot push while the chamber has lapsed.
- **Acceptance.** A member's submission is refused by the policy, not merely hidden; a member with a
  live plan of their own cannot push while the chamber has lapsed; their paid time is preserved for
  the day they are individual again.
- **Hazards.** Hiding the screen is the cheap half and not the requirement: §5.1 says the **server**
  refuses the submission, so the policy change is the deliverable and the UI change is the courtesy.

### Phase 10 — The Lapse Allowance — **Owed**


- **Status.** **Owed** — a lapsed account is stopped by the 50-case free wall instead, and notes and references have no ceiling at all.
- **Discharges.** §5.2, §5.4, §10.8. Task 15.
- **Depends On.** Phase 7 — the allowance is derived from the stored tier and from nothing else.
- **Why Here.** It is the rule the revamp exists for: a lapse must cost a lapsed account the writability of its *extra* rows — not its data, and not its ability to read what it already holds.
- **Objects.** `freeTierCaseLimit` (`lib/core/constants/free_tier.dart`) and its consumption at `lib/shared/widgets/add_edit_case_sheet.dart:1667`; the paywall and Subscription-screen read paths (`paywall_screen.dart:194`, `subscription_details_screen.dart:186`); `firms.tier` / `profiles.tier` as the allowance’s source; the entitlement gate on `push_changes`, left in place as the security boundary.
- **Proof.** Tests over the computed writable set — the most-recently-updated 100/500/1,000 writable, the excess read-only but readable, a deletion freeing a slot, and renewal restoring all at once — with the free-wall tests unchanged for a genuinely free account.
- **The rule.** A lapsed account keeps writing up to the allowance of the **tier it last held**: Pro
  100, Firm 500, Firm Plus 1,000 cases, notes and case references. The **most recently updated** rows
  are the writable set and the excess is read-only — but never hidden: still readable, searchable,
  printable and exportable. Children follow their parent, seed customisation stays unlimited, a
  deletion of a writable row frees a slot, and nothing is deleted. Renewal restores everything at
  once.
- **Client.** The sites, named so this is not a rule without one: The shipped gate is
  `freeTierCaseLimit` (50) in `lib/core/constants/free_tier.dart`, consumed at the Add Case save path
  (`lib/shared/widgets/add_edit_case_sheet.dart:1667`) and surfaced by
  `paywall_screen.dart:194` and `subscription_details_screen.dart:186` — a lapsed Pro or Firm account
  would be stopped at **50** until that check reads the allowance instead. **Notes and case
  references have no gate anywhere today**, so their ceilings are two new checks. A member's
  allowance is the chamber's, so the site reads `firms.tier` rather than the member's own absent
  plan.
- **Server.** The entitlement gate on `push_changes` stays the security boundary; the device cap is
  the usability half.
- **Acceptance.** A lapsed Pro account can write its 100 most-recently-updated cases and no more,
  sees the remainder read-only, loses nothing readable, and regains everything on renewal; a lapsed
  chamber holding 2,500 cases keeps its 500 most recent writable.
- **Hazards.** §5.2's "every device computes the same set" is **false during a lapse**, because
  nothing syncs and each device's ledger is its own — two devices of one chamber can disagree about
  which case is editable. The audit narrowed that claim and it must stay narrowed, and renewal needs
  a stated behaviour for an over-allowance backlog.

### Phase 11 — Dissolution — **Owed**


- **Status.** **Owed** — no dissolve RPC exists.
- **Discharges.** §4.4, §10.4, §10.11. Task 20.
- **Depends On.** Phase 1's `scope_owner_id` and its read rule (**built**) — without the column the
  unscoping step cannot be written at all.
- **Why Here.** It is the only way an owner leaves firm mode without losing the ledger his members wrote, and it is why Phase 1’s `scope_owner_id` exists at all.
- **Server.** One new RPC (`<timestamp>_firm_mode_dissolution.sql`):
  - the **roster-empty precondition**: refuse while `firm_members` holds anyone but the owner, and
    **say how many are left** rather than only refusing;
  - open invites **retired** (`revoked = true`), so a code issued before the dissolve can never
    create a seat in a chamber that no longer exists;
  - every row carrying that `firm_id` has `firm_id` set to null **and `scope_owner_id` set to the
    owner** — so he keeps a complete, ordinary diary. **`conflict_log` is the exception**: a
    colleague's merge diagnostics are neither handed to him nor taken from their author;
  - the `firms` row and the owner's `firm_members` row removed, `profiles.role` back to `individual`
    and `firm_id` nulled, so `delete_my_account()` is no longer refused;
  - the owner's **plan untouched** — dissolving is not a cancellation, and the subscription now
    covers the individual diary.
- **Objects.** A new `<timestamp>_firm_mode_dissolution.sql` RPC; `firm_members` for the roster precondition; `firm_invites` for the retire step; `delete_requests` and `conflict_log` as the tables whose history must stay readable; `profiles.firm_id` / `profiles.role`; `delete_my_account()`’s firm refusal; client: the dissolve action and its copy.
- **Client.** The dissolve action and its count-of-remaining copy.
- **Proof.** A rolled-back SQL run: a dissolve with a member present is refused **with the count**; after the roster empties, the owner reads every row his members wrote and its authors read none; attribution is untouched; `conflict_log` is neither handed over nor taken; `delete_my_account()` unblocks.
- **Acceptance.** A dissolve with a member is refused with the count; after the roster is empty the
  dissolve leaves the owner able to read **every** row his members wrote and its authors unable to;
  attribution is untouched; `delete_my_account()` is unblocked; re-creating a chamber makes a new
  `firm_id`, and the rows are shared into it the way any existing diary is at creation.
- **Hazards.** A bare `firm_id` null **inverts ownership** — the audit's most serious finding: the
  owner could read only the rows he personally authored and the removed members would keep the rest,
  and §2.1's join refusal would then misfire on those rows as "its own diary". The scope owner is not
  optional and is a scope key, not attribution: `user_id`, `created_by` and `last_modified_by` are
  never rewritten.

### Phase 12 — Retention And The Recovery Window — **Owed**


- **Status.** **Owed** — the pair is still 180/150.
- **Discharges.** §5.5, §10.7. Plan: *What Firm Mode Still Owes*. Task 19.
- **Depends On.** Nothing — it is independent and could be taken early, but it is a
- **Why Here.** It is independent of firm mode and could be taken at any point, but it is deliberately placed after the work it protects: the 365-day retention is what makes a dissolve, a restore and a removed member’s re-pull recoverable inside the 335-day window.
- **Server.** No new table and no new policy — one change to `purge_tombstones`’s default and one migration carrying its corrected comments; the rest of the phase is the generator, one Dart constant and the privacy policy.
  change-a-number-everywhere-it-appears phase and belongs after the firm-mode work it protects.
- **Objects.** `purge_tombstones`’s default parameter, its `comment on function` and its file’s header comment (`20260929104000_phase5_indexes_and_tombstone_purge.sql`); the generator’s section label (`tool/generate_all_supabase_sql.dart`); `recoveryOfflineThreshold` and its doc block (`lib/sync/recovery_lock.dart`); the privacy policy’s retention row; the generated `supabase/AllSupabaseSql.md`.
- **Client.** None — the pair lives server-side, in the generator, and in one Dart constant.
- **Proof.** `dart run tool/generate_all_supabase_sql.dart --check` clean with the ledger’s label reading **365**; a test pinning `recoveryOfflineThreshold` at **335**; and a check that the 30-day buffer is intact.
- **The pair.** Retention **365 days**, recovery window **335** — a 30-day buffer preserved so a
  device returning inside 335 days still finds every tombstone it needs.
- **The four places for 365:**
  1. `purge_tombstones`'s default parameter — `20260929104000_phase5_indexes_and_tombstone_purge.sql:71`;
  2. its `comment on function` — same file, line 121;
  3. the file's own header comment — same file, line 9, which states the 180/150 pair;
  4. **the generator's section label** — `tool/generate_all_supabase_sql.dart:172`,
     `'purge_tombstones(180 days) scheduled daily through pg_cron.'`, which `--check` and
     `test/supabase/all_supabase_sql_test.dart` both police.
- **And 150 → 335:** `lib/sync/recovery_lock.dart:43`'s
  `const Duration recoveryOfflineThreshold = Duration(days: 150)` **and** its doc block, which states
  180/150 twice. The lock itself is firm-mode only and never reads entitlement — unchanged.
- **Also in this phase:** the **400-day `mutation_receipts` invariant**, which today is documented
  only and enforced nowhere, so a later cleanup job could break it silently — give it a site where it
  is (re)checked; and the privacy policy's retention placeholder row.
- **Then regenerate:** `dart run tool/generate_all_supabase_sql.dart`, because the ledger is
  generated and rule 13 forbids hand-editing it.
- **Acceptance.** `--check` is clean; the ledger's label reads 365; `recoveryOfflineThreshold` is 335
  with its doc block agreeing; the 365/335 buffer is intact; the receipts invariant has a home.
- **Hazards.** Both numbers are prose in more places than §11 names. Missing the generator label
  fails `--check` outright; missing the in-code comment leaves the file lying about its own constant.

### Phase 13 — Restore Inside A Chamber — **Owed** (partly built)


- **Status.** **Partly Built** — the firm-mode restore bar ships; the three refinements below do not.
- **Discharges.** §6, §10.14. Task 15.
- **Depends On.** Phase 4, for the removal condition this must not trip, and Phase 1, for the scope rule a restored row is stamped into.
- **Why Here.** It is the last place a local file can write into a chamber, and the one that can destroy the diary it has just restored.
- **Server.** None — client only.
- **Objects.** `backup_repository.dart` (`backupTableOrder`), `backup_ownership.dart` (`classifyBackupOwnership` / `stampRowOwnership`), `backup_restore_screen.dart`, and `membershipRevokedProvider` as the condition a stale restored account pair would trip.
- **Proof.** Restore tests against a blank device: no account row written, every restored row stamped into the current chamber with no scope owner, a file naming another firm refused.
- **Already built.** The firm-mode **restore bar** and its ownership rules: the shipped guard blocks a
  restore when the account is premium, has synced **and** still holds user-authored data
  (`backup_restore_screen.dart`), which is what makes the empty-device exception the only one.
- **Owed — three refinements:**
  - **`profiles`, `firms` and `firm_members` are never restored.** They are pull-only caches and the
    server's, not the device's. This is not tidiness: a restored profile naming a dead `firm_id`
    beside a restored `firm_members` row **is** `membershipRevokedProvider`'s own condition, so a
    restore could trigger the removal erase and destroy the diary it had just written. Today the
    snapshot replays **every** portable table including those three.
  - **A restored row's scope is settled, not inherited.** Each restored row is stamped with the
    current chamber's `firm_id` and has `scope_owner_id` cleared; a file whose rows name **another
    firm** is refused outright, because such a row can neither be pushed (`sync_can_write` refuses a
    foreign firm) nor read back, which would make it permanent local-only data.
  - **Attribution is not the restorer's to rewrite.** `user_id`, `created_by` and `last_modified_by`
    are left alone; the existing ownership rule still fills an owner column that names **nobody**,
    which is a hand-filled workbook.
- **Client.** `backup_repository.dart` (`backupTableOrder`), `backup_ownership.dart`
  (`classifyBackupOwnership` / `stampRowOwnership`), `backup_restore_screen.dart`.
- **Acceptance.** A restore onto a blank phone inside a chamber writes no account row, stamps every
  restored row into the current chamber with no scope owner, refuses a file naming another firm, and
  leaves the full pull to run over the restored rows.
- **Hazards.** The three refinements are one decision, not three: clearing the caches without the
  stamping rule re-creates the mixed ledger §1 forbids, and the stamping rule without the foreign-firm
  refusal creates the permanent local-only rows above.

### Phase 14 — Attribution And The Roster — **Owed** (verify rather than rebuild)


- **Status.** **Owed (Verification Only)** — no change is expected; the deliverable is the finding.
- **Discharges.** §9.9. Plan §9's step 9.
- **Depends On.** Phase 3 and Phase 4, for the membership state it renders; nothing else.
- **Why Here.** It is readability rather than correctness, so it sits last among the firm-mode items — but an attribution bug would surface here as a display lie rather than a data fault.
- **Server.** None — this phase writes no SQL.
- **Objects.** The *edited by [Name]* rendering (reading `last_modified_by` / `created_by`) and the Manage Associates roster (Task 20 Phase 1).
- **Client.** `lib/features/accounts_and_profile/presentation/`, plus the case and note rendering that shows attribution.
- **Proof.** A written finding per item — already correct, or added — recorded even when nothing is missing.
- **Hazards.** Treating it as a build phase. If the verification finds nothing missing, closing it **with no change** is the correct outcome, not an empty phase.
- **What it is.** The *edited by [Name]* rendering (reading `last_modified_by` / `created_by`) and
  the owner's roster (Manage Associates) are **readability, not correctness**, and both exist — Task
  20 Phase 1 built the Manage Associates screen and Task 20's permission management built the
  per-member toggles.
- **Deliverable.** A verification pass that confirms each reads the right column and shows the right
  set, and fills **only** what is missing.
- **Acceptance.** A written finding per item: already correct, or added. If nothing is missing, the
  phase closes with the verification recorded and **no change** — that is a pass, not an empty phase.

### Phase 15 — Distribution — **Owed**


- **Status.** **Owed** — the updater ships with no authenticity check.
- **Discharges.** §5.6, §10.10, and the audit's authenticity finding. Task 21.
- **Depends On.** Nothing.
- **Why Here.** Direct distribution is the settled channel, which makes the in-app updater the **only**
  way an update reaches anyone — there is no store to fall back on and no store's signature check
  standing between a user and a bad release.
- **Server.** None — client and docs only.
- **Objects.** `lib/features/settings/data/update_repository.dart`, `update_release.dart`, `presentation/update_flow.dart`, `update_screen.dart`, `update_schedule_card.dart`; the release naming and `FileProvider` grant as they already exist; the readme and the site.
- **Proof.** A test that a tampered or unverifiable release is refused rather than offered to the user.
- **Hazards.** With direct distribution there is no store’s signature check standing behind this, and the updater is the **only** path an update takes — so a failure here is a failure of the whole channel.
- **Owed.** **Update authenticity** — a signed release, or a checksum pinned in the app — so a
  tampered or unverifiable update is refused; and the **install path's docs**: the APK's download
  page, a stated owner, and install instructions that survive Android's unknown-sources prompt.
  Release naming and the `FileProvider` grant already exist.
- **Client.** `lib/features/settings/data/update_repository.dart`, `update_release.dart`,
  `update_flow.dart`, `update_screen.dart`, `update_schedule_card.dart`; the readme and the site.
- **Acceptance.** A tampered or unverifiable release is refused rather than offered; the install path
  is documented and reachable without the app.
- **Note.** If Play is adopted later it is a **build flavour**, not a code change: it switches to Play
  Billing and drops the self-updater, and the 15 % comes off margin rather than being added to the
  customer's price.

---

### Ordering Hazards, Collected

1. **Phase 7 ↔ Phase 8 (the one real ordering defect in this list).** No Firm plan key exists until
   Phase 8, and Phase 7's seat cap and creation gate are unsafe without one. Ship them together, or
   hold Phase 7's two behavioural changes to the end of Phase 8. See Phase 7.
2. **Phase 3's revoke-without-grant trap, still live for 5, 6, 7 and 11.** A revoke that names
   `authenticated` is a lock-out unless a grant follows it, and a passing RPC test does not cover the
   helpers it calls.
3. **`push_changes` is `SECURITY DEFINER`.** It bypasses the column privileges and the RLS policies,
   so enforcement must be a trigger (Phase 5) and **any column a later migration adds is
   client-writable through the RPC unless it is named in the RPC's strip list** (Phase 2's rule).
4. **`purge_tombstones` fails as a whole on a blocked foreign key** (Phase 6). One stale reference
   edit can stop every tombstone on the project from being purged, silently.
5. **Every new migration is registered in two more places** — the generator's hand-maintained
   manifest with a `_groupTitles` entry, and the count literals in
   `test/supabase/migration_applier_test.dart` and `all_supabase_sql_test.dart`.
6. **Every `supabase/tests/*.sql` proof is run wrapped** — several open a PL/pgSQL block rather than
   a transaction, so a bare `psql -f` commits fixture data to the live project.
7. **Phase 4 was only safe after Phase 3** (the audit's sequencing finding): a self-erasing device
   needs the seat-empty refusal first, or an account that kept a diary and joined anyway would have
   it erased with no backup and no confirmation step left to warn them. Built in that order.

### Applying A Phase To The Live Project

The project is `lsthasywrdrhuuxnykau` ("Legal Case Diary") and **only** that project — rule 12.

```bash
flutter analyze                                                   # must be clean
flutter test                                                      # full suite
dart run tool/apply_supabase_migrations.dart                      # apply to the live project

# A rolled-back SQL proof. The wrapper is not optional: several proofs open their own PL/pgSQL
# block, so a bare `psql -f` commits its fixtures.
printf 'begin;\n' | cat - supabase/tests/<proof>.sql <(echo rollback;) \
  | psql "$URL" -v ON_ERROR_STOP=1 --file=-

dart run tool/generate_all_supabase_sql.dart                      # regenerate the ledger (rule 13)
dart run tool/generate_all_supabase_sql.dart --check              # must be clean
python tool/record_version.py --summary "One short, precise sentence."
python tool/record_version.py --check                             # must be OK
```

The completion protocol in `AGENTS.md` governs: fix every error and warning the phase introduced,
record the version with the script and never by hand, and update `docs/currentlyWorking.md` with the
completed phase and the next resume point.

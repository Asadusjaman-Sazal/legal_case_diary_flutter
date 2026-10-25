# Manual verification — Firm shared capacity and device limits

**App version tested:** 0.0.637 or later  
**Checklist version:** 0.0.638  
**Date:** ________  **Tester:** ________  **Result:** ________

---

## 1. What this checklist proves

This is the physical-device pass for the shared firm capacity introduced in
**0.0.635** and the grace countdown in **0.0.636**:

- the firm’s slots (Firm 5, Firm Plus 10, Enterprise 20, owner included) are
  shared between associates and the owner’s own devices;
- the owner’s device allowance follows the number of associates;
- a downgrade’s smaller capacity waits for the **48-hour grace**, warns the
  owner, and then signs out the excess — the owner’s extra devices first, then
  the newest associates;
- a signed-out associate stays a member, shows **Not Signed In**, and can be
  removed or admitted again;
- a pure lapse keeps the last tier’s slots but freezes new joins and does not
  auto-remove anyone;
- a chamber owner cannot buy a 0-seat plan;
- removal and dissolution behave as designed;
- a legacy over-capacity chamber is not mass-signed-out on deploy.

It does **not** repeat the server rules already proved automatically (see §2),
and it does not test the general individual device limit or payment approval
beyond what is needed to prepare a test chamber.

## 2. Already proved automatically (do not repeat)

| Proof | What it covers |
|---|---|
| `supabase/tests/firm_capacity_test.sql` (`CAPACITY OK`) | Slot map, owner/associate/signed-out device caps, join invariant, freeze, `already_in_firm`, owner sign-out/admit, trim order, legacy no-trim, removal and orphan safety |
| `test/features/firm_capacity_test.dart` | The client capacity resolver: used/seated, owner cap, reserved first device, pending shrink, grace boundary |
| `test/supabase/firm_capacity_parity_test.dart` | Tier slot counts and trim/join invariants pinned to the SQL |
| `test/supabase/device_cap_parity_test.dart` | Owner/associate/flagged device-cap arms |
| `test/features/manage_associates_test.dart` | **Not Signed In**, Admit Again, roster actions |
| `supabase/tests/firm_mode_join_gate_test.sql`, `firm_mode_stored_tier_test.sql`, `subscription_ladder_test.sql`, `firm_removal_test.sql`, `device_limit_test.sql` | The existing join, tier, ladder, removal and device rules |

Use this checklist for what only real devices, real Realtime and the real
scheduler can show: the actual sign-out screens, the phone-to-phone propagation,
the 15-minute sweep, and the 48-hour boundary without waiting two days.

## 3. Safety rules — read first

- [ ] **Never use the live owner’s chamber.** Create a dedicated **test owner**
      account and a chamber named `TEST — CAPACITY — <date>`.
- [ ] Use **test phones** (or Windows installs) and **test associate accounts**
      only. A capacity sign-out and a removal erase the device’s local copy.
- [ ] In Supabase, confirm the project is **`lsthasywrdrhuuxnykau`
      (“Legal Case Diary”)**. Never run anything, read anything or open any
      branch/log on **`ykbwzodadijtiizobehk` (“Swanirvor-23”)**.
- [ ] The SQL shortcuts in §12 are **live writes**. Use the test chamber’s id
      and name in every `where`; never run the all-firms sweep on production.
- [ ] Test payments are real rows in the payment ledger and cannot be deleted.
      Use a clearly named test owner and a test TrxID; approve only that
      submission in the Admin Panel. Do not use the live owner’s account.
- [ ] Record the original values before a SQL update, and dissolve the test
      chamber (or restore the values) at the end.
- [ ] Do not run the manual tests against real client data or a chamber holding
      real cases.

## 4. Prerequisites

### Accounts

- [ ] A dedicated **test owner** with a live **Firm** plan for Scenarios
      1–3, 10–12. If the test owner is Firm Plus/Enterprise, either use a
      separate Firm test owner or run the Firm-numbered scenarios after the
      downgrade in Scenario 4; the same rules apply with different numbers.
- [ ] A dedicated **Firm Plus test owner** for Scenarios 4–9 (the downgrade to
      Firm and the lapse/countdown). If you only have one test owner, the Firm
      owner can be upgraded to Firm Plus for this pass; the payment is recorded.
- [ ] **Six empty associate accounts** for the basic pass (four to fill Firm,
      one for the fifth refusal, one spare), and **five empty associate
      accounts** on the Firm Plus chamber for the downgrade pass.
- [ ] **One account for a second chamber** if you want to test the
      `already_in_firm` refusal; otherwise the SQL proof covers it.

### Devices

- [ ] **Owner devices:** at least **three** installs for the owner (three Android
      phones, or two phones plus a Windows install). The app supports Windows,
      so a desktop install counts as a device.
- [ ] **Associate devices:** one per associate; a second phone for one associate
      to check the one-device cap.
- [ ] Every device can reach the internet for the sign-out and Realtime checks.
      An offline device is valid too, but it learns on its next launch instead
      of immediately; note which case you observed.

### Access and tools

- [ ] Latest app build installed on every test device (Settings → About shows
      the version).
- [ ] The Supabase dashboard for **`lsthasywrdrhuuxnykau`**, with SQL editor
      access. The SQL editor runs as the project owner and can call the
      internal capacity functions.
- [ ] The Admin Panel in the app, to approve the test payment(s).
- [ ] This document open on a second screen or printed.

### Test data sheet

Fill this in before starting:

| Item | Value |
|---|---|
| Test owner e-mail | |
| Firm chamber name | `TEST — CAPACITY — ____` |
| Firm id (from SQL, §12.1) | |
| Owner’s own user id | |
| Associate 1 e-mail / device | |
| Associate 2 e-mail / device | |
| Associate 3 e-mail / device | |
| Associate 4 e-mail / device | |
| Associate 5 e-mail / device | |
| Spare associate e-mail | |
| Pre-created invite codes | |
| Original firm tier / expiry / pending | |
| Original owner devices (labels) | |

## 5. Setup

1. [ ] Sign in as the test owner on **owner device A**.
2. [ ] Create the chamber (Manage Associates → Create Firm) named
       `TEST — CAPACITY — <date>`.
3. [ ] Confirm the plan is the intended one (Manage Plan shows the tier and
       expiry). For the Firm Plus pass, buy/approve Firm Plus first.
4. [ ] Generate **five invite codes** while the chamber is empty and keep them
       for the tests that need a code at full capacity (the Add Associate
       button is disabled once the chamber is full).
5. [ ] Note the firm id and the owner’s user id with §12.1.
6. [ ] Sign in as each associate only when a scenario tells you to; each
       associate’s diary must be empty.

---

## 6. Scenarios

### Scenario 1 — The owner alone uses the whole plan

**Setup:** an empty Firm chamber, owner device A signed in.

- [ ] Open **Manage Plan**. The **Seats and Devices** meter reads **1 of 5**
      (the owner’s one signed-in device).
- [ ] Open **Account & Profile → Devices**. The owner’s device list shows
      **1 of 5 devices in use** (the owner’s dynamic cap is 5 while there are no
      associates).
- [ ] Open **Manage Associates**. The capacity card reads **1 of 5** and the
      **Add Associate** button is enabled.

**Expected:** no associate can be added yet? No — the Add button is enabled
because four associates fit: 0 associates + 1 owner device + 1 new associate =
2 ≤ 5. Proceed to Scenario 2.

### Scenario 2 — Two associates and three owner devices

1. [ ] Invite and join **Associate 1** on their phone using one pre-created code.
2. [ ] Invite and join **Associate 2** on their phone.
3. [ ] Sign the owner in on **owner device B** and **owner device C**.
4. [ ] Open **Manage Plan**.

**Expected:**

- [ ] **Seats and Devices** reads **5 of 5**: 2 associates + 3 owner devices.
- [ ] **Devices** on the owner’s phone reads **3 of 3 devices in use**.
- [ ] Each associate’s **Devices** screen reads **1 of 1**.
- [ ] The capacity card reads **5 of 5**.

### Scenario 3 — The owner’s fourth device is refused

- [ ] Sign the owner in on a **fourth** install (owner device D).

**Expected:**

- [ ] The **Device Limit Reached** screen appears, naming a cap of **3** and
      listing the three current devices.
- [ ] Signing out one of the three (or removing it from the owner’s Devices
      screen) lets the fourth in; the cap is still 3.
- [ ] The owner’s first device is never the one automatically evicted by this
      flow; the app asks the owner to choose.

**Cleanup for this scenario:** sign the owner out of devices B, C and D, leaving
only owner device A, so the next scenarios start from one owner device.

### Scenario 4 — The fifth associate is refused, and the server agrees

With owner device A and **four** associates:

- [ ] Invite/join **Associate 3** and **Associate 4**.
- [ ] Open **Manage Associates**.

**Expected:**

- [ ] The capacity card reads **5 of 5** (4 associates + 1 owner device).
- [ ] **Add Associate** is **disabled** and the reason reads
      **“No free slot: the last slot is for your own device.”**
- [ ] Attempt to redeem one of the **pre-created fifth codes** on the spare
      associate’s phone.

**Expected on the spare phone:** the join is refused with
**“This firm’s plan has 5 seats and they are all in use. Ask the owner to remove
an associate or sign out one of their own devices.”** No membership is created
and the code is not consumed.

- [ ] Check the spare account’s profile is still an individual (no firm in
      Account & Profile / Manage Associates shows the create-firm screen).

**Optional — one chamber per account.** If you have a second test chamber, have
an associate of this chamber redeem a code for the other chamber. The join is
refused with **“You are already in a firm. Ask that firm’s owner to remove you
before joining another.”**, the code is left unused, and the first membership
is unchanged.

### Scenario 5 — An associate’s second device is refused

- [ ] Sign **Associate 1** in on a second phone.

**Expected:**

- [ ] The **Device Limit Reached** screen appears with a cap of **1**; the first
      phone keeps working.
- [ ] Signing the second phone out (or removing the first) is the only way to
      move the slot; the existing seven-day idle rule is unchanged.

### Scenario 6 — A downgrade warns, and the owner chooses during the grace

Use the **Firm Plus test chamber** (10 slots). This scenario needs a live
Firm Plus plan and a test payment for the Firm downgrade.

1. [ ] Fill the chamber with **five associates** on their phones and keep the
       owner on **one** device.
2. [ ] As the owner, open **Subscription Plans** and choose **Firm**.
3. [ ] Confirm the change dialog, submit the test payment, and approve it in
       the **Admin Panel**.
4. [ ] Open **Manage Plan** and **Manage Associates** after the approval.

**Expected:**

- [ ] The chamber remains on **Firm Plus** (10 slots) until the deadline; sync
      and joins are unchanged.
- [ ] The capacity card shows **Capacity Changes Soon** with the date, the
      current associates/devices and the slots that will remain (5).
- [ ] The change dialog’s date is the current expiry **plus 48 hours** (not the
      expiry itself).
- [ ] During the grace, open the member sheet for a **specific associate** and
      tap **Sign Out Devices**; confirm.
- [ ] That associate’s phone receives the sign-out within seconds (online) and
      shows **“Your firm no longer has a slot for this device …”**; the local
      copy is erased.
- [ ] The roster shows that associate as **Not Signed In**; their membership and
      seat remain.
- [ ] The owner’s own devices are untouched during the grace.

**If the member sheet has no Sign Out Devices action:** the action appears only
while a shrink is pending or the chamber is over capacity. Check that the
downgrade is actually queued (Manage Plan / capacity card) and refresh the
account (pull or relaunch) before concluding it is missing.

### Scenario 7 — The 48-hour shortcut, and the trim

The real 48-hour wait is impractical. Use the **test chamber only** and the
per-firm shortcut in §12.3; do not run the all-firms sweep.

- [ ] Before the shortcut, note the associates’ join order (the last joined is
      the newest).
- [ ] Run §12.3 (`tier_pending_from` into the past and
      `rebalance_firm_capacity('<firm id>')`).
- [ ] Force the app to refresh: **Settings → Online Sync → Sync Now**, or
      relaunch, then reopen Manage Plan / Manage Associates.

**Expected (five associates, one owner device, no owner choice):**

- [ ] The chamber is now on **Firm** (5 slots).
- [ ] The newest associate is **Not Signed In**; their phone shows the capacity
      screen and is signed out; the other four associates keep working.
- [ ] The owner’s single device stays signed in.
- [ ] The capacity card shows the over-capacity state and the signed-out count.
- [ ] No new associate can join until the owner removes someone; the Add button
      remains disabled.

**Expected (owner had three devices, four associates):**

- [ ] The trim removes the owner’s **two least recently used** devices first;
      the current device stays.
- [ ] The two revoked devices show the capacity screen; the Devices screen shows
      the remaining one of one.
- [ ] No associate is signed out in this case, because four associates fit in
      the five slots beside the owner’s one device.
- [ ] The trim result JSON (§12.3) reports `owner_devices_trimmed = 2` and
      `associates_signed_out = 0`.

**A note on labels after the shortcut.** The SQL shortcut changes the firm’s
effective tier; the Manage Plan screen may still print the **stored** plan name
(Firm Plus) until a new purchase updates it. The **Seats and Devices** meter,
the capacity card and the enforcement all use the effective Firm tier (5), so
those are the values to check here.

### Scenario 8 — Signed-out member: admit or remove

Using the signed-out associate from Scenario 7:

- [ ] Open the member’s sheet. The note explains the capacity sign-out and the
      buttons **Admit Again** / **Remove From Firm**.
- [ ] Tap **Admit Again** while the chamber is still over capacity.

**Expected:** the server refuses with the seat message; the member is not
admitted; the roster label stays.

- [ ] Remove one **seated** associate (confirm the removal). Then admit the
      signed-out associate again.

**Expected:** the admit succeeds, the label clears, and the member can sign in
again on one device; the chamber pulls its data on sign-in.

- [ ] Sign the admitted member in on a phone. The app should let them in (cap 1)
      and the chamber data should return.

### Scenario 9 — Removal ends membership but keeps the login

Use an associate you are prepared to lose (a test account):

- [ ] Note one case the associate authored in the chamber (or create one while
      they are signed in).
- [ ] As the owner, remove that associate and confirm.
- [ ] Watch the associate’s phone.

**Expected:**

- [ ] The phone shows **“The firm owner removed this account …”** and erases the
      local chamber copy.
- [ ] The membership row is gone; the seat is free; the Add Associate button is
      enabled again if capacity allows.
- [ ] The associate’s login still works. Signing in shows an individual account,
      not the chamber; the chamber-authored case is still visible to the owner
      and not to the removed member.
- [ ] The removed member can join another chamber with the same login (their
      diary is empty), or stay individual.

### Scenario 10 — Pure lapse: frozen joins, no auto-removal

Use the **Firm/Firm Plus test chamber** with at least two associates and one
owner device. Use §12.4 for the grace and §12.5 for the expired state.

- [ ] Set the firm expiry **one hour in the past** (§12.4). Refresh the app.
- [ ] Open the subscription banner and Manage Associates.

**Expected during the grace:**

- [ ] The banner shows **“Your subscription expired. Renew to avoid losing sync
      access.”** and the live countdown **“Sync stops in …”** (see Scenario 11).
- [ ] A new invite code still joins (inside the grace); the chamber syncs.
- [ ] The capacity card does not say frozen yet.

- [ ] Set the firm expiry **49 hours in the past** (§12.5). Refresh/relaunch.
- [ ] Attempt a new associate join with a pre-created code.

**Expected after the grace:**

- [ ] The join is refused with **“This firm’s subscription has ended, so no new
      associate can join until the owner renews.”**; the code is not consumed.
- [ ] **Add Associate** is disabled with the frozen note.
- [ ] Existing associates and their seats are untouched; no one is signed out by
      a pure lapse.
- [ ] Existing devices stay signed in; a reinstall within the slot allowance
      still works.
- [ ] The owner can still remove devices and associates and dissolve the firm.
- [ ] The app stops syncing and shows the expired banner; the data is still
      readable locally.

### Scenario 11 — The 48-hour countdown

- [ ] Set the firm expiry to **47 hours 59 minutes in the past** (§12.6) and
      refresh the app.
- [ ] Open any screen carrying the app-wide subscription banner.

**Expected:**

- [ ] The grace banner shows a countdown of about **00:01:00** (hours, minutes,
      seconds), updating every second, in the app’s language digits.
- [ ] After it reaches **00:00:00**, the banner changes to the red expired
      message without a relaunch; the sync is off.
- [ ] The countdown never exceeds **48:00:00**.

### Scenario 12 — A chamber owner cannot buy a 0-seat plan

- [ ] As the chamber owner, open **Subscription Plans**.
- [ ] Try the **Starter** and **Pro** cards.

**Expected:**

- [ ] Both cards are greyed/locked for the owner; tapping shows
      **“Dissolve your chamber before choosing an individual plan.”**
- [ ] The Firm, Firm Plus and Enterprise cards remain available; no checkout is
      reached for Starter/Pro.
- [ ] As an **associate**, the plan cards are readable but every buy action is
      locked with the firm-owner message.

### Scenario 13 — Dissolve

- [ ] Remove every associate, including the signed-out ones.
- [ ] Open Manage Associates → Firm Management → **Dissolve Firm**.
- [ ] Confirm.

**Expected:**

- [ ] The dissolve is offered only when the roster is empty; with a signed-out
      member still listed it is blocked with the member count.
- [ ] After dissolving: the chamber, its logo and its memberships are gone; the
      owner is an individual; the chamber’s ledger is the owner’s own; the plan
      remains.
- [ ] The capacity card, Manage Associates and the firm header are gone; the
      owner’s Account & Profile no longer shows a Firm section.

### Scenario 14 — Legacy over-capacity is not mass-signed-out

Use the test chamber **after** all other scenarios and a direct tier change
(§12.7) — test only.

- [ ] With five associates on a Firm Plus chamber, set the firm tier directly to
      `firm` **without** a pending shrink (§12.7). Refresh/relaunch.
- [ ] Open Manage Associates.

**Expected:**

- [ ] The capacity card shows the over-capacity state (more associates than the
      plan allows) and the owner is told to remove associates.
- [ ] **No** associate is automatically signed out, because no queued shrink has
      started.
- [ ] `firm_capacity_trim_due('<firm id>')` is false and
      `firm_capacity_needs_trim` is true in SQL (§12.8).
- [ ] The owner removes associates until the roster fits; the Add button returns
      only when a slot frees.

### Scenario 15 — Cron and Realtime

- [ ] Confirm the job exists (§12.9):
      `rebalance-firm-capacity`, `*/15 * * * *`.
- [ ] With a queued shrink that has started, wait for the next quarter hour
      **without** running the per-firm shortcut. Watch the owner devices and the
      newest associate.

**If Scenario 7 already ran the trim**, the chamber has nothing left to trim and
the cron will correctly do nothing. To test the sweep, put the test chamber back
into a due state first — for example, add a new associate beyond the effective
slot count (or repeat §12.3’s pending setup with a fresh over-capacity state) and
then wait for the next quarter hour **without** calling the per-firm function.

**Expected:**

- [ ] The trim runs within 15 minutes and produces the same result as
      Scenario 7.
- [ ] The member’s phone and the owner’s extra device receive the revocation
      while online and show the relevant screen; no manual refresh is needed.
- [ ] A device that is offline learns on its next launch (note this if tested).

---

## 7. SQL shortcuts

The SQL editor runs as the project owner. Every statement below is limited to
the test chamber by **both id and name**. Never use the live chamber.

### 12.1 Find the test chamber and ids

```sql
select f.id            as firm_id,
       f.name,
       f.owner_id,
       f.tier,
       f.tier_pending,
       f.tier_pending_from,
       f.subscription_expiry
  from public.firms f
 where f.name like 'TEST — CAPACITY%';
```

Record the `firm_id` and `owner_id` in the test data sheet.

### 12.2 Check the capacity picture

```sql
select public.firm_capacity_usage('<FIRM_ID>') as usage,
       public.firm_capacity_needs_trim('<FIRM_ID>') as needs_trim,
       public.firm_capacity_trim_due('<FIRM_ID>') as trim_due;
```

- `usage` shows slots, associates, seated, signed_out, owner devices, the owner
  cap, committed and active usage, over, frozen.
- `needs_trim` is true while active usage is over.
- `trim_due` is true only while a **lower** pending tier has started.

### 12.3 Force the queued downgrade to run now (Scenario 7)

```sql
-- Verify it is the test chamber first.
select id, name, tier, tier_pending, tier_pending_from
  from public.firms
 where id = '<FIRM_ID>'
   and name = 'TEST — CAPACITY — <DATE>';

update public.firms
   set tier_pending = 'firm',
       tier_pending_from = now() - interval '1 minute'
 where id = '<FIRM_ID>'
   and name = 'TEST — CAPACITY — <DATE>';

-- Run only this chamber. This is the live trim: it signs devices out.
select public.rebalance_firm_capacity('<FIRM_ID>');
```

The returned JSON reports `slots`, `associates`, `seated`, `owner_devices`,
`owner_devices_trimmed` and `associates_signed_out`.

Do **not** run `rebalance_all_firm_capacities()` for this shortcut; the cron may
process any other chamber that is due. The per-firm call is the safe target.

### 12.4 Put the chamber inside the grace (Scenario 10)

```sql
update public.firms
   set subscription_expiry = now() - interval '1 hour'
 where id = '<FIRM_ID>'
   and name = 'TEST — CAPACITY — <DATE>';
```

### 12.5 End the grace (Scenario 10)

```sql
update public.firms
   set subscription_expiry = now() - interval '49 hours'
 where id = '<FIRM_ID>'
   and name = 'TEST — CAPACITY — <DATE>';
```

### 12.6 Shorten the countdown to one minute (Scenario 11)

```sql
update public.firms
   set subscription_expiry = now() - interval '47 hours 59 minutes'
 where id = '<FIRM_ID>'
   and name = 'TEST — CAPACITY — <DATE>';
```

### 12.7 Create a legacy over-capacity state (Scenario 14)

```sql
-- Test only: drops the effective tier without a queued shrink.
update public.firms
   set tier = 'firm',
       tier_pending = null,
       tier_pending_from = null
 where id = '<FIRM_ID>'
   and name = 'TEST — CAPACITY — <DATE>';
```

### 12.8 Prove the legacy state is not due (Scenario 14)

```sql
select public.firm_capacity_trim_due('<FIRM_ID>') as trim_due,
       public.firm_capacity_needs_trim('<FIRM_ID>') as needs_trim;
```

Expected: `trim_due = false`, `needs_trim = true`.

### 12.9 Check the cron job (Scenario 15)

```sql
select jobname, schedule, active
  from cron.job
 where jobname = 'rebalance-firm-capacity';

select status, return_message, start_time
  from cron.job_run_details
 where jobid = (select jobid from cron.job
                 where jobname = 'rebalance-firm-capacity')
 order by start_time desc
 limit 3;
```

### 12.10 Check the member and device rows (after sign-out/removal)

```sql
-- The signed-out member keeps membership and firm_id; the removed member does not.
select p.id, p.firm_id, p.role
  from public.profiles p
 where p.id = '<MEMBER_ID>';

select d.device_key, d.revoked_reason, d.revoked_at
  from public.user_devices d
 where d.user_id = '<MEMBER_ID>'
 order by d.created_at desc;

select count(*) as remaining_push_tokens
  from public.device_tokens t
 where t.user_id = '<MEMBER_ID>';

select count(*) as authored_chamber_rows
  from public.cases c
 where c.firm_id = '<FIRM_ID>'
   and c.user_id = '<MEMBER_ID>';
```

Expected: a capacity sign-out leaves `firm_id` set and revokes devices with
reason `capacity`; a removal sets `firm_id = null`, revokes with `removed`, and
keeps the authored chamber rows. Push tokens are 0 in both cases.

Always refresh the app after a SQL change: **Settings → Online Sync → Sync Now**,
or relaunch. The firm row is a pull-only cache.

---

## 8. Cleanup

- [ ] Remove every remaining test associate (including signed-out ones).
- [ ] Dissolve the test chamber(s).
- [ ] Sign out every test device; confirm the local test data is gone.
- [ ] Delete the test owner and associate accounts, or clearly label them for the
      next run. The payment ledger rows cannot be deleted; keep the test owner
      labelled.
- [ ] Confirm the live owner’s chamber was not touched:
      no capacity card changes, no device revocations, no expiry changes.
- [ ] Confirm no test row remains in `firms`, `firm_members` or `firm_invites`
      for the test chamber (the dissolve cascades them).
- [ ] Note any surviving test payments in the test data sheet.

## 9. Results log

| ID | Check | Expected | Actual | Pass / Fail | Notes |
|---|---|---|---|---|---|
| 1 | Owner alone: 1 of 5; Add enabled | | | | |
| 2 | 2 associates + 3 owner devices = 5 of 5 | | | | |
| 3 | Fourth owner device refused at cap 3 | | | | |
| 4 | Fifth associate refused; Add disabled; server `seats_full` | | | | |
| 5 | Associate’s second device refused at cap 1 | | | | |
| 6 | Downgrade warns; date is expiry + 48h; owner can sign out a member | | | | |
| 7 | Trim: owner devices first; newest associate signed out; current device stays | | | | |
| 8 | Admit refuses while full; succeeds after a removal; member signs in | | | | |
| 9 | Removal ends membership, keeps login, frees the seat, authored rows stay | | | | |
| 10 | Grace join succeeds; expired join `firm_lapsed`; no auto-removal | | | | |
| 11 | Countdown ticks; flips to expired at zero; never over 48h | | | | |
| 12 | Starter/Pro locked for a chamber owner | | | | |
| 13 | Dissolve blocked with members; succeeds when empty | | | | |
| 14 | Legacy over-capacity: no auto-trim; owner trims | | | | |
| 15 | Cron within 15 minutes; Realtime sign-outs; offline device on next launch | | | | |

**Final result:** ________  
**Blocking issues found:** ________  
**Follow-ups / notes:** ________

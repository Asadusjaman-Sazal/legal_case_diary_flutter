-- Readable plan names beside the plan_type key, on both payment ledgers.
--
-- `plan_type` on `payment_submissions` and `payment_approval_events` is a
-- machine key (`monthly`, `quarterly`, `half_yearly`, `annual`): `approve_payment`
-- validates it against that exact set and uses a CASE over it to choose both the
-- expected amount and the interval the plan extends by. `plan_name` is its
-- human-readable counterpart — `1 Month`, `3 Months`, `6 Months`, `1 Year` — so
-- the raw tables read plainly in the Supabase table editor and in any SQL output
-- instead of showing a bare key.
--
-- A generated column, not a written one: the value derives from `plan_type` on
-- every read, so it can never drift from the key it names, no data migration is
-- needed (existing rows are computed on the spot) and neither the approval path
-- nor either table's write privileges changes. `plan_type` stays the key.
--
-- The names are English, matching the app's English ARB labels; the app
-- localizes its own display text (Bengali included) from the key. A future plan
-- key this CASE does not yet know shows its raw key rather than a blank.
--
-- Table class: `payment_submissions` and `payment_approval_events` remain
-- server-managed (no client write policy exists for either).

alter table public.payment_submissions
  add column if not exists plan_name text
  generated always as (
    case plan_type
      when 'monthly' then '1 Month'
      when 'quarterly' then '3 Months'
      when 'half_yearly' then '6 Months'
      when 'annual' then '1 Year'
      else plan_type
    end
  ) stored;

comment on column public.payment_submissions.plan_name is
  'Readable name of the plan the submission pays for, derived from plan_type (1 Month / 3 Months / 6 Months / 1 Year). Generated, so it cannot disagree with the key; the app localizes its own labels from plan_type.';

alter table public.payment_approval_events
  add column if not exists plan_name text
  generated always as (
    case plan_type
      when 'monthly' then '1 Month'
      when 'quarterly' then '3 Months'
      when 'half_yearly' then '6 Months'
      when 'annual' then '1 Year'
      else plan_type
    end
  ) stored;

comment on column public.payment_approval_events.plan_name is
  'Readable name of the plan this approval event recorded, derived from plan_type. Generated, so the immutable ledger carries a name that can never disagree with its key.';

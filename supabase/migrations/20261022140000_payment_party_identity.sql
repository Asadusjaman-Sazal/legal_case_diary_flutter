-- ===========================================================================
-- Payment identity snapshots
--
-- The payment tables are read by the payer and by admins for troubleshooting,
-- but a bare user_id forces a join to profiles/auth before anyone can tell who
-- paid. Both now carry the payer's display name and login e-mail as they stood
-- when the row was written.
--
-- A BEFORE INSERT trigger fills them from profiles and overwrites anything a
-- client sends, so the columns stay trustworthy even though `authenticated`
-- holds a table-wide INSERT grant on payment_submissions.
-- ===========================================================================

alter table public.payment_submissions
  add column if not exists full_name text not null default '',
  add column if not exists email text not null default '';

alter table public.payment_approval_events
  add column if not exists full_name text not null default '',
  add column if not exists email text not null default '';

comment on column public.payment_submissions.full_name is
  'Payer display name at submission time, copied from profiles by fill_payment_party_identity(); a snapshot for support, not a live join.';
comment on column public.payment_submissions.email is
  'Payer login e-mail at submission time, copied from profiles by fill_payment_party_identity(); a snapshot for support, not a live join.';
comment on column public.payment_approval_events.full_name is
  'Payer display name at approval time, copied from profiles by fill_payment_party_identity(); a snapshot for support, not a live join.';
comment on column public.payment_approval_events.email is
  'Payer login e-mail at approval time, copied from profiles by fill_payment_party_identity(); a snapshot for support, not a live join.';

-- Backfill existing rows from the profile they already point at. A row whose
-- profile has since been deleted keeps the blank default.
update public.payment_submissions s
   set full_name = p.full_name,
       email = p.email
  from public.profiles p
 where p.id = s.user_id
   and (s.full_name = '' or s.email = '');

-- The approval ledger refuses every UPDATE by its immutability trigger. This
-- one administrative backfill is the exception: the trigger is disabled and
-- re-enabled inside the same transaction, so a failure rolls the disable back
-- and the ledger is never left mutable.
alter table public.payment_approval_events
  disable trigger trg_payment_approval_events_immutable;

update public.payment_approval_events e
   set full_name = p.full_name,
       email = p.email
  from public.profiles p
 where p.id = e.user_id
   and (e.full_name = '' or e.email = '');

alter table public.payment_approval_events
  enable trigger trg_payment_approval_events_immutable;

-- The identity always comes from the row's user_id, never from client text.
-- SECURITY DEFINER so a PostgREST insert made by `authenticated` can read the
-- profile row it is copying.
create or replace function public.fill_payment_party_identity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  select p.full_name, p.email
    into new.full_name, new.email
    from public.profiles p
   where p.id = new.user_id;

  if not found then
    new.full_name := '';
    new.email := '';
  end if;

  return new;
end;
$$;

comment on function public.fill_payment_party_identity() is
  'Copies the payer profile''s full_name and email onto a new payment row; both payment tables keep the snapshot for support.';

drop trigger if exists trg_payment_submissions_party_identity
  on public.payment_submissions;
create trigger trg_payment_submissions_party_identity
  before insert on public.payment_submissions
  for each row
  execute function public.fill_payment_party_identity();

drop trigger if exists trg_payment_approval_events_party_identity
  on public.payment_approval_events;
create trigger trg_payment_approval_events_party_identity
  before insert on public.payment_approval_events
  for each row
  execute function public.fill_payment_party_identity();

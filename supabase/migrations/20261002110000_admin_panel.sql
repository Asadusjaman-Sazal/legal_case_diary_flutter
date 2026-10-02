-- Task 23 — the Admin Panel: who may administer, and the two calls it makes.
--
-- `app_admins` shipped empty with RLS on and **no policy of any kind**, so the
-- app cannot read it — which is correct: it is the registry, and the registry is
-- not the question the app asks. The app asks "am I an admin?", so this adds
-- `is_app_admin()` to answer exactly that for the caller and nothing else.
--
-- The panel then needs two more things it cannot get today. It cannot list
-- anyone's payments (`payment_submissions_select_own` is `user_id = auth.uid()`
-- and there is no admin branch), and it cannot learn who paid: a submission
-- carries only a `user_id`, and `profiles_select_self_or_firm` shows a client
-- its own row or its firm's. Both are answered by one admin-gated RPC that
-- joins the two, rather than by opening `profiles` to every profile in the
-- system — a much wider door than the panel needs.
--
-- Approval needs nothing: `approve_payment` already exists, is already
-- admin-gated and already writes its own immutable audit event. Rejection does
-- not exist, so this adds it — with the who and the when recorded, because a
-- rejection that leaves no trace of who made it is not an audit trail.
--
-- Table class: `app_admins` stays server-managed. Adding two descriptive
-- columns changes nothing about who may read or write it, and they are
-- hand-filled by the owner for each later admin. The new columns are NOT
-- populated from `auth.users` on read — `full_name` comes from the profile the
-- admin typed, and `email` is copied once at migration time below.

-- ---------------------------------------------------------------------------
-- app_admins — descriptive columns for the owner to fill in
-- ---------------------------------------------------------------------------

alter table public.app_admins
  add column if not exists full_name text not null default '';
alter table public.app_admins
  add column if not exists email text not null default '';

comment on table public.app_admins is
  'Server-internal admin registry. No client policy of any kind; grants and revocations happen only through audited migrations or service-role operations. full_name and email are filled in by hand by the owner for each later admin, so a revoked admin can still be identified after the fact.';

-- The rows already in the table predate these columns, so their email would
-- otherwise render as an empty cell in an audit log. `auth.users` is the
-- authority here and only here: this is a migration, not a client read, and it
-- is written once so a later email change does not rewrite the registry's
-- record of who was an admin and when.
--
-- The guard is narrowed rather than lifted. `reject_admin_update()` refuses
-- *every* UPDATE, which was right when a row held nothing but the grant — but
-- the owner now fills `full_name` and `email` in by hand for each later admin,
-- so an untouched trigger would make those columns unwritable. What must stay
-- immutable is the grant itself, so that is exactly what is refused: any UPDATE
-- that touches `user_id`, `granted_at` or `granted_by`. Revocation remains a
-- DELETE, as the function's own message says.
drop trigger if exists trg_app_admins_no_update on public.app_admins;

create or replace function public.reject_admin_grant_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.user_id is distinct from old.user_id
     or new.granted_at is distinct from old.granted_at
     or new.granted_by is distinct from old.granted_by then
    raise exception 'app_admins grant is immutable; revoke by deleting the row'
      using errcode = '55000';
  end if;
  return new;
end;
$$;

comment on function public.reject_admin_grant_change() is
  'Refuses any UPDATE that would change an existing grant (user_id, granted_at, granted_by). The descriptive full_name and email columns stay writable so the owner can fill them in.';

drop trigger if exists trg_app_admins_grant_immutable on public.app_admins;
create trigger trg_app_admins_grant_immutable
  before update on public.app_admins
  for each row
  execute function public.reject_admin_grant_change();

update public.app_admins a
   set email = coalesce(u.email, '')
  from auth.users u
 where u.id = a.user_id
   and a.email = '';

-- ---------------------------------------------------------------------------
-- payment_submissions — who rejected a submission, and when
-- ---------------------------------------------------------------------------

-- `approved_by` / `approved_at` are the approval record and stay untouched by a
-- rejection. These two are the same idea for the other outcome; without them a
-- rejected payment carries no record of which admin turned it down.
alter table public.payment_submissions
  add column if not exists rejected_by uuid references auth.users (id);
alter table public.payment_submissions
  add column if not exists rejected_at timestamptz;

-- ---------------------------------------------------------------------------
-- is_app_admin() — is the caller an admin?
-- ---------------------------------------------------------------------------

-- SECURITY DEFINER so the policy and the RPCs below can ask without the client
-- ever holding a grant on the registry itself.
create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.is_admin();
$$;

comment on function public.is_app_admin() is
  'True when the calling user is a registered admin. The only way a client learns its own admin status — app_admins itself has no client policy, so the row behind this answer is never readable.';

-- ---------------------------------------------------------------------------
-- admin_list_payment_submissions() — every submission, with who it is for
-- ---------------------------------------------------------------------------

create or replace function public.admin_list_payment_submissions()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  -- One row per submission, joined to the payer. The client's RLS policies are
  -- deliberately not consulted: this runs as the owner, which is the point —
  -- it is admin-gated in the function body instead.
  --
  -- `approved_new_expiry` comes from the immutable event rather than from
  -- `profiles.subscription_expiry`, so a Resolved row shows what THIS approval
  -- set, not the account's current expiry several renewals later.
  return (
    select coalesce(
             jsonb_agg(
               jsonb_build_object(
                 'id', s.id,
                 'user_id', s.user_id,
                 'plan_type', s.plan_type,
                 'amount', s.amount,
                 'mfs_provider', s.mfs_provider,
                 'sender_number', s.sender_number,
                 'transaction_id', s.transaction_id,
                 'status', s.status,
                 'admin_notes', s.admin_notes,
                 'submitted_at', s.submitted_at,
                 'approved_at', s.approved_at,
                 'approved_by', s.approved_by,
                 'rejected_at', s.rejected_at,
                 'rejected_by', s.rejected_by,
                 'approved_new_expiry', e.new_expiry,
                 'full_name', p.full_name,
                 'email', p.email,
                 'bar_association', p.bar_association,
                 'membership_no', p.membership_no,
                 'mobile_no', p.mobile_no
               )
               order by s.submitted_at desc
             ),
             '[]'::jsonb
           )
      from public.payment_submissions s
      left join public.profiles p on p.id = s.user_id
      left join public.payment_approval_events e
             on e.payment_submission_id = s.id
  );
end;
$$;

comment on function public.admin_list_payment_submissions() is
  'Admin-only list of every payment submission joined to the payer profile (name, email, bar association, membership number, mobile). Newest first; the client splits pending from resolved and sorts each.';

-- ---------------------------------------------------------------------------
-- admin_reject_payment() — refuse a submission, with a note and a record
-- ---------------------------------------------------------------------------

create or replace function public.admin_reject_payment(
  payment_submission_id uuid,
  rejection_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_submission public.payment_submissions%rowtype;
begin
  if not public.is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  select * into v_submission
    from public.payment_submissions s
   where s.id = payment_submission_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  -- Idempotency and the same escape hatches as approve_payment: an already
  -- resolved submission is never silently re-resolved, and a rejection can
  -- never undo an approval.
  if v_submission.status <> 'pending' then
    return jsonb_build_object(
      'status', 'already_resolved',
      'current_status', v_submission.status
    );
  end if;

  update public.payment_submissions s
     set status = 'rejected',
         admin_notes = nullif(btrim(rejection_note), ''),
         rejected_by = auth.uid(),
         rejected_at = now(),
         updated_at = (extract(epoch from clock_timestamp()) * 1000)::bigint
   where s.id = payment_submission_id;

  -- No audit event: `payment_approval_events` records an entitlement change and
  -- requires a non-null new_expiry, which a rejection does not have. The
  -- rejected_by / rejected_at columns above are the record.
  return jsonb_build_object('status', 'rejected');
end;
$$;

comment on function public.admin_reject_payment(uuid, text) is
  'Admin-only rejection of a pending payment submission: sets status, stores the note, and records which admin refused it and when. Returns already_resolved for an approved or previously rejected submission.';

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

-- Supabase's default privileges grant EXECUTE on a new function in `public`
-- directly to `anon` and `authenticated`, and a direct grant outlives a revoke
-- aimed at PUBLIC — so every function here is re-asserted explicitly.
revoke all on function public.is_app_admin() from public, anon;
grant execute on function public.is_app_admin() to authenticated;

revoke all on function public.admin_list_payment_submissions() from public, anon;
grant execute on function public.admin_list_payment_submissions() to authenticated;

revoke all on function public.admin_reject_payment(uuid, text) from public, anon;
grant execute on function public.admin_reject_payment(uuid, text) to authenticated;

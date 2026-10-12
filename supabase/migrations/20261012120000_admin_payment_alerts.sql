-- Admin payment alerts — the server half of the admin push notification.
--
-- Why this exists. An administrator must learn that a payment request is waiting,
-- and the only shape that is a real notification is one that arrives while the app
-- is closed — which needs a push sender. The sender itself is an Edge Function and
-- is therefore not in this file; what is here is everything it stands on:
--
--   * `device_tokens` — where a signed-in device registers the FCM token it was
--     given. Classified **local operational**: per-device state the client writes
--     about itself, never firm-shared, never part of the delta pull, read only by
--     the sender.
--   * `user_preferences.payment_alerts_enabled` — the per-user toggle from
--     Settings → Notifications, default **on** (an admin who installs the panel
--     wants to hear about payments waiting, and can silence it). The table stays
--     in the per-user preference class: self-only, never firm-shared.
--   * `push_pending_payment_count()` and `push_alert_targets()` — the two reads the
--     sender needs, left to the server's own API role **alone**. Further down, why
--     they are not `security definer` and why the token list must have no client
--     path.
--
-- Whose role that is, said once so the rest of the file can stay quiet about it:
-- the server's role is the one PostgREST uses with the secret key, and Supabase's
-- default privileges grant every new function **and** every new table in `public`
-- to it directly — exactly as they do for `anon` and `authenticated`. That is why
-- the revokes below name only the client roles: naming them is what closes a door,
-- and the server's door is the same default grant the whole schema already relies
-- on. (No migration in this repository names that role in SQL, and the structural
-- contract test fails if one does — a shipped grant is not a credential.)
--   * `pg_net` and one trigger on `payment_submissions`, which posts to the sender
--     whenever a submission appears or its status changes.
--
-- One value is deliberately absent, and is the only manual step: the shared secret
-- the trigger sends and the function compares. It lives in Supabase Vault as
-- `fcm_webhook_secret`, and the same value is set on the function as
-- `FCM_WEBHOOK_SECRET`. Missing, the trigger raises a warning and sends nothing —
-- a missing notification must never be the reason a payment fails.
--
-- What is deliberately not stored: no count, no "last notified at". The sender
-- recomputes the pending count on every change, so the number a notification shows
-- is the number the server holds at that moment and a missed push leaves nothing
-- stale behind.

-- ---------------------------------------------------------------------------
-- device_tokens — one row per device that wants push, written by that device
-- ---------------------------------------------------------------------------

create table if not exists public.device_tokens (
  -- The FCM registration token *is* the identity: it is unique per app install,
  -- and re-registering must update the row rather than add a second one. As the
  -- primary key it also settles what a shared device does — registering the same
  -- token under another account reassigns the row (`on conflict (token) do
  -- update set user_id = ...`), so a phone that changes hands stops feeding the
  -- account that left, which is the same rule Task 23's 0.0.394 leak fix applied
  -- to the panel itself.
  token text primary key,
  -- Deleting the account — Task 12's delete_my_account, or an administrator
  -- removing an abandoned sign-up — takes its tokens with it.
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  -- Server-owned, because a device's clock is not evidence of anything. Refreshed
  -- by the trigger below on every re-registration, so a stale row is visible when
  -- a device stops coming back.
  last_seen_at timestamptz not null default now()
);

comment on table public.device_tokens is
  'Per-device FCM registration tokens: written by the device itself, read only by the admin payment-alert sender through an RPC no client role can execute. A row follows the account, so a device that changes hands stops feeding the previous one.';

-- The fan-set joins on user_id; the primary key already covers the token lookup.
create index if not exists device_tokens_user_id_idx
  on public.device_tokens (user_id);

create or replace function public.touch_device_token()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.last_seen_at := now();
  return new;
end;
$$;

comment on function public.touch_device_token() is
  'Keeps device_tokens.last_seen_at server-timed on every re-registration; a device cannot claim when it was last seen.';

drop trigger if exists trg_device_tokens_touch on public.device_tokens;
create trigger trg_device_tokens_touch
before update on public.device_tokens
for each row execute function public.touch_device_token();

-- Self-only, like every other per-account row. The policies are written with the
-- wrapped `(select auth.uid())` the performance advisor asks for — the documented
-- fix for the existing policies, applied here from the start.
alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_select_own on public.device_tokens;
create policy device_tokens_select_own on public.device_tokens
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists device_tokens_insert_own on public.device_tokens;
create policy device_tokens_insert_own on public.device_tokens
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists device_tokens_update_own on public.device_tokens;
create policy device_tokens_update_own on public.device_tokens
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- DELETE matters as much as the rest: an admin who logs out must stop receiving
-- alerts on that device, so the client removes its own row on the way out.
drop policy if exists device_tokens_delete_own on public.device_tokens;
create policy device_tokens_delete_own on public.device_tokens
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- Supabase's default privileges grant every new table to `anon`, and a direct
-- grant outlives a revoke aimed at PUBLIC — the lesson of 20260929102500 — so
-- `anon` is named. The four verbs a device needs on its own row are granted back;
-- RLS is what narrows them to that row.
revoke all on table public.device_tokens from public, anon;
grant select, insert, update, delete on table public.device_tokens
  to authenticated;
-- The server's own role needs nothing stated: the default grant above covers it,
-- and the sender reads the fan-set through an RPC and prunes a dead token as that
-- role.

-- ---------------------------------------------------------------------------
-- The per-user toggle — Settings → Notifications
-- ---------------------------------------------------------------------------

alter table public.user_preferences
  add column if not exists payment_alerts_enabled boolean not null default true;

comment on column public.user_preferences.payment_alerts_enabled is
  'Whether this account wants a push when a payment request is waiting (Settings → Notifications). Defaults to true. Self-only and writable by its owner through the grants the table already carries, so the toggle needs no privilege of its own; never firm-shared (Rev 2.4 scope contract).';

-- ---------------------------------------------------------------------------
-- The two reads the sender needs — the server's role only
-- ---------------------------------------------------------------------------

-- Both are plain invoker functions on purpose: the only role left able to execute
-- them already bypasses RLS, so a `security definer` wrapper would add escalation
-- surface and buy nothing.

create or replace function public.push_pending_payment_count()
returns integer
language sql
stable
set search_path = pg_catalog, public
as $$
  -- Payments only, by the design decision taken with the user: the unverified
  -- accounts half cannot be event-driven (nothing writes when a sign-up crosses
  -- the 72-hour line), so it is not part of this number.
  select count(*)::integer
    from public.payment_submissions s
   where s.status = 'pending';
$$;

comment on function public.push_pending_payment_count() is
  'How many payment submissions are pending right now — the number a notification carries. Reachable by the server''s own API role only: every client role is revoked.';

create or replace function public.push_alert_targets()
returns table (user_id uuid, token text)
language sql
stable
set search_path = pg_catalog, public
as $$
  -- Administrators with a registered device, minus anyone who turned the toggle
  -- off. A missing preference row means "never touched it", which is the column's
  -- own default of true — hence the coalesce rather than an inner join. ponytail:
  -- an admin whose toggle is off is skipped entirely, including the count-reached-
  -- zero correction; their device clears the stale line when the app is next
  -- opened, and honouring the toggle at all is worth more than that edge.
  select t.user_id, t.token
    from public.device_tokens t
    join public.app_admins a on a.user_id = t.user_id
    left join public.user_preferences p on p.user_id = t.user_id
   where coalesce(p.payment_alerts_enabled, true)
   order by t.created_at;
$$;

comment on function public.push_alert_targets() is
  'Every device belonging to an administrator who has not switched payment alerts off — the fan-set the FCM sender posts to. Reachable by the server''s own API role only: the token list has no client-facing path.';

-- All three are revoked from `public`, `anon` and `authenticated` explicitly: a
-- direct grant to `anon`/`authenticated` (which Supabase's default privileges
-- create) outlives a revoke aimed at PUBLIC, the lesson of 20261009130000. Nothing
-- is granted back, because the server's own role already holds its default grant
-- and no client role may execute any of them.
revoke all on function public.touch_device_token() from public, anon, authenticated;
revoke all on function public.push_pending_payment_count()
  from public, anon, authenticated;
revoke all on function public.push_alert_targets() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The webhook — pg_net posts to the sender when a submission appears or changes
-- ---------------------------------------------------------------------------

-- Installed into `extensions`, not `public`: pg_net's own objects still land in
-- the `net` schema, so `net.http_post` is exactly the same call, and the security
-- advisor's "extension in public" warning stays away. pg_net is not relocatable
-- (`alter extension ... set schema` is refused: "does not support SET SCHEMA"), so
-- an install already sitting in `public` is dropped and made again. The drop is
-- guarded, and it is safe here because nothing used pg_net before this migration —
-- this project had no webhook at all — so there is no queue to lose.
do $$
begin
  if exists (
    select 1 from pg_extension e
     where e.extname = 'pg_net'
       and e.extnamespace <> 'extensions'::regnamespace
  ) then
    drop extension pg_net;
  end if;
end;
$$;

create extension if not exists pg_net with schema extensions;

create or replace function public.notify_admin_payment_alerts()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  -- The allow-listed project (AGENTS.md rule 12) and the deployed function's
  -- slug. Both are public facts — the same host the app already calls — so
  -- neither is a secret; the secret is the Vault value read below.
  c_url constant text :=
    'https://lsthasywrdrhuuxnykau.supabase.co/functions/v1/send-admin-payment-alerts';
  v_secret text;
begin
  select s.decrypted_secret
    into v_secret
    from vault.decrypted_secrets s
   where s.name = 'fcm_webhook_secret';

  if v_secret is null then
    -- Loud, but never fatal: the submission is already saved and a missing
    -- notification is not a reason to fail a payment. This is what an unarmed
    -- hook looks like in the logs.
    raise warning
      'admin payment alerts: vault secret fcm_webhook_secret is missing; nothing sent';
    return null;
  end if;

  perform net.http_post(
    url := c_url,
    body := jsonb_build_object(
      'type', tg_op,
      'table', 'payment_submissions',
      'schema', 'public',
      'record', jsonb_build_object(
        'id', new.id,
        'status', new.status,
        'plan_name', new.plan_name
      ),
      -- A resolution is a correction, not news. The sender compares the two
      -- statuses to decide between waking the device (a request appeared) and
      -- quietly updating the count the notification shows.
      'old_record', case
                      when tg_op = 'UPDATE'
                        then jsonb_build_object('status', old.status)
                      else null
                    end
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    -- Fire and forget: pg_net queues this and makes the call after the
    -- transaction commits, so a slow or unavailable sender never delays the
    -- submission the user is waiting on.
    timeout_milliseconds := 5000
  );

  return null;
end;
$$;

comment on function public.notify_admin_payment_alerts() is
  'Posts {type, table, schema, record, old_record} to the send-admin-payment-alerts Edge Function through pg_net, carrying the Vault-held shared secret. Queues after commit, so it can never delay a payment submission.';

-- Two triggers, not one, because PostgreSQL refuses a WHEN condition that leans
-- on OLD values the moment the same trigger is also an INSERT trigger: "INSERT
-- trigger's WHEN condition cannot reference OLD values" — found by applying this
-- file, not by reading it. The split says the same thing more plainly: a new
-- submission always counts (it is pending by the column's own default), and a
-- status change counts only when the status actually moved, so an unrelated
-- UPDATE — a note being added — sends nothing, because the count it would carry
-- has not changed.
drop trigger if exists trg_payment_submissions_admin_alerts_insert
  on public.payment_submissions;
create trigger trg_payment_submissions_admin_alerts_insert
after insert on public.payment_submissions
for each row
execute function public.notify_admin_payment_alerts();

drop trigger if exists trg_payment_submissions_admin_alerts_update
  on public.payment_submissions;
create trigger trg_payment_submissions_admin_alerts_update
after update on public.payment_submissions
for each row
when (new.status is distinct from old.status)
execute function public.notify_admin_payment_alerts();

revoke all on function public.notify_admin_payment_alerts()
  from public, anon, authenticated;

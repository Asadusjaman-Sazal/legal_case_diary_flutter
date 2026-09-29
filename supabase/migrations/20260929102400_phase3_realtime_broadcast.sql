-- Phase 3 (5/6) — Realtime: notification-only Broadcast from the database.
--
-- The app never subscribes to `postgres_changes` (that ships whole rows and
-- makes Supabase evaluate RLS for every subscriber on every change). Instead a
-- trigger on each domain table sends a tiny `{table, id}` ping to a private
-- topic, and the client answers with a micro delta pull for that one row:
-- `firm:{firm_id}` for firm rows, `user:{user_id}` for individual rows.
--
-- Two project-level prerequisites live in the dashboard, not in SQL:
-- Realtime Authorization must be enabled, and topic access is enforced there
-- through the `realtime.messages` policy below.

create or replace function public.broadcast_row_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_row jsonb := to_jsonb(new);
  v_topic text;
begin
  -- Payload is deliberately tiny: the client pulls the row itself, so RLS and
  -- conflict handling stay on the REST path.
  if v_row ->> 'firm_id' is not null then
    v_topic := 'firm:' || (v_row ->> 'firm_id');
  elsif v_row ->> 'user_id' is not null then
    v_topic := 'user:' || (v_row ->> 'user_id');
  elsif v_row ->> 'requested_by' is not null then
    -- delete_requests carries no user_id; the requester is the scoped party.
    v_topic := 'user:' || (v_row ->> 'requested_by');
  else
    -- Nothing to scope the ping to; stay silent rather than broadcast wide.
    return null;
  end if;

  perform realtime.send(
    jsonb_build_object('table', TG_TABLE_NAME, 'id', v_row ->> 'id'),
    'row_change',
    v_topic,
    true
  );

  return null;
end;
$$;

comment on function public.broadcast_row_change() is
  'AFTER INSERT/UPDATE on every domain table: sends {table, id} to the row''s private firm/user topic.';

do $$
declare
  v_table text;
  v_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references', 'court_categories',
    'case_categories', 'courts', 'steps', 'case_types', 'on_behalfs',
    'delete_requests', 'conflict_log'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop trigger if exists trg_%1$s_broadcast on public.%1$I',
      v_table
    );
    execute format(
      'create trigger trg_%1$s_broadcast after insert or update on public.%1$I '
      'for each row execute function public.broadcast_row_change()',
      v_table
    );
  end loop;
end;
$$;

-- Topic authorization: a client may receive only its own user topic and its
-- firm's topic. Realtime evaluates this policy per subscriber, so the payload
-- above never needs to carry the row itself.
--
-- `realtime.messages` is owned by the Realtime service rather than the
-- migration role, so on a project where the policy cannot be created from SQL
-- the failure is reported and the policy is created from the dashboard instead
-- (see supabase/README.md).
do $$
begin
  execute 'drop policy if exists realtime_messages_read_own_topics '
       || 'on realtime.messages';
  execute $policy$
    create policy realtime_messages_read_own_topics on realtime.messages
      for select to authenticated
      using (public.can_read_topic(realtime.topic()))
  $policy$;
exception
  when insufficient_privilege then
    raise notice
      'Realtime topic policy not created (%). Enable Realtime Authorization and '
      'create realtime_messages_read_own_topics from the dashboard.',
      sqlerrm;
  when undefined_table then
    raise notice
      'realtime.messages is not present on this project (%).',
      sqlerrm;
end;
$$;

-- ===========================================================================
-- Device revocation — tell the device itself, over the channel it already holds.
--
-- A device signed out from another phone used to learn about it on its next
-- launch, resume, refused push or Devices-screen read. The foreground heartbeat
-- added in 0.0.601 covered an idle open app by polling every 30 seconds, but
-- that is two requests a minute for a rare event.
--
-- This migration reuses the app's **one** private Realtime channel. When a
-- `user_devices` row turns revoked, the trigger sends the existing `row_change`
-- `{table,id}` ping on the topic the device actually joined:
--
--   * `firm:<firm_id>` when the owner's profile holds a firm (the app joins the
--     firm topic in firm mode);
--   * `user:<user_id>` for an individual.
--
-- The client routes a `user_devices` ping to a light `touch_device` check, not
-- to the sync pull. The send is deliberately guarded: Realtime is a
-- notification, never the source of truth, so a failed send must not roll back
-- the revocation. The device still discovers it on launch, resume, rejoin or a
-- refused push.
--
-- Only the null -> non-null transition broadcasts. The BEFORE trigger rewrites
-- `last_seen_at` on every update, and re-registration, wipe acknowledgements and
-- the identity backfill must stay silent.
-- ===========================================================================

create or replace function public.broadcast_device_revoked()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_firm_id uuid;
  v_topic text;
begin
  select p.firm_id
    into v_firm_id
    from public.profiles p
   where p.id = new.user_id;

  if v_firm_id is not null then
    v_topic := 'firm:' || v_firm_id::text;
  else
    v_topic := 'user:' || new.user_id::text;
  end if;

  begin
    perform realtime.send(
      jsonb_build_object('table', TG_TABLE_NAME, 'id', new.id::text),
      'row_change',
      v_topic,
      true
    );
  exception when others then
    -- A Realtime failure must never undo a revocation: the device still learns
    -- on resume, on its next join, or from a refused push.
    raise warning 'device revocation broadcast failed (device %, topic %): %',
      new.id, v_topic, sqlerrm;
  end;

  return null;
end;
$$;

comment on function public.broadcast_device_revoked() is
  'AFTER UPDATE on user_devices, only when revoked_at turns from null to non-null: sends the existing row_change {table,id} ping to the owner''s firm topic or user topic, and never fails the revocation.';

drop trigger if exists trg_user_devices_revoked on public.user_devices;
create trigger trg_user_devices_revoked
after update on public.user_devices
for each row
when (old.revoked_at is null and new.revoked_at is not null)
execute function public.broadcast_device_revoked();

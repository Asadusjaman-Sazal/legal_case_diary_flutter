-- Recorded duplicate — `seed_payment_configuration`, applied under a connector
-- version.
--
-- `supabase_migrations.schema_migrations` holds version `20261001102048` with
-- this upsert: the same seed `20261001020000_seed_payment_configuration.sql`
-- ships, applied again through a connector that generated its own timestamp.
-- Nothing was missing; the project history simply had a statement with no file
-- behind it. This file is that statement verbatim, so the two agree.
--
-- The upsert is idempotent (`on conflict (provider) do update`), so re-running
-- it cannot duplicate a row or half-write one, and version `20261001102048` is
-- already recorded on the live project, so the applier skips it there.
--
-- Table class: `payment_configuration` is server-managed configuration —
-- readable by any authenticated client, writable by no client.

insert into public.payment_configuration (provider, receiving_number)
values
  ('bkash', '01835252721'),
  ('nagad', '01835252721'),
  ('rocket', '01835252721')
on conflict (provider) do update
  set receiving_number = excluded.receiving_number,
      is_active = true,
      updated_at = now();

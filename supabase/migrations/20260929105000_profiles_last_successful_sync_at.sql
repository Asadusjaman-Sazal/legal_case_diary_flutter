-- Audit gap closure — `profiles.last_successful_sync_at` (admin analytics only).
--
-- The plan's `profiles` definition lists this column; the live project never had
-- it, and nothing in Part A reads it. It is added here so the schema matches the
-- plan, and it stays NULL until the sync work of Task 17+ writes it.
--
-- Scope, deliberately narrow:
--
--   * It is NOT the extended-offline reset source. That check is per-*device*:
--     each device keeps its own `last_successful_sync_at` in local storage
--     (`sync_metadata` in Drift) and reads that value on reconnect. A shared
--     server column would be masked by the user's other, daily-syncing device,
--     which is exactly the case the check exists for (plan §3). Do not read this
--     column for that purpose.
--   * There is no Drift mirror. `profiles` is a pull-only cache refreshed from
--     the server, and the device value is local operational state — so the app
--     stores it in `sync_metadata`, not on its cached profile row.
--   * It is not client-writable. Phase 3 revoked table-level UPDATE on
--     `profiles` and granted it back for `full_name` only, so a column added by
--     a later migration is closed by default.
--
-- Table class: server-managed/account (`profiles`). Nothing else is touched.

alter table public.profiles
  add column if not exists last_successful_sync_at timestamptz;

comment on column public.profiles.last_successful_sync_at is
  'Admin analytics only. Never the extended-offline reset source: that check is per-device and reads the local sync_metadata value (plan §3).';

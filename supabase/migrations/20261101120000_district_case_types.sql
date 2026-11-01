-- District-scoped case types on the server, starting with the seven Narayanganj
-- CJM types (user request).
--
-- 0.0.784. `public.case_types` gains a nullable `district` and `name_bn`, so a
-- case type can belong to every district in its court category (the defaults,
-- both columns null) or to one district (the seven rows below). The division is
-- derived from the district and is not stored.
--
-- The seven rows are built-in (`is_custom = false`) like the category defaults:
-- every account can read them, and the app filters them to the Narayanganj CJM
-- form. Table class (AGENTS.md rule 4): push/pull domain — no policy or function
-- list changes, because `push_changes` is column-generic and the reference-table
-- RLS already treats built-in rows as the shared baseline.
--
-- Applied to `lsthasywrdrhuuxnykau` ("Legal Case Diary") only — rule 12.

-- ---------------------------------------------------------------------------
-- 1. The two columns
-- ---------------------------------------------------------------------------

alter table public.case_types
  add column if not exists name_bn text,
  add column if not exists district text;

comment on column public.case_types.name_bn is
  'Bengali display name for a case type; null falls back to the app translation of the English name.';
comment on column public.case_types.district is
  'Stable district id for a case type limited to one district; null means every district in its court category. The division is derived, never stored.';

-- The reference tables carry column-level INSERT/UPDATE grants because their
-- table-level write privileges are revoked. A new column starts with none, so
-- the two are added explicitly for the app's own writes; SELECT stays
-- table-level and therefore already covers them.
grant insert (name_bn, district), update (name_bn, district)
  on public.case_types to authenticated;

-- ---------------------------------------------------------------------------
-- 2. The built-in Narayanganj CJM types
-- ---------------------------------------------------------------------------

insert into public.case_types (
  id, court_category_id, case_category_id, name, name_bn, district,
  order_index, is_custom, is_user_modified, user_id, firm_id, updated_at,
  version, synced_at, is_deleted, last_modified_by
) values
  ('casetype-chief_judicial_magistrate-narayanganj', 'chief_judicial_magistrate', null,
   'Narayanganj', 'নারায়ণগঞ্জ', 'narayanganj', 4,
   false, false, null, null,
   (extract(epoch from clock_timestamp()) * 1000)::bigint, 1, null, false, null),
  ('casetype-chief_judicial_magistrate-fatulla', 'chief_judicial_magistrate', null,
   'Fatulla', 'ফতুল্লা', 'narayanganj', 5,
   false, false, null, null,
   (extract(epoch from clock_timestamp()) * 1000)::bigint, 1, null, false, null),
  ('casetype-chief_judicial_magistrate-rupganj', 'chief_judicial_magistrate', null,
   'Rupganj', 'রুপগঞ্জ', 'narayanganj', 6,
   false, false, null, null,
   (extract(epoch from clock_timestamp()) * 1000)::bigint, 1, null, false, null),
  ('casetype-chief_judicial_magistrate-araihajar', 'chief_judicial_magistrate', null,
   'Araihajar', 'আড়াইহাজার', 'narayanganj', 7,
   false, false, null, null,
   (extract(epoch from clock_timestamp()) * 1000)::bigint, 1, null, false, null),
  ('casetype-chief_judicial_magistrate-sonargaon', 'chief_judicial_magistrate', null,
   'Sonargaon', 'সোনারাগাঁও', 'narayanganj', 8,
   false, false, null, null,
   (extract(epoch from clock_timestamp()) * 1000)::bigint, 1, null, false, null),
  ('casetype-chief_judicial_magistrate-bandar', 'chief_judicial_magistrate', null,
   'Bandar', 'বন্দর', 'narayanganj', 9,
   false, false, null, null,
   (extract(epoch from clock_timestamp()) * 1000)::bigint, 1, null, false, null),
  ('casetype-chief_judicial_magistrate-siddhirganj', 'chief_judicial_magistrate', null,
   'Siddhirganj', 'সিদ্ধিরগঞ্জ', 'narayanganj', 10,
   false, false, null, null,
   (extract(epoch from clock_timestamp()) * 1000)::bigint, 1, null, false, null)
on conflict (id) do update set
  court_category_id = excluded.court_category_id,
  case_category_id = excluded.case_category_id,
  name = excluded.name,
  name_bn = excluded.name_bn,
  district = excluded.district,
  order_index = excluded.order_index,
  updated_at = excluded.updated_at
where public.case_types.is_user_modified = false;

-- Merge the retired Contract, Land, Property & Business law category into
-- Civil Law, and order the merged built-ins alphabetically.
--
-- 0.0.771 (user request). `laws.category` has carried two headings since the
-- list was seeded; the app now shows one **Civil Law** heading for Civil
-- Procedure & Evidence and Contract, Land, Property & Business. This migration
-- moves every stored row to `civil_procedure_evidence`, hands the 22 built-in
-- Civil Law names their existing slots in alphabetical order (English first,
-- then Bengali), and normalises the retired ID on every later write so an
-- older phone's queued payload cannot bring the category back.
--
-- Table class (AGENTS.md rule 4): push/pull domain. No table, policy, grant or
-- function list is added or changed: `push_changes` is column-generic and the
-- applier runs this as the database owner.
--
-- Applied to `lsthasywrdrhuuxnykau` ("Legal Case Diary") only — rule 12.

-- ---------------------------------------------------------------------------
-- 1. The retired ID is normalised on arrival
-- ---------------------------------------------------------------------------

create or replace function public.normalize_law_category()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if new.category = 'contract_land_property_business' then
    new.category := 'civil_procedure_evidence';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_laws_normalize_category on public.laws;
create trigger trg_laws_normalize_category
  before insert or update on public.laws
  for each row execute function public.normalize_law_category();

-- ---------------------------------------------------------------------------
-- 2. Move every stored row
-- ---------------------------------------------------------------------------

update public.laws
   set category = 'civil_procedure_evidence'
 where category = 'contract_land_property_business';

-- ---------------------------------------------------------------------------
-- 3. Alphabetise the 22 built-in Civil Law names
-- ---------------------------------------------------------------------------
-- The two former headings' built-ins already hold 22 distinct order_index slots
-- (4…25). The alphabetical rank is handed those same slots, so no other
-- category moves and the seed's 0…56 set stays intact. Custom rows keep their
-- own slots and stay after the seeded list.
--
-- `lower(name) collate "C"` matches the phone's `compareCivilLawNames`:
-- English-script names first, then Bengali-script names, each by Unicode order.

with ranked as (
  select id,
         row_number() over (
           order by (name ~ E'[\u0980-\u09FF]'),
                    lower(name) collate "C",
                    name collate "C",
                    id collate "C"
         ) as name_rank
    from public.laws
   where is_custom = false
     and category = 'civil_procedure_evidence'
),
slots as (
  select id,
         order_index,
         row_number() over (order by order_index) as slot_rank
    from public.laws
   where is_custom = false
     and category = 'civil_procedure_evidence'
)
update public.laws l
   set order_index = s.order_index
  from ranked r
  join slots s on s.slot_rank = r.name_rank
 where l.id = r.id
   and l.order_index is distinct from s.order_index;

-- ---------------------------------------------------------------------------
-- 4. The column's meaning
-- ---------------------------------------------------------------------------

comment on column public.laws.category is
  'One of the six stable law-category IDs (constitution_courts_practice … labour_everyday_regulation). The retired Contract, Land, Property & Business ID is normalised to civil_procedure_evidence (Civil Law) by trg_laws_normalize_category. The heading''s label lives in the app''s ARB files, so it follows the language while the law name does not.';

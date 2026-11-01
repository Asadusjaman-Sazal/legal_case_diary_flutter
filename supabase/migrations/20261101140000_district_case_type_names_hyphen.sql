-- The seven district-scoped Narayanganj CJM case types gain the trailing hyphen
-- every other built-in case type carries (user correction, 0.0.785).
--
-- Their first insert (20261101120000) used the bare names. This migration only
-- corrects those built-in labels in both languages; a row the user edited is
-- preserved by the `is_user_modified` guard, and a tombstone is not revived.
--
-- Applied to `lsthasywrdrhuuxnykau` ("Legal Case Diary") only — rule 12.

update public.case_types as t
set name = v.name,
    name_bn = v.name_bn,
    updated_at = (extract(epoch from clock_timestamp()) * 1000)::bigint
from (values
  ('casetype-chief_judicial_magistrate-narayanganj', 'Narayanganj-', 'নারায়ণগঞ্জ-'),
  ('casetype-chief_judicial_magistrate-fatulla', 'Fatulla-', 'ফতুল্লা-'),
  ('casetype-chief_judicial_magistrate-rupganj', 'Rupganj-', 'রুপগঞ্জ-'),
  ('casetype-chief_judicial_magistrate-araihajar', 'Araihajar-', 'আড়াইহাজার-'),
  ('casetype-chief_judicial_magistrate-sonargaon', 'Sonargaon-', 'সোনারাগাঁও-'),
  ('casetype-chief_judicial_magistrate-bandar', 'Bandar-', 'বন্দর-'),
  ('casetype-chief_judicial_magistrate-siddhirganj', 'Siddhirganj-', 'সিদ্ধিরগঞ্জ-')
) as v(id, name, name_bn)
where t.id = v.id
  and t.is_user_modified = false
  and t.is_deleted = false
  and (t.name is distinct from v.name or t.name_bn is distinct from v.name_bn);

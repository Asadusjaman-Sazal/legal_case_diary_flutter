-- Case Note and Tags on both reference libraries.
--
-- The Case Reference screen and the Admin Panel's Server-wide Case Reference
-- screen gained two fields (user request): a Case Note beside the case summary,
-- and comma-separated Tags that a citation can be searched by. Both are stored
-- as nullable text on both libraries, so every existing citation keeps reading
-- exactly as it was written and simply carries neither until it is edited.
--
-- No function is re-created. `push_changes` validates a payload's keys against
-- the table's own `pg_attribute` list and applies the row through
-- `jsonb_populate_record`, so the new columns are accepted as soon as they
-- exist; the shared table's write grant is table-level, so the new columns
-- inherit it; and the delta pull selects every column.
--
-- Applied to `lsthasywrdrhuuxnykau` ("Legal Case Diary") only — AGENTS.md rule 12.

alter table public.case_references
  add column case_note text,
  add column tags text;

alter table public.shared_case_references
  add column case_note text,
  add column tags text;

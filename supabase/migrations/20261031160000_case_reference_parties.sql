-- The parties to the case on both reference libraries.
--
-- A citation often needs to name the case's parties (for example "State vs.
-- Md. Karim") beside its citation; the Case Reference form gained the field
-- right after **Citation** (user request, 0.0.758). It is nullable text on both
-- libraries, so every existing citation keeps reading exactly as it was written
-- and simply carries none until it is edited.
--
-- No function is re-created. `push_changes` validates a payload's keys against
-- the table's own `pg_attribute` list and applies the row through
-- `jsonb_populate_record`, so the new column is accepted as soon as it exists;
-- the shared table's write grant is table-level, so the column inherits it; and
-- the delta pull selects every column.
--
-- Applied to `lsthasywrdrhuuxnykau` ("Legal Case Diary") only — AGENTS.md rule 12.

alter table public.case_references
  add column parties text;

alter table public.shared_case_references
  add column parties text;

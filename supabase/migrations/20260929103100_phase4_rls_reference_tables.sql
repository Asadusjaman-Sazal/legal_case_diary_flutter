-- Phase 4 (2/3) — RLS for the six editable reference tables.
--
-- All six share one matrix (plan, Row-Level Security Strategy + Rev 2.4 §1):
--
--   SELECT  every authenticated user sees the built-in rows; a custom row is
--           visible to its creator and, in firm mode, to the firm;
--   INSERT  only as yourself, scoped to your own firm (or to no firm);
--   UPDATE  the creator, or a firm member with can_edit — which is also how a
--           firm shares a customization, since the edit lands on a row the
--           whole firm can read;
--   DELETE  never: deletion is a soft delete, guarded by the can_delete
--           trigger from Phase 3.
--
-- One consequence worth stating plainly: a *built-in* row has no creator and no
-- firm, so `user_id = auth.uid()` and `can_edit_firm(firm_id)` are both false
-- for it. Editing a pre-seeded court, step, case type, role, category or case
-- category is therefore a local-only act until the client models it as a custom
-- row — flagged in docs/currentlyWorking.md.

alter table public.court_categories enable row level security;
alter table public.case_categories enable row level security;
alter table public.courts enable row level security;
alter table public.steps enable row level security;
alter table public.case_types enable row level security;
alter table public.on_behalfs enable row level security;

do $$
declare
  v_table text;
  v_tables text[] := array[
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop policy if exists %1$s_select_scoped on public.%1$I',
      v_table
    );
    execute format(
      'create policy %1$s_select_scoped on public.%1$I for select to '
      'authenticated using (is_custom = false or user_id = auth.uid() or '
      'firm_id = public.current_firm_id())',
      v_table
    );

    execute format(
      'drop policy if exists %1$s_insert_own on public.%1$I',
      v_table
    );
    execute format(
      'create policy %1$s_insert_own on public.%1$I for insert to '
      'authenticated with check (user_id = auth.uid() and (firm_id is null or '
      'firm_id = public.current_firm_id()))',
      v_table
    );

    execute format(
      'drop policy if exists %1$s_update_scoped on public.%1$I',
      v_table
    );
    execute format(
      'create policy %1$s_update_scoped on public.%1$I for update to '
      'authenticated using (user_id = auth.uid() or '
      'public.can_edit_firm(firm_id)) with check (user_id = auth.uid() or '
      'public.can_edit_firm(firm_id))',
      v_table
    );
  end loop;
end;
$$;

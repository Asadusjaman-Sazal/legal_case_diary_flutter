-- A requester may withdraw their own pending delete request.
--
-- `delete_requests` carries the ordinary tombstone gate from
-- `20260929102100`: a firm-scoped row may only be soft-deleted by the owner or a
-- member holding `can_delete`. That rule is right for chamber data and wrong for
-- this one row — a member with no `can_delete` is exactly the member who raises a
-- delete request, and the **Withdraw** action the app offers them is that row
-- toggled to `is_deleted`. So the button could never work once the request had
-- reached the server: the trigger refused it with `delete_not_permitted`, the
-- client rolled the withdrawal back, and the requester was told their firm
-- permissions had changed.
--
-- The exception below is the rule the shipped policy already states —
-- `delete_requests_update_scoped` grants the requester their own **still-pending**
-- row ("The requester edits their own still-pending request; a reviewer with
-- can_delete acts on it. Anything else is refused") — and the same rule
-- `sync_can_write`'s delete-request branch spells out for the RPC door. It is
-- keyed on `old.requested_by`, so a decided request cannot be withdrawn after the
-- fact, and on `old.status = 'pending'`, so a review that has already been
-- answered is never erased by the requester. Nothing else changes: every other
-- table, and every decided request, keeps the gate it had.
--
-- Proven by `supabase/tests/delete_request_review_test.sql`.

create or replace function public.enforce_delete_transition()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if old.is_deleted = false and new.is_deleted = true then
    -- Individual rows (no firm) are the creator's own; a firm row needs either
    -- the owner or a member holding can_delete. An associate without it must go
    -- through the delete-request workflow instead — and withdrawing their own
    -- request is that workflow's own exit, so it is allowed by the caller's own
    -- row rather than by a permission they do not have.
    if tg_table_name = 'delete_requests'
       and old.status = 'pending'
       and old.requested_by = auth.uid() then
      return new;
    end if;

    if not public.can_delete_firm(old.firm_id)
       and old.firm_id is not null then
      raise exception 'delete_not_permitted'
        using errcode = '42501',
              hint = 'Requires can_delete in this firm; raise a delete request instead.';
    end if;
  end if;
  return new;
end;
$$;

comment on function public.enforce_delete_transition() is
  'BEFORE UPDATE on the twelve domain tables: refuses is_deleted true unless the caller may delete in the row''s firm (owner or can_delete), with one carrying row excepted — a requester''s own still-pending delete request, which the delete-request workflow lets them withdraw.';

-- The grants are untouched: `create or replace` keeps the function's ACL, and a
-- trigger function needs no EXECUTE privilege of its own.

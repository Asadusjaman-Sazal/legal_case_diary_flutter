-- Task 21 follow-up — the daily payment submission limit is now five.
--
-- `20260929102100_phase3_sync_and_guard_triggers.sql` set the server-side
-- `BEFORE INSERT` rate limit on `payment_submissions` to three per rolling 24
-- hours (and that value still lives there, as history). The limit is now five,
-- so this replaces `enforce_payment_rate_limit()` with the same body and one
-- changed constant: the count, the server-time stamp, the exception and its
-- errcode are untouched. The trigger already points at the function, so
-- `create or replace` is the whole change and the existing grants carry over.
--
-- The client's best-effort UX copy (`paymentLocalSubmissionLimit`) follows to
-- five in the same phase, so the early warning and the authoritative gate agree.
--
-- Table class: `payment_submissions` remains server-managed (no client write
-- policy exists for it), and this runs as the controlled re-issue of a function
-- under its old grants.

create or replace function public.enforce_payment_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  c_daily_limit constant integer := 5;
  v_recent integer;
begin
  -- Server time only: a client-supplied submitted_at is overwritten, never
  -- trusted, and the rolling count reads this column.
  new.submitted_at := now();

  select pg_catalog.count(*) into v_recent
    from public.payment_submissions s
   where s.user_id = new.user_id
     and s.submitted_at > now() - interval '24 hours';

  if v_recent >= c_daily_limit then
    raise exception 'payment_submission_limit_reached'
      using errcode = 'P0001',
            hint = 'Five submissions per 24 hours; the client shows the friendly message.';
  end if;
  return new;
end;
$$;

-- Task 19 Phase 3 — the three-way conflict verdict travels with the conflict.
--
-- `conflict_log` is mirrored to Supabase so a conflict raised on one device can
-- be reviewed on another: Sync Plan §1 says the log "is queued to its Supabase
-- mirror for portability", and the Addendum repeats that the queue metadata must
-- support `mergeable_conflict` from day one.
--
-- Why a column rather than a computed answer: whether a conflict could be merged
-- depends on the three payloads **as they were at detection time** and on the
-- field coupling the detecting client applied. Recomputing it on a second device
-- from its own copy could disagree, and the reviewed verdict would then differ
-- from the one the queue acted on. The client writes it; the mirror carries it.
--
-- `default false` is the safe direction: an old row, or a payload that omits the
-- key, reads as "needs a person" rather than as "safe to merge".

alter table public.conflict_log
  add column if not exists mergeable_conflict boolean not null default false;

comment on column public.conflict_log.mergeable_conflict is
  'True when the detecting client found the local and server changes disjoint and rebased them automatically; false when they overlap, are semantically coupled, or involve a tombstone, so the conflict needs a person.';

-- The local column is the source of the value; the mirror keeps it in step with
-- every other conflict field the client sends through push_changes.

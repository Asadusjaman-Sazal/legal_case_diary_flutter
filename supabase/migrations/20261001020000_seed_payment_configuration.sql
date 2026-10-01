-- Task 21 follow-up — the real MFS receiving number is now known.
--
-- `20261001000000_payment_configuration.sql` created the read-only
-- `payment_configuration` table and deliberately left it **unseeded**, because
-- the real bKash/Nagad/Rocket number was not invented. The firm's actual
-- account is now known, so this migration seeds one row per provider with the
-- same number — the single receiving account for all three channels — through
-- an idempotent upsert so re-running cannot duplicate or half-write it.
--
-- The number is stored in the local 11-digit form the client validates
-- (`isValidBdMobileNumber`: `01` + operator digit + 8 digits); the international
-- `+880…` form would be rejected by that rule and shown to no one.
--
-- Table class: `payment_configuration` is server-managed configuration — still
-- readable by any authenticated client and writable by no client at all. This
-- migration is the controlled admin write that the table's missing write policy
-- reserves for exactly this.

insert into public.payment_configuration (provider, receiving_number)
values
  ('bkash', '01835252721'),
  ('nagad', '01835252721'),
  ('rocket', '01835252721')
on conflict (provider) do update
  set receiving_number = excluded.receiving_number,
      is_active = true,
      updated_at = now();

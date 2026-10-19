-- Applied 2026-10-19 (plain SQL through the connector). Anonymous sign-ins are on, so anyone with the publishable
-- key can mint a user and write rows to their own account; these caps bound what one account can store per row.
alter table public.activity_events add constraint activity_events_payload_size check (pg_column_size(payload) < 65536);
alter table public.receipts add constraint receipts_payload_size check (pg_column_size(payload) < 65536);
alter table public.corrections add constraint corrections_payload_size check (pg_column_size(payload) < 65536);
alter table public.profiles add constraint profiles_state_size check (state is null or pg_column_size(state) < 4194304);

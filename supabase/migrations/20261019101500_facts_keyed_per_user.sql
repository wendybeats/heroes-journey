-- Applied 2026-10-19 (plain SQL through the connector), HER-17 increment 2. Facts are keyed per user, so a change of
-- identity (guest -> an Apple ID that already had an account) can re-append the same facts under the new user without
-- colliding with the guest's rows. Tables were empty.
alter table public.receipts drop constraint receipts_event_id_fkey;
alter table public.corrections drop constraint corrections_event_id_fkey;
alter table public.activity_events drop constraint activity_events_pkey;
alter table public.activity_events add primary key (user_id, id);
alter table public.receipts drop constraint receipts_pkey;
alter table public.receipts add primary key (user_id, submission_id);
alter table public.receipts add constraint receipts_event_fkey foreign key (user_id, event_id) references public.activity_events (user_id, id) on delete cascade;
alter table public.corrections add constraint corrections_event_fkey foreign key (user_id, event_id) references public.activity_events (user_id, id) on delete cascade;
alter table public.profiles drop constraint profiles_profile_id_key;
create index profiles_profile_id on public.profiles (profile_id);

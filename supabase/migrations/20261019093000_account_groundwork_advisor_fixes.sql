-- NOT YET APPLIED (the connector call was declined on 2026-10-19). Advisor fixes: pinned search_path on the trigger
-- functions, RLS auth calls wrapped in a subselect so they evaluate once per query, covering indexes on two foreign keys.
-- Apply from the Supabase SQL editor or ask Claude to apply it through the connector.

create or replace function public.reject_mutation() returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception '% is append-only: insert a correction or an admin fact instead', tg_table_name;
end;
$$;

create or replace function public.touch_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop policy "profiles: own row" on public.profiles;
drop policy "profiles: create own" on public.profiles;
drop policy "profiles: update own" on public.profiles;
drop policy "activity_events: own rows" on public.activity_events;
drop policy "activity_events: append own" on public.activity_events;
drop policy "receipts: own rows" on public.receipts;
drop policy "receipts: append own" on public.receipts;
drop policy "corrections: own rows" on public.corrections;
drop policy "corrections: append own" on public.corrections;

create policy "profiles: own row" on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "profiles: create own" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy "profiles: update own" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "activity_events: own rows" on public.activity_events for select to authenticated using (user_id = (select auth.uid()));
create policy "activity_events: append own" on public.activity_events for insert to authenticated with check (user_id = (select auth.uid()) and inserted_by = 'client');
create policy "receipts: own rows" on public.receipts for select to authenticated using (user_id = (select auth.uid()));
create policy "receipts: append own" on public.receipts for insert to authenticated with check (user_id = (select auth.uid()));
create policy "corrections: own rows" on public.corrections for select to authenticated using (user_id = (select auth.uid()));
create policy "corrections: append own" on public.corrections for insert to authenticated with check (user_id = (select auth.uid()) and inserted_by = 'client');

create index receipts_event on public.receipts (event_id);
create index corrections_event on public.corrections (event_id);

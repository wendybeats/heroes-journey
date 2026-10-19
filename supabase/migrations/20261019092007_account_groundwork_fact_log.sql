-- Applied to project fuwscpmwyaksklwvrohm on 2026-10-19 through the Supabase connector (HER-17).
-- An account is its fact log. Facts are append-only; everything else is derived and rebuildable.

create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  profile_id uuid not null unique,
  state jsonb,
  state_version int not null default 0,
  state_updated_at timestamptz,
  rebuild_required boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.activity_events (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  profile_id uuid not null,
  started_at timestamptz not null,
  source text not null,
  activity_type_id text not null,
  family_id text not null,
  schema_version int not null default 1,
  payload jsonb not null,
  inserted_by text not null default 'client' check (inserted_by in ('client', 'admin')),
  reason text,
  created_at timestamptz not null default now()
);
create index activity_events_user_created on public.activity_events (user_id, created_at);
create index activity_events_user_started on public.activity_events (user_id, started_at);

create table public.receipts (
  submission_id uuid primary key,
  event_id uuid not null references public.activity_events (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  ruleset_id text not null,
  xp int not null,
  level_before int not null,
  level_after int not null,
  payload jsonb not null,
  confirmed_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index receipts_user_event on public.receipts (user_id, event_id);

create table public.corrections (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  event_id uuid not null references public.activity_events (id) on delete cascade,
  kind text not null,
  payload jsonb not null default '{}'::jsonb,
  inserted_by text not null default 'client' check (inserted_by in ('client', 'admin')),
  reason text,
  created_at timestamptz not null default now()
);
create index corrections_user_created on public.corrections (user_id, created_at);

create or replace function public.reject_mutation() returns trigger language plpgsql as $$
begin
  raise exception '% is append-only: insert a correction or an admin fact instead', tg_table_name;
end;
$$;
create trigger activity_events_append_only before update or delete on public.activity_events for each row execute function public.reject_mutation();
create trigger receipts_append_only before update or delete on public.receipts for each row execute function public.reject_mutation();
create trigger corrections_append_only before update or delete on public.corrections for each row execute function public.reject_mutation();

create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();

alter table public.profiles enable row level security;
alter table public.activity_events enable row level security;
alter table public.receipts enable row level security;
alter table public.corrections enable row level security;

create policy "profiles: own row" on public.profiles for select to authenticated using (id = auth.uid());
create policy "profiles: create own" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles: update own" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "activity_events: own rows" on public.activity_events for select to authenticated using (user_id = auth.uid());
create policy "activity_events: append own" on public.activity_events for insert to authenticated with check (user_id = auth.uid() and inserted_by = 'client');
create policy "receipts: own rows" on public.receipts for select to authenticated using (user_id = auth.uid());
create policy "receipts: append own" on public.receipts for insert to authenticated with check (user_id = auth.uid());
create policy "corrections: own rows" on public.corrections for select to authenticated using (user_id = auth.uid());
create policy "corrections: append own" on public.corrections for insert to authenticated with check (user_id = auth.uid() and inserted_by = 'client');

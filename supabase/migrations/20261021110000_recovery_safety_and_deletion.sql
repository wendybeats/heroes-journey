-- HER-14 (2026-10-21): recovery safety and account deletion. Project fuwscpmwyaksklwvrohm; this file is the record.
-- Applied through the connector on 2026-10-21: the profiles columns and size check, guard_profile_state() and its
-- trigger, the reject_mutation() rewrite. NOT applied by the connector: delete_my_account() and its grants (the
-- connector cancels any statement containing DELETE as destructive, even inside a function body). The owner runs
-- that block in the SQL editor; the whole file is idempotent and can be rerun as one.
--
-- 1. A snapshot never destroys another character: when a profile's state is replaced by a different character's
--    archive (a sign-in that kept the phone's character over the account's), the displaced snapshot is kept in
--    previous_state. When the same character uploads an older version than the server holds (a stale second device),
--    the update is refused, so an old device cannot roll an account back.
-- 2. Account deletion in-app (App Store Review 5.1.1(v)): delete_my_account() erases the caller's rows and auth user.
--    The append-only triggers allow deletes only inside that function, through a transaction-scoped setting.

alter table public.profiles add column if not exists previous_state jsonb;
alter table public.profiles add column if not exists previous_state_version int;
alter table public.profiles add column if not exists previous_state_replaced_at timestamptz;
alter table public.profiles drop constraint if exists profiles_previous_state_size;
alter table public.profiles add constraint profiles_previous_state_size check (previous_state is null or pg_column_size(previous_state) < 4194304);

create or replace function public.guard_profile_state() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  old_character text := old.state ->> 'userID';
  new_character text := new.state ->> 'userID';
begin
  if old.state is null or new.state is null then
    return new;
  end if;
  if old_character is distinct from new_character then
    -- a different character takes the snapshot: keep the one it displaces
    new.previous_state := old.state;
    new.previous_state_version := old.state_version;
    new.previous_state_replaced_at := now();
    return new;
  end if;
  if new.state_version < old.state_version then
    raise exception 'stale snapshot: server holds version % for this character, got %', old.state_version, new.state_version
      using errcode = 'serialization_failure';
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_guard_state on public.profiles;
create trigger profiles_guard_state before update of state on public.profiles for each row execute function public.guard_profile_state();

-- The append-only rule, with one exit: erasure of the caller's own account.
create or replace function public.reject_mutation() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and current_setting('heroes.erasure', true) = 'on' then
    return old;
  end if;
  raise exception '% is append-only: insert a correction or an admin fact instead', tg_table_name;
end;
$$;

create or replace function public.delete_my_account() returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not signed in';
  end if;
  perform set_config('heroes.erasure', 'on', true);   -- this transaction only
  delete from public.corrections where user_id = uid;
  delete from public.receipts where user_id = uid;
  delete from public.activity_events where user_id = uid;
  delete from public.profiles where id = uid;
  delete from auth.users where id = uid;
end;
$$;
revoke all on function public.delete_my_account() from public;
revoke all on function public.delete_my_account() from anon;
grant execute on function public.delete_my_account() to authenticated;

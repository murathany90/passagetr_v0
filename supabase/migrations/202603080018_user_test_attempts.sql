create extension if not exists pgcrypto;

create table if not exists public.user_test_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_type text not null check (source_type in ('word', 'grammar', 'reading')),
  source_id text not null,
  score int not null default 0,
  correct_count int not null default 0,
  wrong_count int not null default 0,
  payload_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists ix_user_test_attempts_user_id
  on public.user_test_attempts (user_id, created_at desc);

alter table public.user_test_attempts enable row level security;
grant select, insert on public.user_test_attempts to authenticated;

drop policy if exists user_test_attempts_select_own on public.user_test_attempts;
create policy user_test_attempts_select_own on public.user_test_attempts
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists user_test_attempts_insert_own on public.user_test_attempts;
create policy user_test_attempts_insert_own on public.user_test_attempts
for insert
to authenticated
with check (auth.uid() = user_id);

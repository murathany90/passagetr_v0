create table if not exists public.user_daily_stats (
  user_id uuid not null references auth.users(id) on delete cascade,
  stat_date date not null default current_date,
  words_studied int not null default 0,
  readings_completed int not null default 0,
  grammar_completed int not null default 0,
  streak_count int not null default 0,
  goal_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, stat_date)
);

drop trigger if exists trg_user_daily_stats_updated_at on public.user_daily_stats;
create trigger trg_user_daily_stats_updated_at
before update on public.user_daily_stats
for each row execute function public.set_updated_at();

alter table public.user_daily_stats enable row level security;
grant select, insert, update on public.user_daily_stats to authenticated;

drop policy if exists user_daily_stats_select_own on public.user_daily_stats;
create policy user_daily_stats_select_own on public.user_daily_stats
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists user_daily_stats_insert_own on public.user_daily_stats;
create policy user_daily_stats_insert_own on public.user_daily_stats
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists user_daily_stats_update_own on public.user_daily_stats;
create policy user_daily_stats_update_own on public.user_daily_stats
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

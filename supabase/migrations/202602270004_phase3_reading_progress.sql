create table if not exists public.user_reading_progress (
  user_id uuid not null,
  passage_id uuid not null references public.reading_passages(id) on delete cascade,
  completed boolean not null default false,
  last_idx int not null default 0,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, passage_id),
  constraint user_reading_progress_last_idx_check check (last_idx >= 0)
);

create index if not exists ix_user_reading_progress_user_id
  on public.user_reading_progress (user_id);

create index if not exists ix_user_reading_progress_passage_id
  on public.user_reading_progress (passage_id);

create index if not exists ix_user_reading_progress_completed
  on public.user_reading_progress (completed);

-- Reuse Faz 1 trigger function if available; create if missing.
do $$
begin
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.proname = 'set_updated_at'
      and n.nspname = 'public'
  ) then
    execute $fn$
      create function public.set_updated_at()
      returns trigger
      language plpgsql
      as $body$
      begin
        new.updated_at = now();
        return new;
      end;
      $body$;
    $fn$;
  end if;
end
$$;

drop trigger if exists trg_user_reading_progress_updated_at on public.user_reading_progress;
create trigger trg_user_reading_progress_updated_at
before update on public.user_reading_progress
for each row execute function public.set_updated_at();

alter table public.user_reading_progress enable row level security;

grant select, insert, update on table public.user_reading_progress to authenticated;

drop policy if exists user_reading_progress_select_own on public.user_reading_progress;
create policy user_reading_progress_select_own on public.user_reading_progress
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists user_reading_progress_insert_own on public.user_reading_progress;
create policy user_reading_progress_insert_own on public.user_reading_progress
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists user_reading_progress_update_own on public.user_reading_progress;
create policy user_reading_progress_update_own on public.user_reading_progress
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

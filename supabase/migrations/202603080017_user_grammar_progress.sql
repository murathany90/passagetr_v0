create table if not exists public.user_grammar_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  module_id bigint not null references public.gramer_modulleri(id) on delete cascade,
  page_id bigint references public.gramer_sayfalari(id) on delete set null,
  completed_pages int not null default 0,
  last_page_no int not null default 0,
  completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, module_id)
);

create index if not exists ix_user_grammar_progress_user_id
  on public.user_grammar_progress (user_id);

drop trigger if exists trg_user_grammar_progress_updated_at on public.user_grammar_progress;
create trigger trg_user_grammar_progress_updated_at
before update on public.user_grammar_progress
for each row execute function public.set_updated_at();

alter table public.user_grammar_progress enable row level security;
grant select, insert, update on public.user_grammar_progress to authenticated;

drop policy if exists user_grammar_progress_select_own on public.user_grammar_progress;
create policy user_grammar_progress_select_own on public.user_grammar_progress
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists user_grammar_progress_insert_own on public.user_grammar_progress;
create policy user_grammar_progress_insert_own on public.user_grammar_progress
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists user_grammar_progress_update_own on public.user_grammar_progress;
create policy user_grammar_progress_update_own on public.user_grammar_progress
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

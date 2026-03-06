create table if not exists public.user_reading_bookmarks (
  user_id uuid not null,
  passage_id uuid not null references public.reading_passages(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, passage_id)
);

create table if not exists public.user_reading_favorites (
  user_id uuid not null,
  passage_id uuid not null references public.reading_passages(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, passage_id)
);

create index if not exists ix_user_reading_bookmarks_user
  on public.user_reading_bookmarks(user_id, created_at desc);

create index if not exists ix_user_reading_favorites_user
  on public.user_reading_favorites(user_id, created_at desc);

alter table public.user_reading_bookmarks enable row level security;
alter table public.user_reading_favorites enable row level security;

drop policy if exists reading_bookmarks_select_own on public.user_reading_bookmarks;
create policy reading_bookmarks_select_own on public.user_reading_bookmarks
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists reading_bookmarks_insert_own on public.user_reading_bookmarks;
create policy reading_bookmarks_insert_own on public.user_reading_bookmarks
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists reading_bookmarks_delete_own on public.user_reading_bookmarks;
create policy reading_bookmarks_delete_own on public.user_reading_bookmarks
for delete
to authenticated
using (auth.uid() = user_id);

drop policy if exists reading_favorites_select_own on public.user_reading_favorites;
create policy reading_favorites_select_own on public.user_reading_favorites
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists reading_favorites_insert_own on public.user_reading_favorites;
create policy reading_favorites_insert_own on public.user_reading_favorites
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists reading_favorites_delete_own on public.user_reading_favorites;
create policy reading_favorites_delete_own on public.user_reading_favorites
for delete
to authenticated
using (auth.uid() = user_id);

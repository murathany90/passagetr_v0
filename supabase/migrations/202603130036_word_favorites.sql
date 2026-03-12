create table if not exists public.user_word_favorites (
  user_id uuid not null,
  word_id uuid not null references public.words(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, word_id)
);

create index if not exists ix_user_word_favorites_user
  on public.user_word_favorites(user_id, created_at desc);

alter table public.user_word_favorites enable row level security;

drop policy if exists word_favorites_select_own on public.user_word_favorites;
create policy word_favorites_select_own on public.user_word_favorites
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists word_favorites_insert_own on public.user_word_favorites;
create policy word_favorites_insert_own on public.user_word_favorites
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists word_favorites_delete_own on public.user_word_favorites;
create policy word_favorites_delete_own on public.user_word_favorites
for delete
to authenticated
using (auth.uid() = user_id);

create or replace function public.apply_user_word_favorite_event(
  p_event_id text,
  p_word_id uuid,
  p_should_favorite boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted boolean;
begin
  v_inserted := public.mark_sync_event_processed(
    p_event_id,
    'user_word_favorites',
    p_word_id::text
  );

  if not v_inserted then
    return;
  end if;

  if coalesce(p_should_favorite, false) then
    insert into public.user_word_favorites (user_id, word_id)
    values (auth.uid(), p_word_id)
    on conflict (user_id, word_id) do nothing;
  else
    delete from public.user_word_favorites
    where user_id = auth.uid()
      and word_id = p_word_id;
  end if;
end;
$$;

grant execute on function public.apply_user_word_favorite_event(text, uuid, boolean) to authenticated;

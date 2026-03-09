create table if not exists public.processed_sync_events (
  event_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null,
  entity_id text not null,
  processed_at timestamptz not null default now()
);

create or replace function public.pull_content_changes(
  p_scope text,
  p_after_id bigint default 0,
  p_limit integer default 100
)
returns table (
  id bigint,
  scope text,
  entity_type text,
  entity_id text,
  operation text,
  payload_json jsonb,
  changed_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ccl.id,
    ccl.scope,
    ccl.entity_type,
    ccl.entity_id,
    ccl.operation,
    ccl.payload_json,
    ccl.changed_at
  from public.content_change_log ccl
  where ccl.scope = p_scope
    and ccl.id > p_after_id
  order by ccl.id asc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

create or replace function public.mark_sync_event_processed(
  p_event_id text,
  p_entity_type text,
  p_entity_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.processed_sync_events (
    event_id,
    user_id,
    entity_type,
    entity_id
  )
  values (
    p_event_id,
    auth.uid(),
    p_entity_type,
    p_entity_id
  )
  on conflict (event_id) do nothing;

  return found;
end;
$$;

create or replace function public.apply_user_reading_progress_event(
  p_event_id text,
  p_passage_id uuid,
  p_last_idx int,
  p_completed boolean default false
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
    'user_reading_progress',
    p_passage_id::text
  );

  if not v_inserted then
    return;
  end if;

  insert into public.user_reading_progress (
    user_id,
    passage_id,
    completed,
    last_idx,
    last_seen_at
  )
  values (
    auth.uid(),
    p_passage_id,
    coalesce(p_completed, false),
    greatest(0, coalesce(p_last_idx, 0)),
    now()
  )
  on conflict (user_id, passage_id) do update
  set completed = public.user_reading_progress.completed or coalesce(excluded.completed, false),
      last_idx = greatest(public.user_reading_progress.last_idx, excluded.last_idx),
      last_seen_at = greatest(public.user_reading_progress.last_seen_at, excluded.last_seen_at);
end;
$$;

create or replace function public.apply_user_bookmark_event(
  p_event_id text,
  p_passage_id uuid,
  p_should_bookmark boolean
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
    'user_reading_bookmarks',
    p_passage_id::text
  );

  if not v_inserted then
    return;
  end if;

  if coalesce(p_should_bookmark, false) then
    insert into public.user_reading_bookmarks (user_id, passage_id)
    values (auth.uid(), p_passage_id)
    on conflict (user_id, passage_id) do nothing;
  else
    delete from public.user_reading_bookmarks
    where user_id = auth.uid()
      and passage_id = p_passage_id;
  end if;
end;
$$;

create or replace function public.apply_user_favorite_event(
  p_event_id text,
  p_passage_id uuid,
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
    'user_reading_favorites',
    p_passage_id::text
  );

  if not v_inserted then
    return;
  end if;

  if coalesce(p_should_favorite, false) then
    insert into public.user_reading_favorites (user_id, passage_id)
    values (auth.uid(), p_passage_id)
    on conflict (user_id, passage_id) do nothing;
  else
    delete from public.user_reading_favorites
    where user_id = auth.uid()
      and passage_id = p_passage_id;
  end if;
end;
$$;

grant execute on function public.pull_content_changes(text, bigint, integer) to authenticated;
grant execute on function public.apply_user_reading_progress_event(text, uuid, int, boolean) to authenticated;
grant execute on function public.apply_user_bookmark_event(text, uuid, boolean) to authenticated;
grant execute on function public.apply_user_favorite_event(text, uuid, boolean) to authenticated;

create or replace function public.admin_apply_word_pack_reclassification(
  p_run_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request_role text := coalesce(auth.jwt() ->> 'role', '');
  v_existing_apply_summary jsonb;
  v_summary jsonb := '{}'::jsonb;
  v_rows_affected integer := 0;
  v_merged_duplicate_count integer := 0;
begin
  if v_request_role <> 'service_role'
     and not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if p_run_id is null then
    raise exception 'run id required';
  end if;

  select apply_summary
  into v_existing_apply_summary
  from public.word_pack_reclassification_runs
  where id = p_run_id
    and applied_at is not null;

  if v_existing_apply_summary is not null then
    return v_existing_apply_summary;
  end if;

  if not exists (
    select 1
    from public.word_pack_reclassification_runs
    where id = p_run_id
  ) then
    raise exception 'reclassification run not found';
  end if;

  if not exists (
    select 1
    from public.word_pack_reclassification_items
    where run_id = p_run_id
  ) then
    raise exception 'reclassification run has no items';
  end if;

  with merge_candidates as (
    select
      item.word_id as source_word_id,
      existing.id as target_word_id
    from public.word_pack_reclassification_items item
    join public.words source_word
      on source_word.id = item.word_id
    join public.words existing
      on existing.pack_id = item.target_pack_id
     and existing.id <> source_word.id
     and trim(coalesce(existing.en_word, '')) = trim(coalesce(source_word.en_word, ''))
     and trim(coalesce(existing.pos, '')) = trim(coalesce(source_word.pos, ''))
    where item.run_id = p_run_id
      and source_word.pack_id is distinct from item.target_pack_id
  )
  select count(*)::integer
  into v_merged_duplicate_count
  from merge_candidates;

  with merge_candidates as (
    select
      item.word_id as source_word_id,
      existing.id as target_word_id
    from public.word_pack_reclassification_items item
    join public.words source_word
      on source_word.id = item.word_id
    join public.words existing
      on existing.pack_id = item.target_pack_id
     and existing.id <> source_word.id
     and trim(coalesce(existing.en_word, '')) = trim(coalesce(source_word.en_word, ''))
     and trim(coalesce(existing.pos, '')) = trim(coalesce(source_word.pos, ''))
    where item.run_id = p_run_id
      and source_word.pack_id is distinct from item.target_pack_id
  )
  insert into public.reading_passage_words (
    passage_id,
    word_id
  )
  select
    link_row.passage_id,
    merge_candidates.target_word_id
  from public.reading_passage_words link_row
  join merge_candidates
    on merge_candidates.source_word_id = link_row.word_id
  on conflict (passage_id, word_id) do nothing;

  with merge_candidates as (
    select
      item.word_id as source_word_id,
      existing.id as target_word_id
    from public.word_pack_reclassification_items item
    join public.words source_word
      on source_word.id = item.word_id
    join public.words existing
      on existing.pack_id = item.target_pack_id
     and existing.id <> source_word.id
     and trim(coalesce(existing.en_word, '')) = trim(coalesce(source_word.en_word, ''))
     and trim(coalesce(existing.pos, '')) = trim(coalesce(source_word.pos, ''))
    where item.run_id = p_run_id
      and source_word.pack_id is distinct from item.target_pack_id
  )
  delete from public.reading_passage_words link_row
  using merge_candidates
  where link_row.word_id = merge_candidates.source_word_id;

  with merge_candidates as (
    select
      item.word_id as source_word_id,
      existing.id as target_word_id
    from public.word_pack_reclassification_items item
    join public.words source_word
      on source_word.id = item.word_id
    join public.words existing
      on existing.pack_id = item.target_pack_id
     and existing.id <> source_word.id
     and trim(coalesce(existing.en_word, '')) = trim(coalesce(source_word.en_word, ''))
     and trim(coalesce(existing.pos, '')) = trim(coalesce(source_word.pos, ''))
    where item.run_id = p_run_id
      and source_word.pack_id is distinct from item.target_pack_id
  )
  insert into public.user_word_progress (
    user_id,
    word_id,
    mastery,
    seen_count,
    correct_count,
    wrong_count,
    last_seen_at,
    last_answer,
    created_at,
    updated_at
  )
  select
    progress.user_id,
    merge_candidates.target_word_id,
    progress.mastery,
    progress.seen_count,
    progress.correct_count,
    progress.wrong_count,
    progress.last_seen_at,
    progress.last_answer,
    progress.created_at,
    progress.updated_at
  from public.user_word_progress progress
  join merge_candidates
    on merge_candidates.source_word_id = progress.word_id
  on conflict (user_id, word_id) do update
  set mastery = greatest(public.user_word_progress.mastery, excluded.mastery),
      seen_count = public.user_word_progress.seen_count + excluded.seen_count,
      correct_count = public.user_word_progress.correct_count + excluded.correct_count,
      wrong_count = public.user_word_progress.wrong_count + excluded.wrong_count,
      last_seen_at = greatest(public.user_word_progress.last_seen_at, excluded.last_seen_at),
      last_answer = case
        when excluded.last_seen_at is not null
         and (
           public.user_word_progress.last_seen_at is null
           or excluded.last_seen_at >= public.user_word_progress.last_seen_at
         ) then excluded.last_answer
        else public.user_word_progress.last_answer
      end,
      updated_at = now();

  with merge_candidates as (
    select
      item.word_id as source_word_id,
      existing.id as target_word_id
    from public.word_pack_reclassification_items item
    join public.words source_word
      on source_word.id = item.word_id
    join public.words existing
      on existing.pack_id = item.target_pack_id
     and existing.id <> source_word.id
     and trim(coalesce(existing.en_word, '')) = trim(coalesce(source_word.en_word, ''))
     and trim(coalesce(existing.pos, '')) = trim(coalesce(source_word.pos, ''))
    where item.run_id = p_run_id
      and source_word.pack_id is distinct from item.target_pack_id
  )
  delete from public.user_word_progress progress
  using merge_candidates
  where progress.word_id = merge_candidates.source_word_id;

  with merge_candidates as (
    select
      item.word_id as source_word_id,
      existing.id as target_word_id
    from public.word_pack_reclassification_items item
    join public.words source_word
      on source_word.id = item.word_id
    join public.words existing
      on existing.pack_id = item.target_pack_id
     and existing.id <> source_word.id
     and trim(coalesce(existing.en_word, '')) = trim(coalesce(source_word.en_word, ''))
     and trim(coalesce(existing.pos, '')) = trim(coalesce(source_word.pos, ''))
    where item.run_id = p_run_id
      and source_word.pack_id is distinct from item.target_pack_id
  )
  insert into public.user_word_favorites (
    user_id,
    word_id,
    created_at
  )
  select
    favorite.user_id,
    merge_candidates.target_word_id,
    favorite.created_at
  from public.user_word_favorites favorite
  join merge_candidates
    on merge_candidates.source_word_id = favorite.word_id
  on conflict (user_id, word_id) do nothing;

  with merge_candidates as (
    select
      item.word_id as source_word_id,
      existing.id as target_word_id
    from public.word_pack_reclassification_items item
    join public.words source_word
      on source_word.id = item.word_id
    join public.words existing
      on existing.pack_id = item.target_pack_id
     and existing.id <> source_word.id
     and trim(coalesce(existing.en_word, '')) = trim(coalesce(source_word.en_word, ''))
     and trim(coalesce(existing.pos, '')) = trim(coalesce(source_word.pos, ''))
    where item.run_id = p_run_id
      and source_word.pack_id is distinct from item.target_pack_id
  )
  delete from public.user_word_favorites favorite
  using merge_candidates
  where favorite.word_id = merge_candidates.source_word_id;

  with merge_candidates as (
    select
      item.word_id as source_word_id,
      existing.id as target_word_id
    from public.word_pack_reclassification_items item
    join public.words source_word
      on source_word.id = item.word_id
    join public.words existing
      on existing.pack_id = item.target_pack_id
     and existing.id <> source_word.id
     and trim(coalesce(existing.en_word, '')) = trim(coalesce(source_word.en_word, ''))
     and trim(coalesce(existing.pos, '')) = trim(coalesce(source_word.pos, ''))
    where item.run_id = p_run_id
      and source_word.pack_id is distinct from item.target_pack_id
  )
  delete from public.words source_word
  using merge_candidates
  where source_word.id = merge_candidates.source_word_id;

  update public.words w
  set pack_id = item.target_pack_id,
      updated_at = now(),
      updated_by = auth.uid()
  from public.word_pack_reclassification_items item
  where item.run_id = p_run_id
    and item.word_id = w.id
    and w.pack_id is distinct from item.target_pack_id
    and not exists (
      select 1
      from public.words existing
      where existing.pack_id = item.target_pack_id
        and existing.id <> w.id
        and trim(coalesce(existing.en_word, '')) = trim(coalesce(w.en_word, ''))
        and trim(coalesce(existing.pos, '')) = trim(coalesce(w.pos, ''))
    );

  get diagnostics v_rows_affected = row_count;

  with item_rows as (
    select
      item.current_pack_id,
      item.target_pack_id,
      target_pack.name as target_pack_name
    from public.word_pack_reclassification_items item
    join public.packs target_pack
      on target_pack.id = item.target_pack_id
    where item.run_id = p_run_id
  ),
  target_counts as (
    select
      target_pack_name,
      count(*)::integer as total_count
    from item_rows
    group by target_pack_name
  )
  select jsonb_build_object(
    'run_id', p_run_id::text,
    'total_words', coalesce((select count(*)::integer from item_rows), 0),
    'rows_affected', v_rows_affected,
    'merged_duplicate_count', v_merged_duplicate_count,
    'updated_count', coalesce(
      (
        select count(*)::integer
        from item_rows
        where current_pack_id is distinct from target_pack_id
      ),
      0
    ),
    'unchanged_count', coalesce(
      (
        select count(*)::integer
        from item_rows
        where current_pack_id = target_pack_id
      ),
      0
    ),
    'target_counts', coalesce(
      (select jsonb_object_agg(target_pack_name, total_count) from target_counts),
      '{}'::jsonb
    )
  )
  into v_summary;

  update public.word_pack_reclassification_runs
  set applied_at = now(),
      applied_by = auth.uid(),
      apply_summary = v_summary
  where id = p_run_id;

  perform public.write_audit_log(
    'admin.word.pack_reclassification.applied',
    'maintenance',
    p_run_id::text,
    v_summary
  );

  return v_summary;
end;
$$;

grant execute on function public.admin_apply_word_pack_reclassification(uuid) to authenticated, service_role;

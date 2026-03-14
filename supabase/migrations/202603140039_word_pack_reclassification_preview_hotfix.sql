create or replace function public.admin_preview_word_pack_reclassification(
  p_source_pack_name text default 'YDS Set 001',
  p_target_pack_names text[] default array['YDS Set 001', 'YDS Set 002', 'YDS Set 003', 'YDS Set 004', 'YDS Set 005'],
  p_other_pack_name text default 'Other',
  p_autolink_missing boolean default true,
  p_autolink_limit integer default 10
)
returns table (
  run_id text,
  word_id text,
  en_word text,
  current_pack_name text,
  target_pack_name text,
  reason text,
  set_hit_counts jsonb,
  linked_passage_count integer
)
language plpgsql
security definer
set search_path = public, auth
as $$
#variable_conflict use_column
declare
  v_request_role text := coalesce(auth.jwt() ->> 'role', '');
  v_source_pack_name text := trim(coalesce(p_source_pack_name, ''));
  v_other_pack_name text := trim(coalesce(p_other_pack_name, ''));
  v_target_pack_names text[] := p_target_pack_names;
  v_source_pack_id uuid;
  v_other_pack_id uuid;
  v_run_id uuid := gen_random_uuid();
  v_missing_pack_names text[];
  v_missing_before integer := 0;
  v_missing_after integer := 0;
  v_autolinked_passages integer := 0;
  v_no_match_passages integer := 0;
  v_inserted_count integer := 0;
  v_preview_summary jsonb := '{}'::jsonb;
  v_autolink_summary jsonb := '{}'::jsonb;
  v_passage record;
begin
  if v_request_role <> 'service_role'
     and not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_source_pack_name = '' then
    raise exception 'source pack name required';
  end if;

  if v_other_pack_name = '' then
    raise exception 'other pack name required';
  end if;

  if coalesce(array_length(v_target_pack_names, 1), 0) = 0 then
    v_target_pack_names := array['YDS Set 001', 'YDS Set 002', 'YDS Set 003', 'YDS Set 004', 'YDS Set 005'];
  end if;

  select p.id
  into v_source_pack_id
  from public.packs p
  where p.name = v_source_pack_name
  limit 1;

  if v_source_pack_id is null then
    raise exception 'source pack not found';
  end if;

  select array_agg(requested.pack_name order by requested.pack_order)
  into v_missing_pack_names
  from (
    select
      trim(pack_name) as pack_name,
      pack_order
    from unnest(v_target_pack_names) with ordinality as t(pack_name, pack_order)
  ) requested
  left join public.packs p
    on p.name = requested.pack_name
  where p.id is null;

  if coalesce(array_length(v_missing_pack_names, 1), 0) > 0 then
    raise exception 'target packs not found: %', array_to_string(v_missing_pack_names, ', ');
  end if;

  insert into public.packs (
    name,
    from_lang,
    to_lang,
    is_published,
    published_at,
    created_by,
    updated_by
  )
  select
    v_other_pack_name,
    'en',
    'tr',
    true,
    now(),
    auth.uid(),
    auth.uid()
  where not exists (
    select 1
    from public.packs
    where name = v_other_pack_name
  );

  select p.id
  into v_other_pack_id
  from public.packs p
  where p.name = v_other_pack_name
  limit 1;

  if v_other_pack_id is null then
    raise exception 'other pack resolve edilemedi';
  end if;

  if not exists (
    select 1
    from public.words w
    where w.pack_id = v_source_pack_id
  ) then
    raise exception 'source pack has no words';
  end if;

  select count(*)::integer
  into v_missing_before
  from public.reading_passages rp
  join public.packs p
    on p.id = rp.pack_id
  where p.name = any(v_target_pack_names)
    and not exists (
      select 1
      from public.reading_passage_words rpw
      where rpw.passage_id = rp.id
    );

  if coalesce(p_autolink_missing, true) then
    for v_passage in
      select rp.id
      from public.reading_passages rp
      join public.packs p
        on p.id = rp.pack_id
      where p.name = any(v_target_pack_names)
        and not exists (
          select 1
          from public.reading_passage_words rpw
          where rpw.passage_id = rp.id
        )
      order by rp.title asc
    loop
      insert into public.reading_passage_words (
        passage_id,
        word_id
      )
      select
        v_passage.id,
        suggestion.word_id
      from public.admin_suggest_reading_focus_words_v2(
        v_passage.id,
        greatest(1, least(coalesce(p_autolink_limit, 10), 25))
      ) suggestion
      on conflict (passage_id, word_id) do nothing;

      get diagnostics v_inserted_count = row_count;

      if v_inserted_count > 0 then
        v_autolinked_passages := v_autolinked_passages + 1;
      else
        v_no_match_passages := v_no_match_passages + 1;
      end if;
    end loop;
  end if;

  select count(*)::integer
  into v_missing_after
  from public.reading_passages rp
  join public.packs p
    on p.id = rp.pack_id
  where p.name = any(v_target_pack_names)
    and not exists (
      select 1
      from public.reading_passage_words rpw
      where rpw.passage_id = rp.id
    );

  v_autolink_summary := jsonb_build_object(
    'missing_before', v_missing_before,
    'missing_after', v_missing_after,
    'autolinked_passages', v_autolinked_passages,
    'no_match_passages', v_no_match_passages,
    'autolink_missing', coalesce(p_autolink_missing, true),
    'autolink_limit', greatest(1, least(coalesce(p_autolink_limit, 10), 25))
  );

  insert into public.word_pack_reclassification_runs (
    id,
    source_pack_name,
    target_pack_names,
    other_pack_name,
    autolink_missing,
    autolink_limit,
    autolink_summary,
    created_by
  )
  values (
    v_run_id,
    v_source_pack_name,
    v_target_pack_names,
    v_other_pack_name,
    coalesce(p_autolink_missing, true),
    greatest(1, least(coalesce(p_autolink_limit, 10), 25)),
    v_autolink_summary,
    auth.uid()
  );

  insert into public.word_pack_reclassification_items (
    run_id,
    word_id,
    current_pack_id,
    target_pack_id,
    linked_passage_count,
    set_hit_counts,
    reason
  )
  with target_packs as (
    select
      trim(t.pack_name) as pack_name,
      t.pack_order::integer as set_rank,
      p.id as pack_id
    from unnest(v_target_pack_names) with ordinality as t(pack_name, pack_order)
    join public.packs p
      on p.name = trim(t.pack_name)
  ),
  target_passages as (
    select
      rp.id as passage_id,
      rp.pack_id
    from public.reading_passages rp
    join target_packs tp
      on tp.pack_id = rp.pack_id
  ),
  source_words as (
    select
      w.id as word_id,
      trim(coalesce(w.en_word, '')) as en_word,
      w.pack_id as current_pack_id
    from public.words w
    where w.pack_id = v_source_pack_id
  ),
  target_pack_hits as (
    select
      sw.word_id,
      tp.pack_id,
      tp.pack_name,
      tp.set_rank,
      count(distinct rpw.passage_id)::integer as hit_count
    from source_words sw
    join public.reading_passage_words rpw
      on rpw.word_id = sw.word_id
    join target_passages tpass
      on tpass.passage_id = rpw.passage_id
    join target_packs tp
      on tp.pack_id = tpass.pack_id
    group by sw.word_id, tp.pack_id, tp.pack_name, tp.set_rank
  ),
  hit_summary as (
    select
      sw.word_id,
      coalesce(sum(tph.hit_count), 0)::integer as linked_passage_count,
      coalesce(
        jsonb_object_agg(tph.pack_name, tph.hit_count order by tph.set_rank)
          filter (where tph.pack_name is not null),
        '{}'::jsonb
      ) as set_hit_counts
    from source_words sw
    left join target_pack_hits tph
      on tph.word_id = sw.word_id
    group by sw.word_id
  ),
  max_hits as (
    select
      tph.word_id,
      max(tph.hit_count)::integer as max_hit_count
    from target_pack_hits tph
    group by tph.word_id
  ),
  tie_counts as (
    select
      tph.word_id,
      count(*)::integer as tie_count
    from target_pack_hits tph
    join max_hits mh
      on mh.word_id = tph.word_id
     and mh.max_hit_count = tph.hit_count
    group by tph.word_id
  ),
  ranked_targets as (
    select
      tph.word_id,
      tph.pack_id,
      tph.pack_name,
      row_number() over (
        partition by tph.word_id
        order by
          tph.hit_count desc,
          tph.set_rank asc,
          tph.pack_name asc
      ) as rn
    from target_pack_hits tph
  ),
  classified as (
    select
      sw.word_id,
      sw.current_pack_id,
      coalesce(rt.pack_id, v_other_pack_id) as target_pack_id,
      coalesce(hs.linked_passage_count, 0)::integer as linked_passage_count,
      coalesce(hs.set_hit_counts, '{}'::jsonb) as set_hit_counts,
      case
        when coalesce(hs.linked_passage_count, 0) = 0 then 'no_linked_passages'
        when coalesce(tc.tie_count, 0) > 1 then 'tie_break_lowest_set'
        else 'majority_match'
      end as reason
    from source_words sw
    left join ranked_targets rt
      on rt.word_id = sw.word_id
     and rt.rn = 1
    left join hit_summary hs
      on hs.word_id = sw.word_id
    left join tie_counts tc
      on tc.word_id = sw.word_id
  )
  select
    v_run_id,
    classified.word_id,
    classified.current_pack_id,
    classified.target_pack_id,
    classified.linked_passage_count,
    classified.set_hit_counts,
    classified.reason
  from classified;

  with item_rows as (
    select
      item.current_pack_id,
      item.target_pack_id,
      target_pack.name as target_pack_name,
      item.reason
    from public.word_pack_reclassification_items item
    join public.packs target_pack
      on target_pack.id = item.target_pack_id
    where item.run_id = v_run_id
  ),
  target_counts as (
    select
      target_pack_name,
      count(*)::integer as total_count
    from item_rows
    group by target_pack_name
  ),
  reason_counts as (
    select
      reason,
      count(*)::integer as total_count
    from item_rows
    group by reason
  )
  select jsonb_build_object(
    'run_id', v_run_id::text,
    'total_words', coalesce((select count(*)::integer from item_rows), 0),
    'move_count', coalesce(
      (
        select count(*)::integer
        from item_rows
        where current_pack_id is distinct from target_pack_id
      ),
      0
    ),
    'stay_count', coalesce(
      (
        select count(*)::integer
        from item_rows
        where current_pack_id = target_pack_id
      ),
      0
    ),
    'other_count', coalesce(
      (
        select count(*)::integer
        from item_rows
        where target_pack_name = v_other_pack_name
      ),
      0
    ),
    'target_counts', coalesce(
      (select jsonb_object_agg(target_pack_name, total_count) from target_counts),
      '{}'::jsonb
    ),
    'reason_counts', coalesce(
      (select jsonb_object_agg(reason, total_count) from reason_counts),
      '{}'::jsonb
    )
  )
  into v_preview_summary;

  update public.word_pack_reclassification_runs
  set preview_summary = v_preview_summary
  where id = v_run_id;

  perform public.write_audit_log(
    'admin.word.pack_reclassification.previewed',
    'maintenance',
    v_run_id::text,
    jsonb_build_object(
      'source_pack_name', v_source_pack_name,
      'target_pack_names', to_jsonb(v_target_pack_names),
      'other_pack_name', v_other_pack_name,
      'autolink_summary', v_autolink_summary,
      'preview_summary', v_preview_summary
    )
  );

  return query
  select
    v_run_id::text,
    item.word_id::text,
    trim(coalesce(w.en_word, '')) as en_word,
    current_pack.name as current_pack_name,
    target_pack.name as target_pack_name,
    item.reason,
    item.set_hit_counts,
    item.linked_passage_count
  from public.word_pack_reclassification_items item
  join public.words w
    on w.id = item.word_id
  join public.packs current_pack
    on current_pack.id = item.current_pack_id
  join public.packs target_pack
    on target_pack.id = item.target_pack_id
  where item.run_id = v_run_id
  order by
    target_pack.name asc,
    trim(coalesce(w.en_word, '')) asc,
    item.word_id asc;
end;
$$;

grant execute on function public.admin_preview_word_pack_reclassification(text, text[], text, boolean, integer) to authenticated, service_role;

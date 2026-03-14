create or replace function public.admin_suggest_reading_focus_words_v2(
  p_passage_id uuid,
  p_limit integer default 10
)
returns table (
  word_id uuid,
  en_word text,
  tr_meaning text,
  pos text,
  hit_count integer,
  first_seen_order integer,
  score integer
)
language plpgsql
security definer
set search_path = public, auth
as $$
#variable_conflict use_column
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 25));
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role'
     and not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if not exists (
    select 1
    from public.reading_passages
    where id = p_passage_id
  ) then
    raise exception 'reading passage not found';
  end if;

  return query
  with stop_words as (
    select unnest(array[
      'a','an','the','and','or','but','if','so',
      'in','on','at','to','of','for','by','with','from','as',
      'is','are','was','were','be','been','being',
      'this','that','these','those',
      'it','its','he','she','they','them','we','you','i',
      'his','her','their','our','your',
      'into','onto','over','under','after','before','about','around',
      'through','during','without','within',
      'many','more','most','much','very','other','such','all','any',
      'when','while','because','however','than','also',
      'people','time','work','way','life','like','new','long','high'
    ]) as word
  ),
  passage_text as (
    select
      rp.id as passage_id,
      rp.pack_id,
      trim(
        regexp_replace(
          lower(coalesce(string_agg(coalesce(rps.sentence_en, ''), ' ' order by rps.idx), '')),
          '[^[:alnum:]]+',
          ' ',
          'g'
        )
      ) as normalized_text
    from public.reading_passages rp
    left join public.reading_passage_sentences rps
      on rps.passage_id = rp.id
    where rp.id = p_passage_id
    group by rp.id, rp.pack_id
  ),
  tokenized as (
    select
      pt.passage_id,
      pt.pack_id,
      tok.ordinality::integer as token_order,
      tok.token as normalized_token
    from passage_text pt,
    lateral regexp_split_to_table(pt.normalized_text, E'\\s+') with ordinality as tok(token, ordinality)
    where tok.token <> ''
  ),
  token_variants as (
    select distinct
      t.passage_id,
      t.pack_id,
      t.token_order,
      variant.normalized_token
    from tokenized t
    cross join lateral (
      values
        (t.normalized_token),
        (
          case
            when t.normalized_token ~ '^[a-z]{4,}s$'
              then left(t.normalized_token, length(t.normalized_token) - 1)
          end
        ),
        (
          case
            when t.normalized_token ~ '^[a-z]{5,}ies$'
              then left(t.normalized_token, length(t.normalized_token) - 3) || 'y'
          end
        )
    ) as variant(normalized_token)
    where variant.normalized_token is not null
      and variant.normalized_token <> ''
  ),
  eligible_word_cards as (
    select
      w.id as word_id,
      w.pack_id as word_pack_id,
      trim(coalesce(w.en_word, '')) as en_word,
      trim(coalesce(w.tr_meaning, '')) as tr_meaning,
      trim(coalesce(w.pos, '')) as pos,
      trim(
        regexp_replace(
          lower(trim(coalesce(w.en_word, ''))),
          '[^[:alnum:]]+',
          ' ',
          'g'
        )
      ) as normalized_en_word,
      trim(
        regexp_replace(
          lower(coalesce(w.pos, '')),
          '[^a-z]+',
          ' ',
          'g'
        )
      ) as pos_tokens
    from public.words w
    where coalesce(w.is_published, true) = true
      and nullif(trim(coalesce(w.en_word, '')), '') is not null
  ),
  classified_cards as (
    select
      card.*,
      case
        when card.pos_tokens ~ '(^| )(prep|conj|det|pron)( |$)' then -1
        when card.pos_tokens ~ '(^| )(phr v|phrasal verb)( |$)' then 82
        when card.pos_tokens ~ '(^| )(n|noun)( |$)' then 90
        when card.pos_tokens ~ '(^| )(v|verb)( |$)' then 85
        when card.pos_tokens ~ '(^| )(adj|adjective)( |$)' then 80
        when card.pos_tokens ~ '(^| )(adv|adverb)( |$)' then 75
        else 0
      end as pos_score,
      case
        when strpos(card.normalized_en_word, ' ') > 0 then true
        else false
      end as is_phrase,
      array_length(regexp_split_to_array(card.normalized_en_word, E'\\s+'), 1) as token_count
    from eligible_word_cards card
  ),
  single_word_cards as (
    select *
    from classified_cards
    where pos_score > 0
      and not is_phrase
      and normalized_en_word not in (select word from stop_words)
      and length(replace(normalized_en_word, ' ', '')) >= 4
  ),
  phrase_cards as (
    select *
    from classified_cards
    where pos_score > 0
      and is_phrase
      and token_count between 2 and 4
  ),
  single_candidates as (
    select
      tv.passage_id,
      swc.word_id,
      swc.en_word,
      swc.tr_meaning,
      swc.pos,
      min(tv.token_order)::integer as first_seen_order,
      count(*)::integer as hit_count,
      max(
        case
          when tv.pack_id is not null and swc.word_pack_id = tv.pack_id then 1000
          else 0
        end
      )::integer as pack_score,
      max(swc.pos_score)::integer as pos_score,
      max(length(replace(swc.normalized_en_word, ' ', '')))::integer as length_score
    from token_variants tv
    join single_word_cards swc
      on swc.normalized_en_word = tv.normalized_token
    group by tv.passage_id, swc.word_id, swc.en_word, swc.tr_meaning, swc.pos
  ),
  phrase_candidates as (
    select
      pt.passage_id,
      pc.word_id,
      pc.en_word,
      pc.tr_meaning,
      pc.pos,
      strpos(' ' || pt.normalized_text || ' ', ' ' || pc.normalized_en_word || ' ')::integer as first_seen_order,
      1::integer as hit_count,
      (
        case
          when pt.pack_id is not null and pc.word_pack_id = pt.pack_id then 1000
          else 0
        end
      )::integer as pack_score,
      pc.pos_score::integer as pos_score,
      length(replace(pc.normalized_en_word, ' ', ''))::integer as length_score
    from passage_text pt
    join phrase_cards pc
      on strpos(' ' || pt.normalized_text || ' ', ' ' || pc.normalized_en_word || ' ') > 0
  ),
  combined_candidates as (
    select * from single_candidates
    union all
    select * from phrase_candidates
  ),
  deduped as (
    select
      ranked.passage_id,
      ranked.word_id,
      ranked.en_word,
      ranked.tr_meaning,
      ranked.pos,
      ranked.hit_count,
      ranked.first_seen_order,
      ranked.pack_score,
      ranked.pos_score,
      ranked.length_score
    from (
      select
        candidate.*,
        row_number() over (
          partition by candidate.passage_id, candidate.word_id
          order by
            candidate.pack_score desc,
            candidate.pos_score desc,
            candidate.hit_count desc,
            candidate.length_score desc,
            candidate.first_seen_order asc,
            candidate.en_word asc
        ) as candidate_rank
      from combined_candidates candidate
    ) ranked
    where ranked.candidate_rank = 1
  ),
  final_ranked as (
    select
      deduped.word_id,
      deduped.en_word,
      deduped.tr_meaning,
      deduped.pos,
      deduped.hit_count,
      deduped.first_seen_order,
      (
        deduped.pack_score
        + deduped.pos_score
        + least(deduped.hit_count, 4) * 10
        + least(deduped.length_score, 18)
      )::integer as score,
      row_number() over (
        order by
          deduped.pack_score desc,
          deduped.pos_score desc,
          deduped.hit_count desc,
          deduped.length_score desc,
          deduped.first_seen_order asc,
          deduped.en_word asc
      ) as rn
    from deduped
  )
  select
    final_ranked.word_id,
    final_ranked.en_word,
    final_ranked.tr_meaning,
    final_ranked.pos,
    final_ranked.hit_count,
    final_ranked.first_seen_order,
    final_ranked.score
  from final_ranked
  where final_ranked.rn <= v_limit
  order by final_ranked.rn;
end;
$$;

create table if not exists public.word_pack_reclassification_runs (
  id uuid primary key default gen_random_uuid(),
  source_pack_name text not null,
  target_pack_names text[] not null,
  other_pack_name text not null,
  autolink_missing boolean not null default true,
  autolink_limit integer not null default 10,
  autolink_summary jsonb not null default '{}'::jsonb,
  preview_summary jsonb not null default '{}'::jsonb,
  apply_summary jsonb,
  created_at timestamptz not null default now(),
  created_by uuid,
  applied_at timestamptz,
  applied_by uuid
);

create table if not exists public.word_pack_reclassification_items (
  run_id uuid not null references public.word_pack_reclassification_runs(id) on delete cascade,
  word_id uuid not null references public.words(id) on delete cascade,
  current_pack_id uuid not null references public.packs(id) on delete cascade,
  target_pack_id uuid not null references public.packs(id) on delete cascade,
  linked_passage_count integer not null default 0,
  set_hit_counts jsonb not null default '{}'::jsonb,
  reason text not null,
  created_at timestamptz not null default now(),
  primary key (run_id, word_id)
);

create index if not exists ix_word_pack_reclassification_items_target_pack
  on public.word_pack_reclassification_items (target_pack_id);

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

grant execute on function public.admin_suggest_reading_focus_words_v2(uuid, integer) to authenticated, service_role;
grant execute on function public.admin_preview_word_pack_reclassification(text, text[], text, boolean, integer) to authenticated, service_role;
grant execute on function public.admin_apply_word_pack_reclassification(uuid) to authenticated, service_role;

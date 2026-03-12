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
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 25));
begin
  if not public.is_admin_or_developer() then
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

create or replace function public.admin_autolink_reading_focus_words_v2(
  p_passage_id uuid,
  p_limit integer default 10,
  p_replace_existing boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_assigned_count integer := 0;
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 25));
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if not exists (
    select 1
    from public.reading_passages
    where id = p_passage_id
  ) then
    raise exception 'reading passage not found';
  end if;

  if coalesce(p_replace_existing, true) then
    delete from public.reading_passage_words
    where passage_id = p_passage_id;
  end if;

  insert into public.reading_passage_words (
    passage_id,
    word_id
  )
  select
    p_passage_id,
    suggestion.word_id
  from public.admin_suggest_reading_focus_words_v2(p_passage_id, v_limit) suggestion
  on conflict (passage_id, word_id) do nothing;

  get diagnostics v_assigned_count = row_count;

  perform public.write_audit_log(
    'admin.reading.focus_words.auto_assigned_v2',
    'reading',
    p_passage_id::text,
    jsonb_build_object(
      'assigned_count', v_assigned_count,
      'limit', v_limit,
      'replace_existing', coalesce(p_replace_existing, true)
    )
  );

  return public.admin_get_reading_detail(p_passage_id);
end;
$$;

create or replace function public.admin_autolink_all_reading_focus_words_v2(
  p_limit integer default 10,
  p_only_missing boolean default true,
  p_include_unpublished boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 10), 25));
  v_processed_count integer := 0;
  v_assigned_count integer := 0;
  v_skipped_existing_count integer := 0;
  v_no_match_count integer := 0;
  v_error_count integer := 0;
  v_sample_failures jsonb := '[]'::jsonb;
  v_result jsonb;
  v_target record;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  for v_target in
    select
      rp.id,
      coalesce(rp.title, '') as title,
      (
        select count(*)::integer
        from public.reading_passage_words link_row
        where link_row.passage_id = rp.id
      ) as linked_word_count
    from public.reading_passages rp
    where (coalesce(p_include_unpublished, true) or coalesce(rp.is_published, false))
    order by rp.title asc
  loop
    if coalesce(p_only_missing, true) and coalesce(v_target.linked_word_count, 0) > 0 then
      v_skipped_existing_count := v_skipped_existing_count + 1;
      continue;
    end if;

    v_processed_count := v_processed_count + 1;

    begin
      v_result := public.admin_autolink_reading_focus_words_v2(
        v_target.id,
        v_limit,
        not coalesce(p_only_missing, true)
      );

      if jsonb_array_length(coalesce(v_result -> 'linked_words', '[]'::jsonb)) > 0 then
        v_assigned_count := v_assigned_count + 1;
      else
        v_no_match_count := v_no_match_count + 1;
      end if;
    exception
      when others then
        v_error_count := v_error_count + 1;
        if jsonb_array_length(v_sample_failures) < 5 then
          v_sample_failures := v_sample_failures || jsonb_build_array(
            format('%s | %s | %s', v_target.id::text, v_target.title, sqlerrm)
          );
        end if;
    end;
  end loop;

  perform public.write_audit_log(
    'admin.reading.focus_words.auto_assigned_v2.bulk',
    'reading',
    null,
    jsonb_build_object(
      'processed_count', v_processed_count,
      'assigned_count', v_assigned_count,
      'skipped_existing_count', v_skipped_existing_count,
      'no_match_count', v_no_match_count,
      'error_count', v_error_count,
      'limit', v_limit,
      'only_missing', coalesce(p_only_missing, true),
      'include_unpublished', coalesce(p_include_unpublished, true)
    )
  );

  return jsonb_build_object(
    'processed_count', v_processed_count,
    'assigned_count', v_assigned_count,
    'skipped_existing_count', v_skipped_existing_count,
    'no_match_count', v_no_match_count,
    'error_count', v_error_count,
    'sample_failures', v_sample_failures
  );
end;
$$;

create or replace function public.admin_list_reading_passages_paged(
  p_query text default null,
  p_level text default null,
  p_status text default null,
  p_offset integer default 0,
  p_limit integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_payload jsonb;
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_query text := nullif(trim(coalesce(p_query, '')), '');
  v_level text := nullif(trim(coalesce(p_level, '')), '');
  v_status text := nullif(lower(trim(coalesce(p_status, ''))), '');
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  with filtered as (
    select
      rp.id::text as id,
      rp.pack_id::text as pack_id,
      rp.pack_name,
      coalesce(rp.title, '') as title,
      rp.level,
      rp.category,
      rp.tags_raw,
      coalesce(rp.is_pro, false) as is_pro,
      coalesce(rp.is_published, false) as is_published,
      (
        select count(*)::integer
        from public.reading_passage_words link_row
        where link_row.passage_id = rp.id
      ) as linked_word_count,
      coalesce(
        (
          select jsonb_agg(preview_word.en_word order by preview_word.en_word)
          from (
            select distinct w.en_word
            from public.reading_passage_words link_row
            join public.words w
              on w.id = link_row.word_id
            where link_row.passage_id = rp.id
            order by w.en_word asc
            limit 3
          ) preview_word
        ),
        '[]'::jsonb
      ) as linked_words_preview,
      rp.created_at,
      rp.updated_at,
      coalesce(actor.email, '') as updated_by_email
    from public.reading_passages rp
    left join auth.users actor
      on actor.id = rp.updated_by
    where (
        v_query is null
        or concat_ws(' ', rp.title, coalesce(rp.category, ''), coalesce(rp.level, ''), coalesce(rp.tags_raw, ''))
           ilike '%' || v_query || '%'
      )
      and (v_level is null or rp.level = v_level)
      and (
        v_status is null
        or v_status = 'all'
        or (v_status = 'published' and coalesce(rp.is_published, false))
        or (v_status = 'draft' and not coalesce(rp.is_published, false))
      )
  ),
  paged as (
    select *
    from filtered
    order by title asc
    offset v_offset
    limit v_limit
  )
  select jsonb_build_object(
    'items',
    coalesce(
      (select jsonb_agg(to_jsonb(paged_item)) from paged as paged_item),
      '[]'::jsonb
    ),
    'total_count',
    coalesce((select count(*)::integer from filtered), 0),
    'offset',
    v_offset,
    'limit',
    v_limit
  )
  into v_payload;

  return v_payload;
end;
$$;

grant execute on function public.admin_suggest_reading_focus_words_v2(uuid, integer) to authenticated;
grant execute on function public.admin_autolink_reading_focus_words_v2(uuid, integer, boolean) to authenticated;
grant execute on function public.admin_autolink_all_reading_focus_words_v2(integer, boolean, boolean) to authenticated;
grant execute on function public.admin_list_reading_passages_paged(text, text, text, integer, integer) to authenticated;

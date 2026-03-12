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
      lower(
        regexp_replace(
          string_agg(rps.sentence_en, ' ' order by rps.idx),
          '[^a-z0-9]+',
          ' ',
          'gi'
        )
      ) as normalized_text
    from public.reading_passages rp
    join public.reading_passage_sentences rps
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
    lateral regexp_split_to_table(pt.normalized_text, '\s+') with ordinality as tok(token, ordinality)
    where tok.token <> ''
  ),
  eligible_word_cards as (
    select
      w.id as word_id,
      w.pack_id as word_pack_id,
      trim(coalesce(w.en_word, '')) as en_word,
      trim(coalesce(w.tr_meaning, '')) as tr_meaning,
      trim(coalesce(w.pos, '')) as pos,
      lower(trim(coalesce(w.en_word, ''))) as normalized_en_word,
      case
        when lower(coalesce(w.pos, '')) ~ '(^|[;/.[:space:]])n(\.|$)' then 90
        when lower(coalesce(w.pos, '')) ~ '(^|[;/.[:space:]])v(\.|$)' then 85
        when lower(coalesce(w.pos, '')) ~ '(^|[;/.[:space:]])adj(\.|$)' then 80
        when lower(coalesce(w.pos, '')) ~ '(^|[;/.[:space:]])adv(\.|$)' then 75
        else 0
      end as pos_score
    from public.words w
    where coalesce(w.is_published, true) = true
      and nullif(trim(coalesce(w.en_word, '')), '') is not null
      and lower(trim(coalesce(w.en_word, ''))) not in (select word from stop_words)
      and lower(trim(coalesce(w.en_word, ''))) !~ '\s'
      and length(lower(trim(coalesce(w.en_word, '')))) >= 4
      and (
        lower(coalesce(w.pos, '')) ~ '(^|[;/.[:space:]])n(\.|$)'
        or lower(coalesce(w.pos, '')) ~ '(^|[;/.[:space:]])v(\.|$)'
        or lower(coalesce(w.pos, '')) ~ '(^|[;/.[:space:]])adj(\.|$)'
        or lower(coalesce(w.pos, '')) ~ '(^|[;/.[:space:]])adv(\.|$)'
      )
  ),
  candidate_matches as (
    select
      t.passage_id,
      t.token_order,
      e.word_id,
      e.en_word,
      e.tr_meaning,
      e.pos,
      e.pos_score,
      case
        when t.pack_id is not null and e.word_pack_id = t.pack_id then 1000
        else 0
      end as pack_score
    from tokenized t
    join eligible_word_cards e
      on e.normalized_en_word = t.normalized_token
  ),
  deduped as (
    select
      passage_id,
      word_id,
      en_word,
      tr_meaning,
      pos,
      min(token_order)::integer as first_seen_order,
      count(*)::integer as hit_count,
      max(pack_score)::integer as pack_score,
      max(pos_score)::integer as pos_score,
      length(en_word)::integer as length_score
    from candidate_matches
    group by passage_id, word_id, en_word, tr_meaning, pos
  ),
  ranked as (
    select
      word_id,
      en_word,
      tr_meaning,
      pos,
      hit_count,
      first_seen_order,
      (
        pack_score
        + pos_score
        + least(hit_count, 4) * 10
        + least(length_score, 12)
      )::integer as score,
      row_number() over (
        partition by passage_id
        order by
          pack_score desc,
          pos_score desc,
          hit_count desc,
          length_score desc,
          first_seen_order asc,
          en_word asc
      ) as rn
    from deduped
  )
  select
    ranked.word_id,
    ranked.en_word,
    ranked.tr_meaning,
    ranked.pos,
    ranked.hit_count,
    ranked.first_seen_order,
    ranked.score
  from ranked
  where ranked.rn <= v_limit
  order by ranked.rn;
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
  from public.admin_suggest_reading_focus_words_v2(p_passage_id, p_limit) suggestion
  on conflict (passage_id, word_id) do nothing;

  get diagnostics v_assigned_count = row_count;

  perform public.write_audit_log(
    'admin.reading.focus_words.auto_assigned_v2',
    'reading',
    p_passage_id::text,
    jsonb_build_object(
      'assigned_count', v_assigned_count,
      'limit', greatest(1, least(coalesce(p_limit, 10), 25)),
      'replace_existing', coalesce(p_replace_existing, true)
    )
  );

  return public.admin_get_reading_detail(p_passage_id);
end;
$$;

drop function if exists public.admin_list_reading_passages();

create or replace function public.admin_list_reading_passages()
returns table (
  id text,
  pack_id text,
  pack_name text,
  title text,
  level text,
  category text,
  tags_raw text,
  is_published boolean,
  linked_word_count integer,
  linked_words_preview jsonb,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    rp.id::text,
    rp.pack_id::text,
    rp.pack_name,
    coalesce(rp.title, ''),
    rp.level,
    rp.category,
    rp.tags_raw,
    coalesce(rp.is_published, false),
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
    rp.updated_at
  from public.reading_passages rp
  where public.is_admin_or_developer()
  order by rp.title asc;
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
  v_items jsonb;
  v_total integer;
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
  select count(*)::integer into v_total
  from filtered;

  select coalesce(jsonb_agg(to_jsonb(paged)), '[]'::jsonb)
  into v_items
  from paged;

  return jsonb_build_object(
    'items', v_items,
    'total_count', v_total,
    'offset', v_offset,
    'limit', v_limit
  );
end;
$$;

grant execute on function public.admin_suggest_reading_focus_words_v2(uuid, integer) to authenticated;
grant execute on function public.admin_autolink_reading_focus_words_v2(uuid, integer, boolean) to authenticated;
grant execute on function public.admin_list_reading_passages() to authenticated;

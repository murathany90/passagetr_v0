create or replace function public.admin_count_words_from_html(
  p_html text
)
returns integer
language sql
immutable
set search_path = public
as $$
  select case
    when trim(regexp_replace(regexp_replace(coalesce(p_html, ''), '<[^>]+>', ' ', 'g'), '\s+', ' ', 'g')) = ''
      then 0
    else cardinality(
      regexp_split_to_array(
        trim(regexp_replace(regexp_replace(coalesce(p_html, ''), '<[^>]+>', ' ', 'g'), '\s+', ' ', 'g')),
        '\s+'
      )
    )
  end;
$$;

create or replace function public.admin_list_users_paged(
  p_query text default null,
  p_role text default null,
  p_plan text default null,
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
  v_role text := nullif(lower(trim(coalesce(p_role, ''))), '');
  v_plan text := nullif(lower(trim(coalesce(p_plan, ''))), '');
  v_status text := nullif(lower(trim(coalesce(p_status, ''))), '');
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  with raw_users as (
    select
      u.id as user_id,
      coalesce(u.email, '') as email,
      coalesce(p.display_name, '') as display_name,
      coalesce(
        (
          select ur.role
          from public.user_roles ur
          where ur.user_id = u.id
            and ur.revoked_at is null
          order by case ur.role
            when 'developer' then 3
            when 'admin' then 2
            else 1
          end desc
          limit 1
        ),
        'user'
      ) as app_role,
      coalesce(
        (
          select e.plan
          from public.entitlements e
          where e.user_id = u.id
            and e.revoked_at is null
            and e.starts_at <= now()
            and (e.expires_at is null or e.expires_at > now())
          order by e.starts_at desc
          limit 1
        ),
        'free'
      ) as plan,
      case
        when coalesce(p.is_anonymous, false) then 'anonymous'
        when exists (
          select 1
          from public.user_roles ur
          where ur.user_id = u.id
            and ur.revoked_at is null
            and ur.role in ('admin', 'developer')
        ) then 'staff'
        else 'active'
      end as status_label,
      u.last_sign_in_at as last_seen_at,
      coalesce(p.updated_at, u.created_at) as updated_at,
      u.created_at
    from auth.users u
    left join public.profiles p
      on p.user_id = u.id
  ),
  filtered as (
    select *
    from raw_users
    where (v_query is null or email ilike '%' || v_query || '%' or display_name ilike '%' || v_query || '%')
      and (v_role is null or app_role = v_role)
      and (v_plan is null or plan = v_plan)
      and (v_status is null or v_status = 'all' or status_label = v_status)
  ),
  paged as (
    select *
    from filtered
    order by coalesce(last_seen_at, created_at) desc, email asc
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

drop function if exists public.admin_list_packs();

create or replace function public.admin_list_packs()
returns table (
  id text,
  name text,
  from_lang text,
  to_lang text,
  word_count integer,
  reading_count integer,
  is_pro boolean,
  is_published boolean,
  publish_at timestamptz,
  unpublish_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  updated_by_email text
)
language sql
security definer
set search_path = public, auth
as $$
  select
    p.id::text,
    coalesce(p.name, ''),
    coalesce(p.from_lang, 'en'),
    coalesce(p.to_lang, 'tr'),
    (
      select count(*)::integer
      from public.words w
      where w.pack_id = p.id
    ) as word_count,
    (
      select count(*)::integer
      from public.reading_passages rp
      where rp.pack_id = p.id
    ) as reading_count,
    coalesce(p.is_pro, false),
    coalesce(p.is_published, false),
    p.publish_at,
    p.unpublish_at,
    p.created_at,
    p.updated_at,
    coalesce(actor.email, '')
  from public.packs p
  left join auth.users actor
    on actor.id = p.updated_by
  where public.is_admin_or_developer()
  order by p.name asc;
$$;

create or replace function public.admin_list_words_paged(
  p_pack_id uuid default null,
  p_query text default null,
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
  v_status text := nullif(lower(trim(coalesce(p_status, ''))), '');
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  with filtered as (
    select
      w.id::text as id,
      w.pack_id::text as pack_id,
      coalesce(w.en_word, '') as en_word,
      coalesce(w.tr_meaning, '') as tr_meaning,
      coalesce(w.pos, '') as pos,
      w.pos_raw,
      coalesce(w.example_en, '') as example_en,
      w.example_tr,
      w.synonyms_raw,
      w.antonyms_raw,
      w.level,
      w.tags_raw,
      w.notes,
      coalesce(w.is_pro, false) as is_pro,
      coalesce(w.is_published, false) as is_published,
      w.publish_at,
      w.unpublish_at,
      w.created_at,
      w.updated_at,
      coalesce(actor.email, '') as updated_by_email
    from public.words w
    left join auth.users actor
      on actor.id = w.updated_by
    where (p_pack_id is null or w.pack_id = p_pack_id)
      and (
        v_query is null
        or concat_ws(
          ' ',
          w.en_word,
          w.tr_meaning,
          w.pos,
          coalesce(w.level, ''),
          coalesce(w.tags_raw, ''),
          coalesce(w.notes, '')
        ) ilike '%' || v_query || '%'
      )
      and (
        v_status is null
        or v_status = 'all'
        or (v_status = 'published' and coalesce(w.is_published, false))
        or (v_status = 'draft' and not coalesce(w.is_published, false))
      )
  ),
  paged as (
    select *
    from filtered
    order by en_word asc
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
      rp.publish_at,
      rp.unpublish_at,
      rp.created_at,
      rp.updated_at,
      coalesce(actor.email, '') as updated_by_email
    from public.reading_passages rp
    left join auth.users actor
      on actor.id = rp.updated_by
    where (
        v_query is null
        or concat_ws(
          ' ',
          rp.title,
          coalesce(rp.category, ''),
          coalesce(rp.level, ''),
          coalesce(rp.tags_raw, '')
        ) ilike '%' || v_query || '%'
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

drop function if exists public.admin_list_grammar_modules();

create or replace function public.admin_list_grammar_modules()
returns table (
  id bigint,
  sira integer,
  baslik text,
  dosya_adi text,
  toplam_sayfa integer,
  icon text,
  renk text,
  is_published boolean,
  publish_at timestamptz,
  unpublish_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  updated_by_email text
)
language sql
security definer
set search_path = public, auth
as $$
  select
    gm.id::bigint,
    gm.sira,
    coalesce(gm.baslik, ''),
    coalesce(gm.dosya_adi, ''),
    coalesce(gm.toplam_sayfa, 0),
    coalesce(gm.icon, 'menu_book'),
    coalesce(gm.renk, '#4776E6'),
    coalesce(gm.is_published, false),
    gm.publish_at,
    gm.unpublish_at,
    gm.created_at,
    gm.updated_at,
    coalesce(actor.email, '')
  from public.gramer_modulleri gm
  left join auth.users actor
    on actor.id = gm.updated_by
  where public.is_admin_or_developer()
  order by gm.sira asc nulls last, gm.id asc;
$$;

create or replace function public.admin_get_pack_detail(
  p_pack_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_payload jsonb;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select jsonb_build_object(
    'id', p.id::text,
    'name', coalesce(p.name, ''),
    'from_lang', coalesce(p.from_lang, 'en'),
    'to_lang', coalesce(p.to_lang, 'tr'),
    'is_pro', coalesce(p.is_pro, false),
    'is_published', coalesce(p.is_published, false),
    'publish_at', p.publish_at,
    'unpublish_at', p.unpublish_at,
    'word_count', (select count(*)::integer from public.words w where w.pack_id = p.id),
    'reading_count', (select count(*)::integer from public.reading_passages rp where rp.pack_id = p.id),
    'created_at', p.created_at,
    'updated_at', p.updated_at,
    'created_by_email', coalesce(created_actor.email, ''),
    'updated_by_email', coalesce(updated_actor.email, '')
  )
  into v_payload
  from public.packs p
  left join auth.users created_actor
    on created_actor.id = p.created_by
  left join auth.users updated_actor
    on updated_actor.id = p.updated_by
  where p.id = p_pack_id;

  if v_payload is null then
    raise exception 'pack not found';
  end if;

  return v_payload;
end;
$$;

create or replace function public.admin_upsert_pack_detail(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_pack_id uuid := coalesce(nullif(trim(coalesce(p_payload->>'id', '')), '')::uuid, gen_random_uuid());
  v_name text := nullif(trim(coalesce(p_payload->>'name', '')), '');
  v_from_lang text := coalesce(nullif(trim(coalesce(p_payload->>'from_lang', '')), ''), 'en');
  v_to_lang text := coalesce(nullif(trim(coalesce(p_payload->>'to_lang', '')), ''), 'tr');
  v_is_pro boolean := coalesce((p_payload->>'is_pro')::boolean, false);
  v_is_published boolean := coalesce((p_payload->>'is_published')::boolean, true);
  v_publish_at timestamptz := nullif(trim(coalesce(p_payload->>'publish_at', '')), '')::timestamptz;
  v_unpublish_at timestamptz := nullif(trim(coalesce(p_payload->>'unpublish_at', '')), '')::timestamptz;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_name is null then
    raise exception 'pack name required';
  end if;

  if nullif(trim(coalesce(p_payload->>'id', '')), '') is null then
    insert into public.packs (
      id,
      name,
      from_lang,
      to_lang,
      is_pro,
      is_published,
      published_at,
      publish_at,
      unpublish_at,
      created_by,
      updated_by
    )
    values (
      v_pack_id,
      v_name,
      v_from_lang,
      v_to_lang,
      v_is_pro,
      v_is_published,
      case when v_is_published then now() else null end,
      v_publish_at,
      v_unpublish_at,
      auth.uid(),
      auth.uid()
    );
  else
    update public.packs
    set name = v_name,
        from_lang = v_from_lang,
        to_lang = v_to_lang,
        is_pro = v_is_pro,
        is_published = v_is_published,
        published_at = case
          when v_is_published then coalesce(published_at, now())
          else null
        end,
        publish_at = v_publish_at,
        unpublish_at = v_unpublish_at,
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_pack_id;

    if not found then
      raise exception 'pack not found';
    end if;
  end if;

  perform public.write_audit_log(
    case
      when nullif(trim(coalesce(p_payload->>'id', '')), '') is null then 'admin.pack.created'
      else 'admin.pack.updated'
    end,
    'pack',
    v_pack_id::text,
    jsonb_build_object(
      'name', v_name,
      'from_lang', v_from_lang,
      'to_lang', v_to_lang,
      'is_pro', v_is_pro,
      'is_published', v_is_published,
      'publish_at', v_publish_at,
      'unpublish_at', v_unpublish_at
    )
  );

  return public.admin_get_pack_detail(v_pack_id);
end;
$$;

create or replace function public.admin_get_word_detail(
  p_word_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_payload jsonb;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select jsonb_build_object(
    'id', w.id::text,
    'pack_id', w.pack_id::text,
    'en_word', coalesce(w.en_word, ''),
    'tr_meaning', coalesce(w.tr_meaning, ''),
    'pos', coalesce(w.pos, 'noun'),
    'pos_raw', w.pos_raw,
    'example_en', coalesce(w.example_en, ''),
    'example_tr', w.example_tr,
    'synonyms_raw', w.synonyms_raw,
    'antonyms_raw', w.antonyms_raw,
    'level', w.level,
    'tags_raw', w.tags_raw,
    'notes', w.notes,
    'is_pro', coalesce(w.is_pro, false),
    'is_published', coalesce(w.is_published, false),
    'publish_at', w.publish_at,
    'unpublish_at', w.unpublish_at,
    'created_at', w.created_at,
    'updated_at', w.updated_at,
    'created_by_email', coalesce(created_actor.email, ''),
    'updated_by_email', coalesce(updated_actor.email, '')
  )
  into v_payload
  from public.words w
  left join auth.users created_actor
    on created_actor.id = w.created_by
  left join auth.users updated_actor
    on updated_actor.id = w.updated_by
  where w.id = p_word_id;

  if v_payload is null then
    raise exception 'word not found';
  end if;

  return v_payload;
end;
$$;

create or replace function public.admin_upsert_word_detail(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_word_id uuid := coalesce(nullif(trim(coalesce(p_payload->>'id', '')), '')::uuid, gen_random_uuid());
  v_existing_id uuid;
  v_pack_id uuid := nullif(trim(coalesce(p_payload->>'pack_id', '')), '')::uuid;
  v_en_word text := nullif(trim(coalesce(p_payload->>'en_word', '')), '');
  v_tr_meaning text := nullif(trim(coalesce(p_payload->>'tr_meaning', '')), '');
  v_pos text := coalesce(nullif(trim(coalesce(p_payload->>'pos', '')), ''), 'noun');
  v_pos_raw text := nullif(trim(coalesce(p_payload->>'pos_raw', '')), '');
  v_example_en text := nullif(trim(coalesce(p_payload->>'example_en', '')), '');
  v_example_tr text := nullif(trim(coalesce(p_payload->>'example_tr', '')), '');
  v_synonyms_raw text := nullif(trim(coalesce(p_payload->>'synonyms_raw', '')), '');
  v_antonyms_raw text := nullif(trim(coalesce(p_payload->>'antonyms_raw', '')), '');
  v_level text := nullif(trim(coalesce(p_payload->>'level', '')), '');
  v_tags_raw text := nullif(trim(coalesce(p_payload->>'tags_raw', '')), '');
  v_notes text := nullif(trim(coalesce(p_payload->>'notes', '')), '');
  v_is_pro boolean := coalesce((p_payload->>'is_pro')::boolean, false);
  v_is_published boolean := coalesce((p_payload->>'is_published')::boolean, true);
  v_publish_at timestamptz := nullif(trim(coalesce(p_payload->>'publish_at', '')), '')::timestamptz;
  v_unpublish_at timestamptz := nullif(trim(coalesce(p_payload->>'unpublish_at', '')), '')::timestamptz;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_pack_id is null then
    raise exception 'pack required';
  end if;

  if v_en_word is null then
    raise exception 'english word required';
  end if;

  if v_tr_meaning is null then
    raise exception 'turkish meaning required';
  end if;

  if v_example_en is null then
    raise exception 'example sentence required';
  end if;

  if nullif(trim(coalesce(p_payload->>'id', '')), '') is null then
    insert into public.words (
      id,
      pack_id,
      en_word,
      tr_meaning,
      pos,
      pos_raw,
      example_en,
      example_tr,
      synonyms_raw,
      antonyms_raw,
      level,
      tags_raw,
      notes,
      is_pro,
      is_published,
      published_at,
      publish_at,
      unpublish_at,
      created_by,
      updated_by
    )
    values (
      v_word_id,
      v_pack_id,
      v_en_word,
      v_tr_meaning,
      v_pos,
      v_pos_raw,
      v_example_en,
      v_example_tr,
      v_synonyms_raw,
      v_antonyms_raw,
      v_level,
      v_tags_raw,
      v_notes,
      v_is_pro,
      v_is_published,
      case when v_is_published then now() else null end,
      v_publish_at,
      v_unpublish_at,
      auth.uid(),
      auth.uid()
    )
    on conflict (pack_id, en_word, pos) do update
      set tr_meaning = excluded.tr_meaning,
          pos_raw = excluded.pos_raw,
          example_en = excluded.example_en,
          example_tr = excluded.example_tr,
          synonyms_raw = excluded.synonyms_raw,
          antonyms_raw = excluded.antonyms_raw,
          level = excluded.level,
          tags_raw = excluded.tags_raw,
          notes = excluded.notes,
          is_pro = excluded.is_pro,
          is_published = excluded.is_published,
          published_at = case
            when excluded.is_published then coalesce(public.words.published_at, now())
            else null
          end,
          publish_at = excluded.publish_at,
          unpublish_at = excluded.unpublish_at,
          updated_at = now(),
          updated_by = auth.uid()
    returning id into v_existing_id;

    v_word_id := coalesce(v_existing_id, v_word_id);
  else
    update public.words
    set pack_id = v_pack_id,
        en_word = v_en_word,
        tr_meaning = v_tr_meaning,
        pos = v_pos,
        pos_raw = v_pos_raw,
        example_en = v_example_en,
        example_tr = v_example_tr,
        synonyms_raw = v_synonyms_raw,
        antonyms_raw = v_antonyms_raw,
        level = v_level,
        tags_raw = v_tags_raw,
        notes = v_notes,
        is_pro = v_is_pro,
        is_published = v_is_published,
        published_at = case
          when v_is_published then coalesce(published_at, now())
          else null
        end,
        publish_at = v_publish_at,
        unpublish_at = v_unpublish_at,
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_word_id;

    if not found then
      raise exception 'word not found';
    end if;
  end if;

  perform public.write_audit_log(
    case
      when nullif(trim(coalesce(p_payload->>'id', '')), '') is null then 'admin.word.created'
      else 'admin.word.updated'
    end,
    'word',
    v_word_id::text,
    jsonb_build_object(
      'pack_id', v_pack_id,
      'en_word', v_en_word,
      'pos', v_pos,
      'is_pro', v_is_pro,
      'is_published', v_is_published,
      'publish_at', v_publish_at,
      'unpublish_at', v_unpublish_at
    )
  );

  return public.admin_get_word_detail(v_word_id);
end;
$$;

create or replace function public.admin_get_reading_detail(
  p_passage_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_payload jsonb;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select jsonb_build_object(
    'id', rp.id::text,
    'pack_id', rp.pack_id::text,
    'title', coalesce(rp.title, ''),
    'level', rp.level,
    'category', rp.category,
    'tags_raw', rp.tags_raw,
    'is_pro', coalesce(rp.is_pro, false),
    'is_published', coalesce(rp.is_published, false),
    'publish_at', rp.publish_at,
    'unpublish_at', rp.unpublish_at,
    'created_at', rp.created_at,
    'updated_at', rp.updated_at,
    'created_by_email', coalesce(created_actor.email, ''),
    'updated_by_email', coalesce(updated_actor.email, ''),
    'sentences',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', sentence.id::text,
              'idx', sentence.idx,
              'sentence_en', sentence.sentence_en,
              'sentence_tr', sentence.sentence_tr,
              'translations',
                coalesce(
                  (
                    select jsonb_agg(
                      jsonb_build_object(
                        'id', translation.id::text,
                        'provider', translation.provider,
                        'target_lang', translation.target_lang,
                        'translated_text', translation.translated_text
                      )
                      order by translation.provider asc, translation.target_lang asc
                    )
                    from public.reading_sentence_translations translation
                    where translation.sentence_id = sentence.id
                  ),
                  '[]'::jsonb
                )
            )
            order by sentence.idx asc
          )
          from public.reading_passage_sentences sentence
          where sentence.passage_id = rp.id
        ),
        '[]'::jsonb
      ),
    'linked_words',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'word_id', word_row.id::text,
              'en_word', word_row.en_word,
              'tr_meaning', word_row.tr_meaning
            )
            order by word_row.en_word asc
          )
          from public.reading_passage_words link_row
          join public.words word_row
            on word_row.id = link_row.word_id
          where link_row.passage_id = rp.id
        ),
        '[]'::jsonb
      )
  )
  into v_payload
  from public.reading_passages rp
  left join auth.users created_actor
    on created_actor.id = rp.created_by
  left join auth.users updated_actor
    on updated_actor.id = rp.updated_by
  where rp.id = p_passage_id;

  if v_payload is null then
    raise exception 'reading passage not found';
  end if;

  return v_payload;
end;
$$;

create or replace function public.admin_upsert_reading_detail(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_passage_id uuid := coalesce(nullif(trim(coalesce(p_payload->>'id', '')), '')::uuid, gen_random_uuid());
  v_pack_id uuid := nullif(trim(coalesce(p_payload->>'pack_id', '')), '')::uuid;
  v_pack_name text;
  v_title text := nullif(trim(coalesce(p_payload->>'title', '')), '');
  v_level text := nullif(trim(coalesce(p_payload->>'level', '')), '');
  v_category text := nullif(trim(coalesce(p_payload->>'category', '')), '');
  v_tags_raw text := nullif(trim(coalesce(p_payload->>'tags_raw', '')), '');
  v_is_pro boolean := coalesce((p_payload->>'is_pro')::boolean, false);
  v_is_published boolean := coalesce((p_payload->>'is_published')::boolean, true);
  v_publish_at timestamptz := nullif(trim(coalesce(p_payload->>'publish_at', '')), '')::timestamptz;
  v_unpublish_at timestamptz := nullif(trim(coalesce(p_payload->>'unpublish_at', '')), '')::timestamptz;
  v_sentences jsonb := case
    when jsonb_typeof(p_payload->'sentences') = 'array' then p_payload->'sentences'
    else '[]'::jsonb
  end;
  v_linked_words jsonb := case
    when jsonb_typeof(p_payload->'linked_words') = 'array' then p_payload->'linked_words'
    else '[]'::jsonb
  end;
  v_sentence record;
  v_translation record;
  v_linked_word record;
  v_sentence_id uuid;
  v_linked_word_id uuid;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_title is null then
    raise exception 'title required';
  end if;

  if v_pack_id is not null then
    select p.name into v_pack_name
    from public.packs p
    where p.id = v_pack_id;

    if v_pack_name is null then
      raise exception 'pack not found';
    end if;
  else
    v_pack_name := null;
  end if;

  if nullif(trim(coalesce(p_payload->>'id', '')), '') is null then
    insert into public.reading_passages (
      id,
      pack_id,
      pack_name,
      title,
      level,
      category,
      tags_raw,
      is_pro,
      is_published,
      published_at,
      publish_at,
      unpublish_at,
      created_by,
      updated_by
    )
    values (
      v_passage_id,
      v_pack_id,
      v_pack_name,
      v_title,
      v_level,
      v_category,
      v_tags_raw,
      v_is_pro,
      v_is_published,
      case when v_is_published then now() else null end,
      v_publish_at,
      v_unpublish_at,
      auth.uid(),
      auth.uid()
    );
  else
    update public.reading_passages
    set pack_id = v_pack_id,
        pack_name = v_pack_name,
        title = v_title,
        level = v_level,
        category = v_category,
        tags_raw = v_tags_raw,
        is_pro = v_is_pro,
        is_published = v_is_published,
        published_at = case
          when v_is_published then coalesce(published_at, now())
          else null
        end,
        publish_at = v_publish_at,
        unpublish_at = v_unpublish_at,
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_passage_id;

    if not found then
      raise exception 'reading passage not found';
    end if;
  end if;

  delete from public.reading_passage_words
  where passage_id = v_passage_id;

  delete from public.reading_passage_sentences
  where passage_id = v_passage_id;

  for v_sentence in
    select value, ordinality
    from jsonb_array_elements(v_sentences) with ordinality as source(value, ordinality)
  loop
    if nullif(trim(coalesce(v_sentence.value->>'sentence_en', '')), '') is null then
      continue;
    end if;

    insert into public.reading_passage_sentences (
      passage_id,
      passage_title,
      idx,
      sentence_en,
      sentence_tr
    )
    values (
      v_passage_id,
      v_title,
      greatest(
        coalesce(nullif(trim(coalesce(v_sentence.value->>'idx', '')), '')::integer, v_sentence.ordinality::integer),
        1
      ),
      trim(v_sentence.value->>'sentence_en'),
      nullif(trim(coalesce(v_sentence.value->>'sentence_tr', '')), '')
    )
    returning id into v_sentence_id;

    if jsonb_typeof(v_sentence.value->'translations') = 'array' then
      for v_translation in
        select value
        from jsonb_array_elements(v_sentence.value->'translations')
      loop
        if nullif(trim(coalesce(v_translation.value->>'translated_text', '')), '') is null then
          continue;
        end if;

        insert into public.reading_sentence_translations (
          sentence_id,
          provider,
          target_lang,
          translated_text
        )
        values (
          v_sentence_id,
          coalesce(nullif(trim(coalesce(v_translation.value->>'provider', '')), ''), 'manual'),
          coalesce(nullif(trim(coalesce(v_translation.value->>'target_lang', '')), ''), 'tr'),
          trim(v_translation.value->>'translated_text')
        );
      end loop;
    end if;
  end loop;

  for v_linked_word in
    select value
    from jsonb_array_elements(v_linked_words)
  loop
    v_linked_word_id := nullif(trim(coalesce(v_linked_word.value->>'word_id', '')), '')::uuid;
    if v_linked_word_id is null then
      continue;
    end if;

    insert into public.reading_passage_words (
      passage_id,
      word_id
    )
    values (
      v_passage_id,
      v_linked_word_id
    )
    on conflict do nothing;
  end loop;

  perform public.write_audit_log(
    case
      when nullif(trim(coalesce(p_payload->>'id', '')), '') is null then 'admin.reading.created'
      else 'admin.reading.updated'
    end,
    'reading',
    v_passage_id::text,
    jsonb_build_object(
      'title', v_title,
      'pack_id', v_pack_id,
      'is_pro', v_is_pro,
      'is_published', v_is_published,
      'sentence_count', jsonb_array_length(v_sentences),
      'linked_word_count', jsonb_array_length(v_linked_words),
      'publish_at', v_publish_at,
      'unpublish_at', v_unpublish_at
    )
  );

  return public.admin_get_reading_detail(v_passage_id);
end;
$$;

create or replace function public.admin_get_grammar_module_detail(
  p_module_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_payload jsonb;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select jsonb_build_object(
    'id', gm.id::text,
    'sort_order', gm.sira,
    'title', coalesce(gm.baslik, ''),
    'file_name', coalesce(gm.dosya_adi, ''),
    'icon', coalesce(gm.icon, 'menu_book'),
    'color', coalesce(gm.renk, '#4776E6'),
    'is_published', coalesce(gm.is_published, false),
    'publish_at', gm.publish_at,
    'unpublish_at', gm.unpublish_at,
    'created_at', gm.created_at,
    'updated_at', gm.updated_at,
    'created_by_email', coalesce(created_actor.email, ''),
    'updated_by_email', coalesce(updated_actor.email, ''),
    'pages',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', page_row.id::text,
              'page_number', page_row.sayfa_no,
              'title', page_row.baslik,
              'html_content', page_row.icerik_html,
              'word_count', page_row.kelime_sayisi,
              'examples',
                coalesce(
                  (
                    select jsonb_agg(
                      jsonb_build_object(
                        'id', example_row.id::text,
                        'sort_order', example_row.sira,
                        'english', example_row.ingilizce,
                        'turkish', example_row.turkce,
                        'description', example_row.aciklama
                      )
                      order by example_row.sira asc, example_row.id asc
                    )
                    from public.gramer_ornekler example_row
                    where example_row.sayfa_id = page_row.id
                  ),
                  '[]'::jsonb
                ),
              'tests',
                coalesce(
                  (
                    select jsonb_agg(
                      jsonb_build_object(
                        'id', test_row.id::text,
                        'sort_order', test_row.sira,
                        'question', test_row.soru,
                        'options', case
                          when jsonb_typeof(test_row.secenekler_json) = 'array' then test_row.secenekler_json
                          else coalesce(
                            (
                              select jsonb_agg(option_value order by option_key)
                              from jsonb_each_text(coalesce(test_row.secenekler_json, '{}'::jsonb)) as option_map(option_key, option_value)
                            ),
                            '[]'::jsonb
                          )
                        end,
                        'correct_answer', test_row.dogru_cevap,
                        'description', test_row.aciklama
                      )
                      order by test_row.sira asc, test_row.id asc
                    )
                    from public.gramer_testler test_row
                    where test_row.sayfa_id = page_row.id
                  ),
                  '[]'::jsonb
                )
            )
            order by page_row.sayfa_no asc, page_row.id asc
          )
          from public.gramer_sayfalari page_row
          where page_row.modul_id = gm.id
        ),
        '[]'::jsonb
      )
  )
  into v_payload
  from public.gramer_modulleri gm
  left join auth.users created_actor
    on created_actor.id = gm.created_by
  left join auth.users updated_actor
    on updated_actor.id = gm.updated_by
  where gm.id = p_module_id;

  if v_payload is null then
    raise exception 'grammar module not found';
  end if;

  return v_payload;
end;
$$;

create or replace function public.admin_upsert_grammar_module_detail(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_module_id bigint := coalesce(nullif(trim(coalesce(p_payload->>'id', '')), '')::bigint, 0);
  v_module_id_created bigint;
  v_sort_order integer := nullif(trim(coalesce(p_payload->>'sort_order', '')), '')::integer;
  v_title text := nullif(trim(coalesce(p_payload->>'title', '')), '');
  v_file_name text := nullif(trim(coalesce(p_payload->>'file_name', '')), '');
  v_icon text := coalesce(nullif(trim(coalesce(p_payload->>'icon', '')), ''), 'menu_book');
  v_color text := coalesce(nullif(trim(coalesce(p_payload->>'color', '')), ''), '#4776E6');
  v_is_published boolean := coalesce((p_payload->>'is_published')::boolean, true);
  v_publish_at timestamptz := nullif(trim(coalesce(p_payload->>'publish_at', '')), '')::timestamptz;
  v_unpublish_at timestamptz := nullif(trim(coalesce(p_payload->>'unpublish_at', '')), '')::timestamptz;
  v_pages jsonb := case
    when jsonb_typeof(p_payload->'pages') = 'array' then p_payload->'pages'
    else '[]'::jsonb
  end;
  v_page record;
  v_example record;
  v_test record;
  v_page_id bigint;
  v_page_count integer := 0;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_title is null then
    raise exception 'title required';
  end if;

  if v_file_name is null then
    raise exception 'file name required';
  end if;

  v_page_count := jsonb_array_length(v_pages);

  if v_module_id = 0 then
    select coalesce(v_sort_order, coalesce(max(gm.sira), 0) + 1)
    into v_sort_order
    from public.gramer_modulleri gm;

    insert into public.gramer_modulleri (
      sira,
      baslik,
      dosya_adi,
      toplam_sayfa,
      icon,
      renk,
      is_published,
      published_at,
      publish_at,
      unpublish_at,
      created_by,
      updated_by
    )
    values (
      coalesce(v_sort_order, 1),
      v_title,
      v_file_name,
      v_page_count,
      v_icon,
      v_color,
      v_is_published,
      case when v_is_published then now() else null end,
      v_publish_at,
      v_unpublish_at,
      auth.uid(),
      auth.uid()
    )
    returning id into v_module_id_created;

    v_module_id := v_module_id_created;
  else
    if v_sort_order is null then
      select gm.sira into v_sort_order
      from public.gramer_modulleri gm
      where gm.id = v_module_id;
    end if;

    update public.gramer_modulleri
    set sira = coalesce(v_sort_order, sira),
        baslik = v_title,
        dosya_adi = v_file_name,
        toplam_sayfa = v_page_count,
        icon = v_icon,
        renk = v_color,
        is_published = v_is_published,
        published_at = case
          when v_is_published then coalesce(published_at, now())
          else null
        end,
        publish_at = v_publish_at,
        unpublish_at = v_unpublish_at,
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_module_id;

    if not found then
      raise exception 'grammar module not found';
    end if;
  end if;

  delete from public.gramer_sayfalari
  where modul_id = v_module_id;

  for v_page in
    select value, ordinality
    from jsonb_array_elements(v_pages) with ordinality as source(value, ordinality)
  loop
    if nullif(trim(coalesce(v_page.value->>'title', '')), '') is null then
      continue;
    end if;

    insert into public.gramer_sayfalari (
      modul_id,
      sayfa_no,
      baslik,
      icerik_html,
      kelime_sayisi,
      is_published,
      published_at,
      created_by,
      updated_by
    )
    values (
      v_module_id,
      greatest(
        coalesce(nullif(trim(coalesce(v_page.value->>'page_number', '')), '')::integer, v_page.ordinality::integer),
        1
      ),
      trim(v_page.value->>'title'),
      coalesce(v_page.value->>'html_content', ''),
      public.admin_count_words_from_html(coalesce(v_page.value->>'html_content', '')),
      v_is_published,
      case when v_is_published then now() else null end,
      auth.uid(),
      auth.uid()
    )
    returning id into v_page_id;

    if jsonb_typeof(v_page.value->'examples') = 'array' then
      for v_example in
        select value, ordinality
        from jsonb_array_elements(v_page.value->'examples') with ordinality as source(value, ordinality)
      loop
        if nullif(trim(coalesce(v_example.value->>'english', '')), '') is null then
          continue;
        end if;

        insert into public.gramer_ornekler (
          sayfa_id,
          sira,
          ingilizce,
          turkce,
          aciklama,
          is_published,
          created_by,
          updated_by
        )
        values (
          v_page_id,
          greatest(
            coalesce(nullif(trim(coalesce(v_example.value->>'sort_order', '')), '')::integer, v_example.ordinality::integer),
            1
          ),
          trim(v_example.value->>'english'),
          coalesce(v_example.value->>'turkish', ''),
          nullif(trim(coalesce(v_example.value->>'description', '')), ''),
          v_is_published,
          auth.uid(),
          auth.uid()
        );
      end loop;
    end if;

    if jsonb_typeof(v_page.value->'tests') = 'array' then
      for v_test in
        select value, ordinality
        from jsonb_array_elements(v_page.value->'tests') with ordinality as source(value, ordinality)
      loop
        if nullif(trim(coalesce(v_test.value->>'question', '')), '') is null then
          continue;
        end if;

        insert into public.gramer_testler (
          sayfa_id,
          sira,
          soru,
          secenekler_json,
          dogru_cevap,
          aciklama,
          is_published,
          created_by,
          updated_by
        )
        values (
          v_page_id,
          greatest(
            coalesce(nullif(trim(coalesce(v_test.value->>'sort_order', '')), '')::integer, v_test.ordinality::integer),
            1
          ),
          trim(v_test.value->>'question'),
          case
            when jsonb_typeof(v_test.value->'options') = 'array' then v_test.value->'options'
            else '[]'::jsonb
          end,
          nullif(trim(coalesce(v_test.value->>'correct_answer', '')), ''),
          nullif(trim(coalesce(v_test.value->>'description', '')), ''),
          v_is_published,
          auth.uid(),
          auth.uid()
        );
      end loop;
    end if;
  end loop;

  perform public.write_audit_log(
    case
      when nullif(trim(coalesce(p_payload->>'id', '')), '') is null then 'admin.grammar.created'
      else 'admin.grammar.updated'
    end,
    'grammar',
    v_module_id::text,
    jsonb_build_object(
      'title', v_title,
      'file_name', v_file_name,
      'page_count', v_page_count,
      'is_published', v_is_published,
      'publish_at', v_publish_at,
      'unpublish_at', v_unpublish_at
    )
  );

  return public.admin_get_grammar_module_detail(v_module_id);
end;
$$;

grant execute on function public.admin_count_words_from_html(text) to authenticated;
grant execute on function public.admin_list_users_paged(text, text, text, text, integer, integer) to authenticated;
grant execute on function public.admin_list_packs() to authenticated;
grant execute on function public.admin_list_words_paged(uuid, text, text, integer, integer) to authenticated;
grant execute on function public.admin_list_reading_passages_paged(text, text, text, integer, integer) to authenticated;
grant execute on function public.admin_list_grammar_modules() to authenticated;
grant execute on function public.admin_get_pack_detail(uuid) to authenticated;
grant execute on function public.admin_upsert_pack_detail(jsonb) to authenticated;
grant execute on function public.admin_get_word_detail(uuid) to authenticated;
grant execute on function public.admin_upsert_word_detail(jsonb) to authenticated;
grant execute on function public.admin_get_reading_detail(uuid) to authenticated;
grant execute on function public.admin_upsert_reading_detail(jsonb) to authenticated;
grant execute on function public.admin_get_grammar_module_detail(bigint) to authenticated;
grant execute on function public.admin_upsert_grammar_module_detail(jsonb) to authenticated;

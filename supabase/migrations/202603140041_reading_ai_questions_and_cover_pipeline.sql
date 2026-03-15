alter table public.reading_passages
  add column if not exists cover_media_asset_id uuid references public.media_assets(id) on delete set null,
  add column if not exists cover_bucket_name text,
  add column if not exists cover_storage_path text,
  add column if not exists cover_alt_text text,
  add column if not exists cover_generation_meta jsonb;

create index if not exists ix_reading_passages_cover_media_asset_id
  on public.reading_passages (cover_media_asset_id);

insert into storage.buckets (id, name, public)
values ('reading-covers', 'reading-covers', true)
on conflict (id) do update
set public = excluded.public,
    name = excluded.name;

drop policy if exists reading_covers_public_read on storage.objects;
create policy reading_covers_public_read
on storage.objects
for select
to public
using (bucket_id = 'reading-covers');

drop policy if exists reading_covers_admin_insert on storage.objects;
create policy reading_covers_admin_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'reading-covers'
  and public.is_admin_or_developer()
);

drop policy if exists reading_covers_admin_update on storage.objects;
create policy reading_covers_admin_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'reading-covers'
  and public.is_admin_or_developer()
)
with check (
  bucket_id = 'reading-covers'
  and public.is_admin_or_developer()
);

drop policy if exists reading_covers_admin_delete on storage.objects;
create policy reading_covers_admin_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'reading-covers'
  and public.is_admin_or_developer()
);

create table if not exists public.reading_ai_runs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null,
  status text not null default 'queued',
  provider text not null,
  model text not null,
  question_count integer not null default 3,
  filter_snapshot jsonb not null default '{}'::jsonb,
  total_count integer not null default 0,
  processed_count integer not null default 0,
  succeeded_count integer not null default 0,
  failed_count integer not null default 0,
  skipped_count integer not null default 0,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  constraint reading_ai_runs_job_type_check check (
    job_type in ('question_backfill', 'cover_backfill')
  ),
  constraint reading_ai_runs_status_check check (
    status in ('queued', 'running', 'completed', 'failed', 'cancelled')
  )
);

create table if not exists public.reading_ai_run_items (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.reading_ai_runs(id) on delete cascade,
  passage_id uuid not null references public.reading_passages(id) on delete cascade,
  status text not null default 'queued',
  error_message text,
  attempt_count integer not null default 0,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reading_ai_run_items_status_check check (
    status in ('queued', 'processing', 'succeeded', 'failed', 'skipped')
  ),
  constraint ux_reading_ai_run_items_run_passage unique (run_id, passage_id)
);

create index if not exists ix_reading_ai_run_items_run_status
  on public.reading_ai_run_items (run_id, status, created_at);

drop trigger if exists trg_reading_ai_runs_updated_at
  on public.reading_ai_runs;
create trigger trg_reading_ai_runs_updated_at
before update on public.reading_ai_runs
for each row execute function public.set_updated_at();

drop trigger if exists trg_reading_ai_run_items_updated_at
  on public.reading_ai_run_items;
create trigger trg_reading_ai_run_items_updated_at
before update on public.reading_ai_run_items
for each row execute function public.set_updated_at();

alter table public.reading_ai_runs enable row level security;
alter table public.reading_ai_run_items enable row level security;

grant select on table public.reading_ai_runs to authenticated;
grant select on table public.reading_ai_run_items to authenticated;

drop policy if exists reading_ai_runs_select_admin on public.reading_ai_runs;
create policy reading_ai_runs_select_admin
on public.reading_ai_runs
for select
to authenticated
using (public.is_admin_or_developer());

drop policy if exists reading_ai_run_items_select_admin on public.reading_ai_run_items;
create policy reading_ai_run_items_select_admin
on public.reading_ai_run_items
for select
to authenticated
using (public.is_admin_or_developer());

drop function if exists public.student_list_reading_catalog();
create or replace function public.student_list_reading_catalog()
returns table (
  id text,
  pack_id text,
  title text,
  level text,
  category text,
  tags_raw text,
  summary text,
  question_count integer,
  cover_bucket_name text,
  cover_storage_path text,
  cover_alt_text text,
  is_published boolean,
  is_pro boolean,
  updated_at timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    rp.id::text,
    rp.pack_id::text,
    coalesce(rp.title, ''),
    rp.level,
    rp.category,
    rp.tags_raw,
    null::text as summary,
    (
      select count(*)::integer
      from public.reading_passage_questions question_row
      where question_row.passage_id = rp.id
        and coalesce(question_row.is_published, false)
    ) as question_count,
    rp.cover_bucket_name,
    rp.cover_storage_path,
    rp.cover_alt_text,
    coalesce(rp.is_published, false),
    coalesce(rp.is_pro, false),
    rp.updated_at,
    rp.created_at
  from public.reading_passages rp
  where coalesce(rp.is_published, false)
  order by
    case
      when substring(coalesce(rp.title, '') from '^\d+') is null then 2147483647
      else substring(coalesce(rp.title, '') from '^\d+')::integer
    end asc,
    lower(coalesce(rp.title, '')) asc;
$$;

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
    and (
      ccl.scope <> 'readings'
      or (
        ccl.entity_type = 'reading_passages'
        and (
          ccl.operation = 'delete'
          or coalesce((ccl.payload_json ->> 'is_published')::boolean, false)
        )
      )
      or (
        ccl.entity_type in (
          'reading_passage_sentences',
          'reading_passage_words',
          'reading_passage_questions'
        )
        and exists (
          select 1
          from public.reading_passages rp
          where rp.id::text = coalesce(
            ccl.payload_json ->> 'passage_id',
            split_part(ccl.entity_id, ':', 1)
          )
            and public.can_read_published_content(rp.is_published, rp.is_pro)
        )
      )
    )
  order by ccl.id asc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
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
  is_pro boolean,
  is_published boolean,
  linked_word_count integer,
  question_count integer,
  has_cover boolean,
  linked_words_preview jsonb,
  created_at timestamptz,
  updated_at timestamptz,
  updated_by_email text
)
language sql
security definer
set search_path = public, auth
as $$
  select
    rp.id::text,
    rp.pack_id::text,
    rp.pack_name,
    coalesce(rp.title, ''),
    rp.level,
    rp.category,
    rp.tags_raw,
    coalesce(rp.is_pro, false),
    coalesce(rp.is_published, false),
    (
      select count(*)::integer
      from public.reading_passage_words link_row
      where link_row.passage_id = rp.id
    ) as linked_word_count,
    (
      select count(*)::integer
      from public.reading_passage_questions question_row
      where question_row.passage_id = rp.id
    ) as question_count,
    (
      nullif(trim(coalesce(rp.cover_bucket_name, '')), '') is not null
      and nullif(trim(coalesce(rp.cover_storage_path, '')), '') is not null
    ) as has_cover,
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
  where public.is_admin_or_developer()
  order by lower(coalesce(rp.title, '')) asc;
$$;

drop function if exists public.admin_list_reading_passages_paged(text, text, text, integer, integer);
drop function if exists public.admin_list_reading_passages_paged(text, text, text, boolean, boolean, integer, integer);
create or replace function public.admin_list_reading_passages_paged(
  p_query text default null,
  p_level text default null,
  p_status text default null,
  p_has_questions boolean default null,
  p_has_cover boolean default null,
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
      (
        select count(*)::integer
        from public.reading_passage_questions question_row
        where question_row.passage_id = rp.id
      ) as question_count,
      (
        nullif(trim(coalesce(rp.cover_bucket_name, '')), '') is not null
        and nullif(trim(coalesce(rp.cover_storage_path, '')), '') is not null
      ) as has_cover,
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
      and (
        p_has_questions is null
        or (
          p_has_questions
          and exists (
            select 1
            from public.reading_passage_questions question_row
            where question_row.passage_id = rp.id
          )
        )
        or (
          not p_has_questions
          and not exists (
            select 1
            from public.reading_passage_questions question_row
            where question_row.passage_id = rp.id
          )
        )
      )
      and (
        p_has_cover is null
        or (
          p_has_cover
          and nullif(trim(coalesce(rp.cover_bucket_name, '')), '') is not null
          and nullif(trim(coalesce(rp.cover_storage_path, '')), '') is not null
        )
        or (
          not p_has_cover
          and (
            nullif(trim(coalesce(rp.cover_bucket_name, '')), '') is null
            or nullif(trim(coalesce(rp.cover_storage_path, '')), '') is null
          )
        )
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
    'ai_generated', coalesce(rp.ai_generated, false),
    'ai_generation_meta', rp.ai_generation_meta,
    'cover_media_asset_id', rp.cover_media_asset_id::text,
    'cover_bucket_name', rp.cover_bucket_name,
    'cover_storage_path', rp.cover_storage_path,
    'cover_alt_text', rp.cover_alt_text,
    'cover_generation_meta', rp.cover_generation_meta,
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
      ),
    'questions',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', question_row.id::text,
              'sort_order', question_row.sort_order,
              'question', question_row.question,
              'options', coalesce(question_row.options_json, '[]'::jsonb),
              'correct_option_index', question_row.correct_option_index,
              'explanation', question_row.explanation
            )
            order by question_row.sort_order asc, question_row.created_at asc
          )
          from public.reading_passage_questions question_row
          where question_row.passage_id = rp.id
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
  v_ai_generated boolean := coalesce((p_payload->>'ai_generated')::boolean, false);
  v_ai_generation_meta jsonb := case
    when jsonb_typeof(p_payload->'ai_generation_meta') = 'object' then p_payload->'ai_generation_meta'
    else null
  end;
  v_cover_media_asset_id uuid := nullif(trim(coalesce(p_payload->>'cover_media_asset_id', '')), '')::uuid;
  v_cover_bucket_name text := nullif(trim(coalesce(p_payload->>'cover_bucket_name', '')), '');
  v_cover_storage_path text := nullif(trim(coalesce(p_payload->>'cover_storage_path', '')), '');
  v_cover_alt_text text := nullif(trim(coalesce(p_payload->>'cover_alt_text', '')), '');
  v_cover_generation_meta jsonb := case
    when jsonb_typeof(p_payload->'cover_generation_meta') = 'object' then p_payload->'cover_generation_meta'
    else null
  end;
  v_sentences jsonb := case
    when jsonb_typeof(p_payload->'sentences') = 'array' then p_payload->'sentences'
    else '[]'::jsonb
  end;
  v_linked_words jsonb := case
    when jsonb_typeof(p_payload->'linked_words') = 'array' then p_payload->'linked_words'
    else '[]'::jsonb
  end;
  v_questions jsonb := case
    when jsonb_typeof(p_payload->'questions') = 'array' then p_payload->'questions'
    else '[]'::jsonb
  end;
  v_sentence record;
  v_translation record;
  v_linked_word record;
  v_question record;
  v_sentence_id uuid;
  v_linked_word_id uuid;
  v_question_sort_order integer;
  v_question_text text;
  v_question_options jsonb;
  v_correct_option_index integer;
  v_question_explanation text;
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
      ai_generated,
      ai_generation_meta,
      cover_media_asset_id,
      cover_bucket_name,
      cover_storage_path,
      cover_alt_text,
      cover_generation_meta,
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
      v_ai_generated,
      v_ai_generation_meta,
      v_cover_media_asset_id,
      v_cover_bucket_name,
      v_cover_storage_path,
      coalesce(v_cover_alt_text, v_title),
      v_cover_generation_meta,
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
        ai_generated = v_ai_generated,
        ai_generation_meta = v_ai_generation_meta,
        cover_media_asset_id = v_cover_media_asset_id,
        cover_bucket_name = v_cover_bucket_name,
        cover_storage_path = v_cover_storage_path,
        cover_alt_text = case
          when v_cover_bucket_name is null or v_cover_storage_path is null then null
          else coalesce(v_cover_alt_text, title)
        end,
        cover_generation_meta = v_cover_generation_meta,
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_passage_id;

    if not found then
      raise exception 'reading passage not found';
    end if;
  end if;

  delete from public.reading_passage_questions
  where passage_id = v_passage_id;

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

  for v_question in
    select value, ordinality
    from jsonb_array_elements(v_questions) with ordinality as source(value, ordinality)
  loop
    v_question_text := nullif(trim(coalesce(v_question.value->>'question', '')), '');
    if v_question_text is null then
      continue;
    end if;

    v_question_sort_order := greatest(
      coalesce(nullif(trim(coalesce(v_question.value->>'sort_order', '')), '')::integer, v_question.ordinality::integer),
      1
    );
    v_question_options := case
      when jsonb_typeof(v_question.value->'options') = 'array' then v_question.value->'options'
      else '[]'::jsonb
    end;
    v_correct_option_index := greatest(
      coalesce(nullif(trim(coalesce(v_question.value->>'correct_option_index', '')), '')::integer, 0),
      0
    );
    v_question_explanation := nullif(trim(coalesce(v_question.value->>'explanation', '')), '');

    insert into public.reading_passage_questions (
      passage_id,
      sort_order,
      question,
      options_json,
      correct_option_index,
      explanation,
      is_published,
      created_by,
      updated_by
    )
    values (
      v_passage_id,
      v_question_sort_order,
      v_question_text,
      v_question_options,
      v_correct_option_index,
      v_question_explanation,
      v_is_published,
      auth.uid(),
      auth.uid()
    );
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
      'question_count', jsonb_array_length(v_questions),
      'has_cover', v_cover_bucket_name is not null and v_cover_storage_path is not null,
      'ai_generated', v_ai_generated,
      'publish_at', v_publish_at,
      'unpublish_at', v_unpublish_at
    )
  );

  return public.admin_get_reading_detail(v_passage_id);
end;
$$;

create or replace function public.admin_set_reading_cover(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_passage_id uuid := nullif(trim(coalesce(p_payload->>'reading_id', '')), '')::uuid;
  v_bucket_name text := nullif(trim(coalesce(p_payload->>'bucket_name', '')), '');
  v_storage_path text := nullif(trim(coalesce(p_payload->>'storage_path', '')), '');
  v_mime_type text := nullif(trim(coalesce(p_payload->>'mime_type', '')), '');
  v_alt_text text := nullif(trim(coalesce(p_payload->>'alt_text', '')), '');
  v_generation_meta jsonb := case
    when jsonb_typeof(p_payload->'generation_meta') = 'object' then p_payload->'generation_meta'
    else null
  end;
  v_old_asset_id uuid;
  v_old_bucket_name text;
  v_old_storage_path text;
  v_asset_id uuid;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_passage_id is null or v_bucket_name is null or v_storage_path is null then
    raise exception 'reading_id, bucket_name and storage_path required';
  end if;

  select
    rp.cover_media_asset_id,
    rp.cover_bucket_name,
    rp.cover_storage_path
  into
    v_old_asset_id,
    v_old_bucket_name,
    v_old_storage_path
  from public.reading_passages rp
  where rp.id = v_passage_id;

  if not found then
    raise exception 'reading passage not found';
  end if;

  insert into public.media_assets (
    bucket_name,
    storage_path,
    mime_type,
    is_published,
    metadata
  )
  values (
    v_bucket_name,
    v_storage_path,
    coalesce(v_mime_type, 'image/png'),
    true,
    coalesce(v_generation_meta, '{}'::jsonb)
  )
  on conflict (bucket_name, storage_path) do update
    set mime_type = excluded.mime_type,
        is_published = excluded.is_published,
        metadata = excluded.metadata,
        updated_at = now()
  returning id into v_asset_id;

  update public.reading_passages
  set cover_media_asset_id = v_asset_id,
      cover_bucket_name = v_bucket_name,
      cover_storage_path = v_storage_path,
      cover_alt_text = coalesce(v_alt_text, title),
      cover_generation_meta = v_generation_meta,
      updated_at = now(),
      updated_by = auth.uid()
  where id = v_passage_id;

  if v_old_asset_id is not null and (
    coalesce(v_old_bucket_name, '') <> v_bucket_name
    or coalesce(v_old_storage_path, '') <> v_storage_path
  ) then
    delete from public.media_assets
    where id = v_old_asset_id;
  end if;

  perform public.write_audit_log(
    'admin.reading.cover.set',
    'reading',
    v_passage_id::text,
    jsonb_build_object(
      'bucket_name', v_bucket_name,
      'storage_path', v_storage_path,
      'mime_type', coalesce(v_mime_type, 'image/png')
    )
  );

  return public.admin_get_reading_detail(v_passage_id);
end;
$$;

create or replace function public.admin_clear_reading_cover(
  p_passage_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_old_asset_id uuid;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select rp.cover_media_asset_id
  into v_old_asset_id
  from public.reading_passages rp
  where rp.id = p_passage_id;

  if not found then
    raise exception 'reading passage not found';
  end if;

  update public.reading_passages
  set cover_media_asset_id = null,
      cover_bucket_name = null,
      cover_storage_path = null,
      cover_alt_text = null,
      cover_generation_meta = null,
      updated_at = now(),
      updated_by = auth.uid()
  where id = p_passage_id;

  if v_old_asset_id is not null then
    delete from public.media_assets
    where id = v_old_asset_id;
  end if;

  perform public.write_audit_log(
    'admin.reading.cover.cleared',
    'reading',
    p_passage_id::text,
    '{}'::jsonb
  );

  return public.admin_get_reading_detail(p_passage_id);
end;
$$;

create or replace function public.admin_create_reading_ai_run(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_run_id uuid := gen_random_uuid();
  v_job_type text := nullif(trim(coalesce(p_payload->>'job_type', '')), '');
  v_provider text := coalesce(nullif(trim(coalesce(p_payload->>'provider', '')), ''), 'gemini');
  v_model text := nullif(trim(coalesce(p_payload->>'model', '')), '');
  v_question_count integer := greatest(coalesce((p_payload->>'question_count')::integer, 3), 1);
  v_filter_snapshot jsonb := case
    when jsonb_typeof(p_payload->'filter_snapshot') = 'object' then p_payload->'filter_snapshot'
    else '{}'::jsonb
  end;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_job_type not in ('question_backfill', 'cover_backfill') then
    raise exception 'job_type invalid';
  end if;

  if jsonb_typeof(p_payload->'reading_ids') <> 'array' then
    raise exception 'reading_ids array required';
  end if;

  insert into public.reading_ai_runs (
    id,
    job_type,
    status,
    provider,
    model,
    question_count,
    filter_snapshot,
    created_by,
    updated_by
  )
  values (
    v_run_id,
    v_job_type,
    'queued',
    v_provider,
    coalesce(v_model, case when v_provider = 'openrouter' then 'arcee-ai/trinity-large-preview:free' else 'gemini-2.5-flash' end),
    v_question_count,
    v_filter_snapshot,
    auth.uid(),
    auth.uid()
  );

  insert into public.reading_ai_run_items (
    run_id,
    passage_id
  )
  select
    v_run_id,
    rp.id
  from public.reading_passages rp
  where rp.id in (
    select distinct nullif(trim(value::text, '"'), '')::uuid
    from jsonb_array_elements(p_payload->'reading_ids')
  );

  return public.admin_get_reading_ai_run(v_run_id);
end;
$$;

create or replace function public.admin_recalculate_reading_ai_run(
  p_run_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_run public.reading_ai_runs%rowtype;
  v_total_count integer := 0;
  v_processed_count integer := 0;
  v_succeeded_count integer := 0;
  v_failed_count integer := 0;
  v_skipped_count integer := 0;
  v_has_processing boolean := false;
  v_has_queued boolean := false;
  v_status text := 'queued';
  v_failure_samples jsonb := '[]'::jsonb;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select *
  into v_run
  from public.reading_ai_runs
  where id = p_run_id;

  if v_run.id is null then
    raise exception 'reading ai run not found';
  end if;

  select
    count(*)::integer,
    count(*) filter (where item.status in ('succeeded', 'failed', 'skipped'))::integer,
    count(*) filter (where item.status = 'succeeded')::integer,
    count(*) filter (where item.status = 'failed')::integer,
    count(*) filter (where item.status = 'skipped')::integer,
    bool_or(item.status = 'processing'),
    bool_or(item.status = 'queued')
  into
    v_total_count,
    v_processed_count,
    v_succeeded_count,
    v_failed_count,
    v_skipped_count,
    v_has_processing,
    v_has_queued
  from public.reading_ai_run_items item
  where item.run_id = p_run_id;

  select coalesce(
    jsonb_agg(sample.message order by sample.message),
    '[]'::jsonb
  )
  into v_failure_samples
  from (
    select concat(coalesce(rp.title, item.passage_id::text), ': ', left(coalesce(item.error_message, 'Bilinmeyen hata'), 180)) as message
    from public.reading_ai_run_items item
    join public.reading_passages rp
      on rp.id = item.passage_id
    where item.run_id = p_run_id
      and item.status = 'failed'
    order by item.updated_at desc
    limit 5
  ) sample;

  if v_total_count = 0 or v_processed_count >= v_total_count then
    v_status := 'completed';
  elsif v_has_processing or v_run.started_at is not null then
    v_status := 'running';
  elsif v_has_queued then
    v_status := 'queued';
  else
    v_status := v_run.status;
  end if;

  update public.reading_ai_runs
  set status = v_status,
      total_count = v_total_count,
      processed_count = v_processed_count,
      succeeded_count = v_succeeded_count,
      failed_count = v_failed_count,
      skipped_count = v_skipped_count,
      started_at = case
        when started_at is not null then started_at
        when v_has_processing or v_processed_count > 0 then now()
        else started_at
      end,
      completed_at = case
        when v_status = 'completed' then coalesce(completed_at, now())
        else null
      end,
      updated_at = now(),
      updated_by = auth.uid()
  where id = p_run_id
  returning * into v_run;

  return jsonb_build_object(
    'id', v_run.id::text,
    'job_type', v_run.job_type,
    'status', v_run.status,
    'provider', v_run.provider,
    'model', v_run.model,
    'question_count', v_run.question_count,
    'total_count', v_run.total_count,
    'processed_count', v_run.processed_count,
    'succeeded_count', v_run.succeeded_count,
    'failed_count', v_run.failed_count,
    'skipped_count', v_run.skipped_count,
    'failure_samples', v_failure_samples,
    'started_at', v_run.started_at,
    'completed_at', v_run.completed_at,
    'updated_at', v_run.updated_at
  );
end;
$$;

create or replace function public.admin_get_reading_ai_run(
  p_run_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  return public.admin_recalculate_reading_ai_run(p_run_id);
end;
$$;

create or replace function public.admin_claim_reading_ai_run_items(
  p_run_id uuid,
  p_limit integer default 3
)
returns table (
  item_id uuid,
  passage_id uuid,
  passage_title text
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  update public.reading_ai_runs
  set status = 'running',
      started_at = coalesce(started_at, now()),
      updated_at = now(),
      updated_by = auth.uid()
  where id = p_run_id;

  return query
  with claim as (
    select item.id
    from public.reading_ai_run_items item
    where item.run_id = p_run_id
      and item.status = 'queued'
    order by item.created_at asc
    limit greatest(1, least(coalesce(p_limit, 3), 20))
    for update skip locked
  ),
  updated as (
    update public.reading_ai_run_items item
    set status = 'processing',
        started_at = coalesce(item.started_at, now()),
        updated_at = now(),
        attempt_count = item.attempt_count + 1
    from claim
    where item.id = claim.id
    returning item.id, item.passage_id
  )
  select
    updated.id,
    updated.passage_id,
    coalesce(rp.title, '')
  from updated
  join public.reading_passages rp
    on rp.id = updated.passage_id;
end;
$$;

create or replace function public.admin_mark_reading_ai_run_item(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_item_id uuid := nullif(trim(coalesce(p_payload->>'item_id', '')), '')::uuid;
  v_status text := nullif(trim(coalesce(p_payload->>'status', '')), '');
  v_error_message text := nullif(trim(coalesce(p_payload->>'error_message', '')), '');
  v_run_id uuid;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_item_id is null then
    raise exception 'item_id required';
  end if;

  if v_status not in ('succeeded', 'failed', 'skipped') then
    raise exception 'status invalid';
  end if;

  update public.reading_ai_run_items
  set status = v_status,
      error_message = v_error_message,
      completed_at = now(),
      updated_at = now()
  where id = v_item_id
  returning run_id into v_run_id;

  if v_run_id is null then
    raise exception 'reading ai run item not found';
  end if;

  return public.admin_recalculate_reading_ai_run(v_run_id);
end;
$$;

grant execute on function public.student_list_reading_catalog() to anon, authenticated;
grant execute on function public.admin_list_reading_passages() to authenticated;
grant execute on function public.admin_list_reading_passages_paged(text, text, text, boolean, boolean, integer, integer) to authenticated;
grant execute on function public.admin_get_reading_detail(uuid) to authenticated;
grant execute on function public.admin_upsert_reading_detail(jsonb) to authenticated;
grant execute on function public.admin_set_reading_cover(jsonb) to authenticated;
grant execute on function public.admin_clear_reading_cover(uuid) to authenticated;
grant execute on function public.admin_create_reading_ai_run(jsonb) to authenticated;
grant execute on function public.admin_recalculate_reading_ai_run(uuid) to authenticated;
grant execute on function public.admin_get_reading_ai_run(uuid) to authenticated;
grant execute on function public.admin_claim_reading_ai_run_items(uuid, integer) to authenticated;
grant execute on function public.admin_mark_reading_ai_run_item(jsonb) to authenticated;


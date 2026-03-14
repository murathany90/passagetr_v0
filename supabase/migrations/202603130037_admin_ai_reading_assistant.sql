alter table public.reading_passages
  add column if not exists ai_generated boolean not null default false,
  add column if not exists ai_generation_meta jsonb;

create table if not exists public.reading_passage_questions (
  id uuid primary key default gen_random_uuid(),
  passage_id uuid not null references public.reading_passages(id) on delete cascade,
  sort_order integer not null default 1,
  question text not null,
  options_json jsonb not null default '[]'::jsonb,
  correct_option_index integer not null,
  explanation text,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  constraint reading_passage_questions_sort_order_check check (sort_order > 0),
  constraint reading_passage_questions_correct_option_index_check check (
    correct_option_index >= 0
  ),
  constraint reading_passage_questions_options_json_array_check check (
    jsonb_typeof(options_json) = 'array'
  )
);

create index if not exists ix_reading_passage_questions_passage_sort_order
  on public.reading_passage_questions (passage_id, sort_order);

drop trigger if exists trg_reading_passage_questions_updated_at
  on public.reading_passage_questions;
create trigger trg_reading_passage_questions_updated_at
before update on public.reading_passage_questions
for each row execute function public.set_updated_at();

alter table public.reading_passage_questions enable row level security;

grant select on table public.reading_passage_questions to anon, authenticated;

drop policy if exists reading_passage_questions_select_all
  on public.reading_passage_questions;
create policy reading_passage_questions_select_all
on public.reading_passage_questions
for select
to anon, authenticated
using (true);

drop trigger if exists trg_reading_passage_questions_content_change
  on public.reading_passage_questions;
create trigger trg_reading_passage_questions_content_change
after insert or update or delete on public.reading_passage_questions
for each row execute function public.log_content_change(
  'reading_passage_questions',
  'readings'
);

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
      'ai_generated', v_ai_generated,
      'publish_at', v_publish_at,
      'unpublish_at', v_unpublish_at
    )
  );

  return public.admin_get_reading_detail(v_passage_id);
end;
$$;

grant execute on function public.admin_get_reading_detail(uuid) to authenticated;
grant execute on function public.admin_upsert_reading_detail(jsonb) to authenticated;

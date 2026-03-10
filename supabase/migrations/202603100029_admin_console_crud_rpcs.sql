drop function if exists public.admin_list_words();
drop function if exists public.admin_list_reading_passages();
drop function if exists public.admin_list_grammar_modules();

create or replace function public.admin_list_packs()
returns table (
  id text,
  name text,
  is_published boolean,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    p.id::text,
    coalesce(p.name, ''),
    coalesce(p.is_published, false),
    p.updated_at
  from public.packs p
  where public.is_admin_or_developer()
  order by p.name asc;
$$;

create or replace function public.admin_list_words()
returns table (
  id text,
  pack_id text,
  en_word text,
  tr_meaning text,
  pos text,
  example_en text,
  example_tr text,
  level text,
  notes text,
  is_published boolean,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    w.id::text,
    w.pack_id::text,
    coalesce(w.en_word, ''),
    coalesce(w.tr_meaning, ''),
    coalesce(w.pos, ''),
    coalesce(w.example_en, ''),
    w.example_tr,
    w.level,
    w.notes,
    coalesce(w.is_published, false),
    w.updated_at
  from public.words w
  where public.is_admin_or_developer()
  order by w.en_word asc;
$$;

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
    rp.updated_at
  from public.reading_passages rp
  where public.is_admin_or_developer()
  order by rp.title asc;
$$;

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
  updated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    gm.id::bigint,
    gm.sira,
    coalesce(gm.baslik, ''),
    coalesce(gm.dosya_adi, ''),
    coalesce(gm.toplam_sayfa, 0),
    coalesce(gm.icon, '📘'),
    coalesce(gm.renk, '#4776E6'),
    coalesce(gm.is_published, false),
    gm.updated_at
  from public.gramer_modulleri gm
  where public.is_admin_or_developer()
  order by gm.sira asc nulls last, gm.id asc;
$$;

create or replace function public.admin_set_content_publish_state(
  p_entity_type text,
  p_entity_id text,
  p_is_published boolean
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  case p_entity_type
    when 'pack' then
      update public.packs
      set is_published = p_is_published,
          published_at = case
            when p_is_published then coalesce(published_at, now())
            else null
          end,
          updated_at = now(),
          updated_by = auth.uid()
      where id::text = p_entity_id;
    when 'reading' then
      update public.reading_passages
      set is_published = p_is_published,
          published_at = case
            when p_is_published then coalesce(published_at, now())
            else null
          end,
          updated_at = now(),
          updated_by = auth.uid()
      where id::text = p_entity_id;
    when 'word' then
      update public.words
      set is_published = p_is_published,
          published_at = case
            when p_is_published then coalesce(published_at, now())
            else null
          end,
          updated_at = now(),
          updated_by = auth.uid()
      where id::text = p_entity_id;
    when 'grammar' then
      update public.gramer_modulleri
      set is_published = p_is_published,
          published_at = case
            when p_is_published then coalesce(published_at, now())
            else null
          end,
          updated_at = now(),
          updated_by = auth.uid()
      where id::text = p_entity_id;
    else
      raise exception 'invalid entity type';
  end case;

  if not found then
    raise exception 'target entity not found';
  end if;

  perform public.write_audit_log(
    case
      when p_is_published then 'content.published'
      else 'content.unpublished'
    end,
    p_entity_type,
    p_entity_id,
    jsonb_build_object('is_published', p_is_published)
  );
end;
$$;

create or replace function public.admin_upsert_pack(
  p_pack_id uuid default null,
  p_name text default null,
  p_is_published boolean default true
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_pack_id uuid := coalesce(p_pack_id, gen_random_uuid());
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if nullif(trim(coalesce(p_name, '')), '') is null then
    raise exception 'pack name required';
  end if;

  if p_pack_id is null then
    insert into public.packs (
      id,
      name,
      is_published,
      published_at,
      created_by,
      updated_by
    )
    values (
      v_pack_id,
      trim(p_name),
      coalesce(p_is_published, true),
      case when coalesce(p_is_published, true) then now() else null end,
      auth.uid(),
      auth.uid()
    );
  else
    update public.packs
    set name = trim(p_name),
        is_published = coalesce(p_is_published, is_published),
        published_at = case
          when coalesce(p_is_published, is_published) then coalesce(published_at, now())
          else null
        end,
        updated_at = now(),
        updated_by = auth.uid()
    where id = p_pack_id;

    if not found then
      raise exception 'pack not found';
    end if;
  end if;

  perform public.write_audit_log(
    case when p_pack_id is null then 'admin.pack.created' else 'admin.pack.updated' end,
    'pack',
    v_pack_id::text,
    jsonb_build_object(
      'name', trim(p_name),
      'is_published', coalesce(p_is_published, true)
    )
  );
end;
$$;

create or replace function public.admin_delete_pack(
  p_pack_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_name text;
  v_word_count integer := 0;
  v_reading_count integer := 0;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select name into v_name
  from public.packs
  where id = p_pack_id;

  if v_name is null then
    raise exception 'pack not found';
  end if;

  select count(*)::integer into v_word_count
  from public.words
  where pack_id = p_pack_id;

  select count(*)::integer into v_reading_count
  from public.reading_passages
  where pack_id = p_pack_id;

  delete from public.packs
  where id = p_pack_id;

  perform public.write_audit_log(
    'admin.pack.deleted',
    'pack',
    p_pack_id::text,
    jsonb_build_object(
      'name', v_name,
      'deleted_words', v_word_count,
      'deleted_readings', v_reading_count
    )
  );
end;
$$;

create or replace function public.admin_upsert_word(
  p_word_id uuid default null,
  p_pack_id uuid default null,
  p_en_word text default null,
  p_tr_meaning text default null,
  p_pos text default null,
  p_example_en text default null,
  p_example_tr text default null,
  p_level text default null,
  p_notes text default null,
  p_is_published boolean default true
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_word_id uuid := coalesce(p_word_id, gen_random_uuid());
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if p_pack_id is null then
    raise exception 'pack required';
  end if;

  if nullif(trim(coalesce(p_en_word, '')), '') is null then
    raise exception 'english word required';
  end if;

  if nullif(trim(coalesce(p_tr_meaning, '')), '') is null then
    raise exception 'turkish meaning required';
  end if;

  if nullif(trim(coalesce(p_pos, '')), '') is null then
    raise exception 'pos required';
  end if;

  if nullif(trim(coalesce(p_example_en, '')), '') is null then
    raise exception 'example sentence required';
  end if;

  if p_word_id is null then
    insert into public.words (
      id,
      pack_id,
      en_word,
      tr_meaning,
      pos,
      example_en,
      example_tr,
      level,
      notes,
      is_published,
      published_at,
      created_by,
      updated_by
    )
    values (
      v_word_id,
      p_pack_id,
      trim(p_en_word),
      trim(p_tr_meaning),
      trim(p_pos),
      trim(p_example_en),
      nullif(trim(coalesce(p_example_tr, '')), ''),
      nullif(trim(coalesce(p_level, '')), ''),
      nullif(trim(coalesce(p_notes, '')), ''),
      coalesce(p_is_published, true),
      case when coalesce(p_is_published, true) then now() else null end,
      auth.uid(),
      auth.uid()
    )
    on conflict (pack_id, en_word, pos) do update
      set tr_meaning = excluded.tr_meaning,
          example_en = excluded.example_en,
          example_tr = excluded.example_tr,
          level = excluded.level,
          notes = excluded.notes,
          is_published = excluded.is_published,
          published_at = case
            when excluded.is_published then coalesce(public.words.published_at, now())
            else null
          end,
          updated_at = now(),
          updated_by = auth.uid();
  else
    update public.words
    set pack_id = p_pack_id,
        en_word = trim(p_en_word),
        tr_meaning = trim(p_tr_meaning),
        pos = trim(p_pos),
        example_en = trim(p_example_en),
        example_tr = nullif(trim(coalesce(p_example_tr, '')), ''),
        level = nullif(trim(coalesce(p_level, '')), ''),
        notes = nullif(trim(coalesce(p_notes, '')), ''),
        is_published = coalesce(p_is_published, is_published),
        published_at = case
          when coalesce(p_is_published, is_published) then coalesce(published_at, now())
          else null
        end,
        updated_at = now(),
        updated_by = auth.uid()
    where id = p_word_id;

    if not found then
      raise exception 'word not found';
    end if;
  end if;

  perform public.write_audit_log(
    case when p_word_id is null then 'admin.word.created' else 'admin.word.updated' end,
    'word',
    v_word_id::text,
    jsonb_build_object(
      'pack_id', p_pack_id,
      'en_word', trim(p_en_word),
      'pos', trim(p_pos),
      'is_published', coalesce(p_is_published, true)
    )
  );
end;
$$;

create or replace function public.admin_delete_word(
  p_word_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_en_word text;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select en_word into v_en_word
  from public.words
  where id = p_word_id;

  if v_en_word is null then
    raise exception 'word not found';
  end if;

  delete from public.words
  where id = p_word_id;

  perform public.write_audit_log(
    'admin.word.deleted',
    'word',
    p_word_id::text,
    jsonb_build_object('en_word', v_en_word)
  );
end;
$$;

create or replace function public.admin_import_words(
  p_pack_id uuid,
  p_rows jsonb
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_row jsonb;
  v_count integer := 0;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if p_pack_id is null then
    raise exception 'pack required';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'rows array required';
  end if;

  for v_row in
    select value
    from jsonb_array_elements(p_rows)
  loop
    perform public.admin_upsert_word(
      null,
      p_pack_id,
      v_row->>'en_word',
      v_row->>'tr_meaning',
      coalesce(nullif(v_row->>'pos', ''), 'other'),
      coalesce(nullif(v_row->>'example_en', ''), v_row->>'en_word'),
      nullif(v_row->>'example_tr', ''),
      nullif(v_row->>'level', ''),
      nullif(v_row->>'notes', ''),
      coalesce((v_row->>'is_published')::boolean, true)
    );
    v_count := v_count + 1;
  end loop;

  perform public.write_audit_log(
    'admin.word.imported',
    'pack',
    p_pack_id::text,
    jsonb_build_object('row_count', v_count)
  );
end;
$$;

create or replace function public.admin_upsert_reading_passage(
  p_passage_id uuid default null,
  p_pack_id uuid default null,
  p_pack_name text default null,
  p_title text default null,
  p_level text default null,
  p_category text default null,
  p_tags_raw text default null,
  p_is_published boolean default true
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_passage_id uuid := coalesce(p_passage_id, gen_random_uuid());
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if nullif(trim(coalesce(p_title, '')), '') is null then
    raise exception 'title required';
  end if;

  if p_passage_id is null then
    insert into public.reading_passages (
      id,
      pack_id,
      pack_name,
      title,
      level,
      category,
      tags_raw,
      is_published,
      published_at,
      created_by,
      updated_by
    )
    values (
      v_passage_id,
      p_pack_id,
      nullif(trim(coalesce(p_pack_name, '')), ''),
      trim(p_title),
      nullif(trim(coalesce(p_level, '')), ''),
      nullif(trim(coalesce(p_category, '')), ''),
      nullif(trim(coalesce(p_tags_raw, '')), ''),
      coalesce(p_is_published, true),
      case when coalesce(p_is_published, true) then now() else null end,
      auth.uid(),
      auth.uid()
    );
  else
    update public.reading_passages
    set pack_id = p_pack_id,
        pack_name = nullif(trim(coalesce(p_pack_name, '')), ''),
        title = trim(p_title),
        level = nullif(trim(coalesce(p_level, '')), ''),
        category = nullif(trim(coalesce(p_category, '')), ''),
        tags_raw = nullif(trim(coalesce(p_tags_raw, '')), ''),
        is_published = coalesce(p_is_published, is_published),
        published_at = case
          when coalesce(p_is_published, is_published) then coalesce(published_at, now())
          else null
        end,
        updated_at = now(),
        updated_by = auth.uid()
    where id = p_passage_id;

    if not found then
      raise exception 'reading passage not found';
    end if;
  end if;

  perform public.write_audit_log(
    case when p_passage_id is null then 'admin.reading.created' else 'admin.reading.updated' end,
    'reading',
    v_passage_id::text,
    jsonb_build_object(
      'title', trim(p_title),
      'level', nullif(trim(coalesce(p_level, '')), ''),
      'category', nullif(trim(coalesce(p_category, '')), ''),
      'is_published', coalesce(p_is_published, true)
    )
  );
end;
$$;

create or replace function public.admin_delete_reading_passage(
  p_passage_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_title text;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select title into v_title
  from public.reading_passages
  where id = p_passage_id;

  if v_title is null then
    raise exception 'reading passage not found';
  end if;

  delete from public.reading_passages
  where id = p_passage_id;

  perform public.write_audit_log(
    'admin.reading.deleted',
    'reading',
    p_passage_id::text,
    jsonb_build_object('title', v_title)
  );
end;
$$;

create or replace function public.admin_upsert_grammar_module(
  p_module_id bigint default null,
  p_sira integer default null,
  p_baslik text default null,
  p_dosya_adi text default null,
  p_toplam_sayfa integer default 0,
  p_icon text default '📘',
  p_renk text default '#4776E6',
  p_is_published boolean default true
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_module_id bigint;
  v_sira integer;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if nullif(trim(coalesce(p_baslik, '')), '') is null then
    raise exception 'title required';
  end if;

  if nullif(trim(coalesce(p_dosya_adi, '')), '') is null then
    raise exception 'file name required';
  end if;

  if p_module_id is null then
    select coalesce(p_sira, coalesce(max(sira), 0) + 1)
    into v_sira
    from public.gramer_modulleri;

    insert into public.gramer_modulleri (
      sira,
      baslik,
      dosya_adi,
      toplam_sayfa,
      icon,
      renk,
      is_published,
      published_at,
      created_by,
      updated_by
    )
    values (
      v_sira,
      trim(p_baslik),
      trim(p_dosya_adi),
      greatest(coalesce(p_toplam_sayfa, 0), 0),
      coalesce(nullif(trim(coalesce(p_icon, '')), ''), '📘'),
      coalesce(nullif(trim(coalesce(p_renk, '')), ''), '#4776E6'),
      coalesce(p_is_published, true),
      case when coalesce(p_is_published, true) then now() else null end,
      auth.uid(),
      auth.uid()
    )
    returning id into v_module_id;
  else
    update public.gramer_modulleri
    set baslik = trim(p_baslik),
        dosya_adi = trim(p_dosya_adi),
        toplam_sayfa = greatest(coalesce(p_toplam_sayfa, 0), 0),
        icon = coalesce(nullif(trim(coalesce(p_icon, '')), ''), '📘'),
        renk = coalesce(nullif(trim(coalesce(p_renk, '')), ''), '#4776E6'),
        is_published = coalesce(p_is_published, is_published),
        published_at = case
          when coalesce(p_is_published, is_published) then coalesce(published_at, now())
          else null
        end,
        updated_at = now(),
        updated_by = auth.uid()
    where id = p_module_id
    returning id into v_module_id;

    if v_module_id is null then
      raise exception 'grammar module not found';
    end if;
  end if;

  perform public.write_audit_log(
    case when p_module_id is null then 'admin.grammar.created' else 'admin.grammar.updated' end,
    'grammar',
    v_module_id::text,
    jsonb_build_object(
      'title', trim(p_baslik),
      'file_name', trim(p_dosya_adi),
      'page_count', greatest(coalesce(p_toplam_sayfa, 0), 0),
      'is_published', coalesce(p_is_published, true)
    )
  );
end;
$$;

create or replace function public.admin_delete_grammar_module(
  p_module_id bigint
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_title text;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select baslik into v_title
  from public.gramer_modulleri
  where id = p_module_id;

  if v_title is null then
    raise exception 'grammar module not found';
  end if;

  delete from public.gramer_modulleri
  where id = p_module_id;

  with ordered as (
    select
      id,
      row_number() over (order by sira asc nulls last, id asc)::integer as next_order
    from public.gramer_modulleri
  )
  update public.gramer_modulleri gm
  set sira = ordered.next_order,
      updated_at = now(),
      updated_by = auth.uid()
  from ordered
  where gm.id = ordered.id;

  perform public.write_audit_log(
    'admin.grammar.deleted',
    'grammar',
    p_module_id::text,
    jsonb_build_object('title', v_title)
  );
end;
$$;

create or replace function public.admin_reorder_grammar_modules(
  p_module_ids bigint[]
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_expected_count integer := 0;
  v_payload_count integer := coalesce(array_length(p_module_ids, 1), 0);
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select count(*)::integer into v_expected_count
  from public.gramer_modulleri;

  if v_payload_count = 0 then
    raise exception 'module ids required';
  end if;

  if v_payload_count <> v_expected_count then
    raise exception 'full module order required';
  end if;

  update public.gramer_modulleri
  set sira = -(coalesce(sira, 0) + 1000),
      updated_at = now(),
      updated_by = auth.uid();

  with ordered as (
    select
      module_id,
      ordinality::integer as next_order
    from unnest(p_module_ids) with ordinality as source(module_id, ordinality)
  )
  update public.gramer_modulleri gm
  set sira = ordered.next_order,
      updated_at = now(),
      updated_by = auth.uid()
  from ordered
  where gm.id = ordered.module_id;

  perform public.write_audit_log(
    'admin.grammar.reordered',
    'grammar',
    null,
    jsonb_build_object('module_ids', p_module_ids)
  );
end;
$$;

grant execute on function public.admin_list_packs() to authenticated;
grant execute on function public.admin_list_words() to authenticated;
grant execute on function public.admin_list_reading_passages() to authenticated;
grant execute on function public.admin_list_grammar_modules() to authenticated;
grant execute on function public.admin_set_content_publish_state(text, text, boolean) to authenticated;
grant execute on function public.admin_upsert_pack(uuid, text, boolean) to authenticated;
grant execute on function public.admin_delete_pack(uuid) to authenticated;
grant execute on function public.admin_upsert_word(uuid, uuid, text, text, text, text, text, text, text, boolean) to authenticated;
grant execute on function public.admin_delete_word(uuid) to authenticated;
grant execute on function public.admin_import_words(uuid, jsonb) to authenticated;
grant execute on function public.admin_upsert_reading_passage(uuid, uuid, text, text, text, text, text, boolean) to authenticated;
grant execute on function public.admin_delete_reading_passage(uuid) to authenticated;
grant execute on function public.admin_upsert_grammar_module(bigint, integer, text, text, integer, text, text, boolean) to authenticated;
grant execute on function public.admin_delete_grammar_module(bigint) to authenticated;
grant execute on function public.admin_reorder_grammar_modules(bigint[]) to authenticated;

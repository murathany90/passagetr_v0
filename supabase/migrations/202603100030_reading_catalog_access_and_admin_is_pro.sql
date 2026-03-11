drop function if exists public.student_list_reading_catalog();
drop function if exists public.admin_list_reading_passages();
drop function if exists public.admin_upsert_reading_passage(uuid, uuid, text, text, text, text, text, boolean);

create or replace function public.student_list_reading_catalog()
returns table (
  id text,
  pack_id text,
  title text,
  level text,
  category text,
  tags_raw text,
  summary text,
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

with ordered_readings as (
  select
    rp.id,
    row_number() over (
      order by
        case
          when substring(coalesce(rp.title, '') from '^\d+') is null then 2147483647
          else substring(coalesce(rp.title, '') from '^\d+')::integer
        end asc,
        lower(coalesce(rp.title, '')) asc
    ) as seq_no
  from public.reading_passages rp
  where coalesce(rp.is_published, false)
)
update public.reading_passages rp
set is_pro = ordered_readings.seq_no > 50
from ordered_readings
where ordered_readings.id = rp.id;

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
        ccl.entity_type in ('reading_passage_sentences', 'reading_passage_words')
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
    coalesce(rp.is_pro, false),
    coalesce(rp.is_published, false),
    rp.updated_at
  from public.reading_passages rp
  where public.is_admin_or_developer()
  order by rp.title asc;
$$;

create or replace function public.admin_upsert_reading_passage(
  p_passage_id uuid default null,
  p_pack_id uuid default null,
  p_pack_name text default null,
  p_title text default null,
  p_level text default null,
  p_category text default null,
  p_tags_raw text default null,
  p_is_pro boolean default false,
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
      is_pro,
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
      coalesce(p_is_pro, false),
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
        is_pro = coalesce(p_is_pro, is_pro),
        is_published = coalesce(p_is_published, is_published),
        published_at = case
          when coalesce(p_is_published, is_published) then coalesce(published_at, now())
          else null
        end,
        updated_by = auth.uid(),
        updated_at = now()
    where id = p_passage_id;

    if not found then
      raise exception 'reading passage not found';
    end if;
  end if;
end;
$$;

grant execute on function public.student_list_reading_catalog() to anon, authenticated;
grant execute on function public.pull_content_changes(text, bigint, integer) to anon, authenticated;
grant execute on function public.admin_list_reading_passages() to authenticated;
grant execute on function public.admin_upsert_reading_passage(uuid, uuid, text, text, text, text, text, boolean, boolean) to authenticated;

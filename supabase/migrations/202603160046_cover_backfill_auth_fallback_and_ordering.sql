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
  v_provider text := nullif(trim(coalesce(p_payload->>'provider', '')), '');
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

  if v_job_type = 'cover_backfill' then
    v_provider := coalesce(v_provider, 'cover_auto');
    v_model := coalesce(v_model, 'auto');
    if v_provider not in ('cover_auto', 'imagerouter', 'huggingface') then
      raise exception 'cover provider invalid';
    end if;
  else
    v_provider := coalesce(v_provider, 'gemini');
    v_model := coalesce(
      v_model,
      case
        when v_provider = 'openrouter' then 'arcee-ai/trinity-large-preview:free'
        else 'gemini-2.5-flash'
      end
    );
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
    v_model,
    v_question_count,
    v_filter_snapshot,
    auth.uid(),
    auth.uid()
  );

  insert into public.reading_ai_run_items (
    run_id,
    passage_id
  )
  with requested_ids as (
    select
      nullif(trim(value::text, '"'), '')::uuid as passage_id,
      ord::integer as ord
    from jsonb_array_elements(p_payload->'reading_ids') with ordinality as source(value, ord)
  )
  select
    v_run_id,
    rp.id
  from public.reading_passages rp
  join requested_ids requested
    on requested.passage_id = rp.id
  order by
    case
      when v_job_type = 'cover_backfill' then lower(coalesce(rp.title, ''))
      else null
    end asc nulls last,
    case
      when v_job_type = 'cover_backfill' then rp.id::text
      else null
    end asc nulls last,
    requested.ord asc;

  return public.admin_get_reading_ai_run(v_run_id);
end;
$$;
